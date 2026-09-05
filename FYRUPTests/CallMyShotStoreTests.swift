import XCTest
@testable import FYRUP

@MainActor
final class CallMyShotStoreTests: XCTestCase {
    func testSignedOutAndUnconfirmedNeverCreateACall() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        let signedOut = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(signedOut)
        await rig.repository.put(ShotStoreFixture.state(confirmed: false))
        await rig.activate()
        XCTAssertFalse(rig.store.canCall)
        let unconfirmed = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(unconfirmed)
        let count = await rig.repository.count(.call)
        XCTAssertEqual(count, 0)
    }

    func testEarnedAndAlreadyAnnouncedWeeksCannotBeCalled() async {
        for week in [ShotStoreFixture.week(count: 4), ShotStoreFixture.week(withCommitment: true)] {
            let rig = ShotStoreRig(); defer { rig.cleanUp() }
            await rig.repository.put(ShotStoreFixture.state(week: week))
            await rig.activate()
            XCTAssertFalse(rig.store.canCall)
            let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
            XCTAssertFalse(value)
            let count = await rig.repository.count(.call)
            XCTAssertEqual(count, 0)
        }
    }

    func testFailedOrExpiredWeeklySnapshotCannotAuthorizeCall() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.setFailure(.read, error: .network)
        await rig.weekly.refresh(force: true)
        XCTAssertFalse(rig.store.canCall)
        await rig.repository.setFailure(.read, error: nil)
        await rig.weekly.refresh(force: true)
        rig.clock.uptime += 8 * 86400
        XCTAssertFalse(rig.store.canCall)
        let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(value)
        let count = await rig.repository.count(.call)
        XCTAssertEqual(count, 0)
    }

    func testWeeklyBusyRejectsCallWithoutSendingMutation() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.read)
        let loading = Task { await rig.weekly.refresh(force: true) }
        await rig.repository.waitFor(.read, count: 2)
        XCTAssertFalse(rig.store.canCall)
        let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(value)
        await rig.repository.release(.read)
        await loading.value
        let count = await rig.repository.count(.call)
        XCTAssertEqual(count, 0)
    }

    func testSuccessUsesWeeklyReceiptAndSuppressesDuplicateTap() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.call)
        let pending = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call)
        XCTAssertTrue(rig.store.isCalling)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        let duplicate = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(duplicate)
        await rig.repository.release(.call)
        let value = await pending.value
        XCTAssertTrue(value)
        XCTAssertFalse(rig.store.isCalling)
        XCTAssertEqual(rig.weekly.currentWeek?.commitment, ShotStoreFixture.commitment())
        XCTAssertNil(rig.store.errorMessage)
        let afterSaved = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(afterSaved)
        let count = await rig.repository.count(.call)
        XCTAssertEqual(count, 1)
        let expected = await rig.repository.expectedWeekIDs
        XCTAssertEqual(expected, [ShotStoreFixture.week().id])
    }

    func testInvalidWriteIdentityCannotBeConfirmedByUnrelatedWeeklyReceipt() async {
        let wrongOwner = ShotStoreFixture.commitment(owner: ShotStoreFixture.friend)
        let wrongGoal = ShotStoreFixture.commitment(goal: 5)
        let wrongWeek = ShotStoreFixture.commitment(offset: 1)
        let wrongCallTime = ShotStoreFixture.commitment(calledAt: ShotStoreFixture.start.addingTimeInterval(-1))
        for reply in [wrongOwner, wrongGoal, wrongWeek, wrongCallTime] {
            let rig = ShotStoreRig(); defer { rig.cleanUp() }
            await rig.activate()
            await rig.repository.configureCall(reply: reply, stored: ShotStoreFixture.state(week: ShotStoreFixture.week(withCommitment: true)))
            let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
            XCTAssertFalse(value)
            XCTAssertNotNil(rig.store.errorMessage)
            XCTAssertFalse(rig.store.isCalling)
        }
    }

    func testMissingOrDifferentStoredCommitmentDoesNotConfirmWrite() async {
        for stored in [ShotStoreFixture.state(), ShotStoreFixture.state(week: ShotStoreFixture.week(withCommitment: true, commitmentID: UUID()))] {
            let rig = ShotStoreRig(); defer { rig.cleanUp() }
            await rig.activate()
            await rig.repository.configureCall(reply: ShotStoreFixture.commitment(), stored: stored)
            let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
            XCTAssertFalse(value)
            XCTAssertNotNil(rig.store.errorMessage)
        }
    }

    func testWriteFailureKeepsDataAndAllowsOnlyExplicitRetry() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        let before = rig.weekly.currentWeek
        await rig.repository.setFailure(.call, error: .network)
        let failed = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(failed)
        XCTAssertEqual(rig.weekly.currentWeek, before)
        XCTAssertNotNil(rig.store.errorMessage)
        var count = await rig.repository.count(.call)
        XCTAssertEqual(count, 1)
        await rig.repository.setFailure(.call, error: nil)
        let retry = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertTrue(retry)
        count = await rig.repository.count(.call)
        XCTAssertEqual(count, 2)
    }

    func testLostResponseAndConflictRecoverWithOneReadNotAnotherCreate() async {
        for error in [AppError.network, AppError.conflict("weekly_commitment_exists")] {
            let rig = ShotStoreRig(); defer { rig.cleanUp() }
            await rig.activate()
            await rig.repository.setFailure(.call, error: error)
            await rig.repository.setPersistDespiteCallError(true)
            let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
            XCTAssertTrue(value)
            XCTAssertNotNil(rig.weekly.currentWeek?.commitment)
            XCTAssertNil(rig.store.errorMessage)
            let count = await rig.repository.count(.call)
            XCTAssertEqual(count, 1)
        }
    }

    func testWriteSuccessWithFailedVerificationDoesNotClaimPersistenceFailed() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.setFailure(.read, error: .network)
        let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(value)
        XCTAssertFalse(rig.weekly.isStateConfirmed)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        XCTAssertTrue(rig.store.errorMessage?.contains("wird geprüft") == true)
    }

    func testConcurrentWeeklyReadQueuesVerificationWithoutPrematureSuccess() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.call)
        let pending = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call)
        await rig.repository.hold(.read)
        let loading = Task { await rig.weekly.refresh(force: true) }
        await rig.repository.waitFor(.read, count: 2)
        await rig.repository.release(.call)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        XCTAssertTrue(rig.store.errorMessage?.contains("wird geprüft") == true)
        await rig.repository.release(.read)
        await loading.value
        XCTAssertNotNil(rig.weekly.currentWeek?.commitment)
    }

    func testAchievementCanAdvanceBetweenWriteAndAuthoritativeRefresh() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        let earned = ShotStoreFixture.week(count: 4, withCommitment: true)
        await rig.repository.configureCall(reply: ShotStoreFixture.commitment(), stored: ShotStoreFixture.state(week: earned))
        let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertTrue(value)
        XCTAssertTrue(rig.weekly.currentWeek?.commitment?.achieved == true)
        XCTAssertEqual(rig.weekly.currentWeek?.commitment?.achievedAt, rig.weekly.currentWeek?.flameEarnedAt)
    }

    func testWeekRolloverDuringCallCannotAnnounceDifferentWeek() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        let next = ShotStoreFixture.week(offset: 1, withCommitment: true)
        await rig.repository.configureCall(reply: ShotStoreFixture.commitment(), stored: ShotStoreFixture.state(week: next))
        let value = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(value)
        XCTAssertEqual(rig.weekly.currentWeek?.id, next.id)
    }

    func testBoundaryConflictRefreshesChangedGoalButRequiresAnotherExplicitCall() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        let next = ShotStoreFixture.week(goal: 5, offset: 1)
        await rig.repository.configureCall(reply: ShotStoreFixture.commitment(), stored: ShotStoreFixture.state(week: next))
        await rig.repository.setPersistDespiteCallError(true)
        await rig.repository.setFailure(.call, error: .conflict("weekly_week_changed"))
        let rejected = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertFalse(rejected)
        XCTAssertEqual(rig.weekly.currentWeek?.weeklyGoal, 5)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        let firstIDs = await rig.repository.expectedWeekIDs
        XCTAssertEqual(firstIDs, [ShotStoreFixture.week().id])
        await rig.repository.setFailure(.call, error: nil)
        await rig.repository.configureCall(reply: ShotStoreFixture.commitment(goal: 5, offset: 1),
                                           stored: ShotStoreFixture.state(week: ShotStoreFixture.week(goal: 5, offset: 1, withCommitment: true)))
        let explicitlyConfirmed = await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id)
        XCTAssertTrue(explicitlyConfirmed)
        let allIDs = await rig.repository.expectedWeekIDs
        XCTAssertEqual(allIDs, [ShotStoreFixture.week().id, next.id])
    }

    func testConfirmationFromOldRenderedWeekCannotCreateInNewCachedWeek() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        let renderedWeekID = ShotStoreFixture.week().id
        await rig.repository.put(ShotStoreFixture.state(week: ShotStoreFixture.week(goal: 5, offset: 1)))
        await rig.weekly.refresh(force: true)
        let value = await rig.store.call(expectedWeekID: renderedWeekID)
        XCTAssertFalse(value)
        XCTAssertTrue(rig.store.errorMessage?.contains("Woche hat gewechselt") == true)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        let calls = await rig.repository.count(.call)
        XCTAssertEqual(calls, 0)
    }

    func testLogoutDuringCallDropsResponseAndDoesNotRefreshOldOwner() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.call)
        let pending = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call)
        rig.store.reset(); rig.weekly.reset()
        await rig.repository.release(.call)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.store.userID)
        XCTAssertNil(rig.weekly.state)
        XCTAssertFalse(rig.store.isCalling)
        XCTAssertNil(rig.store.errorMessage)
        let reads = await rig.repository.count(.read)
        XCTAssertEqual(reads, 1)
    }

    func testOldAccountCallCannotClearNewAccountBusyFlagOrState() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.call)
        let old = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call)
        rig.store.activate(userID: ShotStoreFixture.friend)
        await rig.weekly.activate(userID: ShotStoreFixture.friend)
        await rig.repository.configureCall(reply: ShotStoreFixture.commitment(owner: ShotStoreFixture.friend),
                                           stored: ShotStoreFixture.state(owner: ShotStoreFixture.friend, week: ShotStoreFixture.week(owner: ShotStoreFixture.friend, withCommitment: true)))
        let newer = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call, count: 2)
        await rig.repository.releaseFirst(.call)
        let ignored = await old.value
        XCTAssertFalse(ignored)
        XCTAssertTrue(rig.store.isCalling)
        XCTAssertEqual(rig.weekly.state?.userID, ShotStoreFixture.friend)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        await rig.repository.release(.call)
        let accepted = await newer.value
        XCTAssertTrue(accepted)
        XCTAssertFalse(rig.store.isCalling)
    }

    func testCancelledCallDoesNotPublishErrorOrRefresh() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        await rig.repository.hold(.call)
        let pending = Task { await rig.store.call(expectedWeekID: rig.weekly.currentWeek?.id ?? ShotStoreFixture.week().id) }
        await rig.repository.waitFor(.call)
        pending.cancel()
        await rig.repository.release(.call)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertFalse(rig.store.isCalling)
        XCTAssertNil(rig.weekly.currentWeek?.commitment)
        XCTAssertNil(rig.store.errorMessage)
    }

    func testReactionNeedsVisibleFreshFriendNeverOwnOrUnknownCommitment() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate()
        for id in [ShotStoreFixture.commitment().id, ShotStoreFixture.commitment(owner: ShotStoreFixture.friend).id, UUID()] {
            let value = await rig.store.react(commitmentID: id, reaction: .fire)
            XCTAssertFalse(value)
        }
        await rig.loadFriend()
        rig.clock.uptime += 121
        let expired = await rig.store.react(commitmentID: ShotStoreFixture.commitment(owner: ShotStoreFixture.friend).id, reaction: .target)
        XCTAssertFalse(expired)
        let count = await rig.repository.count(.reaction)
        XCTAssertEqual(count, 0)
    }

    func testReactionPreflightRevocationSendsNoMutationAndHidesFriend() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.setFailure(.read, error: .accessDenied)
        let value = await rig.react(.target)
        XCTAssertFalse(value)
        XCTAssertNil(rig.weekly.friend(userID: ShotStoreFixture.friend))
        let count = await rig.repository.count(.reaction)
        XCTAssertEqual(count, 0)
    }

    func testReactionSuccessIsAuthoritativeAndNilRemovesIt() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        let reacted = await rig.react(.strong)
        XCTAssertTrue(reacted)
        XCTAssertEqual(rig.friendCommitment?.myReaction, .strong)
        XCTAssertEqual(rig.friendCommitment?.reactionCounts, [ShotReactionCount(reaction: .strong, count: 1)])
        let removed = await rig.react(nil)
        XCTAssertTrue(removed)
        XCTAssertNil(rig.friendCommitment?.myReaction)
        XCTAssertEqual(rig.friendCommitment?.reactionCounts, [])
    }

    func testReactionInFlightHasNoOptimisticBadgeAndDuplicateIsSuppressed() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.hold(.reaction)
        let pending = Task { await rig.react(.fire) }
        await rig.repository.waitFor(.reaction)
        let id = ShotStoreFixture.commitment(owner: ShotStoreFixture.friend).id
        XCTAssertTrue(rig.store.isReacting(commitmentID: id))
        XCTAssertNil(rig.friendCommitment?.myReaction)
        let duplicate = await rig.react(.target)
        XCTAssertFalse(duplicate)
        let count = await rig.repository.count(.reaction)
        XCTAssertEqual(count, 1)
        await rig.repository.release(.reaction)
        let value = await pending.value
        XCTAssertTrue(value)
        XCTAssertTrue(rig.store.reactingIDs.isEmpty)
    }

    func testFailedReactionKeepsConfirmedDataAndReportsError() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        let before = rig.friendCommitment
        await rig.repository.setFailure(.reaction, error: .network)
        let value = await rig.react(.target)
        XCTAssertFalse(value)
        XCTAssertEqual(rig.friendCommitment, before)
        XCTAssertNotNil(rig.store.errorMessage)
        XCTAssertTrue(rig.store.reactingIDs.isEmpty)
    }

    func testFalseReactionReceiptIsNotTreatedAsSuccess() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.setReactionResult(false)
        let value = await rig.react(.strong)
        XCTAssertFalse(value)
        XCTAssertNil(rig.friendCommitment?.myReaction)
        XCTAssertNotNil(rig.store.errorMessage)
    }

    func testReactionPostReadMustConfirmRequestedValue() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.setIgnoreReactionWrite(true)
        let value = await rig.react(.target)
        XCTAssertFalse(value)
        XCTAssertNil(rig.friendCommitment?.myReaction)
        XCTAssertTrue(rig.store.errorMessage?.contains("wird geprüft") == true)
    }

    func testFailedPostReactionReadHidesUnconfirmedFriendContent() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.hold(.reaction)
        let pending = Task { await rig.react(.target) }
        await rig.repository.waitFor(.reaction)
        await rig.repository.setFailure(.read, error: .network)
        await rig.repository.release(.reaction)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.weekly.friend(userID: ShotStoreFixture.friend))
        XCTAssertNotNil(rig.store.errorMessage)
    }

    func testBlockDuringReactionPreflightRetiresResponseBeforeWrite() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.hold(.read)
        let pending = Task { await rig.react(.fire) }
        await rig.repository.waitFor(.read, count: 3)
        rig.store.removeFriend(userID: ShotStoreFixture.friend)
        await rig.repository.release(.read)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.friendCommitment)
        let count = await rig.repository.count(.reaction)
        XCTAssertEqual(count, 0)
    }

    func testBlockDuringReactionPreventsFollowUpReadAndRepopulation() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.hold(.reaction)
        let pending = Task { await rig.react(.fire) }
        await rig.repository.waitFor(.reaction)
        let readsBefore = await rig.repository.count(.read)
        rig.store.removeFriend(userID: ShotStoreFixture.friend)
        await rig.repository.release(.reaction)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.friendCommitment)
        XCTAssertTrue(rig.store.reactingIDs.isEmpty)
        let readsAfter = await rig.repository.count(.read)
        XCTAssertEqual(readsAfter, readsBefore)
    }

    func testLogoutDuringReactionClearsFlagsAndDropsLateError() async {
        let rig = ShotStoreRig(); defer { rig.cleanUp() }
        await rig.activate(); await rig.loadFriend()
        await rig.repository.hold(.reaction)
        let pending = Task { await rig.react(.fire) }
        await rig.repository.waitFor(.reaction)
        rig.store.reset(); rig.weekly.reset()
        await rig.repository.setFailure(.reaction, error: .network)
        await rig.repository.release(.reaction)
        let value = await pending.value
        XCTAssertFalse(value)
        XCTAssertNil(rig.store.errorMessage)
        XCTAssertTrue(rig.store.reactingIDs.isEmpty)
        XCTAssertTrue(rig.weekly.friends.isEmpty)
    }
}

private enum ShotStoreFixture {
    static let owner = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!
    static let friend = UUID(uuidString: "82000000-0000-0000-0000-000000000002")!
    static let start = ISO8601DateFormatter().date(from: "2026-08-30T22:00:00Z")!

    static func week(owner: UUID = ShotStoreFixture.owner, count: Int = 0, goal: Int = 4, offset: Int = 0,
                     withCommitment: Bool = false, commitmentID: UUID? = nil,
                     reaction: ShotReaction? = nil) -> WeeklyProgress {
        let starts = start.addingTimeInterval(Double(offset) * 7 * 86400)
        let id = UUID(uuidString: String(format: "82000000-0000-0000-0001-%012d", (owner == Self.owner ? 100 : 200) + offset))!
        var result = WeeklyProgress(id: id, userID: owner, weekStartDate: offset == 0 ? "2026-08-31" : "2026-09-07",
                                    timezone: "Europe/Berlin", startsAt: starts, endsAt: starts.addingTimeInterval(7 * 86400),
                                    weeklyGoal: goal, completedWorkouts: count, flameEarned: count >= goal,
                                    flameEarnedAt: count >= goal ? starts.addingTimeInterval(7200) : nil,
                                    finalized: false, finalizedAt: nil, reactionCounts: [], myReaction: nil)
        if withCommitment {
            result.commitment = commitment(owner: owner, count: count, goal: goal, offset: offset, id: commitmentID, reaction: reaction)
        }
        return result
    }

    static func commitment(owner: UUID = ShotStoreFixture.owner, count: Int = 0, goal: Int = 4, offset: Int = 0,
                           id: UUID? = nil, calledAt: Date? = nil, reaction: ShotReaction? = nil) -> WeeklyCommitment {
        let reference = week(owner: owner, count: count, goal: goal, offset: offset)
        let identifier = id ?? UUID(uuidString: String(format: "82000000-0000-0000-0002-%012d", (owner == Self.owner ? 100 : 200) + offset))!
        return WeeklyCommitment(id: identifier, userID: owner, weekID: reference.id, weekStartDate: reference.weekStartDate,
                                weeklyGoal: goal, calledAt: calledAt ?? reference.startsAt.addingTimeInterval(3600),
                                achieved: reference.flameEarned, achievedAt: reference.flameEarnedAt, finalized: false,
                                reactionCounts: reaction.map { [ShotReactionCount(reaction: $0, count: 1)] } ?? [], myReaction: reaction)
    }

    static func state(owner: UUID = ShotStoreFixture.owner, confirmed: Bool = true, week supplied: WeeklyProgress? = nil) -> WeeklyFlameState {
        let value = supplied ?? week(owner: owner)
        return WeeklyFlameState(userID: owner, serverNow: value.startsAt.addingTimeInterval(3 * 86400),
                                currentWeek: confirmed ? value : nil, suggestedWeeklyGoal: 4,
                                nextWeeklyGoal: nil, nextTimezone: nil, goalConfirmed: confirmed,
                                currentStreak: 0, bestStreak: 0, history: [])
    }
}

@MainActor
private final class ShotStoreClock { var uptime: TimeInterval = 1000 }

@MainActor
private struct ShotStoreRig {
    let repository: ShotStoreRepositoryStub
    let weekly: WeeklyFlameStore
    let store: CallMyShotStore
    let clock: ShotStoreClock
    let suite: String
    let defaults: UserDefaults

    init() {
        let repository = ShotStoreRepositoryStub()
        let suite = "FYRUP.CallMyShotStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let clock = ShotStoreClock()
        let weekly = WeeklyFlameStore(repository: repository, defaults: defaults, uptime: { clock.uptime }, timezone: { "Europe/Berlin" })
        self.repository = repository; self.defaults = defaults; self.weekly = weekly; self.clock = clock; self.suite = suite
        store = CallMyShotStore(repository: repository, weekly: weekly)
    }
    func activate() async { store.activate(userID: ShotStoreFixture.owner); await weekly.activate(userID: ShotStoreFixture.owner) }
    func loadFriend() async {
        await repository.put(ShotStoreFixture.state(owner: ShotStoreFixture.friend, week: ShotStoreFixture.week(owner: ShotStoreFixture.friend, withCommitment: true)))
        _ = await weekly.loadFriend(userID: ShotStoreFixture.friend)
    }
    var friendCommitment: WeeklyCommitment? { weekly.friend(userID: ShotStoreFixture.friend)?.currentWeek?.commitment }
    func react(_ reaction: ShotReaction?) async -> Bool {
        await store.react(commitmentID: ShotStoreFixture.commitment(owner: ShotStoreFixture.friend).id, reaction: reaction)
    }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

private enum ShotStoreOperation: Hashable, Sendable { case read, call, reaction }

/// One in-memory service implements both protocols, but only reads publish UI
/// data. Bounded suspension points exercise real actor reentrancy without sleeps.
private actor ShotStoreRepositoryStub: CallMyShotRepository, WeeklyFlameRepository {
    private var states = [ShotStoreFixture.owner: ShotStoreFixture.state(), ShotStoreFixture.friend: ShotStoreFixture.state(owner: ShotStoreFixture.friend)]
    private var callReply = ShotStoreFixture.commitment()
    private var callStored = ShotStoreFixture.state(week: ShotStoreFixture.week(withCommitment: true))
    private var persistDespiteCallError = false
    private var reactionResult = true
    private var ignoreReactionWrite = false
    private var failures: [ShotStoreOperation: AppError] = [:]
    private var held: Set<ShotStoreOperation> = []
    private var calls: [ShotStoreOperation: Int] = [:]
    private(set) var expectedWeekIDs: [UUID] = []
    private var gates: [ShotStoreOperation: [(UUID, CheckedContinuation<Void, Never>)]] = [:]
    private var observers: [ShotStoreOperation: [(UUID, Int, CheckedContinuation<Void, Never>)]] = [:]

    func put(_ value: WeeklyFlameState) { states[value.userID] = value }
    func configureCall(reply: WeeklyCommitment, stored: WeeklyFlameState) { callReply = reply; callStored = stored }
    func setPersistDespiteCallError(_ value: Bool) { persistDespiteCallError = value }
    func setReactionResult(_ value: Bool) { reactionResult = value }
    func setIgnoreReactionWrite(_ value: Bool) { ignoreReactionWrite = value }
    func setFailure(_ operation: ShotStoreOperation, error: AppError?) { failures[operation] = error }
    func count(_ operation: ShotStoreOperation) -> Int { calls[operation, default: 0] }
    func hold(_ operation: ShotStoreOperation) { held.insert(operation) }

    func waitFor(_ operation: ShotStoreOperation, count: Int = 1) async {
        if calls[operation, default: 0] >= count { return }
        let id = UUID()
        await withCheckedContinuation { continuation in
            observers[operation, default: []].append((id, count, continuation))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.timeoutObserver(operation, id: id)
            }
        }
    }

    private func timeoutObserver(_ operation: ShotStoreOperation, id: UUID) {
        guard let value = observers[operation]?.first(where: { $0.0 == id }) else { return }
        observers[operation]?.removeAll { $0.0 == id }
        XCTFail("Expected \(operation) did not begin within 3 seconds")
        value.2.resume()
    }

    func releaseFirst(_ operation: ShotStoreOperation) {
        guard var waiting = gates[operation], !waiting.isEmpty else { return }
        let first = waiting.removeFirst(); gates[operation] = waiting; first.1.resume()
    }
    func release(_ operation: ShotStoreOperation) {
        held.remove(operation)
        for (_, continuation) in gates.removeValue(forKey: operation) ?? [] { continuation.resume() }
    }

    private func checkpoint(_ operation: ShotStoreOperation) async {
        calls[operation, default: 0] += 1
        let count = calls[operation, default: 0]
        let ready = observers[operation, default: []].filter { $0.1 <= count }
        observers[operation] = observers[operation, default: []].filter { $0.1 > count }
        for (_, _, continuation) in ready { continuation.resume() }
        if held.contains(operation) {
            let id = UUID()
            await withCheckedContinuation { continuation in
                gates[operation, default: []].append((id, continuation))
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    await self?.timeoutGate(operation, id: id)
                }
            }
        }
    }
    private func timeoutGate(_ operation: ShotStoreOperation, id: UUID) {
        guard let value = gates[operation]?.first(where: { $0.0 == id }) else { return }
        gates[operation]?.removeAll { $0.0 == id }
        XCTFail("Unreleased \(operation) gate exceeded 3 seconds")
        value.1.resume()
    }

    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState {
        let captured = states[userID]
        await checkpoint(.read)
        if let error = failures[.read] { throw error }
        guard let captured else { throw AppError.accessDenied }
        return captured
    }
    func callMyShot(expectedWeekID: UUID) async throws -> WeeklyCommitment {
        expectedWeekIDs.append(expectedWeekID)
        let reply = callReply; let stored = callStored
        await checkpoint(.call)
        if failures[.call] == nil || persistDespiteCallError { states[stored.userID] = stored }
        if let error = failures[.call] { throw error }
        return reply
    }
    func setShotReaction(commitmentID: UUID, reaction: ShotReaction?) async throws -> Bool {
        await checkpoint(.reaction)
        if let error = failures[.reaction] { throw error }
        guard reactionResult else { return false }
        if !ignoreReactionWrite, let existing = states[ShotStoreFixture.friend]?.currentWeek, existing.commitment?.id == commitmentID {
            states[ShotStoreFixture.friend] = ShotStoreFixture.state(owner: ShotStoreFixture.friend,
                week: ShotStoreFixture.week(owner: ShotStoreFixture.friend, count: existing.completedWorkouts,
                                            goal: existing.weeklyGoal, withCommitment: true, reaction: reaction))
        }
        return true
    }
    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState { throw AppError.server }
    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState { throw AppError.server }
    func friendsWeeklyState() async throws -> [WeeklyFlameState] { [] }
    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool { throw AppError.server }
    func claimFlameCelebration(weekID: UUID) async throws -> Bool { false }
}
