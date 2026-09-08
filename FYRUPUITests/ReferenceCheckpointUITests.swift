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
            if footer.exists && element.identifier != "personal-setup-next" && element.label != "Fertig" { lowerBound = min(lowerBound, footer.frame.minY) }
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
        XCTAssertEqual(height.value as? String, "180.0")
        try capture("R05-body", app: app)
        tap(height, in: app)
        height.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "182")
        try capture("R05-keyboard", app: app)
        tap(app.toolbars.buttons["Fertig"].firstMatch, in: app)
        tap(app.buttons["personal-setup-next"], in: app)
        XCTAssertTrue(app.staticTexts["Berechtigungen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["rest-options"].exists)
        XCTAssertFalse(app.buttons["Alle erlauben"].exists)
        tap(app.buttons["Zurück"].firstMatch, in: app)
        XCTAssertEqual(height.value as? String, "182")
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
        XCTAssertTrue(app.staticTexts["Berechtigungen"].waitForExistence(timeout: 5))
    }
}
