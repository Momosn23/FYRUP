import XCTest
@testable import FYRUP

@MainActor
final class WidgetStateTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "WidgetStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testSnapshotRoundTripAndRemoval() throws {
        let defaults = defaults(), owner = UUID(), activity = UUID()
        let state = SessionLiveAttributes.ContentState(sport: "Gym", symbol: "dumbbell.fill", timerReference: .now,
                                                       pausedSeconds: nil, restStartedAt: nil, restEndsAt: nil, isGym: true)
        let snapshot = FYRUPWidgetSnapshot(ownerID: owner, sessionID: activity, state: state)
        FYRUPWidgetState.save(snapshot, to: defaults)
        XCTAssertEqual(FYRUPWidgetState.snapshot(from: defaults), snapshot)
        FYRUPWidgetState.save(nil, to: defaults)
        XCTAssertNil(FYRUPWidgetState.snapshot(from: defaults))
    }

    func testAppReloadsAWidgetStartedRestForTheConfirmedActivity() throws {
        let defaults = defaults(), owner = UUID(), activityID = UUID()
        let store = WorkoutRestStore(defaults: defaults)
        store.activate(userID: owner)
        var activity = Activity(id: activityID, userID: owner, sport: .gym, subtype: nil, status: .live,
                                plannedAt: nil, startedAt: .now, endedAt: nil, distanceMeters: nil,
                                plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        activity.status = .live
        store.confirmActivity(activity)
        let external = WidgetRestClock(activityID: activityID, startedAt: .now, duration: 75)
        defaults.set(try JSONEncoder().encode(external), forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "clock"))
        store.reloadExternalClock()
        XCTAssertEqual(store.clock?.activityID, activityID)
        XCTAssertEqual(store.clock?.duration, 75)

        defaults.removeObject(forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "clock"))
        store.reloadExternalClock()
        XCTAssertNil(store.clock)
    }

    func testWidgetToggleUsesSavedDurationAndRejectsAnotherAccount() throws {
        let defaults = defaults(), owner = UUID(), activityID = UUID(), now = Date()
        let state = SessionLiveAttributes.ContentState(sport: "Gym", symbol: "dumbbell.fill", timerReference: now,
                                                       pausedSeconds: nil, restStartedAt: nil, restEndsAt: nil, isGym: true)
        FYRUPWidgetState.save(FYRUPWidgetSnapshot(ownerID: owner, sessionID: activityID, state: state), to: defaults)
        defaults.set(75, forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "duration"))
        XCTAssertNil(FYRUPWidgetState.toggleRest(activityID: activityID, ownerID: UUID(), now: now, defaults: defaults))

        let started = try XCTUnwrap(FYRUPWidgetState.toggleRest(activityID: activityID, ownerID: owner, now: now, defaults: defaults))
        XCTAssertEqual(started.state.restStartedAt, now)
        XCTAssertEqual(started.state.restEndsAt, now.addingTimeInterval(75))
        let saved = try XCTUnwrap(defaults.data(forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "clock")))
        XCTAssertEqual(try JSONDecoder().decode(WorkoutRestClock.self, from: saved).duration, 75)

        let stopped = try XCTUnwrap(FYRUPWidgetState.toggleRest(activityID: activityID, ownerID: owner, now: now.addingTimeInterval(1), defaults: defaults))
        XCTAssertNil(stopped.state.restEndsAt)
        XCTAssertNil(defaults.data(forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "clock")))
    }
}
