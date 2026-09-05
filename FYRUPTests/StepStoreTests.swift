import XCTest
@testable import FYRUP

@MainActor
final class StepStoreTests: XCTestCase {
    private let momo = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let max = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!

    func testNoPermissionPromptOrHealthReadOnFirstActivation() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: momo)
        XCTAssertEqual(rig.reader.requestCount, 0)
        XCTAssertEqual(rig.reader.readCount, 0)
        XCTAssertFalse(rig.store.healthRequested)
        XCTAssertFalse(rig.store.showSteps)
        XCTAssertNil(rig.store.goal)
        XCTAssertEqual(rig.store.sharingEnabled, false)
        XCTAssertTrue(rig.store.isSharingPreferenceCurrent)
    }

    func testExplicitConnectionShows8421ButDoesNotEnableSharing() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: momo)
        await rig.store.connect()
        XCTAssertEqual(rig.reader.requestCount, 1)
        XCTAssertEqual(rig.store.todaysSteps, 8421)
        XCTAssertTrue(rig.store.showSteps)
        XCTAssertEqual(rig.store.sharingEnabled, false)
        let uploads = await rig.repository.uploads
        XCTAssertTrue(uploads.isEmpty)
        let keys = rig.defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("fyrup.steps.") }
        XCTAssertFalse(keys.contains { $0.contains("count") || $0.contains("samples") || $0.contains("8421") })
    }

    func testExplicitSharingUploadsOnlyDailyAggregateAndRevision() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.store.activate(userID: momo)
        await rig.store.setSharing(true)
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.steps, 8421)
        XCTAssertEqual(uploads.first?.date, "2026-09-05")
        XCTAssertEqual(uploads.first?.timezone, "Europe/Berlin")
        XCTAssertEqual(uploads.first?.revision, 1)
        XCTAssertNotNil(rig.store.lastSyncedAt)
        await rig.store.setSharing(false)
        XCTAssertEqual(rig.store.sharingEnabled, false)
        XCTAssertNil(rig.store.lastSyncedAt)
    }

    func testFailedPreferenceReadIsUnknownNotConfirmedPrivate() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setReadFailure(true)
        await rig.store.activate(userID: momo)
        XCTAssertNil(rig.store.sharingEnabled)
        XCTAssertFalse(rig.store.isSharingPreferenceCurrent)
        XCTAssertEqual(rig.store.todaysSteps, 8421)
        XCTAssertNotNil(rig.store.message)
        let uploads = await rig.repository.uploads
        XCTAssertTrue(uploads.isEmpty)
    }

    func testFailedPreferenceRefreshRetainsLastKnownTrueButSuppressesUploads() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        await rig.store.activate(userID: momo)
        await rig.repository.setReadFailure(true)
        rig.reader.count = 9000
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.store.sharingEnabled, true)
        XCTAssertFalse(rig.store.isSharingPreferenceCurrent)
        XCTAssertEqual(rig.store.todaysSteps, 9000)
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.count, 1)
    }

    func testFailedSharingMutationNeverClaimsConfirmedOff() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.repository.setEnabled(momo, enabled: true)
        await rig.store.activate(userID: momo)
        await rig.repository.setWriteFailure(true)
        await rig.store.setSharing(false)
        XCTAssertNil(rig.store.sharingEnabled)
        XCTAssertFalse(rig.store.isSharingPreferenceCurrent)
        XCTAssertNotNil(rig.store.message)
        XCTAssertFalse(rig.store.isChangingSharing)
    }

    func testNoHealthDataIsNeutralAndCanClearAPreviouslySharedDay() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        rig.reader.count = nil
        await rig.repository.setEnabled(momo, enabled: true)
        await rig.store.activate(userID: momo)
        XCTAssertNil(rig.store.todaysSteps)
        XCTAssertEqual(rig.store.healthStatusText, "Keine Schrittdaten verfügbar")
        XCTAssertNil(rig.store.message)
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.count, 1)
        XCTAssertNil(uploads.first?.steps)
    }

    func testRefreshIsThrottledAndForegroundForceReadsUpdatedValue() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.store.activate(userID: momo)
        rig.reader.count = 9000
        await rig.store.refresh()
        XCTAssertEqual(rig.reader.readCount, 1)
        XCTAssertEqual(rig.store.todaysSteps, 8421)
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.reader.readCount, 2)
        XCTAssertEqual(rig.store.todaysSteps, 9000)
    }

    func testOptionalPrivateGoalAndPreferencesAreAccountScoped() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: momo)
        rig.store.setGoal(10000); rig.store.setShowSteps(true)
        await rig.store.connect()
        XCTAssertEqual(rig.store.progress, 0.8421)
        rig.store.reset()
        await rig.store.activate(userID: max)
        XCTAssertNil(rig.store.goal)
        XCTAssertFalse(rig.store.healthRequested)
        XCTAssertFalse(rig.store.showSteps)
        await rig.store.activate(userID: momo)
        XCTAssertEqual(rig.store.goal, 10000)
        XCTAssertTrue(rig.store.healthRequested)
        rig.store.setGoal(nil)
        XCTAssertNil(rig.store.progress)
    }

    func testMidnightHidesOldCountBeforeRefreshAndReadsNewDay() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        rig.clock.date = rig.clock.localDate(2026, 9, 5, 23, 59)
        await rig.store.activate(userID: momo)
        rig.clock.date = rig.clock.localDate(2026, 9, 6, 0, 1)
        XCTAssertNil(rig.store.todaysSteps)
        rig.reader.count = 21
        await rig.store.refresh()
        XCTAssertEqual(rig.store.todaysSteps, 21)
        XCTAssertEqual(rig.store.localDate, "2026-09-06")
        XCTAssertEqual(rig.reader.lastQueryDay, "2026-09-06")
    }

    func testOldAccountQueryCannotOverwriteNewAccountOrABAReactivation() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo); rig.enableHealth(for: max)
        rig.reader.blockNextRead = true
        let old = Task { await rig.store.activate(userID: momo) }
        await rig.reader.waitUntilBlocked()
        rig.reader.count = 99
        await rig.store.activate(userID: max)
        await rig.store.activate(userID: momo)
        rig.reader.release(8421)
        await old.value
        XCTAssertEqual(rig.store.userID, momo)
        XCTAssertEqual(rig.store.todaysSteps, 99)
        XCTAssertFalse(rig.store.isRefreshing)
    }

    func testMidnightDuringHealthQueryDiscardsOldResponseAndUploadsOnlyNewDate() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        rig.clock.date = rig.clock.localDate(2026, 9, 5, 23, 59)
        rig.reader.blockNextRead = true
        let task = Task { await rig.store.activate(userID: momo) }
        await rig.reader.waitUntilBlocked()
        rig.clock.date = rig.clock.localDate(2026, 9, 6, 0, 1)
        rig.reader.count = 21
        rig.reader.release(8421)
        await task.value
        XCTAssertEqual(rig.store.todaysSteps, 21)
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.map(\.date), ["2026-09-06"])
        XCTAssertEqual(uploads.map(\.steps), [21])
    }

    func testRevocationWhileHealthReadIsPendingSuppressesItsUpload() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        rig.reader.blockNextRead = true
        let task = Task { await rig.store.activate(userID: momo) }
        await rig.reader.waitUntilBlocked()
        await rig.store.setSharing(false)
        rig.reader.release(8421)
        await task.value
        XCTAssertEqual(rig.store.todaysSteps, 8421)
        XCTAssertEqual(rig.store.sharingEnabled, false)
        let uploads = await rig.repository.uploads
        XCTAssertTrue(uploads.isEmpty)
    }

    func testOffThenOnDuringOldReadUsesOnlyTheNewRevision() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        rig.reader.blockNextRead = true
        let task = Task { await rig.store.activate(userID: momo) }
        await rig.reader.waitUntilBlocked()
        await rig.store.setSharing(false)
        await rig.store.setSharing(true)
        rig.reader.count = 9000
        rig.reader.release(8421)
        await task.value
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.map(\.revision), [3])
        XCTAssertEqual(uploads.map(\.steps), [9000])
    }

    func testRejectedRevisionDoesNotClaimSuccessfulSyncOrLoopUploads() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        await rig.repository.setAcceptUploads(false)
        await rig.store.activate(userID: momo)
        XCTAssertNil(rig.store.lastSyncedAt)
        XCTAssertNotNil(rig.store.message)
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.count, 1)
    }

    func testSharedDataIsHiddenAfterCacheExpiryAndReset() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.repository.setShared([DailyStepMetric(userID: max, localDate: "2026-09-05", steps: 12804, updatedAt: rig.clock.date, validUntil: rig.clock.date.addingTimeInterval(120))])
        await rig.store.activate(userID: momo)
        XCTAssertEqual(rig.store.shared.first?.steps, 12804)
        rig.clock.date.addTimeInterval(121)
        XCTAssertTrue(rig.store.shared.isEmpty)
        rig.store.reset()
        XCTAssertTrue(rig.store.shared.isEmpty)
        XCTAssertNil(rig.store.todaysSteps)
    }

    func testFriendOwnerMidnightExpiryHidesValueBeforeLocalDayChanges() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        await rig.repository.setShared([DailyStepMetric(userID: max, localDate: "2026-09-05", steps: 12804,
                                                       updatedAt: rig.clock.date, validUntil: rig.clock.date.addingTimeInterval(20))])
        await rig.store.activate(userID: momo)
        XCTAssertEqual(rig.store.shared.count, 1)
        rig.clock.date.addTimeInterval(21)
        XCTAssertTrue(rig.store.shared.isEmpty)
    }

    func testAccountDeletionClearsOnlyCurrentAccountsLocalChoices() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo); rig.enableHealth(for: max)
        await rig.store.activate(userID: momo)
        rig.store.setGoal(7500)
        rig.store.reset(clearLocalPreferences: true)
        await rig.store.activate(userID: momo)
        XCTAssertFalse(rig.store.healthRequested)
        XCTAssertFalse(rig.store.showSteps)
        XCTAssertNil(rig.store.goal)
        await rig.store.activate(userID: max)
        XCTAssertTrue(rig.store.healthRequested)
    }

    func testObservationTimestampIsQueryStartNotDelayedCompletionTime() async {
        let rig = StepRig(); defer { rig.cleanUp() }
        rig.enableHealth(for: momo)
        await rig.repository.setEnabled(momo, enabled: true)
        rig.reader.blockNextRead = true
        let queryStart = rig.clock.date
        let task = Task { await rig.store.activate(userID: momo) }
        await rig.reader.waitUntilBlocked()
        rig.clock.date.addTimeInterval(30)
        rig.reader.release(8421)
        await task.value
        let uploads = await rig.repository.uploads
        XCTAssertEqual(uploads.first?.observedAt, queryStart)
    }

    func testGregorianDayAndDSTBoundsUseLocalTimezone() {
        let clock = StepTestClock()
        let march = StepDay.bounds(for: clock.localDate(2026, 3, 29, 12, 0), calendar: clock.calendar)
        let october = StepDay.bounds(for: clock.localDate(2026, 10, 25, 12, 0), calendar: clock.calendar)
        XCTAssertEqual(march.duration, 23 * 3600)
        XCTAssertEqual(october.duration, 25 * 3600)
        var buddhist = Calendar(identifier: .buddhist); buddhist.timeZone = clock.calendar.timeZone
        XCTAssertEqual(StepDay.key(for: clock.date, calendar: buddhist), "2026-09-05")
        XCTAssertNil(StepDay.count(from: .nan))
        XCTAssertNil(StepDay.count(from: .infinity))
        XCTAssertNil(StepDay.count(from: -1))
        XCTAssertNil(StepDay.count(from: 300001))
        XCTAssertEqual(StepDay.count(from: 8421), 8421)
        XCTAssertEqual(StepDay.count(from: 0), 0)
    }
}

@MainActor
private final class StepTestClock {
    var calendar: Calendar = {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(identifier: "Europe/Berlin")!; return value
    }()
    var date = Date(timeIntervalSince1970: 1_788_609_600)
    init() { date = localDate(2026, 9, 5, 12, 0) }
    func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

@MainActor
private struct StepRig {
    let suite = "FYRUP.StepTests.\(UUID().uuidString)"
    let repository = StepRepositoryDouble()
    let reader = StepReaderDouble()
    let clock = StepTestClock()
    let defaults: UserDefaults
    let store: StepStore
    init() {
        defaults = UserDefaults(suiteName: suite)!
        let clock = self.clock
        store = StepStore(repository: repository, reader: reader, defaults: defaults, now: { clock.date }, calendar: { clock.calendar })
    }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    func enableHealth(for user: UUID) {
        defaults.set(true, forKey: "fyrup.steps.\(user.uuidString).healthRequested")
        defaults.set(true, forKey: "fyrup.steps.\(user.uuidString).show")
    }
}

@MainActor
private final class StepReaderDouble: StepReading {
    var isAvailable = true
    var count: Int? = 8421
    var requestCount = 0
    var readCount = 0
    var lastQueryDay: String?
    var blockNextRead = false
    private var blocked: CheckedContinuation<Int?, Never>?
    private var blockedWaiter: CheckedContinuation<Void, Never>?
    func requestAccess() async throws { requestCount += 1 }
    func todaySteps(now: Date, calendar: Calendar) async throws -> Int? {
        readCount += 1; lastQueryDay = StepDay.key(for: now, calendar: calendar)
        if blockNextRead {
            blockNextRead = false
            return await withCheckedContinuation { continuation in
                blocked = continuation; blockedWaiter?.resume(); blockedWaiter = nil
            }
        }
        return count
    }
    func waitUntilBlocked() async {
        if blocked != nil { return }
        await withCheckedContinuation { blockedWaiter = $0 }
    }
    func release(_ count: Int?) { blocked?.resume(returning: count); blocked = nil }
}

private actor StepRepositoryDouble: StepRepository {
    struct Upload: Sendable {
        let user: UUID; let date: String; let timezone: String; let steps: Int?; let revision: Int; let observedAt: Date
    }
    private var preferences: [UUID: StepSharingPreference] = [:]
    private var readFailure = false
    private var writeFailure = false
    private var acceptUploads = true
    private var sharedValues: [DailyStepMetric] = []
    private(set) var uploads: [Upload] = []
    func setReadFailure(_ value: Bool) { readFailure = value }
    func setWriteFailure(_ value: Bool) { writeFailure = value }
    func setAcceptUploads(_ value: Bool) { acceptUploads = value }
    func setShared(_ value: [DailyStepMetric]) { sharedValues = value }
    func setEnabled(_ userID: UUID, enabled: Bool) {
        preferences[userID] = StepSharingPreference(userID: userID, sharingEnabled: enabled, sharingRevision: enabled ? 1 : 0)
    }
    func stepSharingPreference(userID: UUID) async throws -> StepSharingPreference {
        if readFailure { throw AppError.network }
        return preferences[userID] ?? StepSharingPreference(userID: userID, sharingEnabled: false, sharingRevision: 0)
    }
    func setStepSharing(userID: UUID, enabled: Bool) async throws -> StepSharingPreference {
        if writeFailure { throw AppError.network }
        var value = preferences[userID] ?? StepSharingPreference(userID: userID, sharingEnabled: false, sharingRevision: 0)
        if value.sharingEnabled != enabled { value.sharingRevision += 1 }
        value.sharingEnabled = enabled; preferences[userID] = value
        return value
    }
    func syncSteps(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) async throws -> Bool {
        uploads.append(Upload(user: userID, date: localDate, timezone: timezone, steps: steps, revision: sharingRevision, observedAt: observedAt))
        return acceptUploads && preferences[userID]?.sharingEnabled == true && preferences[userID]?.sharingRevision == sharingRevision
    }
    func sharedSteps() async throws -> [DailyStepMetric] { sharedValues }
}
