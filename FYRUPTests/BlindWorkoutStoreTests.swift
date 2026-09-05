import XCTest
@testable import FYRUP

@MainActor
final class BlindWorkoutStoreTests: XCTestCase {
    func testActivationIsSynchronousAndDoesNotMakeAnImplicitRequest() async {
        let rig = BlindStoreRig()
        XCTAssertEqual(rig.store.userID, BlindStoreFixture.recipient)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        let reads = await rig.repository.readCalls
        XCTAssertEqual(reads, 0)
        rig.store.activate(userID: nil)
        XCTAssertNil(rig.store.userID)
    }

    func testRecipientInvitationContainsMetadataButNoExercises() async {
        let rig = BlindStoreRig()
        await rig.store.refreshSummaries()
        let value = await rig.store.load(id: BlindStoreFixture.id)
        XCTAssertEqual(rig.store.incoming.count, 1)
        XCTAssertTrue(rig.store.outgoing.isEmpty)
        XCTAssertEqual(value?.summary.exerciseCount, 3)
        XCTAssertEqual(value?.visibleExercises, [])
        XCTAssertNil(value?.currentExercise)
        XCTAssertEqual(value?.canCopy, false)
    }

    func testRecipientRejectsCreatorRoleEvenThoughBothKnowTheSameWorkoutID() async {
        let rig = BlindStoreRig()
        await rig.repository.setRead(BlindStoreFixture.state(role: .creator))
        let value = await rig.store.load(id: BlindStoreFixture.id)
        XCTAssertNil(value)
        XCTAssertNil(rig.store.selectedState)
        XCTAssertNotNil(rig.store.errorMessage)
    }

    func testRejectsForeignOwnerWrongIDAndFutureExercisePayloads() async {
        let rig = BlindStoreRig()
        await rig.repository.setRead(BlindStoreFixture.state(id: UUID()))
        let wrongID = await rig.store.load(id: BlindStoreFixture.id)
        XCTAssertNil(wrongID)
        await rig.repository.setRead(BlindStoreFixture.state(recipient: UUID()))
        let foreign = await rig.store.load(id: BlindStoreFixture.id)
        XCTAssertNil(foreign)
        let sent = BlindStoreFixture.state()
        let leaked = BlindWorkoutState(summary: sent.summary, viewerRole: .recipient,
                                       visibleExercises: [BlindStoreFixture.row(0)], activity: nil)
        await rig.repository.setRead(leaked)
        let future = await rig.store.load(id: BlindStoreFixture.id)
        XCTAssertNil(future)
        XCTAssertTrue(rig.store.summaries.isEmpty)
    }

    func testUnauthorizedOrDuplicateOverviewFailsClosed() async {
        let rig = BlindStoreRig()
        await rig.store.refreshSummaries()
        await rig.repository.setList([BlindStoreFixture.state(recipient: UUID()).summary])
        await rig.store.refreshSummaries()
        XCTAssertTrue(rig.store.summaries.isEmpty)
        let summary = BlindStoreFixture.state().summary
        await rig.repository.setList([summary, summary])
        await rig.store.refreshSummaries()
        XCTAssertTrue(rig.store.summaries.isEmpty)
    }

    func testEquipmentConsentRequiredAndDeclineDoesNotRequireEquipment() async {
        let rig = BlindStoreRig(); await rig.load()
        let unconfirmed = await rig.store.respond(id: BlindStoreFixture.id, accept: true, equipmentConfirmed: false)
        XCTAssertFalse(unconfirmed)
        var calls = await rig.repository.writes
        XCTAssertTrue(calls.isEmpty)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .declined))
        let declined = await rig.store.respond(id: BlindStoreFixture.id, accept: false, equipmentConfirmed: false)
        XCTAssertTrue(declined)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .declined)
        calls = await rig.repository.writes
        XCTAssertEqual(calls, ["respond"])
    }

    func testStartShowsOnlyFirstExerciseAfterServerConfirmation() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        await rig.repository.blockNext(.write)
        let starting = Task { await rig.store.start(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.write)
        XCTAssertTrue(rig.store.isBusy)
        XCTAssertEqual(rig.store.selectedState?.visibleExercises, [])
        XCTAssertEqual(rig.store.selectedState?.summary.status, .accepted)
        await rig.repository.release(.write)
        let result = await starting.value
        XCTAssertTrue(result)
        XCTAssertEqual(rig.store.selectedState?.visibleExercises.count, 1)
        XCTAssertEqual(rig.store.selectedState?.currentExercise?.id, BlindStoreFixture.row(0).id)
        XCTAssertNil(rig.store.selectedState?.currentExercise?.sets.first?.weight)
        XCTAssertFalse(rig.store.isBusy)
    }

    func testFailedExerciseSaveKeepsCurrentPrefixAndNeverUsesTargetsAsActuals() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let before = rig.store.selectedState
        await rig.repository.setWriteFailure(.network)
        let saved = await rig.store.saveExercise(id: BlindStoreFixture.id, exerciseID: BlindStoreFixture.row(0).id, sets: [], complete: true)
        XCTAssertFalse(saved)
        XCTAssertEqual(rig.store.selectedState, before)
        XCTAssertEqual(before?.currentExercise?.targetWeight, 80)
        XCTAssertNotNil(rig.store.errorMessage)
        let sent = await rig.repository.lastSets
        XCTAssertEqual(sent, [], "Easy mode must not manufacture weight/reps from targets.")
    }

    func testCompletingCurrentExerciseRevealsExactlyNextConfirmedExercise() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live, completed: 1))
        let saved = await rig.store.saveExercise(id: BlindStoreFixture.id, exerciseID: BlindStoreFixture.row(0).id, sets: [], complete: true)
        XCTAssertTrue(saved)
        XCTAssertEqual(rig.store.selectedState?.visibleExercises.count, 2)
        XCTAssertEqual(rig.store.selectedState?.summary.completedExercises, 1)
        XCTAssertEqual(rig.store.selectedState?.currentExercise?.id, BlindStoreFixture.row(1).id)
    }

    func testMalformedActualsAndHiddenExerciseNeverReachRepository() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let malformed: [[WorkoutSetLog]] = [
            [WorkoutSetLog(setNumber: 1, weight: .nan, reps: 8)],
            [WorkoutSetLog(setNumber: 1, weight: 501, reps: 8)],
            [WorkoutSetLog(setNumber: 1, weight: nil, reps: 31)],
            [WorkoutSetLog(setNumber: 7, weight: nil, reps: 8)],
            Array(repeating: WorkoutSetLog(setNumber: 1, weight: nil, reps: nil), count: 7)
        ]
        for sets in malformed {
            let saved = await rig.store.saveExercise(id: BlindStoreFixture.id, exerciseID: BlindStoreFixture.row(0).id, sets: sets, complete: false)
            XCTAssertFalse(saved)
        }
        let hidden = await rig.store.saveExercise(id: BlindStoreFixture.id, exerciseID: BlindStoreFixture.row(2).id, sets: [], complete: true)
        XCTAssertFalse(hidden)
        let calls = await rig.repository.writes
        XCTAssertTrue(calls.isEmpty)
    }

    func testFinishNeedsAllExercisesAndARealCompletedResponse() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let early = await rig.store.finish(id: BlindStoreFixture.id)
        XCTAssertFalse(early)
        await rig.load(.live, completed: 3)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live, completed: 3))
        let falseDone = await rig.store.finish(id: BlindStoreFixture.id)
        XCTAssertFalse(falseDone)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .live)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .completed))
        let finished = await rig.store.finish(id: BlindStoreFixture.id)
        XCTAssertTrue(finished)
        XCTAssertEqual(rig.store.selectedState?.activity?.status, .completed)
    }

    func testOnlyOneMutationRunsAtATimeWithoutAnOptimisticSecondAction() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        await rig.repository.blockNext(.write)
        let first = Task { await rig.store.start(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.write)
        let repeated = await rig.store.start(id: BlindStoreFixture.id)
        let cancel = await rig.store.cancel(id: BlindStoreFixture.id)
        XCTAssertFalse(repeated); XCTAssertFalse(cancel)
        let calls = await rig.repository.writes
        XCTAssertEqual(calls, ["start"])
        await rig.repository.release(.write)
        _ = await first.value
        XCTAssertFalse(rig.store.isBusy)
    }

    func testOldOverviewCannotUndoNewlyStartedTraining() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        await rig.repository.setList([BlindStoreFixture.state(status: .accepted).summary])
        await rig.repository.blockNext(.list)
        let reading = Task { await rig.store.refreshSummaries() }
        await rig.repository.waitUntilBlocked(.list)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        let started = await rig.store.start(id: BlindStoreFixture.id)
        XCTAssertTrue(started)
        await rig.repository.release(.list); await reading.value
        XCTAssertEqual(rig.store.summaries.first?.status, .live)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .live)
    }

    func testNewEmptyOverviewInvalidatesAnUncachedPendingDetail() async {
        let rig = BlindStoreRig()
        await rig.repository.blockNext(.detail)
        let loading = Task { await rig.store.load(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.detail)
        await rig.repository.setList([])
        await rig.store.refreshSummaries()
        await rig.repository.release(.detail)
        let stale = await loading.value
        XCTAssertNil(stale)
        XCTAssertNil(rig.store.selectedState)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testFailedNewOverviewInvalidatesAnUncachedPendingDetail() async {
        let rig = BlindStoreRig()
        await rig.repository.blockNext(.detail)
        let loading = Task { await rig.store.load(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.detail)
        await rig.repository.setListFailure(true)
        await rig.store.refreshSummaries()
        await rig.repository.release(.detail)
        let stale = await loading.value
        XCTAssertNil(stale)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testOlderEmptyOverviewCannotEraseNewAuthorizedDetail() async {
        let rig = BlindStoreRig()
        await rig.repository.setList([]); await rig.repository.blockNext(.list)
        let overview = Task { await rig.store.refreshSummaries() }
        await rig.repository.waitUntilBlocked(.list)
        await rig.load()
        await rig.repository.release(.list); await overview.value
        XCTAssertNotNil(rig.store.selectedState)
        XCTAssertEqual(rig.store.summaries.count, 1)
    }

    func testChangedSummaryReauthorizesTheSelectedExercisePrefix() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let advanced = BlindStoreFixture.state(status: .live, completed: 1)
        await rig.repository.setList([advanced.summary]); await rig.repository.setRead(advanced)
        await rig.store.refreshSummaries()
        XCTAssertEqual(rig.store.selectedState, advanced)
        XCTAssertEqual(rig.store.selectedState?.currentExercise?.id, BlindStoreFixture.row(1).id)
        XCTAssertFalse(rig.store.isLoadingSummaries)
        XCTAssertFalse(rig.store.isLoading)
        let reads = await rig.repository.readCalls
        XCTAssertEqual(reads, 3, "One initial detail, one authorized overview, one new authorized detail.")
    }

    func testUnchangedSummaryDoesNotUnnecessarilyReloadAnAuthorizedDetail() async {
        let rig = BlindStoreRig(); await rig.load()
        await rig.store.refreshSummaries()
        XCTAssertNotNil(rig.store.selectedState)
        let reads = await rig.repository.readCalls
        XCTAssertEqual(reads, 2)
    }

    func testChangedSummaryCannotRestoreDetailWhenFollowupAccessIsDenied() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        await rig.repository.setList([BlindStoreFixture.state(status: .live, completed: 1).summary])
        await rig.repository.setReadFailure(.accessDenied)
        await rig.store.refreshSummaries()
        XCTAssertNil(rig.store.selectedState)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertNotNil(rig.store.errorMessage)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testNewRevocationBatchRetiresPendingAutomaticReauthorization() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let advanced = BlindStoreFixture.state(status: .live, completed: 1)
        await rig.repository.setList([advanced.summary]); await rig.repository.setRead(advanced)
        await rig.repository.blockNext(.detail)
        let refreshing = Task { await rig.store.refreshSummaries() }
        await rig.repository.waitUntilBlocked(.detail)
        XCTAssertFalse(rig.store.isLoadingSummaries, "An automatic detail read must not lock out a revocation refresh.")
        XCTAssertTrue(rig.store.isLoading)
        await rig.repository.setList([])
        await rig.store.refreshSummaries()
        await rig.repository.release(.detail); await refreshing.value
        XCTAssertNil(rig.store.selectedState)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testNewSameMetadataBatchReauthorizesInsteadOfLeavingPendingDetailUnavailable() async {
        let rig = BlindStoreRig(); await rig.load(.live)
        let advanced = BlindStoreFixture.state(status: .live, completed: 1)
        await rig.repository.setList([advanced.summary]); await rig.repository.setRead(advanced)
        await rig.repository.blockNext(.detail)
        let older = Task { await rig.store.refreshSummaries() }
        await rig.repository.waitUntilBlocked(.detail)
        await rig.store.refreshSummaries()
        XCTAssertEqual(rig.store.selectedState, advanced)
        await rig.repository.release(.detail); await older.value
        XCTAssertEqual(rig.store.selectedState, advanced)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testAccountABASwitchRejectsOldReadAndResetsPrivateData() async {
        let rig = BlindStoreRig()
        await rig.repository.blockNext(.detail)
        let reading = Task { await rig.store.load(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.detail)
        rig.store.activate(userID: BlindStoreFixture.creator)
        rig.store.activate(userID: BlindStoreFixture.recipient)
        await rig.repository.release(.detail)
        let old = await reading.value
        XCTAssertNil(old)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertNil(rig.store.selectedState)
        XCTAssertFalse(rig.store.isLoading)
    }

    func testAccountABASwitchRejectsOldMutationAndDoesNotRepopulateState() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        await rig.repository.blockNext(.write)
        let writing = Task { await rig.store.start(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.write)
        rig.store.reset(); rig.store.activate(userID: BlindStoreFixture.recipient)
        await rig.repository.release(.write)
        let old = await writing.value
        XCTAssertFalse(old)
        XCTAssertTrue(rig.store.summaries.isEmpty)
        XCTAssertNil(rig.store.selectedState)
        XCTAssertFalse(rig.store.isBusy)
    }

    func testFriendRemovalRejectsPendingDetailAndMutationReplies() async {
        let rig = BlindStoreRig()
        await rig.repository.blockNext(.detail)
        let reading = Task { await rig.store.load(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.detail)
        rig.store.removeFriend(userID: BlindStoreFixture.creator)
        await rig.repository.release(.detail)
        let oldRead = await reading.value
        XCTAssertNil(oldRead)
        await rig.load(.accepted)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        await rig.repository.blockNext(.write)
        let writing = Task { await rig.store.start(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.write)
        rig.store.removeFriend(userID: BlindStoreFixture.creator)
        await rig.repository.release(.write)
        let oldWrite = await writing.value
        XCTAssertFalse(oldWrite)
        XCTAssertNil(rig.store.selectedState)
        XCTAssertTrue(rig.store.summaries.isEmpty)
    }

    func testCancelledTaskDoesNotPublishItsLateReveal() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .live))
        await rig.repository.blockNext(.write)
        let writing = Task { await rig.store.start(id: BlindStoreFixture.id) }
        await rig.repository.waitUntilBlocked(.write)
        writing.cancel()
        await rig.repository.release(.write)
        let value = await writing.value
        XCTAssertFalse(value)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .accepted)
        XCTAssertFalse(rig.store.isBusy)
    }

    func testCancellationRemainsAvailableWithoutCachedFriendAccess() async {
        let rig = BlindStoreRig()
        await rig.repository.setWrite(BlindStoreFixture.state(status: .cancelled))
        let cancelled = await rig.store.cancel(id: BlindStoreFixture.id)
        XCTAssertTrue(cancelled)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .cancelled)
        XCTAssertEqual(rig.store.selectedState?.visibleExercises, [])
    }

    func testCopyRequiresCompletedRecipientAndValidPrivateOwnedPlan() async {
        let rig = BlindStoreRig(); await rig.load()
        let tooEarly = await rig.store.copy(id: BlindStoreFixture.id)
        XCTAssertNil(tooEarly)
        await rig.load(.completed)
        var plan = BlindStoreFixture.plan(owner: BlindStoreFixture.creator)
        await rig.repository.setCopy(plan)
        let wrongOwner = await rig.store.copy(id: BlindStoreFixture.id)
        XCTAssertNil(wrongOwner)
        plan.ownerID = BlindStoreFixture.recipient; plan.visibility = .friends
        await rig.repository.setCopy(plan)
        let publicCopy = await rig.store.copy(id: BlindStoreFixture.id)
        XCTAssertNil(publicCopy)
        plan.visibility = .private
        await rig.repository.setCopy(plan)
        let saved = await rig.store.copy(id: BlindStoreFixture.id)
        XCTAssertEqual(saved, plan)
    }

    func testReactionRequiresCompletionAndUsesConfirmedReactionIncludingRemoval() async {
        let rig = BlindStoreRig(); await rig.load()
        let tooEarly = await rig.store.react(id: BlindStoreFixture.id, reaction: .fire)
        XCTAssertFalse(tooEarly)
        await rig.load(.completed)
        var reacted = BlindStoreFixture.state(status: .completed)
        reacted.myReaction = .strong; reacted.reactionCounts = [BlindWorkoutReactionCount(reaction: .strong, count: 1)]
        await rig.repository.setWrite(reacted)
        let confirmed = await rig.store.react(id: BlindStoreFixture.id, reaction: .strong)
        XCTAssertTrue(confirmed)
        XCTAssertEqual(rig.store.selectedState?.myReaction, .strong)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .completed))
        let removed = await rig.store.react(id: BlindStoreFixture.id, reaction: nil)
        XCTAssertTrue(removed)
        XCTAssertNil(rig.store.selectedState?.myReaction)
    }

    func testSendNormalizesDraftKeepsRetryIDAndRejectsSelfRecipient() async {
        let rig = BlindStoreRig(owner: BlindStoreFixture.creator)
        var draft = BlindWorkoutDraft(id: BlindStoreFixture.id, recipientID: BlindStoreFixture.creator, title: "  Push  ",
                                     exercises: (0..<3).map { WorkoutPlanExercise(exercise: BlindStoreFixture.exercise($0)) })
        let selfSend = await rig.store.send(draft)
        XCTAssertFalse(selfSend)
        draft.recipientID = BlindStoreFixture.recipient
        await rig.repository.setWrite(BlindStoreFixture.state(role: .creator))
        let sent = await rig.store.send(draft)
        XCTAssertTrue(sent)
        let actual = await rig.repository.lastDraft
        XCTAssertEqual(actual?.id, draft.id)
        XCTAssertEqual(actual?.title, "Push")
        XCTAssertEqual(actual?.exercises.first?.sortOrder, 0)
        XCTAssertEqual(rig.store.outgoing.count, 1)
    }

    func testRevokedServerAccessClearsPrivateDetailsOnSaveAndCopy() async {
        let rig = BlindStoreRig()
        let forbidden = SupabaseRESTClient.appError(status: 403, code: "42501", message: "forbidden")
        for denied in [AppError.authentication, forbidden] {
            await rig.load(.live)
            await rig.repository.setWriteFailure(denied)
            let saved = await rig.store.saveExercise(id: BlindStoreFixture.id, exerciseID: BlindStoreFixture.row(0).id, sets: [], complete: true)
            XCTAssertFalse(saved)
            XCTAssertNil(rig.store.selectedState)
            XCTAssertTrue(rig.store.summaries.isEmpty)
            await rig.load(.completed)
            let copied = await rig.store.copy(id: BlindStoreFixture.id)
            XCTAssertNil(copied)
            XCTAssertNil(rig.store.selectedState)
            XCTAssertTrue(rig.store.summaries.isEmpty)
        }
    }

    func testPlanningDoesNotRevealAnExerciseOrTrustInvalidDeviceDate() async {
        let rig = BlindStoreRig(); await rig.load(.accepted)
        let invalid = await rig.store.plan(id: BlindStoreFixture.id, startsAt: Date(timeIntervalSince1970: .nan))
        XCTAssertFalse(invalid)
        var writes = await rig.repository.writes
        XCTAssertTrue(writes.isEmpty)
        await rig.repository.setWrite(BlindStoreFixture.state(status: .planned))
        let planned = await rig.store.plan(id: BlindStoreFixture.id, startsAt: BlindStoreFixture.now.addingTimeInterval(3600))
        XCTAssertTrue(planned)
        XCTAssertEqual(rig.store.selectedState?.summary.status, .planned)
        XCTAssertEqual(rig.store.selectedState?.visibleExercises, [])
        XCTAssertEqual(rig.store.selectedState?.activity?.status, .planned)
        writes = await rig.repository.writes
        XCTAssertEqual(writes, ["plan"])
    }
}

private enum BlindStoreFixture {
    static let creator = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    static let recipient = UUID(uuidString: "60000000-0000-0000-0000-000000000002")!
    static let id = UUID(uuidString: "60000000-0000-0000-0000-000000000003")!
    static let activityID = UUID(uuidString: "60000000-0000-0000-0000-000000000004")!
    static let now = Date(timeIntervalSince1970: 1_788_609_600)
    static func exercise(_ index: Int) -> GymExercise {
        GymExercise(id: UUID(uuidString: String(format: "60000000-0000-0000-0001-%012d", index + 1))!,
                    name: ["Bankdrücken", "Schrägbank", "Liegestütze"][index], primaryMuscle: .chest, equipment: .barbell, isCustom: false)
    }
    static func row(_ index: Int, completed: Bool = false) -> WorkoutExerciseLog {
        WorkoutExerciseLog(id: UUID(uuidString: String(format: "60000000-0000-0000-0002-%012d", index + 1))!,
                           exercise: exercise(index), planExerciseID: nil, sortOrder: index, targetSets: 3, targetRepsMin: 8,
                           targetRepsMax: 12, targetWeight: 80, note: nil, completed: completed,
                           completedAt: completed ? now : nil, sets: [])
    }
    static func state(id: UUID = BlindStoreFixture.id, status: BlindWorkoutStatus = .sent, role: BlindWorkoutRole = .recipient,
                      completed: Int = 0, recipient: UUID = BlindStoreFixture.recipient) -> BlindWorkoutState {
        let count = status == .completed ? 3 : completed
        let active = [.planned, .live, .completed].contains(status)
        let accepted = [.accepted, .planned, .live, .completed].contains(status)
        let started = [.live, .completed].contains(status)
        let summary = BlindWorkoutSummary(id: id, creatorID: creator, recipientID: recipient, creatorName: "Max", recipientName: "Momo",
                                          title: "Push", focus: .push, estimatedDurationMinutes: 45, exerciseCount: 3,
                                          requiredEquipment: [.barbell], muscleGroups: [.chest], status: status,
                                          createdAt: now.addingTimeInterval(-600), scheduledAt: status == .planned ? now.addingTimeInterval(3600) : nil,
                                          acceptedAt: accepted ? now.addingTimeInterval(-120) : nil,
                                          startedAt: started ? now.addingTimeInterval(-60) : nil, completedAt: status == .completed ? now : nil,
                                          activityID: active ? activityID : nil, completedExercises: count)
        let activity: Activity? = role == .recipient && active ? Activity(
            id: activityID, userID: recipient, sport: .gym, subtype: "Blind Workout", status: status == .planned ? .planned : status == .completed ? .completed : .live,
            plannedAt: summary.scheduledAt, startedAt: summary.startedAt, endedAt: summary.completedAt, distanceMeters: nil,
            plannedDurationMinutes: 45, note: nil, plannedSessionID: nil, blindWorkoutID: id, exerciseCount: 3) : nil
        let visible: [WorkoutExerciseLog]
        if role == .creator { visible = (0..<3).map { row($0) } }
        else if status == .live || status == .completed { visible = (0..<min(count + 1, 3)).map { row($0, completed: $0 < count) } }
        else { visible = [] }
        return BlindWorkoutState(summary: summary, viewerRole: role, visibleExercises: visible, activity: activity)
    }
    static func plan(owner: UUID = recipient) -> WorkoutPlan {
        WorkoutPlan(ownerID: owner, name: "Mein Blind Workout", exercises: [WorkoutPlanExercise(exercise: exercise(0))])
    }
}

@MainActor
private struct BlindStoreRig {
    let repository: BlindStoreRepositoryDouble
    let store: BlindWorkoutStore
    init(owner: UUID = BlindStoreFixture.recipient) {
        let repository = BlindStoreRepositoryDouble()
        self.repository = repository
        store = BlindWorkoutStore(repository: repository)
        store.activate(userID: owner)
    }
    func load(_ status: BlindWorkoutStatus = .sent, completed: Int = 0) async {
        let value = BlindStoreFixture.state(status: status, completed: completed)
        XCTAssertTrue(value.isValid, "The test fixture must satisfy the same DTO privacy contract.")
        await repository.setRead(value)
        let loaded = await store.load(id: BlindStoreFixture.id)
        XCTAssertNotNil(loaded)
    }
}

private actor BlindStoreRepositoryDouble: BlindWorkoutRepository {
    enum Block: Hashable, Sendable { case detail, list, write }
    private var readState = BlindStoreFixture.state()
    private var writeState = BlindStoreFixture.state()
    private var list = [BlindStoreFixture.state().summary]
    private var copyValue = BlindStoreFixture.plan()
    private var listFailure = false
    private var readFailure: AppError?
    private var writeFailure: AppError?
    private var nextBlocks: Set<Block> = []
    private var blocked: [Block: CheckedContinuation<Void, Never>] = [:]
    private var waiters: [Block: CheckedContinuation<Void, Never>] = [:]
    private(set) var writes: [String] = []
    private(set) var readCalls = 0
    private(set) var lastSets: [WorkoutSetLog]?
    private(set) var lastDraft: BlindWorkoutDraft?
    func setRead(_ value: BlindWorkoutState) { readState = value }
    func setWrite(_ value: BlindWorkoutState) { writeState = value }
    func setList(_ value: [BlindWorkoutSummary]) { list = value }
    func setCopy(_ value: WorkoutPlan) { copyValue = value }
    func setListFailure(_ value: Bool) { listFailure = value }
    func setReadFailure(_ value: AppError?) { readFailure = value }
    func setWriteFailure(_ value: AppError?) { writeFailure = value }
    func blockNext(_ kind: Block) { nextBlocks.insert(kind) }
    func waitUntilBlocked(_ kind: Block) async {
        if blocked[kind] != nil { return }
        await withCheckedContinuation { waiters[kind] = $0 }
    }
    func release(_ kind: Block) { blocked.removeValue(forKey: kind)?.resume() }
    private func pauseIfRequested(_ kind: Block) async {
        guard nextBlocks.remove(kind) != nil else { return }
        await withCheckedContinuation { continuation in
            blocked[kind] = continuation; waiters.removeValue(forKey: kind)?.resume()
        }
    }
    func blindWorkouts() async throws -> [BlindWorkoutSummary] {
        readCalls += 1
        if listFailure { throw AppError.network }
        let captured = list; await pauseIfRequested(.list); return captured
    }
    func blindWorkout(id: UUID) async throws -> BlindWorkoutState {
        readCalls += 1
        if let readFailure { throw readFailure }
        let captured = readState; await pauseIfRequested(.detail); return captured
    }
    private func write(_ name: String) async throws -> BlindWorkoutState {
        writes.append(name)
        if let writeFailure { throw writeFailure }
        let captured = writeState; await pauseIfRequested(.write); return captured
    }
    func sendBlindWorkout(_ draft: BlindWorkoutDraft) async throws -> BlindWorkoutState { lastDraft = draft; return try await write("send") }
    func respondToBlindWorkout(id: UUID, accept: Bool, equipmentConfirmed: Bool) async throws -> BlindWorkoutState { try await write("respond") }
    func planBlindWorkout(id: UUID, startsAt: Date) async throws -> BlindWorkoutState { try await write("plan") }
    func startBlindWorkout(id: UUID) async throws -> BlindWorkoutState { try await write("start") }
    func saveBlindWorkoutExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async throws -> BlindWorkoutState {
        lastSets = sets; return try await write("save")
    }
    func finishBlindWorkout(id: UUID) async throws -> BlindWorkoutState { try await write("finish") }
    func cancelBlindWorkout(id: UUID) async throws -> BlindWorkoutState { try await write("cancel") }
    func copyBlindWorkout(id: UUID) async throws -> WorkoutPlan {
        writes.append("copy")
        if let writeFailure { throw writeFailure }
        return copyValue
    }
    func reactToBlindWorkout(id: UUID, reaction: ReactionKind?) async throws -> BlindWorkoutState { try await write("react") }
}
