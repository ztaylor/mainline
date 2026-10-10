import CryptoKit
import Foundation
import XCTest
@testable import asc

final class ASCTests: XCTestCase {
    func testOnlyAppleURLsCanReceiveCredentials() throws {
        for path in ["https://example.com/v1/apps", "https://api.appstoreconnect.apple.com.evil.test/v1/apps",
                     "https://api.appstoreconnect.apple.com@evil.test/v1/apps", "http://api.appstoreconnect.apple.com/v1/apps",
                     "https://api.appstoreconnect.apple.com:444/v1/apps", "/v1/apps#fragment", "not-a-path"] {
            XCTAssertThrowsError(try ASCClient.apiURL(path), path)
        }
        let url = try ASCClient.apiURL("/v1/apps?limit=1", query: ["filter[bundleId]": "com.example.test"])
        XCTAssertEqual(url.host, "api.appstoreconnect.apple.com")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.count, 2)
        XCTAssertEqual(try ASCClient.apiURL("https://api.appstoreconnect.apple.com/v1/apps?cursor=next").host,
                       "api.appstoreconnect.apple.com")
    }

    func testBuildMustBeAvailableForTesting() throws {
        for state in ["READY_FOR_BETA_TESTING", "IN_BETA_TESTING"] {
            XCTAssertTrue(try buildIsReady(processing: "VALID", internalState: state, buildNumber: "1"))
        }
        for state in ["PROCESSING", "?", "IN_EXPORT_COMPLIANCE_REVIEW", "FUTURE_STATE"] {
            XCTAssertFalse(try buildIsReady(processing: "VALID", internalState: state, buildNumber: "1"))
        }
        for state in ["MISSING_EXPORT_COMPLIANCE", "PROCESSING_EXCEPTION", "EXPIRED"] {
            XCTAssertThrowsError(try buildIsReady(processing: "VALID", internalState: state, buildNumber: "1"))
        }
        for state in ["FAILED", "INVALID"] {
            XCTAssertThrowsError(try buildIsReady(processing: state, internalState: "?", buildNumber: "1"))
        }
        XCTAssertFalse(try buildIsReady(processing: "PROCESSING", internalState: "IN_BETA_TESTING", buildNumber: "1"))
    }

    func testArgumentsDoNotSwallowPositionalsAfterFlags() throws {
        let args = Args(["group", "ensure", "--external", "123", "Testers"])
        try args.validate()
        XCTAssertEqual(args.positional, ["group", "ensure", "123", "Testers"])
        for raw in [["build", "wait"], ["check", "--typo"], ["tester", "add", "1", "a@example.com", "--first"]] {
            XCTAssertThrowsError(try Args(raw).validate())
        }
        for value in ["0", "-1", "abc", "999999999999999999999"] {
            XCTAssertThrowsError(try Args(["--interval", value]).positiveInt("interval", default: 30))
        }
    }

    private func withClient(_ body: (ASCClient) async throws -> Void) async throws {
        let key = P256.Signing.PrivateKey()
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try key.pemRepresentation.write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path); StubProtocol.responses = []; StubProtocol.requests = [] }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let client = try ASCClient(credentials: Credentials(keyID: "TESTKEY", issuerID: "issuer", keyPath: path.path), configuration: config)
        try await body(client)
    }

    func testPaginationFollowsNextAndRejectsTruncation() async throws {
        try await withClient { client in
            StubProtocol.responses = [(200, ["data": [["id": "1"]], "links": ["next": "https://api.appstoreconnect.apple.com/v1/apps?cursor=next"]]),
                                      (200, ["data": [["id": "2"]]])]
            let results = try await client.getAll("/v1/apps")
            XCTAssertEqual(results.map(\.id), ["1", "2"])
            XCTAssertEqual(StubProtocol.requests.count, 2)
            XCTAssertTrue(StubProtocol.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true })
            StubProtocol.responses = [(200, ["data": [["id": "1"]], "links": ["next": "/v1/apps?cursor=next"]])]
            do {
                _ = try await client.getAll("/v1/apps", maxPages: 1)
                XCTFail("must not return an incomplete collection")
            } catch ASCError.http { }
            XCTAssertTrue(StubProtocol.responses.isEmpty)
        }
    }

    func testMutationsAreNotReplayedAfterServerFailure() async throws {
        try await withClient { client in
            StubProtocol.responses = [(503, [:])]
            do {
                try await client.request("POST", "/v1/betaGroups", body: ["data": [:]])
                XCTFail("expected API error")
            } catch ASCError.http(let status, _) { XCTAssertEqual(status, 503) }
            XCTAssertEqual(StubProtocol.requests.count, 1)
        }
    }

    func testRateLimitedMutationsAreRetried() async throws {
        try await withClient { client in
            client.retryDelay = 0
            StubProtocol.responses = [(429, [:]), (201, ["data": ["id": "group"]])]
            let json = try await client.request("POST", "/v1/betaGroups", body: ["data": [:]])
            XCTAssertEqual((json["data"] as? JSON)?["id"] as? String, "group")
            XCTAssertEqual(StubProtocol.requests.count, 2)
        }
    }

    func testExistingGroupMustMatchDistributionRequirements() async throws {
        try await withClient { client in
            for attributes: JSON in [
                ["name": "Internal", "isInternalGroup": false, "hasAccessToAllBuilds": true],
                ["name": "Internal", "isInternalGroup": true, "hasAccessToAllBuilds": false]
            ] {
                StubProtocol.responses = [(200, ["data": [["id": "group", "attributes": attributes]]])]
                do {
                    try await ensureGroup(client, appID: "app", name: "Internal", external: false)
                    XCTFail("incompatible group must not be accepted")
                } catch ASCError.config { }
            }
            XCTAssertEqual(StubProtocol.requests.count, 2)
        }
    }

    func testJWTSignatureAndClaims() throws {
        let key = P256.Signing.PrivateKey()
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try key.pemRepresentation.write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }
        for issuer in ["test-issuer", nil] {
            let token = try makeToken(Credentials(keyID: "TESTKEY", issuerID: issuer, keyPath: path.path))
            let parts = token.split(separator: ".").map(String.init)
            XCTAssertEqual(parts.count, 3)
            func decode(_ part: String) throws -> Data {
                let base = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                return try XCTUnwrap(Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4)))
            }
            let claims = try XCTUnwrap(JSONSerialization.jsonObject(with: decode(parts[1])) as? JSON)
            XCTAssertEqual(claims["aud"] as? String, "appstoreconnect-v1")
            XCTAssertEqual(claims["iss"] as? String, issuer)
            XCTAssertEqual(claims["sub"] as? String, issuer == nil ? "user" : nil)
            XCTAssertEqual((claims["exp"] as! Int) - (claims["iat"] as! Int), 900)
            let signature = try P256.Signing.ECDSASignature(rawRepresentation: decode(parts[2]))
            XCTAssertTrue(key.publicKey.isValidSignature(signature, for: Data((parts[0] + "." + parts[1]).utf8)))
        }
    }
}

/// Intercepts all networking in client tests; no Apple account or server is used.
private final class StubProtocol: URLProtocol {
    static var responses: [(Int, JSON)] = []
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        guard !Self.responses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, json) = Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
