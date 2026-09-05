import XCTest

@MainActor
final class CallMyShotFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private let momo = "00000000-0000-0000-0000-000000000001"
    private let max = "00000000-0000-0000-0000-000000000002"

    private func launch(_ app: XCUIApplication, suite: String, user: String) {
        app.launchArguments = ["--demo", "--workout-persistence=\(suite)", "--demo-user=\(user)"]
        app.launch()
        expectExists(app.staticTexts["home-greeting"], in: app, timeout: 8)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func expectExists(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5,
                              file: StaticString = #filePath, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists { diagnose("missing-element", in: app) }
        XCTAssertTrue(exists, "Das erwartete Steuerelement fehlt: \(element)", file: file, line: line)
    }

    private func expect(_ condition: Bool, in app: XCUIApplication, message: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        if !condition { diagnose("unexpected-state", in: app) }
        XCTAssertTrue(condition, message, file: file, line: line)
    }

    private func waitFor(_ predicate: NSPredicate, element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5,
                         file: StaticString = #filePath, line: UInt = #line) {
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        if result != .completed { diagnose("unconfirmed-state", in: app) }
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if element.exists && element.isHittable {
                waitFor(NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), element: element, in: app, file: file, line: line)
                return
            }
            if element.exists && !element.frame.isEmpty && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        diagnose("unreachable-control", in: app)
        XCTFail("Steuerelement nach begrenztem Scrollen nicht erreichbar: \(element)", file: file, line: line)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication,
                     file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, in: app, file: file, line: line); element.tap()
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    private func diagnose(_ reason: String, in app: XCUIApplication) {
        capture("failure-shot-\(reason)")
        let details = app.debugDescription
        let attachment = XCTAttachment(string: details)
        attachment.name = "Call My Shot accessibility: \(reason)"; attachment.lifetime = .keepAlways; add(attachment)
        print("SHOT_UI_FAILURE_HIERARCHY \(reason)\n\(details)")
    }

    private func openOwnWeek(_ app: XCUIApplication) {
        tap(app.buttons["own-weekly-card"], in: app)
        expectExists(app.staticTexts["Deine Streak"], in: app)
    }

    private func assertOwnFourTrainingShot(_ app: XCUIApplication) {
        let badge = element("own-shot-status", in: app)
        expectExists(badge, in: app)
        expect(badge.label.contains("CALL MY SHOT"), in: app, message: "Der angekündigte, noch offene Shot muss sichtbar sein.")
        let progress = element("own-shot-progress", in: app)
        expectExists(progress, in: app)
        expect(progress.label.hasPrefix("Dein Call: 4 Einheiten"), in: app, message: "Der Shot bleibt an das aktuelle Ziel 4 gebunden.")
        expect(progress.label.hasSuffix("/ 4"), in: app, message: "Der aktuelle Fortschritt darf nicht zum ausstehenden Ziel wechseln.")
    }

    private func openMomosWeekAsFriend(_ app: XCUIApplication) {
        tap(app.tabBars.buttons["Freunde"], in: app)
        tap(app.buttons["friend-momo"], in: app)
        expectExists(app.staticTexts["@momo"], in: app)
        expectExists(element("friend-shot-status", in: app), in: app)
    }

    func testExplicitShotPersistsKeepsCurrentGoalAndAcceptedFriendCanReact() {
        let app = XCUIApplication()
        let suite = UUID().uuidString
        launch(app, suite: suite, user: momo)
        openOwnWeek(app)
        let open = app.buttons["open-call-my-shot"]
        tap(open, in: app)
        let confirmation = element("shot-confirmation-screen", in: app)
        expectExists(confirmation, in: app)
        expectExists(app.staticTexts["4 Einheiten"], in: app)
        reveal(app.buttons["Abbrechen"], in: app)
        capture("48-shot-explicit-confirmation")
        tap(app.buttons["Abbrechen"], in: app)
        waitFor(NSPredicate(format: "exists == false"), element: confirmation, in: app)
        expect(!element("own-shot-status", in: app).exists, in: app, message: "Abbrechen darf keinen Shot erstellen.")

        tap(open, in: app)
        tap(app.buttons["confirm-call-my-shot"], in: app)
        waitFor(NSPredicate(format: "exists == false"), element: confirmation, in: app)
        assertOwnFourTrainingShot(app)
        expect(!open.exists || !open.isEnabled, in: app, message: "Ein bestätigter Shot darf nicht erneut aufrufbar sein.")
        capture("49-shot-called")

        app.terminate(); launch(app, suite: suite, user: momo)
        openOwnWeek(app); assertOwnFourTrainingShot(app)
        tap(app.buttons["edit-weekly-goal"], in: app)
        tap(app.buttons["weekly-goal-5"], in: app)
        tap(app.buttons["confirm-weekly-goal"], in: app)
        expectExists(app.staticTexts["Deine Streak"], in: app)
        expectExists(app.staticTexts["Ab nächster Woche: 5 Einheiten"], in: app)
        assertOwnFourTrainingShot(app)
        capture("50-shot-current-four-next-five")

        // Read the same persisted backend from another accepted account, not an
        // owner-shaped fixture. This verifies the actual friend profile surface.
        app.terminate(); launch(app, suite: suite, user: max)
        openMomosWeekAsFriend(app)
        let friendProgress = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Angekündigt: 4 Einheiten")).firstMatch
        expectExists(friendProgress, in: app)
        let reaction = app.buttons["reaction-shot-target"]
        reveal(reaction, in: app)
        waitFor(NSPredicate(format: "exists == true AND enabled == true AND value == %@", "Nicht ausgewählt"), element: reaction, in: app)
        tap(reaction, in: app)
        waitFor(NSPredicate(format: "exists == true AND enabled == true AND value == %@", "Ausgewählt"), element: reaction, in: app)
        capture("51-friend-shot-confirmed-reaction")

        app.terminate(); launch(app, suite: suite, user: max)
        openMomosWeekAsFriend(app)
        reveal(reaction, in: app)
        waitFor(NSPredicate(format: "exists == true AND enabled == true AND value == %@", "Ausgewählt"), element: reaction, in: app)
        tap(reaction, in: app)
        waitFor(NSPredicate(format: "exists == true AND enabled == true AND value == %@", "Nicht ausgewählt"), element: reaction, in: app)
        capture("52-friend-shot-reaction-removed")
    }
}
