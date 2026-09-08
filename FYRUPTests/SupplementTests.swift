import XCTest
@testable import FYRUP

@MainActor
final class SupplementTests: XCTestCase {
    private let owner = DemoRepository.defaultUserID
    private let other = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func denied(_ action: () async throws -> Void) async {
        do { try await action(); XCTFail("Must reject") } catch { }
    }
    func testUserAuthoredPlanHasNoImplicitNotificationsAndValidatesBounds() throws {
        var plan = SupplementPlan(ownerID: owner, name: "Mein Eintrag")
        XCTAssertFalse(plan.remindersEnabled); XCTAssertEqual(plan.repeatCount, 0)
        XCTAssertNil(plan.validationMessage)
        XCTAssertEqual(try JSONDecoder().decode(SupplementPlan.self, from: JSONEncoder().encode(plan)), plan)
        for text in ["", "  \n", String(repeating: "e\u{301}", count: 31)] {
            plan.name = text; XCTAssertNotNil(plan.validationMessage)
        }
        plan.name = "Mein Eintrag"
        for days in [[], [0], [8], [1, 1]] { plan.weekdays = days; XCTAssertNotNil(plan.validationMessage) }
        plan.weekdays = [1, 5]
        let invalidSlots: [[SupplementSlot]] = [[], [.init(minute: -1)], [.init(minute: 1440)], [.init(minute: 540), .init(minute: 540)]]
        for slots in invalidSlots {
            plan.slots = slots; XCTAssertNotNil(plan.validationMessage)
        }
        plan.slots = [.init(minute: 60)]
        for count in [-1, 4, Int.max] { plan.repeatCount = count; XCTAssertNotNil(plan.validationMessage) }
        plan.repeatCount = 3; plan.repeatMinutes = 1; XCTAssertNotNil(plan.validationMessage)
        plan.repeatMinutes = 180; XCTAssertNil(plan.validationMessage)
    }
    func testQuietHoursUseInclusiveStartAndExclusiveEnd() {
        var settings = SupplementSettings(timezone: "Europe/Berlin")
        XCTAssertTrue(settings.isValid)
        XCTAssertTrue(settings.isQuiet(minute: 1320)); XCTAssertTrue(settings.isQuiet(minute: 0))
        XCTAssertFalse(settings.isQuiet(minute: 480)); XCTAssertFalse(settings.isQuiet(minute: 1319))
        settings.quietStart = 600; settings.quietEnd = 660
        XCTAssertTrue(settings.isQuiet(minute: 600)); XCTAssertFalse(settings.isQuiet(minute: 660))
        settings.quietEnabled = false; XCTAssertFalse(settings.isQuiet(minute: 600))
        settings.timezone = "Invalid/Zone"; XCTAssertFalse(settings.isValid)
    }

    func testOptionalAmountsDecodeOldDataValidateAndEncodeClear() throws {
        var plan = SupplementPlan(ownerID: owner, name: "Eigene Auswahl")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "amount")
        let old = try JSONDecoder().decode(SupplementPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.amount)
        plan.amount = SupplementAmount(value: 1.5, unit: .g)
        XCTAssertNil(plan.validationMessage)
        XCTAssertEqual(try JSONDecoder().decode(SupplementPlan.self, from: JSONEncoder().encode(plan)), plan)
        for value in [0, -1, .nan, .infinity, 1_000_001] {
            plan.amount = SupplementAmount(value: value, unit: .g); XCTAssertNotNil(plan.validationMessage)
        }
        plan.amount = nil
        let cleared = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        XCTAssertTrue(cleared["amount"] is NSNull)
        XCTAssertFalse(plan.remindersEnabled)
    }
    func testSavedTimezoneControlsDatesAndRejectsInvalidClocks() {
        let now = date("2026-09-05T00:30:00Z")
        XCTAssertEqual(SupplementDay.key(now, timezone: "America/New_York"), "2026-09-04")
        XCTAssertEqual(SupplementDay.key(now, timezone: "Europe/Berlin"), "2026-09-05")
        XCTAssertEqual(SupplementDay.weekday(now, timezone: "Europe/Berlin"), 6)
        XCTAssertNil(SupplementDay.key(Date(timeIntervalSince1970: .infinity), timezone: "UTC"))
        XCTAssertNil(SupplementDay.weekday(Date(timeIntervalSince1970: .nan), timezone: "UTC"))
    }
    func testDemoIntakePersistsAndReceiptRetryAfterUndoReturnsCurrentState() async throws {
        let suite = "FYRUP.SupplementTests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let now = date("2026-09-05T12:00:00Z")
        let storage = DemoSupplementStorage(persistenceSuiteName: suite)
        let empty = try await storage.snapshot(owner: owner, timezone: "Europe/Berlin", now: now)
        XCTAssertTrue(empty.plans.isEmpty); XCTAssertTrue(empty.doses.isEmpty)
        let saved = try await storage.save(SupplementPlan(ownerID: owner, name: "Selbst gewählt"), owner: owner, now: now)
        let snap = try await storage.snapshot(owner: owner, timezone: "America/New_York", now: now)
        XCTAssertTrue(snap.isValid(for: owner)); XCTAssertEqual(snap.settings.timezone, "Europe/Berlin")
        let dose = try XCTUnwrap(snap.doses.first)
        let change = SupplementDoseMutation(doseID: dose.id, status: .taken, expectedRevision: dose.revision)
        let taken = try await storage.mark(change, owner: owner, now: now)
        let retry = try await storage.mark(change, owner: owner, now: now)
        XCTAssertEqual(taken, retry); XCTAssertEqual(taken.revision, 2)
        let restarted = DemoSupplementStorage(persistenceSuiteName: suite)
        let restored = try await restarted.snapshot(owner: owner, timezone: "UTC", now: now)
        XCTAssertEqual(restored.doses.first?.status, .taken)
        let undone = try await restarted.mark(.init(doseID: dose.id, status: .open, expectedRevision: 2), owner: owner, now: now)
        XCTAssertEqual(undone.revision, 3)
        let oldRetry = try await restarted.mark(change, owner: owner, now: now)
        XCTAssertEqual(oldRetry.status, .open)
        await denied { _ = try await restarted.mark(change, owner: other, now: now) }
        let foreign = try await restarted.snapshot(owner: other, timezone: "UTC", now: now)
        XCTAssertTrue(foreign.plans.isEmpty); XCTAssertTrue(foreign.doses.isEmpty)
        var stale = saved; stale.revision = 0
        await denied { _ = try await restarted.save(stale, owner: self.owner, now: now) }
        var paused = saved; paused.isPaused = true
        _ = try await restarted.save(paused, owner: owner, now: now)
        let hidden = try await restarted.snapshot(owner: owner, timezone: "UTC", now: now)
        XCTAssertTrue(hidden.doses.isEmpty); XCTAssertEqual(hidden.plans.first?.isPaused, true)
    }
    func testDSTUsesSameUniqueSlotAndMatchesServerTimeResolution() async throws {
        for (instant, expected) in [("2026-03-29T12:00:00Z", "2026-03-29T01:30:00Z"), ("2026-10-25T12:00:00Z", "2026-10-25T01:30:00Z")] {
            let now = date(instant); let storage = DemoSupplementStorage()
            _ = try await storage.snapshot(owner: owner, timezone: "Europe/Berlin", now: now)
            var plan = SupplementPlan(ownerID: owner, name: "Eigener Eintrag"); plan.slots = [.init(minute: 150)]
            _ = try await storage.save(plan, owner: owner, now: now)
            let first = try await storage.snapshot(owner: owner, timezone: "UTC", now: now)
            let second = try await storage.snapshot(owner: owner, timezone: "UTC", now: now)
            XCTAssertEqual(first.doses.count, 1); XCTAssertEqual(first.doses.first?.id, second.doses.first?.id)
            XCTAssertEqual(first.doses.first?.dueAt, date(expected))
        }
    }
    func testSnapshotRejectsForeignDuplicateAndInactiveDose() async throws {
        let repository = try await fixture()
        var snapshot = try await repository.supplements(timezone: "UTC")
        XCTAssertTrue(snapshot.isValid(for: owner)); XCTAssertFalse(snapshot.isValid(for: other))
        snapshot.doses.append(snapshot.doses[0]); XCTAssertFalse(snapshot.isValid(for: owner))
        snapshot.doses.removeLast(); snapshot.plans[0].isPaused = true; XCTAssertFalse(snapshot.isValid(for: owner))
        snapshot.plans[0].isPaused = false; snapshot.doses[0].ownerID = other; XCTAssertFalse(snapshot.isValid(for: owner))
    }
    func testOfflineIntentSurvivesRestartWithSameIDAndNoOptimisticTakenState() async throws {
        let repository = try await fixture(); let persistence = MemorySupplementPendingPersistence()
        let store = SupplementStore(repository: repository, persistence: persistence); store.activate(userID: owner)
        await store.load(); let dose = try XCTUnwrap(store.snapshot?.doses.first)
        await repository.failWrites(true)
        await store.mark(dose.id, as: .taken)
        XCTAssertEqual(store.snapshot?.doses.first?.status, .open); XCTAssertEqual(store.pending.count, 1)
        let change = try XCTUnwrap(store.pending.first)
        await store.mark(dose.id, as: .taken); XCTAssertEqual(store.pending.count, 1)
        let restarted = SupplementStore(repository: repository, persistence: persistence); restarted.activate(userID: owner)
        XCTAssertEqual(restarted.pending.first?.id, change.id)
        await repository.failWrites(false); await restarted.refresh()
        XCTAssertTrue(restarted.pending.isEmpty); XCTAssertEqual(restarted.snapshot?.doses.first?.status, .taken)
        XCTAssertEqual(restarted.snapshot?.doses.first?.revision, 2)
    }
    func testUnreadablePersistenceIsNotOverwrittenOrSent() async throws {
        let repository = try await fixture(); let persistence = MemorySupplementPendingPersistence()
        persistence.values[owner] = Data("broken".utf8)
        let store = SupplementStore(repository: repository, persistence: persistence); store.activate(userID: owner)
        await store.load(); let dose = try XCTUnwrap(store.snapshot?.doses.first)
        await store.mark(dose.id, as: .taken)
        XCTAssertEqual(persistence.values[owner], Data("broken".utf8))
        XCTAssertEqual(store.snapshot?.doses.first?.status, .open); XCTAssertNotNil(store.pendingError)
        let writes = await repository.writes; XCTAssertEqual(writes, 0)
    }
    func testLocalWriteFailureDoesNotCreateUnrecoverableNetworkMutation() async throws {
        let repository = try await fixture(); let persistence = MemorySupplementPendingPersistence()
        let store = SupplementStore(repository: repository, persistence: persistence); store.activate(userID: owner)
        await store.load(); persistence.fails = true
        await store.mark(try XCTUnwrap(store.snapshot?.doses.first?.id), as: .taken)
        XCTAssertTrue(store.pending.isEmpty); XCTAssertNotNil(store.pendingError)
        let writes = await repository.writes; XCTAssertEqual(writes, 0)
    }
    func testHeldReadAndWriteCannotRepopulateAfterAccountABASwitch() async throws {
        let repository = try await fixture(); let persistence = MemorySupplementPendingPersistence()
        let store = SupplementStore(repository: repository, persistence: persistence); store.activate(userID: owner)
        await repository.holdReads()
        let loading = Task { await store.load() }
        for _ in 0..<100 { if await repository.hasHeldRead { break }; await Task.yield() }
        let held = await repository.hasHeldRead; XCTAssertTrue(held)
        store.activate(userID: other); store.activate(userID: owner)
        await repository.releaseRead(); await loading.value
        XCTAssertNil(store.snapshot)
        await store.load(); let dose = try XCTUnwrap(store.snapshot?.doses.first)
        await repository.holdWrites()
        let writing = Task { await store.mark(dose.id, as: .taken) }
        for _ in 0..<100 { if await repository.hasHeldWrite { break }; await Task.yield() }
        let heldWrite = await repository.hasHeldWrite; XCTAssertTrue(heldWrite)
        store.activate(userID: other); store.activate(userID: owner)
        await repository.releaseWrite(); await writing.value
        XCTAssertNil(store.snapshot); XCTAssertEqual(store.pending.count, 1)
        await store.refresh(); XCTAssertEqual(store.snapshot?.doses.first?.status, .taken); XCTAssertTrue(store.pending.isEmpty)
    }
    func testFailedReadNeverAllowsSavingOverUnknownState() async throws {
        let repository = try await fixture(); await repository.failReads(true)
        let store = SupplementStore(repository: repository, persistence: MemorySupplementPendingPersistence()); store.activate(userID: owner)
        await store.load(); XCTAssertNil(store.snapshot); XCTAssertNotNil(store.errorMessage)
        let saved = await store.save(SupplementPlan(ownerID: owner, name: "Nicht blind speichern")); XCTAssertFalse(saved)
    }
    private func fixture() async throws -> SupplementStub {
        let repository = SupplementStub(owner: owner, now: date("2026-09-05T12:00:00Z"))
        _ = try await repository.supplements(timezone: "UTC")
        _ = try await repository.saveSupplement(SupplementPlan(ownerID: owner, name: "Mein Eintrag"))
        return repository
    }

    func testMidnightMakesYesterdayReadOnlyUntilFreshLoad() async throws {
        let repository = try await fixture()
        var clock = date("2026-09-05T12:00:00Z")
        let store = SupplementStore(repository: repository, persistence: MemorySupplementPendingPersistence(), clock: { clock })
        store.activate(userID: owner); await store.load()
        XCTAssertTrue(store.isCurrentDay)
        let dose = try XCTUnwrap(store.snapshot?.doses.first)
        clock = clock.addingTimeInterval(13 * 3600)
        XCTAssertFalse(store.isCurrentDay); XCTAssertTrue(store.changesDisabled)
        await store.mark(dose.id, as: .taken)
        let writes = await repository.writes; XCTAssertEqual(writes, 0)
        XCTAssertTrue(store.pending.isEmpty)
    }
    func testTemporarilyLockedPersistenceCanBeReadAgainWithoutDiscarding() async throws {
        let repository = try await fixture(); let persistence = MemorySupplementPendingPersistence(); persistence.fails = true
        let store = SupplementStore(repository: repository, persistence: persistence); store.activate(userID: owner)
        await store.load(); XCTAssertNotNil(store.pendingError)
        persistence.fails = false
        await store.refresh(); XCTAssertNil(store.pendingError)
        let dose = try XCTUnwrap(store.snapshot?.doses.first)
        await store.mark(dose.id, as: .taken)
        XCTAssertEqual(store.snapshot?.doses.first?.status, .taken)
        XCTAssertTrue(try XCTUnwrap(store.snapshot).isValid(for: owner))
    }
}

private actor SupplementStub: SupplementRepository {
    let storage = DemoSupplementStorage()
    let owner: UUID; let now: Date
    var readFails = false; var writeFails = false; var holdsRead = false; var holdsWrite = false
    var readContinuation: CheckedContinuation<Void, Never>?
    var writeContinuation: CheckedContinuation<Void, Never>?
    private(set) var writes = 0
    init(owner: UUID, now: Date) { self.owner = owner; self.now = now }
    var hasHeldRead: Bool { readContinuation != nil }
    var hasHeldWrite: Bool { writeContinuation != nil }
    func failReads(_ flag: Bool) { readFails = flag }
    func failWrites(_ flag: Bool) { writeFails = flag }
    func holdReads() { holdsRead = true }
    func holdWrites() { holdsWrite = true }
    func releaseRead() { holdsRead = false; readContinuation?.resume(); readContinuation = nil }
    func releaseWrite() { holdsWrite = false; writeContinuation?.resume(); writeContinuation = nil }
    func supplements(timezone: String) async throws -> SupplementSnapshot {
        if readFails { throw AppError.server }
        let value = try await storage.snapshot(owner: owner, timezone: timezone, now: now)
        if holdsRead { await withCheckedContinuation { readContinuation = $0 } }
        return value
    }
    func saveSupplement(_ plan: SupplementPlan) async throws -> SupplementPlan { try await storage.save(plan, owner: owner, now: now) }
    func saveSupplementSettings(_ value: SupplementSettings) async throws -> SupplementSettings { try await storage.saveSettings(value, owner: owner) }
    func setSupplementDose(_ value: SupplementDoseMutation) async throws -> SupplementDose {
        writes += 1
        if writeFails { throw AppError.server }
        let result = try await storage.mark(value, owner: owner, now: now)
        if holdsWrite { await withCheckedContinuation { writeContinuation = $0 } }
        return result
    }
}
