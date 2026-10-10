import Foundation

/// Processing success alone does not mean a build can be tested.
func buildIsReady(processing: String, internalState: String, buildNumber: String) throws -> Bool {
    if processing == "FAILED" || processing == "INVALID" {
        throw ASCError.http(status: 0, message: "Build \(buildNumber) processing ended in \(processing). Check App Store Connect for details.")
    }
    guard processing == "VALID" else { return false }
    switch internalState {
    case "READY_FOR_BETA_TESTING", "IN_BETA_TESTING":
        return true
    case "MISSING_EXPORT_COMPLIANCE":
        throw ASCError.http(status: 0, message: "Build \(buildNumber) needs an export-compliance answer in App Store Connect (docs/troubleshooting.md). Do not upload again.")
    case "PROCESSING_EXCEPTION", "EXPIRED":
        throw ASCError.http(status: 0, message: "Build \(buildNumber) is unavailable for internal testing: \(internalState).")
    default:
        return false
    }
}
