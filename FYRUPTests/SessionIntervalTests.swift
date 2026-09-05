import XCTest
@testable import FYRUP

final class SessionIntervalClockTests: XCTestCase {
    private let configuration = SessionIntervalConfiguration(workSeconds: 45, recoverySeconds: 15, rounds: 3)

    func testExactPhaseBoundariesAndNoRecoveryAfterFinalRound() {
        let clock = SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: 100, configuration: configuration)
        XCTAssertEqual(configuration.totalSeconds, 165)
        let cases: [(Double, SessionIntervalPosition.Phase, Int, Int)] = [
            (0, .work, 1, 45), (44.1, .work, 1, 1), (45, .recovery, 1, 15), (59.9, .recovery, 1, 1),
            (60, .work, 2, 45), (105, .recovery, 2, 15), (120, .work, 3, 45), (164, .work, 3, 1), (165, .completed, 3, 0)
        ]
        for (elapsed, phase, round, remaining) in cases {
            let position = clock.position(activeSeconds: 100 + elapsed)
            XCTAssertEqual(position?.phase, phase); XCTAssertEqual(position?.round, round); XCTAssertEqual(position?.remaining, remaining)
            XCTAssertTrue((0...1).contains(position?.progress ?? -1))
        }
    }

    func testZeroRecoverySingleRoundAndBackgroundJump() {
        let noRest = SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: 0, configuration: .init(workSeconds: 10, recoverySeconds: 0, rounds: 3))
        XCTAssertEqual(noRest.position(activeSeconds: 10)?.round, 2)
        XCTAssertEqual(noRest.position(activeSeconds: 10)?.phase, .work)
        XCTAssertEqual(noRest.position(activeSeconds: Double(30).nextDown)?.round, 3)
        XCTAssertEqual(noRest.position(activeSeconds: 400)?.phase, .completed)
        let single = SessionIntervalConfiguration(workSeconds: 30, recoverySeconds: 300, rounds: 1)
        XCTAssertEqual(single.totalSeconds, 30)
        let resumed = SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: 0, configuration: configuration)
        XCTAssertEqual(resumed.position(activeSeconds: 135)?.remaining, 30)
        XCTAssertEqual(resumed.position(activeSeconds: 135)?.round, 3)
    }

    func testInvalidRestoredConfigurationCannotOverflow() {
        for value in [SessionIntervalConfiguration(workSeconds: Int.max, recoverySeconds: Int.max, rounds: Int.max),
                      .init(workSeconds: 4, recoverySeconds: 0, rounds: 1), .init(workSeconds: 5, recoverySeconds: -1, rounds: 1),
                      .init(workSeconds: 3600, recoverySeconds: 3600, rounds: 99), .init(workSeconds: 60, recoverySeconds: 30, rounds: 0)] {
            XCTAssertNil(value.totalSeconds)
            XCTAssertFalse(SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: 0, configuration: value).isValid)
        }
        XCTAssertEqual(SessionIntervalConfiguration(workSeconds: 3600, recoverySeconds: 0, rounds: 6).totalSeconds, 21600)
    }

    func testInputRejectsFractionsUnknownsSignsAndOverflow() {
        for text in ["", "-5", "+5", "5.5", "1e2", "90,5", "٥", "99999999999999999999"] {
            XCTAssertNil(SessionIntervalConfiguration.parse(work: text, recovery: "0", rounds: "2"), text)
        }
        XCTAssertNotNil(SessionIntervalConfiguration.parse(work: " 45 ", recovery: "0", rounds: "3"))
        XCTAssertNil(SessionIntervalConfiguration.parse(work: "45", recovery: "", rounds: "3"))
        XCTAssertNil(SessionIntervalConfiguration.parse(work: "45", recovery: "15", rounds: "100"))
    }

    func testNonFiniteOrRewoundActiveTimeIsNotDisplayed() {
        let clock = SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: 100, configuration: configuration)
        for value in [Double.nan, .infinity, -.infinity, 99, 604801] { XCTAssertNil(clock.position(activeSeconds: value)) }
        for value in [Double.nan, .infinity, -1, 604801] {
            XCTAssertFalse(SessionIntervalClock(activityID: UUID(), startedAtActiveSeconds: value, configuration: configuration).isValid)
        }
    }
}

@MainActor
final class SessionIntervalStoreTests: XCTestCase {
    private func activity(owner: UUID, at start: Date) -> Activity {
        Activity(id: UUID(), userID: owner, sport: .running, subtype: nil, status: .live, plannedAt: nil, startedAt: start,
                 endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
    }
    private let configuration = SessionIntervalConfiguration(workSeconds: 45, recoverySeconds: 15, rounds: 3)

    func testRestoresExactClockAndIsolatesAccounts() throws {
        let suite = "app.fyrup.tests.intervals.\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = UUID(), other = UUID(), start = Date(timeIntervalSince1970: 1000)
        let activity = activity(owner: owner, at: start), store = SessionIntervalStore(defaults: defaults)
        store.activate(userID: owner)
        XCTAssertTrue(store.start(activity: activity, configuration: configuration, now: start.addingTimeInterval(20)))
        let restored = SessionIntervalStore(defaults: defaults); restored.activate(userID: owner)
        XCTAssertEqual(restored.clock, store.clock); XCTAssertEqual(restored.clock?.position(activeSeconds: 155)?.round, 3)
        restored.activate(userID: other); XCTAssertNil(restored.clock); XCTAssertNil(restored.lastConfiguration)
        restored.activate(userID: owner); XCTAssertEqual(restored.lastConfiguration, configuration)
        restored.stop(activityID: UUID()); XCTAssertNotNil(restored.clock)
        restored.confirmActivity(nil); XCTAssertNil(restored.clock); XCTAssertEqual(restored.lastConfiguration, configuration)
        restored.clearDeletedAccount(); restored.activate(userID: owner); XCTAssertNil(restored.lastConfiguration)
    }

    func testSessionPauseAndResumePreserveIntervalPosition() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var activity = activity(owner: UUID(), at: start)
        let clock = SessionIntervalClock(activityID: activity.id, startedAtActiveSeconds: 0, configuration: configuration)
        activity.pausedAt = start.addingTimeInterval(10)
        let paused = try XCTUnwrap(activity.duration(at: start.addingTimeInterval(1000)))
        XCTAssertEqual(clock.position(activeSeconds: paused)?.remaining, 35)
        activity.pausedAt = nil; activity.pausedSeconds = 990
        let resumed = try XCTUnwrap(activity.duration(at: start.addingTimeInterval(1005)))
        XCTAssertEqual(clock.position(activeSeconds: resumed)?.remaining, 30)
    }

    func testOnlyOwnSupportedUnpausedLiveActivityCanStart() {
        let suite = "app.fyrup.tests.intervals.owner.\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SessionIntervalStore(defaults: defaults), owner = UUID(), now = Date()
        var mine = activity(owner: owner, at: now)
        XCTAssertFalse(store.start(activity: mine, configuration: configuration))
        store.activate(userID: UUID()); XCTAssertFalse(store.start(activity: mine, configuration: configuration))
        store.activate(userID: owner)
        mine.status = .completed; XCTAssertFalse(store.start(activity: mine, configuration: configuration))
        mine.status = .live; mine.pausedAt = now; XCTAssertFalse(store.start(activity: mine, configuration: configuration))
        mine.pausedAt = nil; mine.sport = .gym; XCTAssertFalse(store.start(activity: mine, configuration: configuration))
        mine.sport = .running; XCTAssertTrue(store.start(activity: mine, configuration: configuration))
        mine.status = .completed; store.confirmActivity(mine); XCTAssertNil(store.clock)
    }
}
