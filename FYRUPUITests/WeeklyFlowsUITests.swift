import XCTest

@MainActor
final class WeeklyFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testChangedWeeklyGoalStaysPendingAndSurvivesRelaunch() {
        let app = XCUIApplication()
        // Isolated local demo storage persists this one test across an actual process relaunch.
        app.launchArguments = ["--demo", "--workout-persistence=\(UUID().uuidString)"]
        app.launch()
        openWeeklyDetail(in: app)
        XCTAssertTrue(app.staticTexts["0 / 4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Ab nächster Woche: 5 Trainings"].exists)
        capture("38-weekly-flames")

        revealAndTap(app.buttons["edit-weekly-goal"], in: app)
        let five = app.buttons["weekly-goal-5"]
        waitUntilReady(five)
        XCTAssertTrue(app.staticTexts["Aktuell: 4 Trainings pro Woche"].exists)
        five.tap()
        let save = app.buttons["confirm-weekly-goal"]
        reveal(save, in: app)
        waitUntilReady(save)
        XCTAssertTrue(app.navigationBars["Wochenziel ändern"].exists, "The goal title must remain a readable navigation title after scrolling.")
        XCTAssertEqual(save.label, "Für nächste Woche speichern")
        capture("39-weekly-goal-next-week")
        save.tap()
        assertFourCurrentFivePending(in: app)

        app.terminate()
        app.launch()
        openWeeklyDetail(in: app)
        assertFourCurrentFivePending(in: app)
        capture("40-weekly-goal-restored")
    }

    private func openWeeklyDetail(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 8))
        revealAndTap(app.buttons["own-weekly-card"], in: app)
        XCTAssertTrue(app.staticTexts["Deine Streak"].waitForExistence(timeout: 5))
    }

    private func assertFourCurrentFivePending(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Deine Streak"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ab nächster Woche: 5 Trainings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 / 4"].exists, "A pending goal must not mutate this week's frozen target.")
        XCTAssertFalse(app.staticTexts["0 / 5"].exists)
        XCTAssertFalse(app.alerts["Hinweis"].exists)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.exists)
    }
    private func revealAndTap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app); waitUntilReady(element); element.tap()
    }
    private func waitUntilReady(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }
}
