import XCTest

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
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 4))
        return app
    }

    private func revealAndTap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    func testTodayStartAndCompleteFlow() {
        let app = launchDemo()
        capture("01-home-feed")
        app.buttons["JETZT LOS"].tap()
        capture("04-activity-categories")
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        XCTAssertTrue(app.buttons["TRAINING BEENDEN"].exists)
        capture("07-live-training")
        app.buttons["TRAINING BEENDEN"].tap()
        XCTAssertTrue(app.staticTexts["Workout geschafft!"].waitForExistence(timeout: 3))
        capture("08-workout-complete")
        app.buttons["Auf Feed teilen"].tap()
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 3))
    }

    func testFyrupIsOneTap() {
        let app = launchDemo()
        XCTAssertTrue(app.buttons["FYR UP 🔥"].waitForExistence(timeout: 4))
        app.buttons["FYR UP 🔥"].tap()
    }

    func testPlanWorkoutFlow() {
        let app = launchDemo()
        app.buttons["Planen"].tap()
        XCTAssertTrue(app.staticTexts["Was möchtest du machen?"].waitForExistence(timeout: 2))
        app.buttons["Laufen"].tap()
        app.buttons["PLANEN"].tap()
        capture("05-plan-workout")
        let joinToggle = app.switches["Freunde dürfen sich anschließen"]
        XCTAssertTrue(joinToggle.exists)
        let confirm = app.buttons.matching(identifier: "confirm-activity").element
        revealAndTap(confirm, in: app)
        XCTAssertTrue(app.staticTexts["PLANNED"].waitForExistence(timeout: 3))
        app.buttons["TRAINING ÖFFNEN"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Training planen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["TEILNEHMER"].exists)
        capture("06-hosted-session")
    }

    func testGymOffersConcreteBodyAreas() {
        let app = launchDemo()
        app.buttons["JETZT LOS"].tap()
        app.buttons["Gym"].tap()
        app.buttons["Push"].tap()
        XCTAssertTrue(app.buttons["gym-area-chest"].exists)
        XCTAssertTrue(app.buttons["gym-area-shoulders"].exists)
        XCTAssertTrue(app.buttons["gym-area-triceps"].exists)
        revealAndTap(app.buttons["gym-area-core"], in: app)
        capture("04-gym-body-areas")
    }

    func testCreateTrainingGroup() {
        let app = launchDemo()
        app.tabBars.buttons["Freunde"].tap()
        app.buttons["Gruppe erstellen"].tap()
        XCTAssertTrue(app.navigationBars["Neue Trainingsgruppe"].waitForExistence(timeout: 3))
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
        app.buttons["Push"].tap()
        app.buttons.matching(identifier: "confirm-activity").element.tap()
        app.buttons["TRAINING ÖFFNEN"].tap()
        app.buttons["Training abbrechen"].tap()
        let destructiveAction = app.sheets.buttons["Training abbrechen"]
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
        app.tabBars.buttons["Heute"].tap()
        app.buttons["Details"].firstMatch.tap()
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
        app.buttons["Privatsphäre"].tap()
        XCTAssertTrue(app.navigationBars["Datenschutz"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Wer sieht meine Aktivitäten?"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Abmelden"].tap()
        XCTAssertTrue(app.staticTexts["Gemeinsam\nmehr erreichen."].waitForExistence(timeout: 4))
        app.buttons["Los geht's"].tap()
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.buttons["Mit E-Mail anmelden"].waitForExistence(timeout: 3))
        capture("00-welcome")
    }

    func testNotificationsReferenceScreen() {
        let app = launchDemo()
        app.buttons["Mitteilungen"].tap()
        XCTAssertTrue(app.navigationBars["Mitteilungen"].waitForExistence(timeout: 2))
        capture("10-notifications")
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
        app.textFields["Köln"].typeText("Berlin")
        capture("onboarding-01-profile")
        app.buttons["Weiter"].tap()

        let sportsHeading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Was machst du gerne")).firstMatch
        XCTAssertTrue(sportsHeading.waitForExistence(timeout: 3))
        app.buttons["Gym"].tap()
        app.buttons["Laufen"].tap()
        capture("onboarding-02-sports")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["Was genau trainierst du?"].waitForExistence(timeout: 3))
        capture("onboarding-03-gym")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["Freunde hinzufügen"].waitForExistence(timeout: 3))
        capture("onboarding-04-friends")
        app.buttons["Später"].tap()

        XCTAssertTrue(app.staticTexts["Du bist startklar."].waitForExistence(timeout: 3))
        capture("onboarding-05-complete")
        app.buttons["FYRUP STARTEN"].tap()
        XCTAssertTrue(app.staticTexts["Guten Morgen"].waitForExistence(timeout: 3))
    }
}
