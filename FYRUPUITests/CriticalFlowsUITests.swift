import XCTest

final class CriticalFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testTodayStartAndCompleteFlow() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.staticTexts["HEUTE 🔥"].waitForExistence(timeout: 4))
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        app.buttons["JETZT STARTEN"].tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        XCTAssertTrue(app.buttons["TRAINING BEENDEN"].exists)
        app.buttons["TRAINING BEENDEN"].tap()
        XCTAssertTrue(app.staticTexts["DID IT. 🔥"].waitForExistence(timeout: 3))
        app.buttons["FERTIG"].tap()
        XCTAssertTrue(app.staticTexts["Heute geschafft ✓"].waitForExistence(timeout: 3))
    }

    func testFyrupIsOneTap() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["FYR UP 🔥"].waitForExistence(timeout: 4))
        app.buttons["FYR UP 🔥"].tap()
    }
}
