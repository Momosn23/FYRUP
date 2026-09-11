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
                    capture("failure-workout-unstable-control")
                    print("WORKOUT_UI_UNSTABLE_HIERARCHY\n\(app.debugDescription)")
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
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["profile-workout-plans"], in: app)
        XCTAssertTrue(container("workout-plans-screen", in: app).waitForExistence(timeout: 8))
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
        XCTAssertTrue(container("workout-plans-screen", in: app).waitForExistence(timeout: 8))
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
        let confirm = app.sheets.buttons["Workout abschließen"]
        tap(confirm, in: app)
        XCTAssertTrue(container("workout-completed-summary", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Workout geschafft!"].exists)
        let done = app.buttons["finish-workout-summary"]
        XCTAssertTrue(waitUntilReady(done))
        let plus = app.buttons["Planen"].firstMatch
        XCTAssertTrue(plus.exists)
        XCTAssertLessThan(done.frame.maxY, plus.frame.minY, "The completed workout button must stay above the raised tab-bar action.")
        let share = app.buttons["preview-workout-share"]
        XCTAssertTrue(waitUntilReady(share))
        XCTAssertLessThan(share.frame.maxY, done.frame.minY, "Sharing must be visible above Done, never behind the pinned footer.")
        capture("31-workout-plan-done")
        tap(share, in: app)
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
        tap(app.buttons["review-completed-workout"], in: app)
        let feeling = app.buttons["workout-feeling-great"]
        XCTAssertTrue(waitUntilReady(feeling))
        tap(feeling, in: app)
        capture("58-private-workout-review")
        tap(app.buttons["save-workout-review"], in: app)
        waitUntilDismissed(feeling)
        XCTAssertTrue(app.buttons["review-completed-workout"].label.contains("Richtig gut"))
        tap(app.buttons["review-completed-workout"], in: app)
        XCTAssertTrue(feeling.waitForExistence(timeout: 4))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: feeling)], timeout: 4), .completed)
        tap(app.buttons["Ohne Änderung schließen"], in: app)
        waitUntilDismissed(feeling)
        tap(done, in: app)
        XCTAssertTrue(app.navigationBars["Workout-Plan"].waitForExistence(timeout: 4))
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

    func testBodyAndLabelSelectionStayInSyncAndFilterRealExercises() {
        let app = launch()
        openPlans(app)
        tap(app.buttons["create-workout-plan"], in: app)
        tap(app.buttons["add-plan-exercise"], in: app)
        tap(app.buttons["open-library-muscles"], in: app)
        let chest = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-muscle-body-front-chest-'")).firstMatch
        let core = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-muscle-body-front-core-'")).firstMatch
        XCTAssertTrue(core.waitForExistence(timeout: 4))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-muscle-body-front-core-'")).count, 1, "One muscle is one accessible body control")
        tap(chest, in: app)
        XCTAssertTrue(chest.isSelected)
        tap(core, in: app)
        XCTAssertTrue(core.isSelected)
        XCTAssertTrue(chest.isSelected)
        capture("62-interactive-body-front-back")
        let chestLabel = app.buttons["library-muscle-list-chest"]
        tap(chestLabel, in: app)
        XCTAssertFalse(chestLabel.isSelected)
        XCTAssertFalse(chest.isSelected, "Removing the labelled choice must also turn off its body patch.")
        XCTAssertTrue(app.buttons["library-muscle-list-core"].isSelected)
        tap(app.buttons["show-muscle-exercises"], in: app)
        waitUntilDismissed(app.navigationBars["Muskelgruppen"])
        let search = app.textFields["exercise-search"]
        tap(search, in: app); search.typeText("Bankdrücken Langhantel\n")
        XCTAssertTrue(app.staticTexts["Keine passende Übung"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["exercise-10000000-0000-0000-0000-000000000001"].exists)
        capture("63-muscle-filter-excludes-unrelated")
        tap(app.buttons["Suche löschen"], in: app)
        tap(search, in: app); search.typeText("Pallof Press\n")
        let pallof = app.buttons["exercise-10000000-0000-0000-0000-000000000112"]
        XCTAssertTrue(pallof.waitForExistence(timeout: 4))
        capture("64-muscle-filter-matching-exercise")
        tap(app.buttons["clear-library-muscles"], in: app)
        tap(app.buttons["Suche löschen"], in: app)
        tap(search, in: app); search.typeText("Bankdrücken Langhantel\n")
        tap(app.buttons["exercise-10000000-0000-0000-0000-000000000001"], in: app)
        XCTAssertTrue(app.buttons["plan-exercise-0"].waitForExistence(timeout: 4))
    }

    func testWeeklyRoutineSavesDaysAndSurvivesRelaunch() {
        let app = launch()
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["profile-weekly-routine"], in: app)
        XCTAssertTrue(app.navigationBars["Mein Wochenplan"].waitForExistence(timeout: 5))
        tap(app.buttons["routine-add-sport"], in: app)
        let monday = app.buttons["routine-gym-day-1"]
        let friday = app.buttons["routine-gym-day-5"]
        tap(monday, in: app); tap(friday, in: app)
        XCTAssertTrue(monday.isSelected); XCTAssertTrue(friday.isSelected)
        capture("59-weekly-routine-editor")
        tap(app.buttons["save-training-routine"], in: app)
        waitUntilDismissed(app.navigationBars["Mein Wochenplan"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["profile-weekly-routine"], in: app)
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertTrue(monday.isSelected); XCTAssertTrue(friday.isSelected)
        XCTAssertFalse(app.buttons["routine-gym-day-2"].isSelected)
        capture("60-weekly-routine-restored")
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
        XCTAssertTrue(app.buttons["workout-set-0-1"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["current-workout-exercise"].label.hasPrefix("Aktuelle Übung:"))
        tap(app.buttons["workout-set-0-1"], in: app)
        let weight = app.textFields["set-weight"]
        tap(weight, in: app); weight.typeText("80")
        let reps = app.textFields["set-reps"]; tap(reps, in: app); reps.typeText("8")
        tap(app.buttons["Tastatur schließen"], in: app)
        tap(app.buttons["save-workout-set"], in: app)
        waitUntilDismissed(weight)
        XCTAssertTrue(container("rest-focus-countdown", in: app).waitForExistence(timeout: 4))
        tap(app.buttons["rest-focus-primary"], in: app)
        XCTAssertTrue(app.buttons["workout-set-0-1"].waitForExistence(timeout: 5))
        let effort = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'effort-' AND identifier ENDSWITH '-hardcore'")).firstMatch
        tap(effort, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: effort)], timeout: 4), .completed)
        capture("61-private-exercise-effort")
        tap(effort, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == false"), object: effort)], timeout: 4), .completed)
        capture("30-workout-set-tracking")
        tap(app.buttons["pause-plan-workout"], in: app)
        XCTAssertTrue(app.staticTexts["PAUSIERT"].waitForExistence(timeout: 5))
        tap(app.buttons["pause-plan-workout"], in: app)
        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 5))
        tap(app.buttons["workout-set-0-1"], in: app)
        XCTAssertTrue(app.textFields["set-weight"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.textFields["set-weight"].value as? String, "80")
        XCTAssertEqual(app.textFields["set-reps"].value as? String, "8")
        tap(app.buttons["Abbrechen"], in: app)
        tap(app.buttons["complete-workout-exercise-0"], in: app)
        tap(app.buttons["finish-plan-workout"], in: app)
        tap(app.sheets.buttons["Workout abschließen"], in: app)
        XCTAssertTrue(container("workout-completed-summary", in: app).waitForExistence(timeout: 6))
        tap(app.buttons["finish-workout-summary"], in: app)
        XCTAssertTrue(app.navigationBars["Workout-Plan"].waitForExistence(timeout: 5))
        tap(app.buttons["start-workout-plan"], in: app)
        let performance = container("exercise-performance-10000000-0000-0000-0000-000000000001", in: app)
        XCTAssertTrue(performance.waitForExistence(timeout: 6))
        XCTAssertTrue(performance.label.contains("Zuletzt"))
        XCTAssertTrue(performance.label.contains("80 kg"))
        XCTAssertTrue(performance.label.contains("8"))
        XCTAssertTrue(performance.label.contains("Bestwert vom"), "Die persönliche Bestleistung muss mit ihrem Datum sichtbar sein")
        capture("62-exercise-last-and-best")
    }

    func testUnconfirmedSetTextSurvivesRealRelaunchAndCanBeExplicitlyDiscarded() {
        let app = launch()
        createPlan(app, name: "Draft Recovery Push")
        tap(app.buttons["Draft Recovery Push"], in: app)
        tap(app.buttons["start-workout-plan"], in: app)
        XCTAssertTrue(app.buttons["workout-set-0-1"].waitForExistence(timeout: 6))
        tap(app.buttons["workout-set-0-1"], in: app)
        let weight = app.textFields["set-weight"]; tap(weight, in: app); weight.typeText("81")
        let reps = app.textFields["set-reps"]; tap(reps, in: app); reps.typeText("9")
        XCTAssertEqual(weight.value as? String, "81"); XCTAssertEqual(reps.value as? String, "9")
        XCTAssertEqual(app.staticTexts["set-weight-label"].label, "Gewicht (kg)")
        XCTAssertEqual(app.staticTexts["set-reps-label"].label, "Wiederholungen")
        capture("54-unsaved-set-with-keyboard")
        // No save button, no Back, no graceful sheet dismissal before termination.
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 8))
        tap(app.buttons["open-live-activity"], in: app)
        XCTAssertTrue(container("workout-tracking-screen", in: app).waitForExistence(timeout: 6))
        XCTAssertTrue(container("restored-tracking-draft", in: app).exists)
        let storedRow = app.buttons["workout-set-0-1"]
        XCTAssertTrue(storedRow.waitForExistence(timeout: 4))
        XCTAssertFalse(storedRow.label.contains("81"), "Unconfirmed text must not appear as saved measurements.")
        tap(storedRow, in: app)
        XCTAssertTrue(app.staticTexts["restored-set-draft"].waitForExistence(timeout: 4))
        XCTAssertEqual(weight.value as? String, "81"); XCTAssertEqual(reps.value as? String, "9")
        XCTAssertEqual(app.staticTexts["set-weight-label"].label, "Gewicht (kg)")
        XCTAssertEqual(app.staticTexts["set-reps-label"].label, "Wiederholungen")
        capture("55-restored-set-draft")
        tap(app.buttons["Abbrechen"], in: app)
        tap(app.sheets.buttons["Eingaben verwerfen"], in: app)
        waitUntilDismissed(weight)
        tap(app.buttons["workout-set-0-1"], in: app)
        XCTAssertTrue(weight.waitForExistence(timeout: 4))
        XCTAssertTrue(["", "Optional", "–"].contains(weight.value as? String ?? "unexpected"))
        XCTAssertTrue(["", "Optional", "–"].contains(reps.value as? String ?? "unexpected"))
        XCTAssertFalse(app.staticTexts["restored-set-draft"].exists)
    }
}
