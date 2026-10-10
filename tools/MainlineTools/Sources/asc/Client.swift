import CryptoKit
import Foundation

// MARK: - Errors

enum ASCError: Error, CustomStringConvertible {
    case config(String)
    case usage(String)
    case http(status: Int, message: String)

    var description: String {
        switch self {
        case .config(let m): return "config error: \(m)"
        case .usage(let m): return "usage: \(m)"
        case .http(let status, let m): return "App Store Connect API error (HTTP \(status)): \(m)"
        }
    }
}

// MARK: - Credentials

/// Read from the environment (bin/mainline loads ~/.mainline/credentials.env).
///   ASC_KEY_ID     – the API key ID (10 chars)
///   ASC_ISSUER_ID  – issuer UUID for Team keys; leave empty for Individual keys
///   ASC_KEY_PATH   – path to AuthKey_<ID>.p8
struct Credentials {
    let keyID: String
    let issuerID: String?
    let keyPath: String

    static func fromEnvironment() throws -> Credentials {
        let env = ProcessInfo.processInfo.environment
        guard let keyID = env["ASC_KEY_ID"], !keyID.isEmpty else {
            throw ASCError.config("ASC_KEY_ID is not set (see docs/01-one-time-setup.md)")
        }
        guard let rawPath = env["ASC_KEY_PATH"], !rawPath.isEmpty else {
            throw ASCError.config("ASC_KEY_PATH is not set (see docs/01-one-time-setup.md)")
        }
        let path = (rawPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw ASCError.config("API key file not found at \(path)")
        }
        let issuer = env["ASC_ISSUER_ID"].flatMap { $0.isEmpty ? nil : $0 }
        return Credentials(keyID: keyID, issuerID: issuer, keyPath: path)
    }
}

// MARK: - JWT (ES256)

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// Builds a short-lived App Store Connect token.
/// Team keys put the issuer in `iss`; Individual keys use `sub: "user"` instead.
func makeToken(_ creds: Credentials, lifetime: Int = 15 * 60) throws -> String {
    let pem = try String(contentsOfFile: creds.keyPath, encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let now = Int(Date().timeIntervalSince1970)

    let header: [String: Any] = ["alg": "ES256", "kid": creds.keyID, "typ": "JWT"]
    var payload: [String: Any] = ["iat": now, "exp": now + lifetime, "aud": "appstoreconnect-v1"]
    if let issuer = creds.issuerID {
        payload["iss"] = issuer
    } else {
        payload["sub"] = "user"
    }

    let encode = { (obj: [String: Any]) throws -> String in
        base64URL(try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]))
    }
    let signingInput = try encode(header) + "." + encode(payload)
    let signature = try key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

// MARK: - HTTP client

typealias JSON = [String: Any]

final class ASCClient {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let creds: Credentials
    private var token: String
    private var tokenIssued = Date()

    init(credentials: Credentials) throws {
        creds = credentials
        token = try makeToken(credentials)
    }

    private func freshToken() throws -> String {
        // Tokens live 15 minutes; refresh well before expiry for long waits.
        if Date().timeIntervalSince(tokenIssued) > 10 * 60 {
            token = try makeToken(creds)
            tokenIssued = Date()
        }
        return token
    }

    /// `path` may be an API path ("/v1/apps") or an absolute URL (pagination `links.next`).
    @discardableResult
    func request(_ method: String, _ path: String, query: [String: String] = [:], body: JSON? = nil) async throws -> JSON {
        var components: URLComponents
        if path.hasPrefix("https://") {
            components = URLComponents(string: path)!
        } else {
            // String concatenation keeps any "?query" in `path` intact (useful for `asc api`).
            guard let parsed = URLComponents(string: baseURL.absoluteString + path) else {
                throw ASCError.usage("invalid API path: \(path)")
            }
            components = parsed
        }
        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? [])
                + query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var attempt = 0
        while true {
            attempt += 1
            var req = URLRequest(url: components.url!)
            req.httpMethod = method
            req.setValue("Bearer \(try freshToken())", forHTTPHeaderField: "Authorization")
            if let body {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // Retry rate limiting and transient server errors with backoff.
            if (status == 429 || status >= 500) && attempt < 4 {
                try await Task.sleep(nanoseconds: UInt64(attempt * 5) * 1_000_000_000)
                continue
            }

            let json = (data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data)) as? JSON ?? [:]
            guard (200..<300).contains(status) else {
                throw ASCError.http(status: status, message: Self.errorMessage(json, raw: data))
            }
            return json
        }
    }

    /// GET a collection and follow `links.next` until exhausted.
    func getAll(_ path: String, query: [String: String] = [:], maxPages: Int = 20) async throws -> [JSON] {
        var results: [JSON] = []
        var page = try await request("GET", path, query: query)
        for _ in 0..<maxPages {
            results += page["data"] as? [JSON] ?? []
            guard let next = (page["links"] as? JSON)?["next"] as? String else { break }
            page = try await request("GET", next)
        }
        return results
    }

    private static func errorMessage(_ json: JSON, raw: Data) -> String {
        if let errors = json["errors"] as? [JSON], !errors.isEmpty {
            return errors.map { e in
                [e["code"], e["title"], e["detail"]].compactMap { $0 as? String }.joined(separator: " — ")
            }.joined(separator: "\n")
        }
        return String(data: raw, encoding: .utf8) ?? "<no body>"
    }
}

// MARK: - JSON:API helpers

extension Dictionary where Key == String, Value == Any {
    var id: String { self["id"] as? String ?? "" }
    var attributes: JSON { self["attributes"] as? JSON ?? [:] }
    func attr(_ key: String) -> String? {
        switch attributes[key] {
        case let s as String: return s
        case let b as Bool: return String(b)
        case let n as NSNumber: return n.stringValue
        default: return nil
        }
    }
}
