import XCTest
@testable import FYRUP

final class TerminologyTests: XCTestCase {
    private struct Example: Decodable {
        let type: String; let title: String; let body: String
        let expectedTitle: String; let expectedBody: String
    }
    func testPushAndInboxUseSharedGoldenExamplesWithoutRewritingUserContent() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "terminology-notifications", withExtension: "json"))
        let examples = try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
        XCTAssertEqual(examples.count, 16)
        for example in examples {
            let result = FyrupLanguage.notification(type: example.type, title: example.title, body: example.body)
            XCTAssertEqual(result.title, example.expectedTitle, example.type)
            XCTAssertEqual(result.body, example.expectedBody, example.type)
            let repeated = FyrupLanguage.notification(type: example.type, title: result.title, body: result.body)
            XCTAssertEqual(repeated.title, result.title); XCTAssertEqual(repeated.body, result.body)
        }
    }
    func testLegacyCatalogKeepsStoredValuesButDisplaysModernWords() {
        let pairs: [(SportKind, String, String)] = [(.gym, "Freies Training", "Freies Workout"),
            (.football, "Mannschaftstraining", "Team-Session"), (.football, "Einzeltraining", "Solo-Session"),
            (.basketball, "Training", "Skills"), (.basketball, "Einzeltraining", "Solo-Session"),
            (.racket, "Tennis · Training", "Tennis · Üben"), (.racket, "Padel · Training", "Padel · Üben")]
        for (sport, old, display) in pairs {
            XCTAssertTrue(SportCatalog.subtypes[sport]?.contains(old) == true)
            XCTAssertEqual(FyrupLanguage.subtype(old, sport: sport), display)
            XCTAssertEqual(FyrupLanguage.subtype(old, sport: sport, workoutPlanID: UUID()), old, "Named user plans stay untouched")
        }
        XCTAssertEqual(FyrupLanguage.subtype("Training mit Max", sport: .gym), "Training mit Max")
        XCTAssertEqual(FyrupLanguage.subtype("Training", sport: .other), "Training")
        XCTAssertNil(FyrupLanguage.subtype(nil, sport: .gym))
    }
    func testLegacyLocalizationKeysNeverDisplayLegacyActions() {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.localizedString(forKey: "TRAINING PLANEN", value: nil, table: nil), "SESSION PLANEN")
        XCTAssertEqual(bundle.localizedString(forKey: "TRAINING BEENDEN", value: nil, table: nil), "ABSCHLIESSEN")
    }
}
