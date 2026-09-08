import XCTest
@testable import FYRUP

@MainActor
final class ReferenceRevisionTests: XCTestCase {
    private let day = "2026-09-08"
    private func entry(grams: Double = 150) -> NutritionEntry {
        .init(name: "Eigene Mahlzeit", day: day, meal: .lunch, grams: grams,
              per100g: .init(kcal: 200, protein: 10, carbohydrates: 20, fat: 8))
    }

    func testNutritionIsPortionBasedNotActiveEnergy() {
        let value = entry()
        XCTAssertEqual(value.consumed.kcal, 300)
        XCTAssertEqual(value.consumed.protein, 15)
        let diary = NutritionDiary(goal: .init(kcal: 2000), entries: [value])
        XCTAssertEqual(diary.total(on: day).kcal, 300)
        XCTAssertEqual(diary.remainingText(on: day), "1.700 kcal übrig")
        XCTAssertEqual(NutritionDayPresentation(diary: diary, day: day).progress, 0.15)
        XCTAssertEqual(diary.total(on: "2026-09-07").kcal, 0)
    }

    func testOverGoalIsNeutralAndNoValuesDoesNotMeanZero() {
        let diary = NutritionDiary(goal: .init(kcal: 250), entries: [entry()])
        XCTAssertEqual(diary.remainingText(on: day), "50 kcal über deinem Ziel")
        XCTAssertNil(NutritionDayPresentation(diary: nil, day: day).calories)
        XCTAssertEqual(NutritionDayPresentation(diary: nil, day: day).remaining, "Nicht verfügbar")
        XCTAssertNil(NutritionDayPresentation(diary: .init(), day: day).calories)
        XCTAssertEqual(NutritionDayPresentation(diary: .init(goal: .init(kcal: 2000)), day: day).calories, 0)
        XCTAssertEqual(NutritionDayPresentation(diary: .init(entries: [entry()]), day: day).calories, 300)
    }

    func testUnknownMacrosAreNotZero() {
        var value = entry(); value.per100g.protein = nil
        let totals = NutritionValues.total([value.consumed, entry().consumed])
        XCTAssertEqual(totals.kcal, 600)
        XCTAssertNil(totals.protein)
        XCTAssertEqual(totals.carbohydrates, 60)
    }

    func testInvalidDatesAmountsAndNonFiniteValuesRejected() {
        for day in ["2026-02-29", "2026-13-02", "2026-04-31", "2026-2-1", "abcd-ef-gh"] { XCTAssertFalse(NutritionDay.isValid(day)) }
        XCTAssertTrue(NutritionDay.isValid("2024-02-29"))
        for grams in [0, -1, Double.infinity, Double.nan, 10_001] { XCTAssertFalse(entry(grams: grams).isValid) }
        var value = entry(); value.per100g.kcal = .infinity; XCTAssertFalse(value.isValid)
        value = entry(); value.per100g.fat = -1; XCTAssertFalse(value.isValid)
        XCTAssertFalse(NutritionDiary(entries: [entryWithID(), entryWithID()]).isValid)
    }

    private func entryWithID() -> NutritionEntry {
        var value = entry(); value.id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!; return value
    }

    func testRepeatedSavesAndAccountSwitchAreIsolated() throws {
        let persistence = MemoryNutritionPersistence(), owner = UUID(), stranger = UUID()
        let store = NutritionStore(persistence: persistence)
        store.activate(owner: owner)
        var value = entry()
        XCTAssertTrue(store.save(value)); XCTAssertTrue(store.save(value))
        XCTAssertEqual(store.diary?.entries.count, 1)
        value.grams = 200; XCTAssertTrue(store.save(value)); XCTAssertEqual(store.diary?.total(on: day).kcal, 400)
        store.activate(owner: stranger); XCTAssertEqual(store.diary?.entries.count, 0)
        store.activate(owner: owner); XCTAssertEqual(store.diary?.entries.count, 1)
        try store.deleteAccount(); XCTAssertNil(persistence.values[owner]); XCTAssertNil(store.diary)
    }

    func testWriteFailureKeepsConfirmedNutritionUnchanged() {
        let persistence = FailingNutritionPersistence(), store = NutritionStore(persistence: FailingNutritionPersistence())
        // No data payload is printed in error messages or assertions.
        store.activate(owner: UUID())
        XCTAssertFalse(store.save(entry()))
        XCTAssertEqual(store.diary?.entries.count, 0)
        XCTAssertNotNil(store.errorMessage)
        let readFailure = NutritionStore(persistence: persistence)
        persistence.failRead = true; readFailure.activate(owner: UUID())
        XCTAssertNil(readFailure.diary)
        XCTAssertFalse(readFailure.save(entry()))
    }

    func testOptionalBodyDraftAndExistingPreferencesArePreserved() throws {
        var preferences = PersonalSetupPreferences()
        preferences.activeCalorieGoal = 400; preferences.liveActivityEnabled = true
        let blank = BodyMeasurementsDraft()
        XCTAssertNil(blank.validationMessage)
        blank.apply(to: &preferences)
        XCTAssertNil(preferences.heightCM); XCTAssertNil(preferences.weightKG)
        XCTAssertEqual(preferences.activeCalorieGoal, 400); XCTAssertTrue(preferences.liveActivityEnabled)
        var entered = BodyMeasurementsDraft(); entered.height = "180"; entered.weight = "75,5"; entered.targetWeight = "70"
        XCTAssertNil(entered.validationMessage); entered.apply(to: &preferences)
        XCTAssertEqual(preferences.weightKG, 75.5); XCTAssertEqual(preferences.targetWeightKG, 70)
        entered.targetWeight = "-1"; XCTAssertNotNil(entered.validationMessage)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        json.removeValue(forKey: "targetWeightKG")
        let old = try JSONDecoder().decode(PersonalSetupPreferences.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.heightCM, 180); XCTAssertNil(old.targetWeightKG)
    }
}

@MainActor private final class FailingNutritionPersistence: NutritionPersisting {
    var failRead = false
    func load(owner: UUID) throws -> NutritionDiary? { if failRead { throw AppError.server }; return nil }
    func save(_ diary: NutritionDiary, owner: UUID) throws { throw AppError.server }
    func delete(owner: UUID) throws {}
}
