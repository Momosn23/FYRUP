import XCTest
@testable import FYRUP

@MainActor
final class WorkoutRestReminderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1800000000)

    func testOwnDurationRejectsMalformedAndExtremeInput() {
        for text in ["", "0", "14", "601", "90.5", "1,5", "-90", "+90", "1e2", "999999999999999999999999"] {
            XCTAssertNil(RestDurationInput.seconds(from: text), text)
        }
        for (text, expected) in [("15",15),("90",90),("600",600),(" 123 ",123)] {
            XCTAssertEqual(RestDurationInput.seconds(from: text), expected)
        }
    }

    func testNoAutomaticReminderAndOptOutRemovesOnlyOurReminder() async {
        let suite = "app.fyrup.tests.rest-reminder.\(UUID())", owner = UUID(), activity = UUID()
        let defaults = UserDefaults(suiteName: suite)!, recorder = RestReminderRecorder()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = now
        let store = WorkoutRestStore(defaults: defaults, notifications: recorder, now: { now })
        store.activate(userID: owner); store.start(activityID: activity, now: now)
        await store.waitForReminderSynchronization()
        XCTAssertFalse(store.reminderEnabled); XCTAssertFalse(store.soundEnabled)
        XCTAssertTrue(recorder.calls.allSatisfy { $0 == nil })
        store.setReminderEnabled(true); await store.waitForReminderSynchronization()
        XCTAssertEqual(recorder.current?.ownerID, owner); XCTAssertEqual(recorder.current?.clock.activityID, activity)
        XCTAssertEqual(recorder.current?.sound, false)
        store.setSoundEnabled(true); await store.waitForReminderSynchronization(); XCTAssertEqual(recorder.current?.sound, true)
        store.setReminderEnabled(false); await store.waitForReminderSynchronization(); XCTAssertNil(recorder.current)
        XCTAssertNotNil(store.clock, "Turning off reminders does not stop the actual rest clock")
    }

    func testLateSchedulingCannotSurviveLogout() async {
        let suite = "app.fyrup.tests.rest-race.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!, recorder = RestReminderRecorder()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = now
        let store = WorkoutRestStore(defaults: defaults, notifications: recorder, now: { now })
        store.activate(userID: UUID()); await store.waitForReminderSynchronization()
        store.setReminderEnabled(true); await store.waitForReminderSynchronization()
        recorder.holdsNext = true
        store.start(activityID: UUID(), now: now)
        for _ in 0..<100 where recorder.gate == nil { await Task.yield() }
        XCTAssertNotNil(recorder.gate)
        store.activate(userID: nil)
        recorder.gate?.resume(); recorder.gate = nil
        await store.waitForReminderSynchronization()
        XCTAssertNil(recorder.current); XCTAssertNil(store.userID); XCTAssertNil(store.clock); XCTAssertNil(store.reminderMessage)
    }

    func testCompletedSessionAndDifferentAccountCannotScheduleRest() async {
        let suite = "app.fyrup.tests.rest-owner.\(UUID())", owner = UUID()
        let defaults = UserDefaults(suiteName: suite)!, recorder = RestReminderRecorder()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = now
        let store = WorkoutRestStore(defaults: defaults, notifications: recorder, now: { now })
        store.activate(userID: owner); store.setReminderEnabled(true); store.start(activityID: UUID(), now: now)
        await store.waitForReminderSynchronization(); XCTAssertNotNil(recorder.current)
        store.confirmActivity(nil); await store.waitForReminderSynchronization(); XCTAssertNil(recorder.current)
        store.activate(userID: UUID()); await store.waitForReminderSynchronization()
        XCTAssertFalse(store.reminderEnabled); XCTAssertFalse(store.soundEnabled)
        store.activate(userID: owner); await store.waitForReminderSynchronization()
        XCTAssertTrue(store.reminderEnabled); XCTAssertNotNil(store.clock)
        XCTAssertNil(recorder.current, "Restored preferences are not evidence of a still-live session")
    }

    func testReminderFailureIsVisibleAndDoesNotStopSessionClock() async {
        let suite = "app.fyrup.tests.rest-failure.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!, recorder = RestReminderRecorder()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = now
        let store = WorkoutRestStore(defaults: defaults, notifications: recorder, now: { now })
        store.activate(userID: UUID()); store.setReminderEnabled(true)
        recorder.fails = true; store.start(activityID: UUID(), now: now)
        await store.waitForReminderSynchronization()
        XCTAssertNotNil(store.reminderMessage); XCTAssertNotNil(store.clock)
        recorder.fails = false; store.retryReminder(); await store.waitForReminderSynchronization()
        XCTAssertNil(store.reminderMessage); XCTAssertNotNil(recorder.current)
    }

    func testLocalReminderTapNeedsExactAccountAndClockAndContainsNoSetDetails() {
        let owner = UUID(), activity = UUID()
        let clock = WorkoutRestClock(activityID: activity, startedAt: now, duration: 90)
        let reminder = WorkoutRestReminder(ownerID: owner, clock: clock, sound: false)
        let tap = WorkoutRestReminderTap(requestIdentifier: WorkoutRestReminder.requestIdentifier, userInfo: reminder.userInfo)
        XCTAssertTrue(tap?.matches(ownerID: owner, clock: clock) == true)
        XCTAssertFalse(tap?.matches(ownerID: UUID(), clock: clock) == true)
        XCTAssertFalse(tap?.matches(ownerID: owner, clock: WorkoutRestClock(activityID: activity, startedAt: now.addingTimeInterval(1), duration: 90)) == true)
        XCTAssertNil(WorkoutRestReminderTap(requestIdentifier: "another-notification", userInfo: reminder.userInfo))
        var invalid = reminder.userInfo; invalid["rest_started"] = "nan"
        XCTAssertNil(WorkoutRestReminderTap(requestIdentifier: WorkoutRestReminder.requestIdentifier, userInfo: invalid))
        XCTAssertEqual(Set(reminder.userInfo.keys), ["fyrup_local_type", "owner_id", "activity_id", "rest_started"])
    }

    func testIndependentDemoLaunchesDoNotShareRestPreferences() async {
        let owner = UUID(), first = AppStore(repository: DemoRepository()), second = AppStore(repository: DemoRepository())
        first.rest.activate(userID: owner); first.rest.selectDuration(123); first.rest.setReminderEnabled(true)
        second.rest.activate(userID: owner)
        XCTAssertEqual(second.rest.selectedDuration, 90); XCTAssertFalse(second.rest.reminderEnabled)
        await first.rest.waitForReminderSynchronization(); await second.rest.waitForReminderSynchronization()
    }

    func testExplicitPersistentDemoUsesInjectedRestPreferences() async {
        let suite = "app.fyrup.tests.rest-demo.\(UUID())", owner = UUID()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppStore(repository: DemoRepository(), restDefaults: defaults)
        first.rest.activate(userID: owner); first.rest.selectDuration(123); first.rest.setReminderEnabled(true)
        await first.rest.waitForReminderSynchronization()
        let restored = AppStore(repository: DemoRepository(), restDefaults: defaults)
        restored.rest.activate(userID: owner)
        XCTAssertEqual(restored.rest.selectedDuration, 123); XCTAssertTrue(restored.rest.reminderEnabled)
        XCTAssertNil(restored.rest.clock)
        await restored.rest.waitForReminderSynchronization()
    }
}

@MainActor private final class RestReminderRecorder: WorkoutRestNotificationScheduling {
    var calls: [WorkoutRestReminder?] = []
    var current: WorkoutRestReminder?
    var holdsNext = false, fails = false
    var gate: CheckedContinuation<Void, Never>?
    func replace(with reminder: WorkoutRestReminder?) async throws {
        calls.append(reminder)
        if holdsNext { holdsNext = false; await withCheckedContinuation { gate = $0 } }
        if fails { throw AppError.server }
        current = reminder
    }
}
