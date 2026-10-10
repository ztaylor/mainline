import Foundation

/// Minimal argument parser: positionals plus `--name value` / `--flag` options.
struct Args {
    var positional: [String] = []
    var options: [String: String] = [:]
    var missingValues: [String] = []

    init(_ raw: [String]) {
        var i = 0
        while i < raw.count {
            let arg = raw[i]
            if arg.hasPrefix("--") {
                let name = String(arg.dropFirst(2))
                if !["external", "help"].contains(name), i + 1 < raw.count, !raw[i + 1].hasPrefix("--") {
                    options[name] = raw[i + 1]
                    i += 1
                } else {
                    options[name] = "true"
                    if !["external", "help"].contains(name) { missingValues.append(name) }
                }
            } else {
                positional.append(arg)
            }
            i += 1
        }
    }

    /// Validate before loading credentials so usage errors are useful on a fresh install.
    func validate() throws {
        let command = positional.first ?? "help"
        let sub = positional.count > 1 ? positional[1] : ""
        let count: ClosedRange<Int>
        let allowed: Set<String>
        switch (command, sub) {
        case ("check", _): count = 1...1; allowed = []
        case ("bundle-id", "ensure"): count = 4...4; allowed = []
        case ("app", "find"), ("build", "next-number"): count = 3...3; allowed = []
        case ("build", "list"): count = 3...3; allowed = ["limit"]
        case ("build", "wait"): count = 4...4; allowed = ["timeout", "interval"]
        case ("group", "ensure"): count = 4...4; allowed = ["external"]
        case ("tester", "add"): count = 4...4; allowed = ["first", "last"]
        case ("api", _): count = 3...4; allowed = []
        default: throw ASCError.usage("unknown command")
        }
        guard count.contains(positional.count) else { throw ASCError.usage("wrong number of arguments; run asc help") }
        for option in options.keys where !allowed.contains(option) {
            throw ASCError.usage("unknown option --\(option)")
        }
        for option in missingValues { throw ASCError.usage("--\(option) needs a value") }
    }

    func positiveInt(_ name: String, default fallback: Int) throws -> Int {
        guard let raw = options[name] else { return fallback }
        guard let value = Int(raw), value > 0, value <= Int(UInt32.max) else {
            throw ASCError.usage("--\(name) must be a positive integer no greater than \(UInt32.max)")
        }
        return value
    }

    func at(_ index: Int, _ name: String) throws -> String {
        guard index < positional.count else { throw ASCError.usage("missing <\(name)>\n\n\(usage)") }
        return positional[index]
    }
}

