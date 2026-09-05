import XCTest
@testable import FYRUP

@MainActor
final class PersonalSetupTests: XCTestCase {
    func testSetupNeverEnablesSensitiveFeaturesByDefault() {
        let store = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence())
        store.activate(userID: UUID())
        XCTAssertEqual(store.value?.completed, false); XCTAssertEqual(store.value?.energyRequested, false)
        XCTAssertEqual(store.value?.liveActivityEnabled, false)
        XCTAssertNil(store.value?.weightKG); XCTAssertNil(store.value?.heightCM); XCTAssertNil(store.value?.activeCalorieGoal)
    }
    func testBodyPreferencesAreAccountIsolatedAndCanBeDeleted() throws {
        let persistence = MemoryPersonalSetupPersistence(), owner = UUID(), other = UUID()
        let store = PersonalSetupStore(persistence: persistence); store.activate(userID: owner)
        XCTAssertTrue(store.update { $0.heightCM = 180; $0.weightKG = 80; $0.activeCalorieGoal = 500 })
        store.activate(userID: other); XCTAssertNil(store.value?.heightCM)
        store.activate(userID: owner); XCTAssertEqual(store.value?.heightCM, 180)
        XCTAssertTrue(store.deleteMeasurements()); XCTAssertNil(store.value?.heightCM); XCTAssertNil(store.value?.weightKG)
        XCTAssertEqual(store.value?.activeCalorieGoal, 500)
        try store.clearDeletedAccount(); XCTAssertNil(persistence.values[owner]); XCTAssertNil(store.value)
    }
    func testValidationDoesNotOverwriteConfirmedMeasurements() {
        let store = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence()); store.activate(userID: UUID())
        XCTAssertTrue(store.update { $0.weightKG = 80 })
        for weight in [-1, 0, 19, 451, .infinity, .nan] {
            XCTAssertFalse(store.update { $0.weightKG = weight }); XCTAssertEqual(store.value?.weightKG, 80)
        }
        XCTAssertFalse(store.update { $0.heightCM = 300 })
        XCTAssertFalse(store.update { $0.activeCalorieGoal = -1 })
    }
    func testStorageFailureDoesNotPretendItSavedOrOverwriteOnFailedLoad() {
        let storage = FailingSetupPersistence(), store = PersonalSetupStore(persistence: FailingSetupPersistence())
        store.activate(userID: UUID()); XCTAssertNil(store.value); XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.update { $0.weightKG = 70 })
        storage.failsRead = false
        let writable = PersonalSetupStore(persistence: storage); writable.activate(userID: UUID())
        XCTAssertFalse(writable.update { $0.completed = true }); XCTAssertEqual(writable.value?.completed, false)
    }
    func testEnergyPermissionIsExplicitAndNilIsNotZero() async {
        let setup = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence()); let owner = UUID(); setup.activate(userID: owner)
        let reader = EnergyTestReader(); let store = ActiveEnergyStore(setup: setup, reader: reader)
        store.accountChanged(to: owner); await store.refresh(force: true)
        XCTAssertEqual(reader.requests, 0); XCTAssertEqual(reader.reads, 0); XCTAssertNil(store.kilocalories)
        await store.connect(); XCTAssertEqual(reader.requests, 1); XCTAssertNil(store.kilocalories)
        XCTAssertEqual(setup.value?.energyRequested, true)
        reader.result = 420.5; await store.refresh(force: true); XCTAssertEqual(store.kilocalories, 420.5)
        store.disconnect(); XCTAssertNil(store.kilocalories); XCTAssertEqual(setup.value?.energyRequested, false)
    }
    func testEnergyDisappearsAtMidnightAndAccountSwitch() async {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = EnergyTestClock(date: calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 23, minute: 59))!)
        let setup = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence()); let owner = UUID(); setup.activate(userID: owner)
        let reader = EnergyTestReader(); reader.result = 300
        let store = ActiveEnergyStore(setup: setup, reader: reader, now: { clock.date }, calendar: { calendar })
        store.accountChanged(to: owner); await store.connect(); XCTAssertEqual(store.kilocalories, 300)
        clock.date = clock.date.addingTimeInterval(120); XCTAssertNil(store.kilocalories)
        reader.result = 10; await store.refresh(force: true); XCTAssertEqual(store.kilocalories, 10)
        let other = UUID(); setup.activate(userID: other); store.accountChanged(to: other); XCTAssertNil(store.kilocalories)
    }
    func testInvalidEnergyDataIsUnavailableAndZeroCanBeReal() async {
        let setup = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence()), owner = UUID(); setup.activate(userID: owner)
        let reader = EnergyTestReader()
        let checked = ActiveEnergyStore(setup: setup, reader: reader); checked.accountChanged(to: owner); await checked.connect()
        for result in [-1, .nan, .infinity, 50001] { reader.result = result; await checked.refresh(force: true); XCTAssertNil(checked.kilocalories) }
        reader.result = 0; await checked.refresh(force: true); XCTAssertEqual(checked.kilocalories, 0)
    }
}

@MainActor private final class FailingSetupPersistence: PersonalSetupPersisting {
    var failsRead = true
    func load(userID: UUID) throws -> PersonalSetupPreferences? { if failsRead { throw AppError.server }; return nil }
    func save(_ value: PersonalSetupPreferences, userID: UUID) throws { throw AppError.server }
    func delete(userID: UUID) throws { throw AppError.server }
}
@MainActor private final class EnergyTestReader: ActiveEnergyReading {
    var isAvailable = true, requests = 0, reads = 0
    var result: Double?
    func requestAccess() async throws { requests += 1 }
    func todayKilocalories(now: Date, calendar: Calendar) async throws -> Double? { reads += 1; return result }
}
@MainActor private final class EnergyTestClock {
    var date: Date
    init(date: Date) { self.date = date }
}
