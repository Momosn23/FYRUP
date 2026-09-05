import XCTest

@MainActor
final class StepFlowsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--steps-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 8))
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 3)
        for _ in 0..<7 {
            if element.exists && element.isHittable && element.isEnabled { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Nicht erreichbares Steuerelement: \(element)")
    }

    private func openSteps(_ app: XCUIApplication) {
        app.tabBars.buttons["Profil"].tap()
        tap(app.buttons["Privatsphäre"], in: app)
        tap(app.buttons["privacy-steps"], in: app)
        XCTAssertTrue(app.navigationBars["Schritte"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/fyrup-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    func testHealthIsOptionalAndNotNowKeepsTrainingAvailable() {
        let app = launch()
        XCTAssertFalse(app.buttons["own-steps-card"].exists)
        openSteps(app)
        tap(app.buttons["connect-health"], in: app)
        XCTAssertTrue(app.staticTexts["Deine tägliche Bewegung"].waitForExistence(timeout: 4))
        capture("34-health-explanation")
        tap(app.buttons["Nicht jetzt"], in: app)
        XCTAssertTrue(app.navigationBars["Schritte"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Heute"].tap()
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["own-steps-card"].exists)
    }

    func testConnectingShowsOwnStepsWithoutSharingAndCanRevokeSharing() {
        let app = launch()
        openSteps(app)
        let sharing = app.switches["share-steps"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 5))
        XCTAssertEqual(sharing.value as? String, "0")
        tap(app.buttons["connect-health"], in: app)
        tap(app.buttons["confirm-connect-health"], in: app)
        XCTAssertTrue(app.navigationBars["Schritte"].waitForExistence(timeout: 5))
        XCTAssertEqual(sharing.value as? String, "0")
        app.tabBars.buttons["Heute"].tap()
        XCTAssertTrue(app.buttons["own-steps-card"].waitForExistence(timeout: 5))
        let count = NSPredicate(format: "label CONTAINS '8.421' OR label CONTAINS '8,421'")
        XCTAssertTrue(app.descendants(matching: .any).matching(count).firstMatch.exists)
        capture("35-own-daily-steps")
        tap(app.buttons["own-steps-card"], in: app)
        tap(sharing, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: sharing)], timeout: 4), .completed)
        tap(sharing, in: app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: sharing)], timeout: 4), .completed)
        capture("36-step-privacy")
    }
}
