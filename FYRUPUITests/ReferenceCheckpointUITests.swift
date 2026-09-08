import XCTest

@MainActor final class ReferenceCheckpointUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(body: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reference-checkpoint", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if body { app.launchArguments.append("--reference-body") }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        for _ in 0..<10 {
            // XCTest may call an element below the floating bar hittable, then
            // tap a navigation button instead. Require its full visible bounds.
            let mainTab = app.buttons["tab-today"]
            let footer = app.buttons["personal-setup-next"]
            let isNavigation = element.identifier.hasPrefix("tab-") || element.identifier == "activity-composer"
            var lowerBound = app.frame.maxY
            if mainTab.exists && !isNavigation { lowerBound = mainTab.frame.minY }
            let isSetupFooter = ["personal-setup-next", "personal-setup-skip"].contains(element.identifier)
            if footer.exists && !isSetupFooter && element.label != "Fertig" { lowerBound = min(lowerBound, footer.frame.minY) }
            if element.isHittable && element.frame.minY >= app.frame.minY && element.frame.maxY <= lowerBound {
                element.tap(); return
            }
            let scroll = app.scrollViews.firstMatch
            if element.frame.midY < app.frame.midY { scroll.swipeDown() } else { scroll.swipeUp() }
        }
        XCTFail("Element nicht erreichbar: \(element.identifier)")
    }
    private func capture(_ id: String, app: XCUIApplication) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = id; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(id).png"), options: .atomic)
        // Only this isolated fixture suite exports its accessibility hierarchy.
        try app.debugDescription.write(to: directory.appendingPathComponent("\(id)-accessibility.txt"), atomically: true, encoding: .utf8)
        let configuration: [String: Any] = ["screen": id, "widthPoints": app.frame.width, "heightPoints": app.frame.height,
            "fixture": "ReferenceCheckpointFixtures", "date": "2025-05-22T07:41:00Z", "locale": "de_DE", "timezone": "Europe/Berlin",
            "source": "Production SwiftUI views with isolated fixtures; NOT a physical-device test"]
        try JSONSerialization.data(withJSONObject: configuration, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("\(id).json"), options: .atomic)
    }

    func testA01TodayReferenceAndNavigation() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["home-greeting"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["home-greeting"].label, "Guten Morgen")
        try capture("A01-top", app: app)
        XCTAssertTrue(app.buttons["tab-week"].exists)
        XCTAssertFalse(app.buttons["home-start-hero"].exists)
        XCTAssertFalse(app.buttons["start-rest-timer"].exists)
        XCTAssertTrue(app.staticTexts["Supplements heute"].exists)
        XCTAssertLessThan(app.staticTexts["Supplements heute"].frame.minY, app.staticTexts["Deine Crew"].firstMatch.frame.minY)
        app.swipeUp(); try capture("A01-scroll", app: app)
        tap(app.buttons["tab-week"], in: app)
        XCTAssertTrue(app.staticTexts["Wochenplan"].firstMatch.waitForExistence(timeout: 5))
        tap(app.buttons["activity-composer"], in: app)
        XCTAssertTrue(app.staticTexts["activity-composer-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].exists)
        tap(app.buttons["Schließen"], in: app)
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["profile-nutrition"], in: app)
        try capture("A19-manual-diary-checkpoint", app: app)
        XCTAssertTrue(app.buttons["nutrition-goal-summary"].waitForExistence(timeout: 5))
    }

    func testR05BodyReferenceSavesOnContinueAndDoesNotForceHealth() throws {
        let app = launch(body: true)
        let height = app.textFields["setup-height"]
        XCTAssertTrue(height.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tab-today"].exists, "No main navigation during onboarding")
        XCTAssertEqual(height.value as? String, "180")
        try capture("R05-body", app: app)
        tap(height, in: app)
        height.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "182")
        try capture("R05-keyboard", app: app)
        tap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.staticTexts["Dein Hauptziel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["rest-options"].exists)
        XCTAssertFalse(app.buttons["Alle erlauben"].exists)
        tap(app.buttons["Zurück"].firstMatch, in: app)
        XCTAssertEqual(height.value as? String, "182")
    }

    func testNutritionMealEditUpdatesOverviewAndToday() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["home-nutrition-card"].waitForExistence(timeout: 10))
        tap(app.buttons["home-nutrition-card"], in: app)
        tap(app.buttons["nutrition-meal-lunch"], in: app)
        tap(app.buttons["nutrition-entry-00000000-0000-4000-8000-000000000100"], in: app)
        let amount = app.textFields["Gegessene Menge"]
        tap(amount, in: app)
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (amount.value as? String ?? "").count) + "250")
        tap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        tap(app.buttons["Speichern"], in: app)
        XCTAssertTrue(app.staticTexts["250 g · 925 kcal"].waitForExistence(timeout: 5))
        tap(app.buttons["Schließen"].firstMatch, in: app)
        XCTAssertTrue(app.buttons["nutrition-goal-summary"].label.contains("925"))
        XCTAssertTrue(app.buttons["nutrition-meal-lunch"].label.contains("925 kcal"))
        try capture("A19-edited-meal-summary", app: app)
        tap(app.navigationBars.buttons.element(boundBy: 0), in: app)
        XCTAssertTrue(app.buttons["home-nutrition-card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home-nutrition-card"].label.contains("925"), "Today reflects food intake, not active energy")
    }

    func testR05LargeTypeRemainsScrollableAndActionReachable() throws {
        let app = launch(body: true, largeText: true)
        XCTAssertTrue(app.textFields["setup-height"].waitForExistence(timeout: 10))
        try capture("R05-large-type-top", app: app)
        let target = app.textFields["setup-target-weight"]
        let action = app.buttons["personal-setup-next"]
        for _ in 0..<10 where !target.isHittable || target.frame.maxY >= action.frame.minY { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(target.isHittable, "All body fields must be reachable, not only the fixed footer")
        try capture("R05-large-type-scroll", app: app)
        XCTAssertTrue(action.isHittable)
        XCTAssertLessThan(target.frame.maxY, action.frame.minY)
        XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY)
        tap(action, in: app)
        XCTAssertTrue(app.staticTexts["Dein Hauptziel"].waitForExistence(timeout: 5))
    }

    func testNamedSetupChoicesAndEditableSummary() throws {
        let app = launch(body: true)
        tap(app.buttons["personal-setup-skip"], in: app)
        let primary = app.buttons["setup-primary-feelFitter"]
        XCTAssertFalse(primary.isSelected)
        tap(primary, in: app); XCTAssertTrue(primary.isSelected)
        try capture("R06-primary-goal", app: app)
        tap(app.buttons["personal-setup-next"], in: app)
        tap(app.buttons["setup-additional-friends"], in: app)
        tap(app.buttons["setup-additional-steps"], in: app)
        try capture("R07-additional-goals", app: app)
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.buttons["weekly-goal-2"].waitForExistence(timeout: 5))
        try capture("R08-weekly-goal", app: app)
        tap(app.buttons["personal-setup-skip"], in: app)
        tap(app.buttons["setup-day-1"], in: app); tap(app.buttons["setup-day-6"], in: app)
        try capture("R09-preferred-days", app: app)
        tap(app.buttons["personal-setup-next"], in: app)
        tap(app.buttons["setup-time-flexible"], in: app)
        try capture("R10-preferred-time", app: app)
        tap(app.buttons["personal-setup-next"], in: app)
        for _ in 0..<7 { tap(app.buttons["personal-setup-skip"], in: app) }
        XCTAssertTrue(app.staticTexts["Alles bereit!"].waitForExistence(timeout: 5))
        try capture("R18-setup-summary", app: app)
        tap(app.buttons["setup-summary-primaryGoal"], in: app)
        XCTAssertTrue(primary.isSelected)
        tap(app.buttons["setup-primary-stayActive"], in: app)
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.staticTexts["Alles bereit!"].waitForExistence(timeout: 5))
    }

    func testWelcomeAndEmailChoiceUseRealFormsAndKeepPasswordVisibility() throws {
        let app = launch()
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["Abmelden"], in: app)
        XCTAssertTrue(app.staticTexts["welcome-heading"].waitForExistence(timeout: 8))
        try capture("R01-welcome", app: app)
        tap(app.buttons["welcome-intro-next"], in: app)
        XCTAssertTrue(app.staticTexts["account-choice-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Mit Google fortfahren"].exists, "No disabled production provider presented as functional")
        try capture("R02-account-choice", app: app)
        tap(app.buttons["welcome-create-account"], in: app)
        XCTAssertTrue(app.staticTexts["auth-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["auth-submit"].isEnabled)
        try capture("R03-email-form", app: app)
        tap(app.secureTextFields["auth-password"], in: app)
        app.secureTextFields["auth-password"].typeText("FixtureOnly42")
        tap(app.buttons["auth-toggle-password"], in: app)
        XCTAssertEqual(app.textFields["auth-password"].value as? String, "FixtureOnly42")
        tap(app.buttons["auth-close"], in: app)
        tap(app.buttons["welcome-email-login"], in: app)
        XCTAssertEqual(app.staticTexts["auth-title"].label, "Willkommen zurück")
        XCTAssertFalse(app.buttons["Passwort vergessen"].isEnabled)
        XCTAssertFalse(app.buttons["auth-submit"].isEnabled, "Password does not leak between forms")
    }

    func testSetupSupplementSavesOwnAmountWithoutDosageOrReminderConsent() throws {
        let app = launch(body: true)
        for _ in 0..<6 { tap(app.buttons["personal-setup-skip"], in: app) }
        tap(app.buttons["setup-supplement-Kreatin"], in: app)
        let amount = app.textFields["supplement-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "Keine Angabe", "No dosage suggestion")
        tap(amount, in: app); amount.typeText("1,5")
        tap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        XCTAssertFalse(app.buttons["save-supplement"].isEnabled, "An amount needs an explicitly chosen unit")
        tap(app.buttons["supplement-amount-unit"], in: app)
        tap(app.buttons["g"], in: app)
        try capture("R11-own-supplement-amount", app: app)
        tap(app.buttons["save-supplement"], in: app)
        XCTAssertTrue(app.buttons["setup-supplement-Kreatin"].waitForExistence(timeout: 5))
        try capture("R11-supplement-grid", app: app)
        tap(app.buttons["setup-supplement-Kreatin"], in: app)
        XCTAssertEqual(amount.value as? String, "1,5")
        let reminders = app.switches["supplement-reminders"]
        tap(app.staticTexts["Deine Uhrzeiten"], in: app)
        XCTAssertEqual(reminders.value as? String, "0", "A quantity must not turn on reminders")
    }
}
