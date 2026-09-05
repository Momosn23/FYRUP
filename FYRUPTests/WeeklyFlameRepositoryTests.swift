import XCTest
@testable import FYRUP

@MainActor
final class WeeklyFlameRepositoryTests: XCTestCase {
    private let momoID = DemoRepository.defaultUserID
    private let maxID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let noon = Date(timeIntervalSince1970: 1_788_609_600) // Saturday, 2026-09-05 12:00 UTC

    private func repository(_ clock: WeeklyRepositoryTestClock, storage: DemoWeeklyFlameStorage,
                            userID: UUID = DemoRepository.defaultUserID, newProfile: Bool = true) -> DemoRepository {
        DemoRepository(startsWithoutProfile: newProfile, userID: userID, weeklyStorage: storage, now: { clock.now() })
    }

    private func state(_ repository: DemoRepository, userID: UUID? = nil, timezone: String? = "UTC") async throws -> WeeklyFlameState {
        let value = try await repository.weeklyState(userID: userID ?? momoID, timezone: timezone)
        XCTAssertTrue(value.isValid, "The demo must return the same validated snapshot shape as the server")
        return value
    }

    @discardableResult
    private func complete(_ repository: DemoRepository, clock: WeeklyRepositoryTestClock, seconds: TimeInterval = 60,
                          userID: UUID? = nil, sport: SportKind = .gym) async throws -> Activity {
        let activity = try await repository.startActivity(userID: userID ?? momoID, sport: sport, subtype: nil,
                                                         linkedActivityID: nil, plannedSessionID: nil)
        clock.advance(seconds)
        return try await repository.completeActivity(id: activity.id, distanceMeters: nil)
    }

    private func assertDenied(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("This request must be rejected", file: file, line: line) }
        catch { XCTAssertNotNil(error as? AppError, file: file, line: line) }
    }

    func testNullableRPCArgumentsAreExplicitAndContainNoClientCredits() throws {
        let stateBody = try JSONEncoder.supabase.encode(WeeklyStateRequest(userID: maxID, timezone: nil))
        let stateJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: stateBody) as? [String: Any])
        XCTAssertEqual(Set(stateJSON.keys), Set(["p_user", "p_timezone"]))
        XCTAssertTrue(stateJSON["p_timezone"] is NSNull)
        let reactionBody = try JSONEncoder.supabase.encode(FlameReactionRequest(weekID: maxID, reaction: nil))
        let reactionJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: reactionBody) as? [String: Any])
        XCTAssertEqual(Set(reactionJSON.keys), Set(["p_week", "p_reaction"]))
        XCTAssertTrue(reactionJSON["p_reaction"] is NSNull)
    }

    func testConfirmedGoalSurvivesRelaunchAndAccountsStayIsolatedOnDeletion() async throws {
        let suite = "app.fyrup.tests.weekly.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = WeeklyRepositoryTestClock(noon)
        let storage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let momo = repository(clock, storage: storage)
        let max = repository(clock, storage: storage, userID: maxID)
        let unconfirmed = try await state(momo)
        XCTAssertFalse(unconfirmed.goalConfirmed)
        XCTAssertNil(unconfirmed.currentWeek)
        let confirmed = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        _ = try await max.confirmWeeklyGoal(3, timezone: "UTC")
        _ = try await complete(momo, clock: clock)
        let restoredStorage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let restored = repository(clock, storage: restoredStorage)
        let restoredState = try await state(restored)
        XCTAssertEqual(restoredState.currentWeek?.id, confirmed.currentWeek?.id)
        XCTAssertEqual(restoredState.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(restoredState.currentWeek?.completedWorkouts, 1)
        let other = repository(clock, storage: restoredStorage, userID: maxID)
        let otherState = try await state(other, userID: maxID)
        XCTAssertEqual(otherState.currentWeek?.weeklyGoal, 3)
        XCTAssertEqual(otherState.currentWeek?.completedWorkouts, 0)
        try await restored.deleteAccount()
        let finalStorage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let deleted = try await state(repository(clock, storage: finalStorage))
        let retained = try await state(repository(clock, storage: finalStorage, userID: maxID), userID: maxID)
        XCTAssertFalse(deleted.goalConfirmed)
        XCTAssertEqual(retained.currentWeek?.weeklyGoal, 3)
    }

    func testExistingDemoHasConfirmedGoalWithoutFabricatedCreditsAndNewUsersMustConfirm() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let legacy = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }), newProfile: false)
        let legacyState = try await state(legacy)
        XCTAssertTrue(legacyState.goalConfirmed)
        XCTAssertEqual(legacyState.currentWeek?.completedWorkouts, 0, "Historical visual fixtures must not create weekly credits")
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let fresh = repository(clock, storage: storage)
        _ = try await state(fresh)
        for _ in 0..<3 { _ = try await complete(fresh, clock: clock) }
        let before = try await state(fresh)
        XCTAssertFalse(before.goalConfirmed)
        XCTAssertNil(before.currentWeek)
        let confirmed = try await fresh.confirmWeeklyGoal(3, timezone: "UTC")
        XCTAssertTrue(confirmed.isValid)
        XCTAssertEqual(confirmed.currentWeek?.completedWorkouts, 3)
        XCTAssertEqual(confirmed.currentWeek?.flameEarned, true)
        XCTAssertEqual(confirmed.currentWeek?.flameEarnedAt, clock.now())
    }

    func testOnlyCompletedActivitiesCountAndShortOrCancelledSessionsStillBehaveNormally() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        try await momo.planSession(userID: momoID, sport: .gym, subtype: nil, startsAt: noon.addingTimeInterval(3600),
                                   duration: 60, note: nil, placeName: nil, friendsCanJoin: false, friendIDs: [])
        let live = try await momo.startActivity(userID: momoID, sport: .running, subtype: nil, linkedActivityID: nil, plannedSessionID: nil)
        let whileLive = try await state(momo)
        XCTAssertEqual(whileLive.currentWeek?.completedWorkouts, 0)
        clock.advance(180)
        try await momo.cancelActivity(id: live.id)
        let afterCancel = try await state(momo)
        XCTAssertEqual(afterCancel.currentWeek?.completedWorkouts, 0)
        let short = try await complete(momo, clock: clock, seconds: 59)
        XCTAssertEqual(short.status, .completed)
        let shortRetry = try await momo.completeActivity(id: short.id, distanceMeters: nil)
        XCTAssertEqual(shortRetry.endedAt, short.endedAt)
        let afterShort = try await state(momo)
        XCTAssertEqual(afterShort.currentWeek?.completedWorkouts, 0)
        var tamperedRetry = short
        tamperedRetry.startedAt = short.endedAt?.addingTimeInterval(-600)
        try await storage.recordCompletion(tamperedRetry)
        let noRequalification = try await state(momo)
        XCTAssertEqual(noRequalification.currentWeek?.completedWorkouts, 0, "A processed ineligible activity cannot be requalified by a retry")
        _ = try await complete(momo, clock: clock, sport: .yoga)
        let valid = try await state(momo)
        XCTAssertEqual(valid.currentWeek?.completedWorkouts, 1, "All sports count at 60 active seconds")
    }

    func testPauseTimeDoesNotQualifyAsActiveTrainingTime() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let activity = try await momo.startActivity(userID: momoID, sport: .gym, subtype: nil, linkedActivityID: nil, plannedSessionID: nil)
        clock.advance(30)
        _ = try await momo.setActivityPaused(id: activity.id, paused: true)
        clock.advance(300)
        _ = try await momo.setActivityPaused(id: activity.id, paused: false)
        clock.advance(29)
        let completed = try await momo.completeActivity(id: activity.id, distanceMeters: nil)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.duration, 59)
        let result = try await state(momo)
        XCTAssertEqual(result.currentWeek?.completedWorkouts, 0)
    }

    func testEarnedFlameAndCelebrationAreIdempotentAcrossRetriesAndRelaunch() async throws {
        let suite = "app.fyrup.tests.weekly.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = WeeklyRepositoryTestClock(noon)
        let storage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let momo = repository(clock, storage: storage)
        _ = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        for expected in 1...3 {
            _ = try await complete(momo, clock: clock)
            let progress = try await state(momo)
            XCTAssertEqual(progress.currentWeek?.completedWorkouts, expected)
            XCTAssertEqual(progress.currentWeek?.flameEarned, false)
        }
        let fourth = try await complete(momo, clock: clock)
        let earned = try await state(momo)
        let week = try XCTUnwrap(earned.currentWeek)
        XCTAssertTrue(week.flameEarned)
        XCTAssertEqual(earned.currentStreak, 0, "An open earned week is not a finalized streak week")
        _ = try await momo.completeActivity(id: fourth.id, distanceMeters: nil)
        let firstClaim = try await momo.claimFlameCelebration(weekID: week.id)
        let secondClaim = try await momo.claimFlameCelebration(weekID: week.id)
        XCTAssertTrue(firstClaim); XCTAssertFalse(secondClaim)
        _ = try await complete(momo, clock: clock)
        let extra = try await state(momo)
        XCTAssertEqual(extra.currentWeek?.completedWorkouts, 5)
        XCTAssertEqual(extra.currentWeek?.flameEarnedAt, week.flameEarnedAt)
        let legacySummary = try await momo.goalSummary()
        XCTAssertEqual(legacySummary.weeklyCount, 5)
        XCTAssertEqual(legacySummary.streak, 0, "Older surfaces must not expose fabricated streaks alongside weekly progress")
        let restoredStorage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let restored = repository(clock, storage: restoredStorage)
        let afterRestart = try await state(restored)
        let repeatedClaim = try await restored.claimFlameCelebration(weekID: week.id)
        XCTAssertEqual(afterRestart.currentWeek?.completedWorkouts, 5)
        XCTAssertFalse(repeatedClaim)
        try await restoredStorage.recordCompletion(fourth)
        let repeatedCredit = try await state(restored)
        XCTAssertEqual(repeatedCredit.currentWeek?.completedWorkouts, 5)
    }

    func testGoalChangesApplyNextWeekAndValidationCannotManipulateCurrentGoal() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        await assertDenied { _ = try await momo.setNextWeeklyGoal(4) }
        await assertDenied { _ = try await momo.confirmWeeklyGoal(2, timezone: "UTC") }
        await assertDenied { _ = try await momo.confirmWeeklyGoal(8, timezone: "UTC") }
        await assertDenied { _ = try await momo.confirmWeeklyGoal(3, timezone: "Invalid/Zone") }
        let initial = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        let id = try XCTUnwrap(initial.currentWeek?.id)
        let retried = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        XCTAssertEqual(retried.currentWeek?.id, id)
        await assertDenied { _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC") }
        let lowered = try await momo.setNextWeeklyGoal(3)
        XCTAssertEqual(lowered.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(lowered.nextWeeklyGoal, 3)
        let reset = try await momo.setNextWeeklyGoal(4)
        XCTAssertNil(reset.nextWeeklyGoal)
        let raised = try await momo.setNextWeeklyGoal(5)
        XCTAssertEqual(raised.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(raised.nextWeeklyGoal, 5)
        clock.set(try XCTUnwrap(raised.currentWeek?.endsAt))
        await assertDenied { _ = try await momo.confirmWeeklyGoal(4, timezone: "UTC") }
        let next = try await state(momo)
        XCTAssertEqual(next.currentWeek?.weeklyGoal, 5)
        XCTAssertEqual(next.currentWeek?.completedWorkouts, 0)
        XCTAssertNil(next.nextWeeklyGoal)
        XCTAssertEqual(next.history.first?.weeklyGoal, 4)
        XCTAssertEqual(next.history.first?.id, id)
    }

    func testOnlyClosedSuccessfulWeeksBuildStreakAndMissedWeeksResetIt() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        for expected in 1...3 {
            for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
            let open = try await state(momo)
            XCTAssertEqual(open.currentStreak, expected - 1)
            clock.set(try XCTUnwrap(open.currentWeek?.endsAt))
            let closed = try await state(momo)
            XCTAssertEqual(closed.currentStreak, expected)
            XCTAssertEqual(closed.bestStreak, expected)
        }
        let current = try await state(momo)
        clock.set(try XCTUnwrap(current.currentWeek?.endsAt).addingTimeInterval(7 * 86_400))
        let missed = try await state(momo)
        XCTAssertEqual(missed.currentStreak, 0)
        XCTAssertEqual(missed.bestStreak, 3)
        XCTAssertEqual(missed.history.filter { !$0.flameEarned }.count, 2, "An absence must materialize every missed week")
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        let returned = try await state(momo)
        clock.set(try XCTUnwrap(returned.currentWeek?.endsAt))
        let recovered = try await state(momo)
        XCTAssertEqual(recovered.currentStreak, 1)
        XCTAssertEqual(recovered.bestStreak, 3)
    }

    func testDSTAndTravelKeepFrozenContiguousPeriodsWithExactlySevenDayLabels() async throws {
        let formatter = ISO8601DateFormatter()
        let clock = WeeklyRepositoryTestClock(try XCTUnwrap(formatter.date(from: "2026-10-24T12:00:00Z")))
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        let initial = try await momo.confirmWeeklyGoal(3, timezone: "Europe/Berlin")
        let old = try XCTUnwrap(initial.currentWeek)
        XCTAssertEqual(old.weekStartDate, "2026-10-19")
        XCTAssertEqual(old.endsAt.timeIntervalSince(old.startsAt), 169 * 3600, accuracy: 0.01)
        let travelling = try await state(momo, timezone: "America/Los_Angeles")
        XCTAssertEqual(travelling.currentWeek, old)
        XCTAssertEqual(travelling.nextTimezone, "America/Los_Angeles")
        clock.set(old.endsAt)
        let next = try await state(momo, timezone: "America/Los_Angeles")
        let new = try XCTUnwrap(next.currentWeek)
        XCTAssertEqual(new.weekStartDate, "2026-10-26")
        XCTAssertEqual(new.startsAt, old.endsAt)
        XCTAssertEqual(new.endsAt, formatter.date(from: "2026-11-02T08:00:00Z"))
        XCTAssertEqual(new.timezone, "America/Los_Angeles")
        XCTAssertNil(next.nextTimezone)
        XCTAssertEqual(next.history.first?.timezone, "Europe/Berlin")
    }

    func testCompletionExactlyAtBoundaryBelongsOnlyToNewWeekAndStepsDoNotCount() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let steps = DemoStepStorage(now: { clock.now() })
        let weekly = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = DemoRepository(startsWithoutProfile: true, stepStorage: steps, weeklyStorage: weekly, now: { clock.now() })
        let initial = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        _ = try await complete(momo, clock: clock)
        _ = try await complete(momo, clock: clock)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        _ = try await momo.syncSteps(userID: momoID, localDate: StepDay.key(for: clock.now(), calendar: calendar), timezone: "UTC",
                                    steps: 20_000, sharingRevision: preference.sharingRevision, observedAt: clock.now())
        let before = try await state(momo)
        XCTAssertEqual(before.currentWeek?.completedWorkouts, 2)
        clock.set(try XCTUnwrap(initial.currentWeek?.endsAt).addingTimeInterval(-60))
        _ = try await complete(momo, clock: clock)
        let after = try await state(momo)
        XCTAssertEqual(after.currentWeek?.completedWorkouts, 1)
        XCTAssertEqual(after.history.first?.completedWorkouts, 2)
        XCTAssertEqual(after.history.first?.flameEarned, false)
    }

    func testFriendsSeeOnlyAuthorizedProgressAndReactionsAreUniqueAndRevocable() async throws {
        let clock = WeeklyRepositoryTestClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        // This helper starts before profile setup. Complete that real setup step
        // before testing a subsequent change to the owner's privacy setting.
        let profileFixture = await momo.me
        try await momo.saveProfile(profileFixture)
        let max = repository(clock, storage: storage, userID: maxID)
        let stranger = repository(clock, storage: storage, userID: UUID())
        let initial = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let id = try XCTUnwrap(initial.currentWeek?.id)
        await assertDenied { _ = try await max.setFlameReaction(weekID: id, reaction: .fire) }
        await assertDenied { _ = try await stranger.weeklyState(userID: self.momoID, timezone: nil) }
        await assertDenied { _ = try await max.weeklyState(userID: self.momoID, timezone: "Asia/Tokyo") }
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        _ = try await momo.setNextWeeklyGoal(7)
        _ = try await state(momo, timezone: "Asia/Tokyo")
        _ = try await momo.saveActivityVisibility(userID: momoID, value: .nobody, expected: .friends)
        let friend = try await state(max, userID: momoID, timezone: nil)
        XCTAssertEqual(friend.currentWeek?.completedWorkouts, 3)
        XCTAssertNil(friend.nextWeeklyGoal)
        XCTAssertNil(friend.nextTimezone)
        await assertDenied { _ = try await momo.setFlameReaction(weekID: id, reaction: .fire) }
        await assertDenied { _ = try await max.claimFlameCelebration(weekID: id) }
        _ = try await max.setFlameReaction(weekID: id, reaction: .fire)
        _ = try await max.setFlameReaction(weekID: id, reaction: .fire)
        var reacted = try await state(max, userID: momoID, timezone: nil)
        XCTAssertEqual(reacted.currentWeek?.reactionCounts, [WeeklyFlameReactionCount(reaction: .fire, count: 1)])
        _ = try await max.setFlameReaction(weekID: id, reaction: .applause)
        reacted = try await state(max, userID: momoID, timezone: nil)
        XCTAssertEqual(reacted.currentWeek?.myReaction, .applause)
        XCTAssertEqual(reacted.currentWeek?.reactionCounts.count, 1)
        _ = try await max.setFlameReaction(weekID: id, reaction: nil)
        let removed = try await state(max, userID: momoID, timezone: nil)
        XCTAssertEqual(removed.currentWeek?.reactionCounts, [])
        _ = try await max.setFlameReaction(weekID: id, reaction: .strong)
        clock.set(try XCTUnwrap(friend.currentWeek?.endsAt))
        let single = try await state(max, userID: momoID, timezone: nil)
        XCTAssertEqual(single.history.count, 1)
        let batch = try await max.friendsWeeklyState()
        XCTAssertEqual(batch.first { $0.userID == momoID }?.history, [])
        try await momo.block(maxID)
        await assertDenied { _ = try await max.weeklyState(userID: self.momoID, timezone: nil) }
        await assertDenied { _ = try await max.setFlameReaction(weekID: id, reaction: .fire) }
        let afterBlock = try await state(momo, timezone: "Asia/Tokyo")
        XCTAssertEqual(afterBlock.history.first?.reactionCounts, [])
    }

    func testCorruptedPersistentStateIsPreservedInsteadOfReplacedWithInventedProgress() async throws {
        let suite = "app.fyrup.tests.weekly.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("{invalid saved weekly state".utf8)
        defaults.set(corrupt, forKey: "fyrup.demo.weekly-flames.v1")
        let clock = WeeklyRepositoryTestClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() }))
        await assertDenied { _ = try await momo.weeklyState(userID: self.momoID, timezone: "UTC") }
        await assertDenied { _ = try await momo.confirmWeeklyGoal(4, timezone: "UTC") }
        XCTAssertEqual(defaults.data(forKey: "fyrup.demo.weekly-flames.v1"), corrupt)
    }
}

private final class WeeklyRepositoryTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ date: Date) { value = date }
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ date: Date) { lock.lock(); defer { lock.unlock() }; value = date }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; value = value.addingTimeInterval(seconds) }
}
