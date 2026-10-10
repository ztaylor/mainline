import XCTest

/// End-to-end checks run by `mainline test` (and therefore before every `mainline ship`).
final class TallyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]  // fresh in-memory store
        app.launch()
        return app
    }

    @MainActor
    func testLaunchShowsHome() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["emptyAddCounter"].exists, "fresh install shows the empty state")
    }

    @MainActor
    func testAddCountAndDecrement() {
        let app = launch()
        app.buttons["addCounter"].tap()

        let nameField = app.textFields["counterName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText("Coffee")
        app.buttons["saveCounter"].tap()

        let card = app.descendants(matching: .any)["counter.Coffee"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let count = app.staticTexts["count.Coffee"]
        XCTAssertEqual(count.label, "0")

        card.tap()
        card.tap()
        XCTAssertEqual(count.label, "2")

        app.buttons["decrement.Coffee"].tap()
        XCTAssertEqual(count.label, "1")
    }
}
