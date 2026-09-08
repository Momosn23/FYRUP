import XCTest

extension XCUIApplication {
    @MainActor func openFYRUPCrew(file: StaticString = #filePath, line: UInt = #line) {
        let today = buttons["tab-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), file: file, line: line)
        today.tap()
        let link = buttons["open-crew"]
        for _ in 0..<10 {
            if link.exists && link.isHittable { link.tap(); return }
            if link.exists && link.frame.midY < frame.midY { swipeDown() } else { swipeUp() }
        }
        XCTFail("Crew-Einstieg nicht erreichbar", file: file, line: line)
    }
}
