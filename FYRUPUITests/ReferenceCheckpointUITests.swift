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
            if element.isHittable { element.tap(); return }
            if element.frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Element nicht erreichbar: \(element.identifier)")
    }
    private func capture(_ id: String, app: XCUIApplication) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = id; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(id).png"), options: .atomic)
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
        XCTAssertTrue(app.buttons["tab-week"].exists)
        XCTAssertFalse(app.buttons["home-start-hero"].exists)
        XCTAssertFalse(app.buttons["start-rest-timer"].exists)
        XCTAssertTrue(app.staticTexts["Supplements heute"].exists)
        XCTAssertLessThan(app.staticTexts["Supplements heute"].frame.minY, app.staticTexts["Deine Crew"].firstMatch.frame.minY)
        try capture("A01-top", app: app)
        app.swipeUp(); try capture("A01-scroll", app: app)
        tap(app.buttons["tab-week"], in: app)
        XCTAssertTrue(app.staticTexts["Wochenplan"].waitForExistence(timeout: 5))
        tap(app.buttons["activity-composer"], in: app)
        XCTAssertTrue(app.staticTexts["activity-composer-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schließen"].exists)
        tap(app.buttons["Schließen"], in: app)
        tap(app.buttons["tab-profile"], in: app)
        tap(app.buttons["profile-nutrition"], in: app)
        XCTAssertTrue(app.buttons["nutrition-goal-summary"].waitForExistence(timeout: 5))
        try capture("A19-manual-diary-checkpoint", app: app)
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
        app.swipeUp(); try capture("R05-large-type-scroll", app: app)
        let action = app.buttons["personal-setup-next"]
        XCTAssertTrue(action.isHittable)
        XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY)
        tap(action, in: app)
        XCTAssertTrue(app.staticTexts["Berechtigungen"].waitForExistence(timeout: 5))
    }
}
