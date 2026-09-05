import XCTest

@MainActor
final class BlindFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private let momo = "00000000-0000-0000-0000-000000000001"
    private let max = "00000000-0000-0000-0000-000000000002"
    private let firstExercise = "Bankdrücken Langhantel"
    private let secondExercise = "Schrägbankdrücken Kurzhantel"

    private func launch(_ app: XCUIApplication, suite: String, user: String) {
        app.launchArguments = ["--demo", "--workout-persistence=\(suite)", "--demo-user=\(user)"]
        app.launch()
        expectExists(app.staticTexts["home-greeting"], in: app, timeout: 8)
    }

    private func container(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func expectExists(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5,
                              file: StaticString = #filePath, line: UInt = #line) {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists { diagnose("missing-element", in: app) }
        XCTAssertTrue(exists, "Das erwartete Steuerelement fehlt: \(element)", file: file, line: line)
    }

    private func expectHidden(_ text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        // Inspect the whole exposed accessibility tree, not only a screenshot or
        // the visible row. Server tests separately prove no future DTO is sent.
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        let leaked = query.firstMatch.exists
        if leaked { diagnose("unexpected-exercise-disclosure", in: app) }
        XCTAssertFalse(leaked, "Die noch verdeckte Übung darf nicht im UI erscheinen: \(text)", file: file, line: line)
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
        reveal(element, in: app, file: file, line: line)
        element.tap()
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
        // Called on the main actor before assertions, not from XCTest's
        // nonisolated teardown override (which is unsafe in Swift 6).
        capture("failure-blind-\(reason)")
        let details = app.debugDescription
        let attachment = XCTAttachment(string: details)
        attachment.name = "Blind Workout accessibility: \(reason)"; attachment.lifetime = .keepAlways; add(attachment)
        print("BLIND_UI_FAILURE_HIERARCHY \(reason)\n\(details)")
    }

    private func openInbox(_ app: XCUIApplication) {
        tap(app.tabBars.buttons["Freunde"], in: app)
        tap(app.buttons["open-blind-workouts"], in: app)
        expectExists(app.buttons["create-blind-workout"], in: app)
    }

    private func openSurprise(_ app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Surprise Push")).firstMatch
        tap(row, in: app)
        expectExists(container("blind-detail-screen", in: app), in: app)
        expectExists(app.navigationBars["Blind Workout"], in: app)
    }

    private func addExercise(_ name: String, suffix: String, in app: XCUIApplication) {
        tap(app.buttons["add-blind-exercise"], in: app)
        let search = app.textFields["exercise-search"]
        tap(search, in: app); search.typeText(name + "\n")
        tap(app.buttons["exercise-10000000-0000-0000-0000-\(suffix)"], in: app)
        waitFor(NSPredicate(format: "exists == false"), element: search, in: app)
    }

    private func equipmentSwitch(in app: XCUIApplication) -> XCUIElement {
        let row = app.switches["confirm-blind-equipment"].firstMatch
        reveal(row, in: app)
        // Tap the native switch, not the center of its full-width label row.
        let controls = row.descendants(matching: .switch).allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        return controls.last ?? row
    }

    func testTwoAccountsSendRevealCompleteCopyAndRestoreBlindWorkout() {
        let app = XCUIApplication()
        // AppStore accepts a UUID here and scopes the actual defaults suite.
        let suite = UUID().uuidString
        launch(app, suite: suite, user: momo)
        openInbox(app)
        tap(app.buttons["create-blind-workout"], in: app)
        tap(app.buttons["blind-recipient"], in: app)
        tap(app.buttons["Max"], in: app)
        let title = app.textFields["blind-title"]
        tap(title, in: app); title.typeText("Surprise Push\n")
        addExercise(firstExercise, suffix: "000000000001", in: app)
        addExercise(secondExercise, suffix: "000000000004", in: app)
        tap(app.buttons["sort-blind-exercises"], in: app)
        XCTAssertEqual(app.buttons["sort-blind-exercises"].label, "Fertig")
        tap(app.buttons["sort-blind-exercises"], in: app)
        XCTAssertEqual(app.buttons["sort-blind-exercises"].label, "Sortieren")
        reveal(app.buttons["send-blind-workout"], in: app)
        capture("41-blind-workout-create")
        tap(app.buttons["send-blind-workout"], in: app)
        waitFor(NSPredicate(format: "exists == false"), element: title, in: app)

        // Same persistent backend, a genuinely different demo account and a
        // relaunched app: the recipient does not inherit the creator's view state.
        app.terminate(); launch(app, suite: suite, user: max)
        openInbox(app); openSurprise(app)
        let equipment = equipmentSwitch(in: app)
        expectHidden(firstExercise, in: app); expectHidden(secondExercise, in: app)
        capture("42-blind-invitation-private")
        tap(equipment, in: app)
        waitFor(NSPredicate(format: "exists == true AND value == '1'"), element: equipment, in: app)
        tap(app.buttons["accept-blind-workout"], in: app)
        reveal(app.buttons["start-blind-workout"], in: app)
        expectHidden(firstExercise, in: app); expectHidden(secondExercise, in: app)
        tap(app.buttons["start-blind-workout"], in: app)
        tap(app.buttons["rest-duration-60"], in: app)
        tap(app.buttons["start-rest-timer"], in: app)
        expectExists(app.staticTexts["rest-countdown"], in: app)
        expectHidden(secondExercise, in: app)
        capture("87-blind-rest-without-disclosure")
        tap(app.buttons["stop-rest-timer"], in: app)
        expectExists(app.staticTexts[firstExercise], in: app)
        expectHidden(secondExercise, in: app)
        capture("43-blind-first-reveal")
        tap(app.buttons["complete-blind-exercise"], in: app)
        expectExists(app.staticTexts[secondExercise], in: app)
        capture("44-blind-second-reveal")
        tap(app.buttons["complete-blind-exercise"], in: app)
        tap(app.buttons["finish-blind-workout"], in: app)
        expectExists(container("blind-workout-completed", in: app), in: app)
        reveal(app.staticTexts["BLIND WORKOUT DONE"], in: app)
        capture("45-blind-workout-done")
        tap(app.buttons["copy-blind-workout"], in: app)
        expectExists(app.navigationBars["Workout-Plan"], in: app)
        expectExists(app.staticTexts[firstExercise], in: app)
        expectExists(app.staticTexts[secondExercise], in: app)

        tap(app.tabBars.buttons["Profil"], in: app)
        tap(app.buttons["profile-workout-plans"], in: app)
        expectExists(app.navigationBars["Meine Workout-Pläne"], in: app)
        tap(app.buttons["Surprise Push"], in: app)
        expectExists(app.staticTexts[firstExercise], in: app)
        expectExists(app.staticTexts[secondExercise], in: app)
        capture("46-blind-private-plan-copy")

        app.terminate(); launch(app, suite: suite, user: max)
        openInbox(app); openSurprise(app)
        expectExists(container("blind-workout-completed", in: app), in: app)
        XCTAssertFalse(app.buttons["start-blind-workout"].exists)
        XCTAssertFalse(app.buttons["finish-blind-workout"].exists)
        capture("47-blind-completed-restored")
    }
}
