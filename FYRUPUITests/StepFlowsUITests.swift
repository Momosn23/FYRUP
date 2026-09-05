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

    private func waitUntilReady(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func waitUntilDismissed(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, file: file, line: line)
    }

    private func waitForSharing(_ element: XCUIElement, enabled: Bool, file: StaticString = #filePath, line: UInt = #line) {
        // Confirmed preferences replace the temporary loading row after each request.
        let predicate = NSPredicate(format: "exists == true AND enabled == true AND value == %@", enabled ? "1" : "0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 4), .completed, file: file, line: line)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<7 {
            if element.exists && !element.isEnabled {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
                guard XCTWaiter.wait(for: [ready], timeout: 3) == .completed else {
                    XCTFail("Das Steuerelement blieb deaktiviert: \(element)", file: file, line: line)
                    return
                }
            }
            if element.exists && element.isHittable {
                guard waitUntilReady(element) else {
                    XCTFail("Das Steuerelement wurde nicht bedienbar: \(element)", file: file, line: line)
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
        XCTFail("Nicht erreichbares Steuerelement: \(element)", file: file, line: line)
    }

    private func openSteps(_ app: XCUIApplication) {
        tap(app.tabBars.buttons["Profil"], in: app)
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
        waitUntilDismissed(app.buttons["Schließen"].firstMatch)
        waitUntilDismissed(app.buttons["confirm-connect-health"].firstMatch)
        XCTAssertTrue(app.navigationBars["Schritte"].waitForExistence(timeout: 4))
        tap(app.tabBars.buttons["Heute"], in: app)
        XCTAssertTrue(app.buttons["JETZT LOS"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["own-steps-card"].exists)
    }

    func testConnectingShowsOwnStepsWithoutSharingAndCanRevokeSharing() {
        let app = launch()
        openSteps(app)
        let sharing = app.switches["share-steps"].firstMatch
        waitForSharing(sharing, enabled: false)
        tap(app.buttons["connect-health"], in: app)
        tap(app.buttons["confirm-connect-health"], in: app)
        waitUntilDismissed(app.buttons["Schließen"].firstMatch)
        waitUntilDismissed(app.buttons["confirm-connect-health"].firstMatch)
        XCTAssertTrue(app.navigationBars["Schritte"].waitForExistence(timeout: 5))
        waitForSharing(sharing, enabled: false)
        tap(app.tabBars.buttons["Heute"], in: app)
        XCTAssertTrue(app.buttons["own-steps-card"].waitForExistence(timeout: 5))
        let count = NSPredicate(format: "label CONTAINS '8.421' OR label CONTAINS '8,421'")
        XCTAssertTrue(app.descendants(matching: .any).matching(count).firstMatch.waitForExistence(timeout: 3))
        capture("35-own-daily-steps")
        tap(app.buttons["own-steps-card"], in: app)
        tap(sharing, in: app)
        waitForSharing(sharing, enabled: true)
        tap(sharing, in: app)
        waitForSharing(sharing, enabled: false)
        capture("36-step-privacy")
    }
}
