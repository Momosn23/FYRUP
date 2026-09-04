import XCTest

final class CriticalFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Heute"].waitForExistence(timeout: 4))
        return app
    }

    func testTodayStartAndCompleteFlow() {
        let app = launchDemo()
        capture("01-home-feed")
        app.buttons["JETZT LOS"].tap()
        capture("04-activity-categories")
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        XCTAssertTrue(app.buttons["TRAINING BEENDEN"].exists)
        capture("07-live-training")
        app.buttons["TRAINING BEENDEN"].tap()
        XCTAssertTrue(app.staticTexts["Workout geschafft!"].waitForExistence(timeout: 3))
        capture("08-workout-complete")
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
        capture("05-plan-workout")
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
        capture("03-activity-details")
    }

    func testProfilePrivacyAndLogoutFlow() {
        let app = launchDemo()
        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.staticTexts["Profil"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Momo"].exists)
        capture("09-profile")
        app.buttons["Datenschutz"].tap()
        XCTAssertTrue(app.navigationBars["Datenschutz"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wer sieht meine Aktivitäten?"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Abmelden"].tap()
        XCTAssertTrue(app.buttons["Mit E-Mail anmelden"].waitForExistence(timeout: 3))
        capture("00-welcome")
    }

    func testNotificationsReferenceScreen() {
        let app = launchDemo()
        app.buttons["Mitteilungen"].tap()
        XCTAssertTrue(app.navigationBars["Mitteilungen"].waitForExistence(timeout: 2))
        capture("10-notifications")
    }

    func testCompleteOnboardingWithOptionalFields() {
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-demo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Profil erstellen"].waitForExistence(timeout: 4))
        app.textFields["z. B. Max"].tap()
        app.textFields["z. B. Max"].typeText("Momo")
        app.textFields["maxfyrup"].tap()
        app.textFields["maxfyrup"].typeText("momo_fyrup")
        app.textFields["z. B. 1998"].tap()
        app.textFields["z. B. 1998"].typeText("1998")
        app.textFields["z. B. Köln"].tap()
        app.textFields["z. B. Köln"].typeText("Berlin")
        capture("onboarding-01-profile")
        app.buttons["Weiter"].tap()

        let sportsHeading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Welche Sportarten")).firstMatch
        XCTAssertTrue(sportsHeading.waitForExistence(timeout: 3))
        app.buttons["Gym"].tap()
        app.buttons["Laufen"].tap()
        capture("onboarding-02-sports")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["Du bist startklar."].waitForExistence(timeout: 3))
        capture("onboarding-03-complete")
        app.buttons["FYRUP STARTEN"].tap()
        XCTAssertTrue(app.staticTexts["Heute"].waitForExistence(timeout: 3))
    }
}
