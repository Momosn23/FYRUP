import XCTest

@MainActor
final class WorkoutFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--workout-persistence=\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
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

    private func openPlans(_ app: XCUIApplication) {
        app.tabBars.buttons["Profil"].tap()
        tap(app.buttons["profile-workout-plans"], in: app)
        XCTAssertTrue(app.navigationBars["Meine Pläne"].waitForExistence(timeout: 5))
    }

    private func createPlan(_ app: XCUIApplication, name: String, custom: Bool = false) {
        openPlans(app)
        tap(app.buttons["create-workout-plan"], in: app)
        let field = app.textFields["workout-plan-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        tap(app.buttons["add-plan-exercise"], in: app)
        XCTAssertTrue(app.textFields["exercise-search"].waitForExistence(timeout: 5))
        capture("26-exercise-library")
        if custom {
            tap(app.buttons["create-custom-exercise"], in: app)
            let customName = app.textFields["custom-exercise-name"]
            XCTAssertTrue(customName.waitForExistence(timeout: 5)); customName.tap(); customName.typeText("Prime Chest Press")
            capture("27-custom-exercise")
            tap(app.buttons["save-custom-exercise"], in: app)
        } else {
            tap(app.buttons["exercise-10000000-0000-0000-0000-000000000001"], in: app)
        }
        XCTAssertTrue(app.buttons["plan-exercise-0"].waitForExistence(timeout: 5))
        capture("25-workout-plan-editor")
        tap(app.buttons["save-workout-plan"], in: app)
        XCTAssertTrue(app.navigationBars["Meine Pläne"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[name].exists)
    }

    func testCreatePlanSurvivesRelaunchAndEasyTraining() {
        let app = launch()
        createPlan(app, name: "Push Day")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        openPlans(app)
        tap(app.buttons["Push Day"], in: app)
        XCTAssertTrue(app.staticTexts["Bankdrücken Langhantel"].waitForExistence(timeout: 5))
        capture("28-workout-plan-detail")
        tap(app.buttons["start-workout-plan"], in: app)
        XCTAssertTrue(app.otherElements["workout-tracking-screen"].waitForExistence(timeout: 6))
        tap(app.buttons["complete-workout-exercise-0"], in: app)
        XCTAssertTrue(app.staticTexts["1 / 1 Übungen"].waitForExistence(timeout: 5))
        capture("29-workout-easy-live")
        tap(app.buttons["finish-plan-workout"], in: app)
        let confirm = app.sheets.buttons["Training beenden"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.tap()
        XCTAssertTrue(app.otherElements["workout-completed-summary"].waitForExistence(timeout: 6))
        capture("31-workout-plan-done")
    }

    func testCustomExerciseAddsDirectlyAndPersists() {
        let app = launch()
        createPlan(app, name: "Custom Push", custom: true)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        openPlans(app)
        tap(app.buttons["Custom Push"], in: app)
        XCTAssertTrue(app.staticTexts["Prime Chest Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Hinweis"].exists)
    }

    func testTrackOptionalSetValuesAndPause() {
        let app = launch()
        createPlan(app, name: "Tracked Push")
        tap(app.buttons["Tracked Push"], in: app)
        tap(app.buttons["start-workout-plan"], in: app)
        XCTAssertTrue(app.segmentedControls["tracking-mode"].waitForExistence(timeout: 6))
        app.segmentedControls["tracking-mode"].buttons["Tracken"].tap()
        tap(app.buttons["workout-set-0-1"], in: app)
        let weight = app.textFields["set-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 4)); weight.tap(); weight.typeText("80")
        let reps = app.textFields["set-reps"]; reps.tap(); reps.typeText("8")
        tap(app.buttons["save-workout-set"], in: app)
        XCTAssertTrue(app.buttons["workout-set-0-1"].waitForExistence(timeout: 5))
        capture("30-workout-set-tracking")
        tap(app.buttons["pause-plan-workout"], in: app)
        XCTAssertTrue(app.staticTexts["PAUSIERT"].waitForExistence(timeout: 5))
        tap(app.buttons["pause-plan-workout"], in: app)
        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 5))
        tap(app.buttons["workout-set-0-1"], in: app)
        XCTAssertTrue(app.textFields["set-weight"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.textFields["set-weight"].value as? String, "80")
        XCTAssertEqual(app.textFields["set-reps"].value as? String, "8")
    }
}
