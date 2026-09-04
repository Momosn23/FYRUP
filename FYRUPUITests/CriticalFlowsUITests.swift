import XCTest

final class CriticalFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Heute"].waitForExistence(timeout: 4))
        return app
    }

    func testTodayStartAndCompleteFlow() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        XCTAssertTrue(app.buttons["TRAINING BEENDEN"].exists)
        app.buttons["TRAINING BEENDEN"].tap()
        XCTAssertTrue(app.staticTexts["Workout geschafft!"].waitForExistence(timeout: 3))
        app.buttons["Auf Feed teilen"].tap()
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 3))
    }

    func testFyrupIsOneTap() {
        let app = launchDemo()
        XCTAssertTrue(app.buttons["FYR UP 🔥"].waitForExistence(timeout: 4))
        app.buttons["FYR UP 🔥"].tap()
    }

    func testPlanWorkoutFlow() {
        let app = launchDemo()
        app.tabBars.buttons["Planen"].tap()
        XCTAssertTrue(app.staticTexts["Aktivität wählen"].waitForExistence(timeout: 2))
        app.buttons["Laufen"].tap()
        app.buttons["PLANEN"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        XCTAssertTrue(app.staticTexts["PLANNED"].waitForExistence(timeout: 3))
    }

    func testCancelLiveWorkoutFlow() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        app.buttons["Training abbrechen"].tap()
        let destructiveAction = app.sheets.buttons["Training abbrechen"]
        XCTAssertTrue(destructiveAction.waitForExistence(timeout: 2))
        destructiveAction.tap()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 3))
    }

    func testFriendsAndActivityDetailsNavigation() {
        let app = launchDemo()
        app.tabBars.buttons["Entdecken"].tap()
        XCTAssertTrue(app.staticTexts["FREUNDE"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Max"].exists)
        XCTAssertTrue(app.staticTexts["Sarah"].exists)
        app.tabBars.buttons["Home"].tap()
        app.buttons["Details"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Aktivitätsdetails"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Kategorie"].exists)
    }

    func testProfilePrivacyAndLogoutFlow() {
        let app = launchDemo()
        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.staticTexts["Profil"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Momo"].exists)
        app.buttons["Datenschutz"].tap()
        XCTAssertTrue(app.navigationBars["Datenschutz"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wer sieht meine Aktivitäten?"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Abmelden"].tap()
        XCTAssertTrue(app.buttons["Mit E-Mail anmelden"].waitForExistence(timeout: 3))
    }
}
