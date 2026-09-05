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
        capture("failure-workout-control")
        print("WORKOUT_UI_FAILURE_HIERARCHY\n\(app.debugDescription)")
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
        let sort = app.buttons["sort-workout-exercises"]
        XCTAssertEqual(sort.label, "Sortieren")
        tap(sort, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Fertig'"), object: sort)], timeout: 3), .completed)
        XCTAssertEqual(sort.label, "Fertig")
        tap(sort, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Sortieren'"), object: sort)], timeout: 3), .completed)
        XCTAssertEqual(sort.label, "Sortieren")
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
        let done = app.buttons["finish-workout-summary"]
        XCTAssertTrue(waitUntilReady(done))
        let plus = app.buttons["Planen"].firstMatch
        XCTAssertTrue(plus.exists)
        XCTAssertLessThan(done.frame.maxY, plus.frame.minY, "The completed workout button must stay above the raised tab-bar action.")
        capture("31-workout-plan-done")
        tap(app.buttons["preview-workout-share"], in: app)
        let export = app.staticTexts["workout-share-text"]
        XCTAssertTrue(export.waitForExistence(timeout: 4))
        XCTAssertTrue(export.label.contains("Workout geschafft mit FYRUP!"))
        XCTAssertFalse(export.label.contains("Push Day"))
        XCTAssertFalse(export.label.contains("Bankdrücken"))
        XCTAssertFalse(export.label.contains("kg"))
        XCTAssertTrue(waitUntilReady(app.buttons["confirm-workout-share"]))
        capture("53-workout-share-preview")
        // Inspect and cancel the preview; no recipient is selected and nothing is sent.
        tap(app.buttons["cancel-workout-share"], in: app)
        waitUntilDismissed(export)
        tap(done, in: app)
        XCTAssertTrue(app.navigationBars["Trainingsplan"].waitForExistence(timeout: 4))
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

    func testUnsavedPlanDraftSurvivesTerminationAndCanBeResumed() {
        let app = launch()
        openPlans(app)
        tap(app.buttons["create-workout-plan"], in: app)
        let name = app.textFields["workout-plan-name"]
        tap(name, in: app); name.typeText("Unfinished Push\n")
        tap(app.buttons["add-plan-exercise"], in: app)
        let search = app.textFields["exercise-search"]
        tap(search, in: app); search.typeText("Bankdrücken Langhantel\n")
        tap(app.buttons["exercise-10000000-0000-0000-0000-000000000001"], in: app)
        XCTAssertTrue(waitUntilReady(app.buttons["plan-exercise-0"]))
        capture("32-unsaved-workout-draft")
        // Deliberately never tap Plan speichern: only the local recovery snapshot exists.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        openPlans(app)
        tap(app.buttons["resume-workout-draft"].firstMatch, in: app)
        XCTAssertTrue(app.textFields["workout-plan-name"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.textFields["workout-plan-name"].value as? String, "Unfinished Push")
        let exercise = app.buttons["plan-exercise-0"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 4))
        XCTAssertTrue(exercise.label.contains("Bankdrücken Langhantel"))
        XCTAssertFalse(app.alerts["Hinweis"].exists)
        capture("33-restored-workout-draft")
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

    func testUnconfirmedSetTextSurvivesRealRelaunchAndCanBeExplicitlyDiscarded() {
        let app = launch()
        createPlan(app, name: "Draft Recovery Push")
        tap(app.buttons["Draft Recovery Push"], in: app)
        tap(app.buttons["start-workout-plan"], in: app)
        XCTAssertTrue(app.segmentedControls["tracking-mode"].waitForExistence(timeout: 6))
        tap(app.segmentedControls["tracking-mode"].buttons["Tracken"], in: app)
        tap(app.buttons["workout-set-0-1"], in: app)
        let weight = app.textFields["set-weight"]; tap(weight, in: app); weight.typeText("81")
        let reps = app.textFields["set-reps"]; tap(reps, in: app); reps.typeText("9")
        XCTAssertEqual(weight.value as? String, "81"); XCTAssertEqual(reps.value as? String, "9")
        capture("54-unsaved-set-with-keyboard")
        // No save button, no Back, no graceful sheet dismissal before termination.
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 8))
        tap(app.buttons["TRAINING ÖFFNEN"], in: app)
        XCTAssertTrue(container("workout-tracking-screen", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(container("restored-tracking-draft", in: app).exists)
        tap(app.segmentedControls["tracking-mode"].buttons["Tracken"], in: app)
        let storedRow = app.buttons["workout-set-0-1"]
        XCTAssertTrue(storedRow.waitForExistence(timeout: 4))
        XCTAssertFalse(storedRow.label.contains("81"), "Unconfirmed text must not appear as saved measurements.")
        tap(storedRow, in: app)
        XCTAssertTrue(app.staticTexts["restored-set-draft"].waitForExistence(timeout: 4))
        XCTAssertEqual(weight.value as? String, "81"); XCTAssertEqual(reps.value as? String, "9")
        capture("55-restored-set-draft")
        tap(app.buttons["Abbrechen"], in: app)
        tap(app.sheets.buttons["Eingaben verwerfen"], in: app)
        waitUntilDismissed(weight)
        tap(app.buttons["workout-set-0-1"], in: app)
        XCTAssertTrue(weight.waitForExistence(timeout: 4))
        XCTAssertTrue(["", "Gewicht in kg (optional)"].contains(weight.value as? String ?? "unexpected"))
        XCTAssertTrue(["", "Wdh. (optional)"].contains(reps.value as? String ?? "unexpected"))
        XCTAssertFalse(app.staticTexts["restored-set-draft"].exists)
    }
}
