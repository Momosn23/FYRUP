import XCTest

@MainActor
final class SupplementFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 3)
        for _ in 0..<9 {
            if element.exists && element.isHittable {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: element)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
                element.tap(); return
            }
            if element.exists && !element.frame.isEmpty && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        capture("failure-supplement-control"); XCTFail("Unreachable control: \(element)")
    }
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }
    func testOptionalPersonalListIntakeUndoAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--workout-persistence=\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 8))
        tap(app.buttons["open-supplements"], in: app)
        XCTAssertTrue(app.navigationBars["Supplements"].waitForExistence(timeout: 5))
        let purpose = app.staticTexts["supplement-purpose"]
        let recommendation = app.staticTexts["supplement-no-recommendation"]
        let streak = app.staticTexts["supplement-no-streak-impact"]
        XCTAssertEqual(purpose.label, "Freiwillige Erinnerungen für deine eigene Auswahl.")
        XCTAssertEqual(recommendation.label, "Keine Produktempfehlung.")
        XCTAssertEqual(streak.label, "Ohne Einfluss auf deine Streak.")
        XCTAssertGreaterThan(recommendation.frame.minY, purpose.frame.maxY)
        XCTAssertGreaterThan(streak.frame.minY, recommendation.frame.maxY)
        XCTAssertTrue(streak.isHittable)
        capture("71-supplement-purpose")
        tap(app.buttons["add-supplement"], in: app)
        let name = app.textFields["supplement-name"]
        tap(name, in: app); name.typeText("Meine persönliche Auswahl\n")
        let reminders = app.switches["supplement-reminders"]
        for _ in 0..<5 where !reminders.exists { app.swipeUp() }
        XCTAssertTrue(reminders.exists); XCTAssertEqual(reminders.value as? String, "0", "No automatic push opt-in")
        capture("65-supplement-editor")
        tap(app.buttons["save-supplement"], in: app)
        let taken = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'supplement-taken-'")).firstMatch
        tap(taken, in: app)
        let confirmed = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' · Genommen'")).firstMatch
        XCTAssertTrue(confirmed.waitForExistence(timeout: 5))
        capture("66-supplement-confirmed")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 8))
        tap(app.buttons["open-supplements"], in: app)
        XCTAssertTrue(confirmed.waitForExistence(timeout: 5), "Confirmed intake survives a real app relaunch")
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'supplement-secondary-'")).firstMatch, in: app)
        XCTAssertTrue(taken.waitForExistence(timeout: 5))
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'supplement-secondary-'")).firstMatch, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' · Übersprungen'")).firstMatch.waitForExistence(timeout: 5))
        capture("67-supplement-skipped")
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'supplement-plan-'")).firstMatch, in: app)
        tap(app.switches["Eintrag pausieren"], in: app)
        tap(app.buttons["save-supplement"], in: app)
        XCTAssertTrue(app.staticTexts["Heute ist nichts vorgesehen."].waitForExistence(timeout: 5))
        XCTAssertFalse(taken.exists)
    }
}
