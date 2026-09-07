import XCTest

@MainActor
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
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 4))
        return app
    }

    private func revealAndTap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    private func waitUntilReady(_ element: XCUIElement, timeout: TimeInterval = 4) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed)
    }

    private func assertRegistration(in app: XCUIApplication) {
        let title = app.staticTexts["auth-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "Account erstellen")
        XCTAssertTrue(app.staticTexts["Erstelle dein FYRUP-Profil in wenigen Schritten."].exists)
        XCTAssertTrue(app.staticTexts["Mindestens 8 Zeichen"].exists)
        XCTAssertTrue(app.staticTexts["Ein Großbuchstabe"].exists)
        XCTAssertTrue(app.staticTexts["Eine Zahl"].exists)
        XCTAssertEqual(app.buttons["auth-submit"].label, "Weiter")
        XCTAssertFalse(app.buttons["Passwort vergessen"].exists)
    }

    func testTodayStartAndCompleteFlow() {
        let app = launchDemo()
        capture("01-home-feed")
        app.buttons["JETZT LOS"].tap()
        waitUntilReady(app.buttons["Gym"])
        capture("04-activity-categories")
        app.buttons["Gym"].tap()
        revealAndTap(app.buttons["Push"], in: app)
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["open-live-activity"].tap()
        XCTAssertTrue(app.buttons["ABSCHLIESSEN"].exists)
        capture("07-live-training")
        revealAndTap(app.buttons["ABSCHLIESSEN"], in: app)
        XCTAssertTrue(app.staticTexts["Heute geschafft 🔥"].waitForExistence(timeout: 3))
        capture("08-workout-complete")
        let finish = app.buttons["finish-free-activity"]
        for _ in 0..<5 {
            if finish.isHittable && finish.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(finish.isHittable)
        XCTAssertLessThan(finish.frame.maxY, app.tabBars.firstMatch.frame.minY, "The complete action must be fully above the tab bar")
        capture("68-workout-complete-actions")
        app.buttons["Im Feed ansehen"].tap()
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 3))
    }

    func testDiscoverPreservesTheChosenSport() {
        let app = launchDemo()
        app.tabBars.buttons["Entdecken"].tap()
        waitUntilReady(app.buttons["Laufen"])
        app.buttons["Laufen"].tap()
        waitUntilReady(app.buttons["confirm-activity"])
        XCTAssertTrue(app.staticTexts["Loslegen"].exists)
        XCTAssertTrue(app.staticTexts["Laufen"].exists)
        XCTAssertEqual(app.staticTexts["activity-composer-title"].label, "Loslegen", "Check the open composer, not the discover page behind its sheet")
        capture("56-discover-selected-sport")
    }

    func testImmediateActivityAcceptsAnOptionalPlace() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        waitUntilReady(app.buttons["Laufen"])
        app.buttons["Laufen"].tap()
        let place = app.textFields["activity-place"]
        revealAndTap(place, in: app)
        place.typeText("Rheinpark")
        XCTAssertEqual(place.value as? String, "Rheinpark")
        capture("75-immediate-activity-place")
    }

    func testFyrupIsOneTap() {
        let app = launchDemo()
        let nudge = app.buttons["FYR UP 🔥"].firstMatch
        revealAndTap(nudge, in: app)
        XCTAssertTrue(app.staticTexts["home-greeting"].exists)
        XCTAssertFalse(app.alerts["Hinweis"].exists)
    }

    func testPlanWorkoutFlow() {
        let app = launchDemo()
        app.buttons["Planen"].tap()
        XCTAssertTrue(app.staticTexts["Was hast du vor?"].waitForExistence(timeout: 2))
        capture("12-plus-menu")
        app.buttons["Laufen"].tap()
        app.segmentedControls.buttons["SESSION PLANEN"].tap()
        capture("05-plan-workout")
        let date = app.buttons["session-date"]
        if !date.waitForExistence(timeout: 3) {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "session-date-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCTAssertTrue(date.exists, "Datum must remain a native accessible button")
        waitUntilReady(date)
        XCTAssertTrue(date.isHittable)
        let selectedDate = date.value as? String ?? ""
        XCTAssertFalse(selectedDate.isEmpty)
        XCTAssertNotNil(selectedDate.range(of: "\\b[0-9]{4}\\b", options: .regularExpression), "Show the entire date including its year")
        date.tap()
        XCTAssertTrue(app.navigationBars["Datum wählen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.datePickers["session-calendar"].exists)
        capture("70-session-calendar")
        app.buttons["confirm-session-date"].tap()
        XCTAssertEqual(app.buttons["session-date"].value as? String, selectedDate)
        let joinToggle = app.switches["Freunde dürfen sich anschließen"]
        XCTAssertTrue(joinToggle.exists)
        let confirm = app.buttons.matching(identifier: "confirm-activity").element
        revealAndTap(confirm, in: app)
        if app.staticTexts["PLANNED"].waitForExistence(timeout: 3) {
            app.buttons["SESSION ÖFFNEN"].firstMatch.tap()
        } else {
            // Around midnight, the default one-hour lead time legitimately puts
            // the session on tomorrow. Open it through the weekly overview.
            let plannedDay = app.buttons.matching(NSPredicate(format: "label CONTAINS '1 vorgemerkt'")).firstMatch
            XCTAssertTrue(plannedDay.waitForExistence(timeout: 5))
            plannedDay.tap()
            let session = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'week-session-'")).firstMatch
            XCTAssertTrue(session.waitForExistence(timeout: 5))
            session.tap()
        }
        XCTAssertTrue(app.navigationBars["Session planen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["TEILNEHMER"].exists)
        capture("06-hosted-session")
    }

    func testGymOffersConcreteBodyAreas() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        revealAndTap(app.buttons["Push"], in: app)
        // Saved plans and split choices precede the lazy body-area grid. Reveal
        // the actual controls before checking them, as a person would scroll.
        let chest = app.buttons["gym-area-list-chest"]
        for _ in 0..<6 where !chest.isHittable { app.swipeUp() }
        XCTAssertTrue(chest.isHittable)
        XCTAssertTrue(chest.isSelected)
        XCTAssertTrue(app.buttons["gym-area-list-shoulders"].exists)
        XCTAssertTrue(app.buttons["gym-area-list-triceps"].exists)
        revealAndTap(app.buttons["gym-area-list-core"], in: app)
        XCTAssertTrue(app.buttons["gym-area-list-core"].isSelected)
        capture("04-gym-body-areas")
    }

    func testCreateTrainingGroup() {
        let app = launchDemo()
        app.tabBars.buttons["Freunde"].tap()
        app.buttons["Crew erstellen"].tap()
        XCTAssertTrue(app.navigationBars["Neue Crew"].waitForExistence(timeout: 3))
        let name = app.textFields["group-name"]
        name.tap()
        name.typeText("Weekend Crew")
        revealAndTap(app.buttons["Max"], in: app)
        revealAndTap(app.buttons["create-group"], in: app)
        XCTAssertTrue(app.staticTexts["Weekend Crew"].waitForExistence(timeout: 3))
        capture("friends-training-groups")
    }

    func testCancelLiveWorkoutFlow() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        revealAndTap(app.buttons["Push"], in: app)
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["open-live-activity"].tap()
        app.buttons["Aktivität abbrechen"].tap()
        let destructiveAction = app.sheets.buttons["Aktivität abbrechen"]
        XCTAssertTrue(destructiveAction.waitForExistence(timeout: 2))
        destructiveAction.tap()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 3))
    }

    func testFriendsAndActivityDetailsNavigation() {
        let app = launchDemo()
        app.tabBars.buttons["Freunde"].tap()
        XCTAssertTrue(app.staticTexts["Freunde"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Max"].exists)
        XCTAssertTrue(app.staticTexts["Sarah"].exists)
        XCTAssertTrue(app.buttons["share-fyrup-invite"].exists)
        XCTAssertTrue(app.buttons["share-fyrup-profile"].exists)
        XCTAssertTrue(app.buttons["invite-from-contacts"].exists)
        XCTAssertTrue(app.staticTexts["external-invite-limit"].exists)
        capture("18-friends")
        app.buttons["friend-sarah"].tap()
        XCTAssertTrue(app.staticTexts["@sarah"].waitForExistence(timeout: 3))
        capture("19-friend-profile")
        app.tabBars.buttons["Heute"].tap()
        revealAndTap(app.buttons["Details"].firstMatch, in: app)
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
        revealAndTap(app.buttons["Einstellungen"], in: app)
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 3))
        capture("23-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privatsphäre"].tap()
        XCTAssertTrue(app.navigationBars["Datenschutz"].waitForExistence(timeout: 2))
        capture("69-privacy-settings")
        let privacyHeading = app.staticTexts["privacy-visibility-heading"]
        XCTAssertTrue(privacyHeading.waitForExistence(timeout: 3))
        XCTAssertEqual(privacyHeading.label, "Wer sieht meine Aktivitäten?")
        let nobody = app.buttons["activity-visibility-nobody"]
        waitUntilReady(nobody)
        nobody.tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true AND enabled == true"), object: nobody)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 4), .completed)
        capture("72-privacy-confirmed")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privatsphäre"].tap()
        waitUntilReady(nobody)
        XCTAssertTrue(nobody.isSelected, "Reopening must load the confirmed server value")
        app.buttons["activity-visibility-friends"].tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true AND enabled == true"), object: app.buttons["activity-visibility-friends"])
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 4), .completed)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Abmelden"].tap()
        XCTAssertTrue(app.staticTexts["Gemeinsam\nmehr erreichen."].waitForExistence(timeout: 4))
        waitUntilReady(app.buttons["welcome-intro-next"])
        capture("02-onboarding-intro")
        app.buttons["welcome-intro-next"].tap()
        XCTAssertTrue(app.staticTexts["Gemeinsam aktiv.\nEine stärkere Crew."].waitForExistence(timeout: 3))
        waitUntilReady(app.buttons["welcome-crew-next"])
        capture("03-onboarding-crew")
        app.buttons["welcome-crew-next"].tap()
        waitUntilReady(app.buttons["welcome-email-login"])
        XCTAssertTrue(app.staticTexts["Willkommen bei"].exists)
        capture("00-welcome")
        app.buttons["welcome-create-account"].tap()
        assertRegistration(in: app)
        waitUntilReady(app.buttons["auth-close"])
        capture("06-email-registration")

        // Exercise both fresh sheet items, not merely the form's internal toggle.
        app.buttons["auth-close"].tap()
        waitUntilReady(app.buttons["welcome-email-login"])
        app.buttons["welcome-email-login"].tap()
        XCTAssertTrue(app.staticTexts["auth-title"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["auth-title"].label, "Willkommen zurück")
        XCTAssertEqual(app.buttons["auth-submit"].label, "Anmelden")
        XCTAssertFalse(app.staticTexts["Ein Großbuchstabe"].exists)
        XCTAssertTrue(app.buttons["Passwort vergessen"].exists)
        waitUntilReady(app.buttons["auth-close"])
        capture("06-email-login")
        app.buttons["auth-close"].tap()
        waitUntilReady(app.buttons["welcome-create-account"])
        app.buttons["welcome-create-account"].tap()
        assertRegistration(in: app)
        app.buttons["auth-switch-mode"].tap()
        XCTAssertEqual(app.staticTexts["auth-title"].label, "Willkommen zurück")
        app.buttons["auth-switch-mode"].tap()
        assertRegistration(in: app)
    }

    func testSettingsDestinationsWork() {
        let app = launchDemo()
        app.tabBars.buttons["Profil"].tap()
        revealAndTap(app.buttons["Einstellungen"], in: app)
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 3))

        revealAndTap(app.buttons["settings-about"], in: app)
        XCTAssertTrue(app.navigationBars["Über FYRUP"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["about-version"].exists)
        capture("73-about-fyrup")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        revealAndTap(app.buttons["settings-support"], in: app)
        XCTAssertTrue(app.navigationBars["Hilfe & Support"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["support-email-address"].label, "Kundenservice@objektsignal.com")
        XCTAssertTrue(app.buttons["support-compose-email"].exists)
        capture("74-help-support")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        revealAndTap(app.buttons["settings-friends"], in: app)
        XCTAssertTrue(app.staticTexts["Freunde"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Freunde"].isSelected)
        capture("75-settings-friends")
    }

    func testCrewGoalReferenceScreen() {
        let app = launchDemo()
        revealAndTap(app.buttons["crew-goal"], in: app)
        XCTAssertTrue(app.staticTexts["Unsere Crew"].waitForExistence(timeout: 3))
        capture("20-crew-goal")
    }

    func testNotificationsReferenceScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--social-fixtures"]
        app.launch()
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 4))
        app.buttons["Mitteilungen"].tap()
        XCTAssertTrue(app.navigationBars["Mitteilungen"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Sarah hat deine Aktivität gefeiert."].exists)
        capture("10-notifications")
    }

    func testInvitationResponseFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--social-fixtures"]
        app.launch()
        let invitation = app.buttons["session-invitation"]
        XCTAssertTrue(invitation.waitForExistence(timeout: 4))
        revealAndTap(invitation, in: app)
        XCTAssertTrue(app.buttons["✓ Dabei"].waitForExistence(timeout: 3))
        capture("14-invitation")
        app.buttons["✓ Dabei"].tap()
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["session-invitation"].exists)
        XCTAssertFalse(app.alerts["Hinweis"].exists)
    }

    func testProfileSportsRemainEditable() {
        let app = launchDemo()
        app.tabBars.buttons["Profil"].tap()
        app.buttons["Profil bearbeiten"].tap()
        XCTAssertTrue(app.navigationBars["Profil bearbeiten"].waitForExistence(timeout: 3))
        let yoga = app.buttons["Yoga"]
        for _ in 0..<4 where !yoga.isHittable { app.swipeUp() }
        XCTAssertTrue(yoga.isHittable)
        yoga.tap()
        let save = app.buttons["ÄNDERUNGEN SPEICHERN"]
        revealAndTap(save, in: app)
        XCTAssertTrue(app.staticTexts["Gym · Laufen · Yoga"].waitForExistence(timeout: 3))
    }

    func testCompleteOnboardingWithOptionalFields() {
        let app = XCUIApplication()
        app.launchArguments = ["--onboarding-demo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Erzähl uns von dir"].waitForExistence(timeout: 4))
        app.textFields["Max"].tap()
        app.textFields["Max"].typeText("Momo")
        app.textFields["maxfyrup"].tap()
        app.textFields["maxfyrup"].typeText("momo_fyrup")
        app.textFields["2003"].tap()
        app.textFields["2003"].typeText("1998")
        app.textFields["Köln"].tap()
        app.textFields["Köln"].typeText("Berlin\n")
        let progress = app.otherElements["onboarding-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(progress.frame.minY, app.frame.minY + 48, "Onboarding navigation must stay below the status bar")
        capture("onboarding-01-profile")
        app.buttons["Weiter"].tap()

        let sportsHeading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Was machst du gerne")).firstMatch
        XCTAssertTrue(sportsHeading.waitForExistence(timeout: 3))
        app.buttons["Gym"].tap()
        app.buttons["Laufen"].tap()
        capture("onboarding-02-sports")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["Was ist dein Fokus?"].waitForExistence(timeout: 3))
        capture("onboarding-03-gym")
        app.buttons["Weiter"].tap()

        let weeklyGoal = app.buttons["weekly-goal-4"]
        XCTAssertTrue(weeklyGoal.waitForExistence(timeout: 4))
        weeklyGoal.tap()
        let confirmWeeklyGoal = app.buttons["confirm-weekly-goal"]
        waitUntilReady(confirmWeeklyGoal)
        XCTAssertEqual(confirmWeeklyGoal.label, "Ziel festlegen")
        capture("37-weekly-goal")
        confirmWeeklyGoal.tap()

        XCTAssertTrue(app.staticTexts["Dein Wochenrhythmus"].waitForExistence(timeout: 4))
        capture("57-onboarding-training-routine")
        let skipRoutine = app.buttons["skip-training-routine"]
        waitUntilReady(skipRoutine)
        skipRoutine.tap()

        XCTAssertTrue(app.staticTexts["Freunde hinzufügen"].waitForExistence(timeout: 3))
        let friendSearch = app.textFields["Username suchen …"]
        friendSearch.tap()
        friendSearch.typeText("sarah\n")
        XCTAssertTrue(app.staticTexts["@sarah"].waitForExistence(timeout: 3))
        capture("onboarding-04-friends")
        app.buttons["Später"].tap()

        XCTAssertTrue(app.staticTexts["Jeder Schritt zählt."].waitForExistence(timeout: 4))
        capture("73-setup-health")
        // The choice is required, but an iOS permission is never silently accepted.
        XCTAssertFalse(app.buttons["personal-setup-next"].isEnabled)
        revealAndTap(app.buttons["setup-skip-health"], in: app)
        let stepGoal = app.textFields["setup-step-goal"]
        revealAndTap(stepGoal, in: app)
        stepGoal.typeText("8000")
        revealAndTap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        revealAndTap(app.buttons["personal-setup-next"], in: app)
        capture("74-setup-page-2")

        let height = app.textFields["setup-height"]
        XCTAssertTrue(height.waitForExistence(timeout: 3))
        revealAndTap(app.buttons["save-body-and-goal"], in: app)
        XCTAssertTrue(app.staticTexts["Gib Körpergröße und Gewicht ein. Beide Angaben bleiben privat auf diesem iPhone."].waitForExistence(timeout: 3))
        height.tap()
        height.typeText("182")
        revealAndTap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        let weight = app.textFields["setup-weight"]
        revealAndTap(weight, in: app)
        weight.typeText("84")
        revealAndTap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        revealAndTap(app.buttons["save-body-and-goal"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["body-data-saved"].firstMatch.waitForExistence(timeout: 3))

        revealAndTap(app.buttons["personal-setup-next"], in: app)
        capture("74-setup-page-3")
        revealAndTap(app.buttons["personal-setup-next"], in: app)
        capture("74-setup-page-4")
        revealAndTap(app.buttons["personal-setup-next"], in: app)

        XCTAssertTrue(app.staticTexts["Du bist startklar."].waitForExistence(timeout: 3))
        capture("onboarding-05-complete")
        app.buttons["FYRUP STARTEN"].tap()
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 3))
    }
}
