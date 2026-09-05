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

    private func container(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitUntilReady(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func waitUntilDismissed(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed, file: file, line: line)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        // Give presentation/loading a short chance, but do not require an offscreen lazy
        // row to exist before scrolling can bring it into the accessibility tree.
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if element.exists && !element.isEnabled {
                let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
                guard XCTWaiter.wait(for: [enabled], timeout: 3) == .completed else {
                    XCTFail("The control remained disabled: \(element)", file: file, line: line)
                    return
                }
            }
            if element.exists && element.isHittable {
                guard waitUntilReady(element) else {
                    XCTFail("The control did not become enabled and hittable: \(element)", file: file, line: line)
                    return
                }
                element.tap()
                return
            }
            if element.exists && !element.frame.isEmpty && element.frame.midY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTFail("The control was not reachable after bounded scrolling: \(element)", file: file, line: line)
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
        tap(app.tabBars.buttons["Profil"], in: app)
        tap(app.buttons["profile-workout-plans"], in: app)
        XCTAssertTrue(app.navigationBars["Meine Pläne"].waitForExistence(timeout: 5))
    }

    private func createPlan(_ app: XCUIApplication, name: String, custom: Bool = false) {
        openPlans(app)
        tap(app.buttons["create-workout-plan"], in: app)
        let field = app.textFields["workout-plan-name"]
        tap(field, in: app); field.typeText(name + "\n")
        tap(app.buttons["add-plan-exercise"], in: app)
        XCTAssertTrue(app.textFields["exercise-search"].waitForExistence(timeout: 5))
        capture("26-exercise-library")
        if custom {
            tap(app.buttons["create-custom-exercise"], in: app)
            let customName = app.textFields["custom-exercise-name"]
            tap(customName, in: app); customName.typeText("Prime Chest Press\n")
            capture("27-custom-exercise")
            tap(app.buttons["save-custom-exercise"], in: app)
        } else {
            let search = app.textFields["exercise-search"]
            tap(search, in: app)
            // Filter before selecting: the 122-row library deliberately uses lazy layout.
            // Return dismisses the standard text-field keyboard without locale-specific keys.
            search.typeText("Bankdrücken Langhantel\n")
            tap(app.buttons["exercise-10000000-0000-0000-0000-000000000001"], in: app)
        }
        XCTAssertTrue(waitUntilReady(app.buttons["plan-exercise-0"]))
        capture("25-workout-plan-editor")
        tap(app.buttons["save-workout-plan"], in: app)
        waitUntilDismissed(field)
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
        XCTAssertTrue(container("workout-tracking-screen", in: app).waitForExistence(timeout: 6))
        tap(app.buttons["complete-workout-exercise-0"], in: app)
        XCTAssertTrue(app.staticTexts["1 / 1 Übungen"].waitForExistence(timeout: 5))
        capture("29-workout-easy-live")
        tap(app.buttons["finish-plan-workout"], in: app)
        let confirm = app.sheets.buttons["Training beenden"]
        tap(confirm, in: app)
        XCTAssertTrue(container("workout-completed-summary", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Workout geschafft!"].exists)
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
        tap(app.segmentedControls["tracking-mode"].buttons["Tracken"], in: app)
        tap(app.buttons["workout-set-0-1"], in: app)
        let weight = app.textFields["set-weight"]
        tap(weight, in: app); weight.typeText("80")
        let reps = app.textFields["set-reps"]; tap(reps, in: app); reps.typeText("8")
        tap(app.buttons["Tastatur schließen"], in: app)
        tap(app.buttons["save-workout-set"], in: app)
        waitUntilDismissed(weight)
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
