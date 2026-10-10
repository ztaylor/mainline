import Foundation

// asc — the small slice of the App Store Connect API that mainline needs.
//
// Output contract (so shell scripts can consume it):
//   * the primary result (an ID, a number) is printed alone on stdout
//   * progress and diagnostics go to stderr
//   * exit codes: 0 ok · 1 error · 2 timeout · 3 not found · 64 usage

let usage = """
usage: asc <command> [args]

  check                                     Validate credentials and list visible apps
  bundle-id ensure <identifier> <name>      Register an iOS bundle ID if missing; prints its resource ID
  app find <bundle-identifier>              Print the App Store Connect app ID (exit 3 if no app record)
  build next-number <app-id>                Print (highest uploaded build number) + 1
  build list <app-id> [--limit N]           Show recent builds and their TestFlight state
  build wait <app-id> <build-number> [--timeout SECS] [--interval SECS]
                                            Wait until the build finishes processing; prints build ID
  group ensure <app-id> <name> [--external] Find or create a TestFlight group (internal by default); prints group ID
  tester add <group-id> <email> [--first NAME] [--last NAME]
                                            Add a tester to a group (creating the tester if needed)
  api <METHOD> <path> [json-body]           Raw API call; prints the JSON response

Credentials come from ASC_KEY_ID, ASC_ISSUER_ID (empty for Individual keys) and ASC_KEY_PATH.
"""

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Minimal argument parser: positionals plus `--name value` / `--flag` options.
struct Args {
    var positional: [String] = []
    var options: [String: String] = [:]

    init(_ raw: [String]) {
        var i = 0
        while i < raw.count {
            let arg = raw[i]
            if arg.hasPrefix("--") {
                let name = String(arg.dropFirst(2))
                if i + 1 < raw.count, !raw[i + 1].hasPrefix("--") {
                    options[name] = raw[i + 1]
                    i += 1
                } else {
                    options[name] = "true"
                }
            } else {
                positional.append(arg)
            }
            i += 1
        }
    }

    func at(_ index: Int, _ name: String) throws -> String {
        guard index < positional.count else { throw ASCError.usage("missing <\(name)>\n\n\(usage)") }
        return positional[index]
    }
}

struct NotFound: Error { let message: String }
struct TimedOut: Error { let message: String }

// MARK: - Commands

func check(_ api: ASCClient) async throws {
    let apps = try await api.getAll("/v1/apps", query: ["limit": "200", "fields[apps]": "name,bundleId"])
    log("Credentials OK. \(apps.count) app record(s) visible:")
    for app in apps {
        log("  \(app.id)  \(app.attr("bundleId") ?? "?")  \(app.attr("name") ?? "?")")
    }
    print("ok")
}

func ensureBundleID(_ api: ASCClient, identifier: String, name: String) async throws {
    let existing = try await api.getAll("/v1/bundleIds", query: [
        "filter[identifier]": identifier, "fields[bundleIds]": "identifier,name,platform", "limit": "200",
    ])
    // The filter is a prefix match, so compare exactly.
    if let match = existing.first(where: { $0.attr("identifier") == identifier }) {
        log("Bundle ID \(identifier) already registered.")
        print(match.id)
        return
    }
    // Portal names allow letters, numbers and spaces only.
    let safeName = String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " })
    let created = try await api.request("POST", "/v1/bundleIds", body: [
        "data": [
            "type": "bundleIds",
            "attributes": ["identifier": identifier, "name": safeName.isEmpty ? "App" : safeName, "platform": "IOS"],
        ],
    ])
    log("Registered bundle ID \(identifier).")
    print((created["data"] as? JSON)?.id ?? "")
}

func findApp(_ api: ASCClient, bundleID: String) async throws {
    let apps = try await api.getAll("/v1/apps", query: ["filter[bundleId]": bundleID, "fields[apps]": "name,bundleId"])
    guard let app = apps.first(where: { $0.attr("bundleId") == bundleID }) else {
        throw NotFound(message: "No App Store Connect app record for \(bundleID). Create it on the web (docs/web-steps.md#create-the-app-record).")
    }
    log("Found app \"\(app.attr("name") ?? "?")\" for \(bundleID).")
    print(app.id)
}

func nextBuildNumber(_ api: ASCClient, appID: String) async throws {
    let builds = try await api.getAll("/v1/builds", query: [
        "filter[app]": appID, "fields[builds]": "version", "limit": "200",
    ])
    // Build numbers are plain integers in mainline; ignore anything else.
    let highest = builds.compactMap { $0.attr("version").flatMap(Int.init) }.max() ?? 0
    log("Highest uploaded build number: \(highest == 0 ? "none" : String(highest))")
    print(highest + 1)
}

/// Resolve `included` resources (JSON:API compound documents) by type+id.
func included(_ response: JSON, type: String, id: String?) -> JSON? {
    guard let id else { return nil }
    return (response["included"] as? [JSON])?.first { $0["type"] as? String == type && $0.id == id }
}

func relatedID(_ resource: JSON, _ relationship: String) -> String? {
    (((resource["relationships"] as? JSON)?[relationship] as? JSON)?["data"] as? JSON)?.id
}

func listBuilds(_ api: ASCClient, appID: String, limit: String) async throws {
    let response = try await api.request("GET", "/v1/builds", query: [
        "filter[app]": appID, "sort": "-uploadedDate", "limit": limit,
        "include": "preReleaseVersion,buildBetaDetail",
    ])
    let builds = response["data"] as? [JSON] ?? []
    if builds.isEmpty { log("No builds uploaded yet.") }
    print("VERSION   BUILD  PROCESSING  TESTFLIGHT (internal)        UPLOADED")
    for b in builds {
        let version = included(response, type: "preReleaseVersions", id: relatedID(b, "preReleaseVersion"))?.attr("version") ?? "?"
        let beta = included(response, type: "buildBetaDetails", id: relatedID(b, "buildBetaDetail"))
        let row = [
            version.padding(toLength: 9, withPad: " ", startingAt: 0),
            (b.attr("version") ?? "?").padding(toLength: 6, withPad: " ", startingAt: 0),
            (b.attr("processingState") ?? "?").padding(toLength: 11, withPad: " ", startingAt: 0),
            (beta?.attr("internalBuildState") ?? "-").padding(toLength: 28, withPad: " ", startingAt: 0),
            b.attr("uploadedDate") ?? "",
        ]
        print(row.joined(separator: " "))
    }
}

func waitForBuild(_ api: ASCClient, appID: String, buildNumber: String, timeout: Int, interval: Int) async throws {
    let deadline = Date().addingTimeInterval(TimeInterval(timeout))
    var lastState = ""
    while Date() < deadline {
        let response = try await api.request("GET", "/v1/builds", query: [
            "filter[app]": appID, "filter[version]": buildNumber, "sort": "-uploadedDate", "limit": "1",
            "include": "buildBetaDetail",
        ])
        if let build = (response["data"] as? [JSON])?.first {
            let processing = build.attr("processingState") ?? "?"
            let beta = included(response, type: "buildBetaDetails", id: relatedID(build, "buildBetaDetail"))
            let internalState = beta?.attr("internalBuildState") ?? "?"
            let state = "\(processing) / \(internalState)"
            if state != lastState { log("Build \(buildNumber): \(state)"); lastState = state }

            switch processing {
            case "VALID":
                if internalState == "MISSING_EXPORT_COMPLIANCE" {
                    log("warning: build needs an export-compliance answer. Set ITSAppUsesNonExemptEncryption in Info.plist (see docs/04-troubleshooting.md).")
                }
                // internalBuildState can lag processingState by a few seconds; keep polling until it settles.
                if internalState == "PROCESSING" || internalState == "?" { break }
                print(build.id)
                return
            case "FAILED", "INVALID":
                throw ASCError.http(status: 0, message: "Build \(buildNumber) processing ended in \(processing). Check email from App Store Connect for details.")
            default:
                break
            }
        } else if lastState != "not visible" {
            log("Build \(buildNumber): uploaded, not yet visible in App Store Connect…")
            lastState = "not visible"
        }
        try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
    }
    throw TimedOut(message: "Timed out after \(timeout)s waiting for build \(buildNumber) (last state: \(lastState)). It may still finish; check `mainline status`.")
}

func ensureGroup(_ api: ASCClient, appID: String, name: String, external: Bool) async throws {
    let groups = try await api.getAll("/v1/apps/\(appID)/betaGroups", query: ["limit": "200"])
    if let match = groups.first(where: { $0.attr("name") == name }) {
        log("TestFlight group \"\(name)\" exists.")
        print(match.id)
        return
    }
    var attributes: JSON = ["name": name, "isInternalGroup": !external]
    if !external { attributes["hasAccessToAllBuilds"] = true }  // new builds reach internal testers automatically
    let created = try await api.request("POST", "/v1/betaGroups", body: [
        "data": [
            "type": "betaGroups",
            "attributes": attributes,
            "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
        ],
    ])
    log("Created \(external ? "external" : "internal") TestFlight group \"\(name)\".")
    print((created["data"] as? JSON)?.id ?? "")
}

func addTester(_ api: ASCClient, groupID: String, email: String, first: String?, last: String?) async throws {
    // Creating the tester with a group relationship works for both new and existing testers, and is the only
    // way that reliably adds an existing tester to *another app's* internal group (the relationship endpoint
    // answers 409 "Tester(s) cannot be assigned" there). Fall back to the relationship endpoint on conflict.
    let members = try await api.getAll("/v1/betaGroups/\(groupID)/betaTesters", query: ["limit": "200"])
    if let member = members.first(where: { $0.attr("email")?.lowercased() == email.lowercased() }) {
        log("Tester \(email) is already in the group.")
        print(member.id)
        return
    }
    var attributes: JSON = ["email": email]
    if let first { attributes["firstName"] = first }
    if let last { attributes["lastName"] = last }
    do {
        let created = try await api.request("POST", "/v1/betaTesters", body: [
            "data": [
                "type": "betaTesters",
                "attributes": attributes,
                "relationships": ["betaGroups": ["data": [["type": "betaGroups", "id": groupID]]]],
            ],
        ])
        log("Tester \(email) is in the group.")
        print((created["data"] as? JSON)?.id ?? "")
    } catch ASCError.http(let status, _) where status == 409 {
        let existing = try await api.getAll("/v1/betaTesters", query: ["filter[email]": email, "limit": "10"])
        guard let tester = existing.first(where: { $0.attr("email")?.lowercased() == email.lowercased() }) else { throw ASCError.http(status: 409, message: "tester \(email) conflicts but cannot be found") }
        try await api.request("POST", "/v1/betaGroups/\(groupID)/relationships/betaTesters", body: [
            "data": [["type": "betaTesters", "id": tester.id]],
        ])
        log("Added existing tester \(email) to group.")
        print(tester.id)
    }
}

func rawAPI(_ api: ASCClient, method: String, path: String, body: String?) async throws {
    let json = try body.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as? JSON ?? [:] }
    let response = try await api.request(method.uppercased(), path, body: json)
    let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8) ?? "")
}

// MARK: - Entry point

let args = Args(Array(CommandLine.arguments.dropFirst()))
let command = args.positional.first ?? "help"
let sub = args.positional.count > 1 ? args.positional[1] : ""

do {
    if ["help", "-h", "--help"].contains(command) || args.options["help"] != nil {
        print(usage)
        exit(0)
    }
    let api = try ASCClient(credentials: try Credentials.fromEnvironment())

    switch (command, sub) {
    case ("check", _):
        try await check(api)
    case ("bundle-id", "ensure"):
        try await ensureBundleID(api, identifier: try args.at(2, "identifier"), name: try args.at(3, "name"))
    case ("app", "find"):
        try await findApp(api, bundleID: try args.at(2, "bundle-identifier"))
    case ("build", "next-number"):
        try await nextBuildNumber(api, appID: try args.at(2, "app-id"))
    case ("build", "list"):
        try await listBuilds(api, appID: try args.at(2, "app-id"), limit: args.options["limit"] ?? "10")
    case ("build", "wait"):
        try await waitForBuild(
            api, appID: try args.at(2, "app-id"), buildNumber: try args.at(3, "build-number"),
            timeout: Int(args.options["timeout"] ?? "") ?? 1800, interval: Int(args.options["interval"] ?? "") ?? 30)
    case ("group", "ensure"):
        try await ensureGroup(api, appID: try args.at(2, "app-id"), name: try args.at(3, "name"),
                              external: args.options["external"] != nil)
    case ("tester", "add"):
        try await addTester(api, groupID: try args.at(2, "group-id"), email: try args.at(3, "email"),
                            first: args.options["first"], last: args.options["last"])
    case ("api", _):
        try await rawAPI(api, method: try args.at(1, "METHOD"), path: try args.at(2, "path"),
                         body: args.positional.count > 3 ? args.positional[3] : nil)
    default:
        throw ASCError.usage("unknown command '\(args.positional.joined(separator: " "))'\n\n\(usage)")
    }
} catch let e as NotFound {
    log(e.message)
    exit(3)
} catch let e as TimedOut {
    log(e.message)
    exit(2)
} catch let e as ASCError {
    log(e.description)
    if case .usage = e { exit(64) }
    exit(1)
} catch {
    log("error: \(error)")
    exit(1)
}
