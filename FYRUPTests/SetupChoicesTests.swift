import XCTest
@testable import FYRUP

final class SetupChoicesTests: XCTestCase {
    func testNoChoicesOrConsentAreAssumed() {
        let choices = SetupChoices()
        XCTAssertNil(choices.primaryGoal)
        XCTAssertTrue(choices.additionalGoals.isEmpty)
        XCTAssertTrue(choices.preferredDays.isEmpty)
        XCTAssertNil(choices.preferredTime)
    }

    func testPreferencesRoundTripWithoutCreatingAWeeklyGoalOrGrantingPermissions() throws {
        var preferences = PersonalSetupPreferences()
        preferences.setupChoices = SetupChoices(primaryGoal: .feelFitter, additionalGoals: [.friends, .steps],
            preferredDays: [.monday, .saturday], preferredTime: .flexible)
        let restored = try JSONDecoder().decode(PersonalSetupPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(restored, preferences)
        XCTAssertNil(restored.activeCalorieGoal)
        XCTAssertFalse(restored.energyRequested)
        XCTAssertFalse(restored.liveActivityEnabled)
        XCTAssertNil(restored.weatherPlace)
        XCTAssertFalse(restored.completed)
    }

    func testLegacySettingsDecodeWithoutInventedChoicesOrChangingOldPage() throws {
        var old = PersonalSetupPreferences()
        old.completed = true; old.setupPage = 2; old.heightCM = 180
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "setupChoices")
        let restored = try JSONDecoder().decode(PersonalSetupPreferences.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.setupChoices)
        XCTAssertTrue(restored.completed)
        XCTAssertEqual(restored.setupPage, 2)
        XCTAssertEqual(restored.heightCM, 180)
    }

    func testWeekdayOrderingIsExplicitAndInvalidDaysCannotDecode() throws {
        XCTAssertEqual(SetupWeekday.allCases.map(\.rawValue), Array(1...7))
        XCTAssertEqual(SetupWeekday.monday.calendarWeekday, 2)
        XCTAssertEqual(SetupWeekday.sunday.calendarWeekday, 1)
        XCTAssertThrowsError(try JSONDecoder().decode(SetupWeekday.self, from: Data("8".utf8)))
    }
}
