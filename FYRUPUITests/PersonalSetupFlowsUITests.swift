import XCTest

@MainActor
final class PersonalSetupFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 4)
        for _ in 0..<10 {
            if element.exists && element.isHittable && element.isEnabled { element.tap(); return }
            if element.exists && !element.frame.isEmpty && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        capture("failure-personal-setup")
        XCTFail("Einrichtung nicht bedienbar: \(element)\n\(app.debugDescription)")
    }
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot(), attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }
    func testGuidedSetupSavesBodyAndGoalsWithoutAutomaticHealthSharing() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--steps-demo"]; app.launch()
        tap(app.buttons["open-personal-setup"], in: app)
        XCTAssertTrue(app.staticTexts["Jeder Schritt zählt."].waitForExistence(timeout: 4))
        tap(app.buttons["setup-connect-health"], in: app)
        XCTAssertTrue(app.staticTexts["Schrittdaten verfügbar"].waitForExistence(timeout: 5))
        let share = app.switches["setup-share-steps"].firstMatch
        XCTAssertTrue(share.exists); XCTAssertEqual(share.value as? String, "0", "Connecting Health does not grant friend sharing")
        tap(app.buttons["10.000"], in: app)
        capture("77-setup-steps-opt-in")
        tap(app.buttons["personal-setup-next"], in: app)
        let height = app.textFields["setup-height"], weight = app.textFields["setup-weight"], goal = app.textFields["setup-calorie-goal"]
        tap(height, in: app); height.typeText("180")
        tap(weight, in: app); weight.typeText("81,5")
        tap(app.toolbars.buttons["Fertig"], in: app)
        tap(goal, in: app); goal.typeText("450")
        tap(app.toolbars.buttons["Fertig"], in: app)
        tap(app.buttons["save-body-and-goal"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["body-data-saved"].firstMatch.waitForExistence(timeout: 4))
        capture("78-private-body-energy-setup")
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.staticTexts["Bleib im Moment."].waitForExistence(timeout: 4))
        capture("79-notifications-live-explanation")
        tap(app.buttons["personal-setup-next"], in: app)
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["open-personal-setup"].exists, "Completed setup no longer crowds the top of Today")
        tap(app.tabBars.buttons["Profil"], in: app)
        tap(app.buttons["open-personal-setup"], in: app)
        XCTAssertEqual(app.textFields["setup-step-goal"].value as? String, "10000")
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertEqual(height.value as? String, "180.0"); XCTAssertEqual(weight.value as? String, "81.5")
        XCTAssertEqual(goal.value as? String, "450")
    }
    func testRestClockIsSharedByLiveScreenAndHome() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        tap(app.buttons["JETZT LOS"], in: app); tap(app.buttons["Gym"], in: app); tap(app.buttons["Push"], in: app)
        tap(app.buttons["confirm-activity"], in: app)
        tap(app.buttons["rest-duration-120"], in: app); tap(app.buttons["start-rest-timer"], in: app)
        XCTAssertTrue(app.staticTexts["rest-countdown"].waitForExistence(timeout: 4))
        capture("80-home-live-rest")
        tap(app.buttons["open-live-activity"], in: app)
        XCTAssertTrue(app.staticTexts["rest-countdown"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Satzpause"].exists)
        capture("81-live-session-rest")
        tap(app.buttons["stop-rest-timer"], in: app)
        XCTAssertFalse(app.staticTexts["rest-countdown"].exists)
        XCTAssertTrue(app.buttons["start-rest-timer"].exists)
        tap(app.buttons["PAUSIEREN"], in: app)
        XCTAssertTrue(app.buttons["FORTSETZEN"].waitForExistence(timeout: 4))
        capture("82-paused-session")
    }
}
