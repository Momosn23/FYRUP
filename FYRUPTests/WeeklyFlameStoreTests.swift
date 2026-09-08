import XCTest
@testable import FYRUP

@MainActor
final class WeeklyFlameStoreTests: XCTestCase {
    func testSuggestedGoalNeverConfirmsOnboardingAutomatically() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(confirmed: false))
        await rig.store.activate(userID: WeeklyFixture.momo)
        XCTAssertEqual(rig.store.needsGoalConfirmation, true)
        XCTAssertNil(rig.store.currentWeek)
        XCTAssertEqual(rig.store.state?.suggestedWeeklyGoal, 4)
        let writes = await rig.repository.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testExplicitValidGoalConfirmsAndReloadsFromServerAfterRelaunch() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(confirmed: false))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setWriteState(WeeklyFixture.state(goal: 4))
        let saved = await rig.store.confirmGoal(4)
        XCTAssertTrue(saved)
        XCTAssertEqual(rig.store.needsGoalConfirmation, false)
        let nextStore = rig.makeStore()
        await nextStore.activate(userID: WeeklyFixture.momo)
        XCTAssertEqual(nextStore.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(nextStore.needsGoalConfirmation, false)
    }

    func testOutOfRangeGoalsNeverReachTheRepository() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        for goal in [Int.min, -1, 0, 1, 8, Int.max] {
            let confirmed = await rig.store.confirmGoal(goal)
            let scheduled = await rig.store.scheduleGoal(goal)
            XCTAssertFalse(confirmed); XCTAssertFalse(scheduled)
        }
        let writes = await rig.repository.writes
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(WeeklyGoal.options, [2, 3, 4, 5, 6, 7])
    }

    func testServerProgressOneThroughThreeHasNoFlameOrPresentationClaim() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        for count in 1...3 {
            await rig.repository.put(WeeklyFixture.state(count: count))
            await rig.store.refresh(force: true)
            await rig.store.prepareCelebration()
            XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, count)
            XCTAssertEqual(rig.store.currentWeek?.flameEarned, false)
            XCTAssertNil(rig.store.celebration)
        }
        let claims = await rig.repository.claimCalls
        XCTAssertEqual(claims, 0)
    }

    func testFourthWorkoutPresentsOnlyOnceIncludingFifthWorkoutAndRelaunch() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 4))
        await rig.store.activate(userID: WeeklyFixture.momo)
        XCTAssertNil(rig.store.celebration, "A read must not consume presentation before the UI is ready.")
        await rig.store.prepareCelebration()
        XCTAssertEqual(rig.store.celebration?.week.completedWorkouts, 4)
        rig.store.dismissCelebration()
        await rig.repository.put(WeeklyFixture.state(count: 5))
        await rig.store.refresh(force: true)
        await rig.store.prepareCelebration()
        XCTAssertEqual(rig.store.currentWeek?.progressText, "5 / 4")
        XCTAssertEqual(rig.store.currentWeek?.aboveGoal, 1)
        XCTAssertNil(rig.store.celebration)
        let restarted = rig.makeStore()
        await restarted.activate(userID: WeeklyFixture.momo)
        await restarted.prepareCelebration()
        XCTAssertNil(restarted.celebration)
        let claims = await rig.repository.claimCalls
        XCTAssertEqual(claims, 1)
    }

    func testNewWeekCanPresentItsOwnOneFlame() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 4))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.store.prepareCelebration()
        let firstID = rig.store.celebration?.id
        rig.store.dismissCelebration()
        let nextWeek = WeeklyFixture.week(count: 5, goal: 5, offset: 1)
        await rig.repository.put(WeeklyFixture.state(week: nextWeek, now: WeeklyFixture.now.addingTimeInterval(7 * 86400)))
        await rig.store.refresh(force: true)
        await rig.store.prepareCelebration()
        XCTAssertNotNil(rig.store.celebration)
        XCTAssertNotEqual(firstID, rig.store.celebration?.id)
        let claims = await rig.repository.claimCalls
        XCTAssertEqual(claims, 2)
    }

    func testAlreadyClaimedOnAnotherDeviceDoesNotPresentOrRepeatedlyClaim() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        let state = WeeklyFixture.state(count: 4)
        await rig.repository.put(state)
        await rig.repository.markClaimed(state.currentWeek!.id)
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.store.prepareCelebration(); await rig.store.prepareCelebration()
        XCTAssertNil(rig.store.celebration)
        let claims = await rig.repository.claimCalls
        XCTAssertEqual(claims, 1)
    }

    func testClaimTransportFailureDoesNotCreateLocalAchievementOrReceipt() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 4))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setClaimFailure(true)
        await rig.store.prepareCelebration()
        XCTAssertNil(rig.store.celebration)
        XCTAssertNotNil(rig.store.errorMessage)
        await rig.repository.setClaimFailure(false)
        await rig.store.prepareCelebration()
        XCTAssertNotNil(rig.store.celebration)
    }

    func testGoalChangeKeepsFourThisWeekAndFivePendingUntilServerRollover() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 2))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setWriteState(WeeklyFixture.state(count: 2, next: 5))
        let changed = await rig.store.scheduleGoal(5)
        XCTAssertTrue(changed)
        XCTAssertEqual(rig.store.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(rig.store.state?.nextWeeklyGoal, 5)
        let previous = WeeklyFixture.week(count: 5, finalized: true)
        let next = WeeklyFixture.week(count: 0, goal: 5, offset: 1)
        await rig.repository.put(WeeklyFixture.state(week: next, now: WeeklyFixture.now.addingTimeInterval(7 * 86400),
                                                     currentStreak: 1, bestStreak: 1, history: [previous]))
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.store.currentWeek?.progressText, "0 / 5")
        XCTAssertNil(rig.store.state?.nextWeeklyGoal)
        XCTAssertEqual(rig.store.history.first?.flameEarned, true)
    }

    func testGoalWriteFailureLeavesServerStateUnconfirmedNotOptimisticallyChanged() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setWriteFailure(true)
        let changed = await rig.store.scheduleGoal(7)
        XCTAssertFalse(changed)
        XCTAssertEqual(rig.store.currentWeek?.weeklyGoal, 4)
        XCTAssertNil(rig.store.state?.nextWeeklyGoal)
        XCTAssertFalse(rig.store.isStateConfirmed)
        XCTAssertNil(rig.store.needsGoalConfirmation)
        XCTAssertFalse(rig.store.isSavingGoal)
    }

    func testReadFailureDoesNotPretendExistingAccountNeedsNewOnboarding() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setReadFailure(true)
        await rig.store.refresh(force: true)
        XCTAssertNil(rig.store.needsGoalConfirmation)
        XCTAssertEqual(rig.store.state?.goalConfirmed, true)
        XCTAssertFalse(rig.store.isStateConfirmed)
    }

    func testCurrentEarnedWeekNeverIncrementsServerFinalizedStreakLocally() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 5, currentStreak: 3, bestStreak: 3))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.store.prepareCelebration()
        XCTAssertEqual(rig.store.state?.currentStreak, 3)
        await rig.repository.put(WeeklyFixture.state(currentStreak: 0, bestStreak: 3))
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.store.state?.currentStreak, 0)
        XCTAssertEqual(rig.store.state?.bestStreak, 3)
        await rig.repository.put(WeeklyFixture.state(currentStreak: 1, bestStreak: 3))
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.store.state?.currentStreak, 1)
        XCTAssertEqual(rig.store.state?.bestStreak, 3)
    }

    func testRepeatedRefreshDoesNotInventActivityOrHealthCredits() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 2))
        await rig.store.activate(userID: WeeklyFixture.momo)
        for _ in 0..<4 { await rig.store.refresh(force: true) }
        XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, 2)
        // This store deliberately has no step, calorie, timer or local-completion credit mutation API.
        let writes = await rig.repository.writes
        XCTAssertTrue(writes.isEmpty)
    }

    func testServerWeekBoundaryExpiresWithoutDeviceCalendarCalculation() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        let week = WeeklyFixture.week(count: 3)
        await rig.repository.put(WeeklyFixture.state(week: week, now: week.endsAt.addingTimeInterval(-20)))
        await rig.store.activate(userID: WeeklyFixture.momo)
        XCTAssertNotNil(rig.store.currentWeek)
        rig.clock.uptime += 21
        rig.clock.zone = "Pacific/Honolulu"
        XCTAssertNil(rig.store.currentWeek)
        XCTAssertEqual(rig.store.state?.currentWeek?.completedWorkouts, 3, "Historical snapshot is not rewritten to zero by the device.")
    }

    func testSlowResponseCannotKeepPreviousWeekVisiblePastItsBoundary() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        let week = WeeklyFixture.week(count: 3)
        await rig.repository.put(WeeklyFixture.state(week: week, now: week.endsAt.addingTimeInterval(-10)))
        await rig.repository.blockNextRead()
        let loading = Task { await rig.store.activate(userID: WeeklyFixture.momo) }
        await rig.repository.waitUntilReadBlocked()
        rig.clock.uptime += 15
        await rig.repository.releaseRead()
        await loading.value
        XCTAssertNil(rig.store.currentWeek)
    }

    func testRefreshThrottleAndExplicitCompletionRefresh() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.put(WeeklyFixture.state(count: 1))
        await rig.store.refresh()
        XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, 0)
        await rig.store.refresh(force: true)
        XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, 1)
        let reads = await rig.repository.readCalls
        XCTAssertEqual(reads, 2)
    }

    func testOldAccountReadCannotRepopulateStateAfterABASwitch() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 1))
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.activate(userID: WeeklyFixture.momo) }
        await rig.repository.waitUntilReadBlocked()
        await rig.store.activate(userID: WeeklyFixture.max)
        await rig.repository.put(WeeklyFixture.state(count: 3))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.releaseRead()
        await old.value
        XCTAssertEqual(rig.store.userID, WeeklyFixture.momo)
        XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, 3)
    }

    func testOldReadCannotOverwriteNewGoalMutation() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.refresh(force: true) }
        await rig.repository.waitUntilReadBlocked()
        await rig.repository.setWriteState(WeeklyFixture.state(next: 6))
        let changed = await rig.store.scheduleGoal(6)
        XCTAssertTrue(changed)
        await rig.repository.releaseRead()
        await old.value
        XCTAssertEqual(rig.store.state?.nextWeeklyGoal, 6)
        XCTAssertTrue(rig.store.isStateConfirmed)
    }

    func testClaimResponseCannotShowAnotherAccountsCelebration() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(count: 4))
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextClaim()
        let old = Task { await rig.store.prepareCelebration() }
        await rig.repository.waitUntilClaimBlocked()
        await rig.store.activate(userID: WeeklyFixture.max)
        await rig.repository.releaseClaim()
        await old.value
        XCTAssertNil(rig.store.celebration)
        XCTAssertEqual(rig.store.userID, WeeklyFixture.max)
        XCTAssertFalse(rig.store.isPreparingCelebration)
    }

    func testFriendReadsUseNoTimezoneAndShowServerAuthorizedFiveOfFour() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(owner: WeeklyFixture.max, count: 5))
        await rig.store.activate(userID: WeeklyFixture.momo)
        let friend = await rig.store.loadFriend(userID: WeeklyFixture.max)
        XCTAssertEqual(friend?.currentWeek?.progressText, "5 / 4")
        XCTAssertEqual(friend?.currentWeek?.flameEarned, true)
        let request = await rig.repository.lastRead
        XCTAssertEqual(request?.owner, WeeklyFixture.max)
        XCTAssertNil(request?.timezone)
    }

    func testFriendCacheExpiresAndFailedAccessReadClearsIt() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.setFriends([WeeklyFixture.state(owner: WeeklyFixture.max, count: 5)])
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.store.refreshFriends()
        XCTAssertEqual(rig.store.friends.count, 1)
        rig.clock.uptime += 121
        XCTAssertTrue(rig.store.friends.isEmpty)
        await rig.store.refreshFriends()
        XCTAssertEqual(rig.store.friends.count, 1)
        await rig.repository.setReadFailure(true)
        _ = await rig.store.loadFriend(userID: WeeklyFixture.max)
        XCTAssertNil(rig.store.friend(userID: WeeklyFixture.max))
    }

    func testRemoveFriendInvalidatesInflightFriendRead() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.loadFriend(userID: WeeklyFixture.max) }
        await rig.repository.waitUntilReadBlocked()
        rig.store.removeFriend(userID: WeeklyFixture.max)
        await rig.repository.releaseRead()
        let value = await old.value
        XCTAssertNil(value)
        XCTAssertNil(rig.store.friend(userID: WeeklyFixture.max))
    }

    func testOlderFriendDetailCannotOverwriteNewerConfirmedProgress() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.loadFriend(userID: WeeklyFixture.max) }
        await rig.repository.waitUntilReadBlocked()
        await rig.repository.put(WeeklyFixture.state(owner: WeeklyFixture.max, count: 5))
        _ = await rig.store.loadFriend(userID: WeeklyFixture.max)
        await rig.repository.releaseRead()
        let ignored = await old.value
        XCTAssertNil(ignored)
        XCTAssertEqual(rig.store.friend(userID: WeeklyFixture.max)?.currentWeek?.completedWorkouts, 5)
    }

    func testNewEmptyFriendBatchInvalidatesFirstUncachedDetailRequest() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.loadFriend(userID: WeeklyFixture.max) }
        await rig.repository.waitUntilReadBlocked()
        XCTAssertNil(rig.store.friend(userID: WeeklyFixture.max))
        await rig.repository.setFriends([])
        await rig.store.refreshFriends()
        await rig.repository.releaseRead()
        let ignored = await old.value
        XCTAssertNil(ignored)
        XCTAssertTrue(rig.store.friends.isEmpty)
    }

    func testFailedNewFriendBatchInvalidatesFirstUncachedDetailRequest() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.blockNextRead()
        let old = Task { await rig.store.loadFriend(userID: WeeklyFixture.max) }
        await rig.repository.waitUntilReadBlocked()
        await rig.repository.setReadFailure(true)
        await rig.store.refreshFriends()
        await rig.repository.releaseRead()
        let ignored = await old.value
        XCTAssertNil(ignored)
        XCTAssertTrue(rig.store.friends.isEmpty)
    }

    func testFailedReadCanRetryImmediatelyWithoutRefreshThrottle() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.store.activate(userID: WeeklyFixture.momo)
        await rig.repository.setReadFailure(true)
        await rig.store.refresh(force: true)
        await rig.repository.setReadFailure(false)
        await rig.repository.put(WeeklyFixture.state(count: 2))
        await rig.store.refresh()
        XCTAssertTrue(rig.store.isStateConfirmed)
        XCTAssertEqual(rig.store.currentWeek?.completedWorkouts, 2)
    }

    func testReactionsRequireVisibleEarnedFriendAndDoNotOptimisticallyIncrement() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        let friend = WeeklyFixture.state(owner: WeeklyFixture.max, count: 4)
        await rig.repository.put(friend)
        await rig.store.activate(userID: WeeklyFixture.momo)
        let forbidden = await rig.store.react(weekID: WeeklyFixture.week().id, reaction: .fire)
        XCTAssertFalse(forbidden)
        _ = await rig.store.loadFriend(userID: WeeklyFixture.max)
        await rig.repository.setReactionFailure(true)
        let failed = await rig.store.react(weekID: friend.currentWeek!.id, reaction: .strong)
        XCTAssertFalse(failed)
        XCTAssertNil(rig.store.friend(userID: WeeklyFixture.max)?.currentWeek?.myReaction)
        await rig.repository.setReactionFailure(false)
        let reactedWeek = WeeklyFixture.week(owner: WeeklyFixture.max, count: 4,
                                              reactions: [WeeklyFlameReactionCount(reaction: .strong, count: 1)], myReaction: .strong)
        await rig.repository.put(WeeklyFixture.state(owner: WeeklyFixture.max, week: reactedWeek))
        let succeeded = await rig.store.react(weekID: friend.currentWeek!.id, reaction: .strong)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(rig.store.friend(userID: WeeklyFixture.max)?.currentWeek?.myReaction, .strong)
    }

    func testPresentationReceiptsAreAccountScopedAndDeletionOnlyClearsOwner() {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        let ledger = SuccessAnimationEventStore(defaults: rig.defaults)
        let momoWeek = WeeklyFixture.week(count: 4)
        let maxWeek = WeeklyFixture.week(owner: WeeklyFixture.max, count: 4)
        XCTAssertTrue(ledger.consume(momoWeek)); XCTAssertTrue(ledger.consume(maxWeek))
        XCTAssertFalse(ledger.consume(momoWeek))
        ledger.clear(userID: WeeklyFixture.momo)
        XCTAssertFalse(ledger.hasConsumed(momoWeek))
        XCTAssertTrue(ledger.hasConsumed(maxWeek))
        XCTAssertFalse(ledger.consume(WeeklyFixture.week(count: 3)))
    }

    func testInvalidServerGoalAndForgedEarnedStateAreRejected() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(goal: 1))
        await rig.store.activate(userID: WeeklyFixture.momo)
        XCTAssertNil(rig.store.currentWeek)
        XCTAssertFalse(rig.store.isStateConfirmed)
        let inconsistent = WeeklyFixture.week(count: 2, earnedOverride: true)
        XCTAssertFalse(inconsistent.isValid)
        XCTAssertFalse(WeeklyFixture.state(week: inconsistent).isValid)
        XCTAssertFalse(WeeklyFixture.state(currentStreak: 4, bestStreak: 3).isValid)
    }

    func testTwoUnitsAreAnAllowedConfirmedServerGoal() async {
        let rig = WeeklyRig(); defer { rig.cleanUp() }
        await rig.repository.put(WeeklyFixture.state(goal: 2))
        await rig.store.activate(userID: WeeklyFixture.momo)
        XCTAssertEqual(rig.store.currentWeek?.weeklyGoal, 2)
        XCTAssertTrue(rig.store.isStateConfirmed)
    }

    func testModelsRoundTripRequiredServerFieldsAndDoNotTrustUnfinalizedHistory() throws {
        let value = WeeklyFixture.state(count: 5)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(value)
        XCTAssertEqual(try decoder.decode(WeeklyFlameState.self, from: data), value)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "goal_confirmed")
        XCTAssertThrowsError(try decoder.decode(WeeklyFlameState.self, from: JSONSerialization.data(withJSONObject: object)))
        XCTAssertFalse(WeeklyFixture.state(history: [WeeklyFixture.week(offset: -1)]).isValid)
        XCTAssertFalse(WeeklyFixture.week(label: "2026-02-31").isValid)
    }
}

private enum WeeklyFixture {
    static let momo = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let max = UUID(uuidString: "40000000-0000-0000-0000-000000000002")!
    static let now = ISO8601DateFormatter().date(from: "2026-09-05T10:00:00Z")!
    static let start = ISO8601DateFormatter().date(from: "2026-08-30T22:00:00Z")!

    static func week(owner: UUID = momo, count: Int = 0, goal: Int = 4, offset: Int = 0,
                     finalized: Bool = false, label: String? = nil, earnedOverride: Bool? = nil,
                     reactions: [WeeklyFlameReactionCount] = [], myReaction: ReactionKind? = nil) -> WeeklyProgress {
        let starts = start.addingTimeInterval(Double(offset) * 7 * 86400)
        let ends = starts.addingTimeInterval(7 * 86400)
        let earned = earnedOverride ?? (count >= goal)
        let labels = [-1: "2026-08-24", 0: "2026-08-31", 1: "2026-09-07"]
        let suffix = owner == momo ? 100 + offset : 200 + offset
        let id = UUID(uuidString: String(format: "40000000-0000-0000-0001-%012d", suffix))!
        return WeeklyProgress(id: id, userID: owner, weekStartDate: label ?? labels[offset]!, timezone: "Europe/Berlin",
                              startsAt: starts, endsAt: ends, weeklyGoal: goal, completedWorkouts: count,
                              flameEarned: earned, flameEarnedAt: earned ? starts.addingTimeInterval(3600) : nil,
                              finalized: finalized, finalizedAt: finalized ? ends : nil,
                              reactionCounts: reactions, myReaction: myReaction)
    }

    static func state(owner: UUID = momo, confirmed: Bool = true, count: Int = 0, goal: Int = 4, next: Int? = nil,
                      week suppliedWeek: WeeklyProgress? = nil, now: Date = WeeklyFixture.now,
                      currentStreak: Int = 0, bestStreak: Int = 0, history: [WeeklyProgress] = []) -> WeeklyFlameState {
        WeeklyFlameState(userID: owner, serverNow: now, currentWeek: confirmed ? (suppliedWeek ?? week(owner: owner, count: count, goal: goal)) : nil,
                         suggestedWeeklyGoal: 4, nextWeeklyGoal: next, nextTimezone: nil, goalConfirmed: confirmed,
                         currentStreak: currentStreak, bestStreak: bestStreak, history: history)
    }
}

@MainActor
private final class WeeklyTestClock { var uptime: TimeInterval = 1000; var zone = "Europe/Berlin" }

@MainActor
private struct WeeklyRig {
    let suite: String
    let defaults: UserDefaults
    let repository: WeeklyRepositoryDouble
    let clock: WeeklyTestClock
    let store: WeeklyFlameStore
    init() {
        let suiteName = "FYRUP.WeeklyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let repository = WeeklyRepositoryDouble()
        let clock = WeeklyTestClock()
        suite = suiteName; self.defaults = defaults; self.repository = repository; self.clock = clock
        store = WeeklyFlameStore(repository: repository, defaults: defaults, uptime: { clock.uptime }, timezone: { clock.zone })
    }
    func makeStore() -> WeeklyFlameStore {
        let clock = clock
        return WeeklyFlameStore(repository: repository, defaults: defaults, uptime: { clock.uptime }, timezone: { clock.zone })
    }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

private actor WeeklyRepositoryDouble: WeeklyFlameRepository {
    struct Read: Sendable { let owner: UUID; let timezone: String? }
    private var states = [WeeklyFixture.momo: WeeklyFixture.state(), WeeklyFixture.max: WeeklyFixture.state(owner: WeeklyFixture.max)]
    private var writeState = WeeklyFixture.state()
    private var friendValues: [WeeklyFlameState] = []
    private var claimed: Set<UUID> = []
    private var readFailure = false
    private var writeFailure = false
    private var claimFailure = false
    private var reactionFailure = false
    private(set) var writes: [Int] = []
    private(set) var claimCalls = 0
    private(set) var readCalls = 0
    private(set) var lastRead: Read?
    private var shouldBlockRead = false
    private var blockedRead: CheckedContinuation<Void, Never>?
    private var readWaiter: CheckedContinuation<Void, Never>?
    private var shouldBlockClaim = false
    private var blockedClaim: CheckedContinuation<Void, Never>?
    private var claimWaiter: CheckedContinuation<Void, Never>?

    func put(_ state: WeeklyFlameState) { states[state.userID] = state }
    func setWriteState(_ state: WeeklyFlameState) { writeState = state }
    func setFriends(_ values: [WeeklyFlameState]) { friendValues = values }
    func setReadFailure(_ value: Bool) { readFailure = value }
    func setWriteFailure(_ value: Bool) { writeFailure = value }
    func setClaimFailure(_ value: Bool) { claimFailure = value }
    func setReactionFailure(_ value: Bool) { reactionFailure = value }
    func markClaimed(_ week: UUID) { claimed.insert(week) }
    func blockNextRead() { shouldBlockRead = true }
    func blockNextClaim() { shouldBlockClaim = true }
    func waitUntilReadBlocked() async {
        if blockedRead != nil { return }
        await withCheckedContinuation { readWaiter = $0 }
    }
    func waitUntilClaimBlocked() async {
        if blockedClaim != nil { return }
        await withCheckedContinuation { claimWaiter = $0 }
    }
    func releaseRead() { blockedRead?.resume(); blockedRead = nil }
    func releaseClaim() { blockedClaim?.resume(); blockedClaim = nil }

    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState {
        readCalls += 1; lastRead = Read(owner: userID, timezone: timezone)
        if readFailure { throw AppError.network }
        guard let captured = states[userID] else { throw AppError.server }
        if shouldBlockRead {
            shouldBlockRead = false
            await withCheckedContinuation { continuation in blockedRead = continuation; readWaiter?.resume(); readWaiter = nil }
        }
        return captured
    }
    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState { try write(goal) }
    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState { try write(goal) }
    private func write(_ goal: Int) throws -> WeeklyFlameState {
        writes.append(goal)
        if writeFailure { throw AppError.network }
        states[writeState.userID] = writeState
        return writeState
    }
    func friendsWeeklyState() async throws -> [WeeklyFlameState] {
        if readFailure { throw AppError.network }
        return friendValues
    }
    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool {
        if reactionFailure { throw AppError.network }
        return true
    }
    func claimFlameCelebration(weekID: UUID) async throws -> Bool {
        claimCalls += 1
        if claimFailure { throw AppError.network }
        let first = claimed.insert(weekID).inserted
        if shouldBlockClaim {
            shouldBlockClaim = false
            await withCheckedContinuation { continuation in blockedClaim = continuation; claimWaiter?.resume(); claimWaiter = nil }
        }
        return first
    }
}
