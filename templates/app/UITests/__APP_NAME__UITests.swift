import XCTest

/// Smoke test: the app launches and shows its first screen.
/// `mainline ship` refuses to upload if this fails.
final class __APP_NAME__UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home"].waitForExistence(timeout: 10))
    }
}
