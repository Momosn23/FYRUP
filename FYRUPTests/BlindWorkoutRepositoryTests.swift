import XCTest
@testable import FYRUP

@MainActor
final class BlindWorkoutRepositoryTests: XCTestCase {
    private let momoID = DemoRepository.defaultUserID
    private let maxID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let noon = Date(timeIntervalSince1970: 1_788_609_600)

    private var library: [GymExercise] {
        ["Bankdrücken", "Schrägbank Kurzhantel", "Schulterdrücken", "Seitheben", "Trizeps Pushdown", "Overhead Extension"].enumerated().map { index, name in
            GymExercise(id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1))!,
                        name: name, primaryMuscle: index < 2 ? .chest : .shoulders,
                        equipment: index.isMultiple(of: 2) ? .barbell : .dumbbell, isCustom: false)
        }
    }
    private struct Context {
        let clock: BlindRepositoryTestClock
        let storage: DemoBlindWorkoutStorage
        let workouts: DemoWorkoutStorage
        let weekly: DemoWeeklyFlameStorage
        let creator: DemoRepository
        let recipient: DemoRepository
    }
    private func context(suite: String? = nil, clock: BlindRepositoryTestClock? = nil) -> Context {
        let clock = clock ?? BlindRepositoryTestClock(noon)
        let storage = DemoBlindWorkoutStorage(persistenceSuiteName: suite, now: { clock.now() })
        let workouts = DemoWorkoutStorage(persistenceSuiteName: suite, library: library)
        let weekly = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let creator = DemoRepository(startsWithoutProfile: true, userID: maxID, workoutStorage: workouts,
                                     weeklyStorage: weekly, blindStorage: storage, now: { clock.now() })
        let recipient = DemoRepository(startsWithoutProfile: true, workoutStorage: workouts,
                                       weeklyStorage: weekly, blindStorage: storage, now: { clock.now() })
        return Context(clock: clock, storage: storage, workouts: workouts, weekly: weekly, creator: creator, recipient: recipient)
    }
    private func draft(count: Int = 6) -> BlindWorkoutDraft {
        BlindWorkoutDraft(recipientID: momoID, title: "Push von Max", focus: .push, estimatedDurationMinutes: 55,
                          exercises: library.prefix(count).enumerated().map { index, exercise in
                              WorkoutPlanExercise(exercise: exercise, sortOrder: index, targetSets: 3,
                                                  targetRepsMin: 8, targetRepsMax: 12, targetWeight: index == 0 ? 80 : nil)
                          })
    }
    private func assertDenied(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("This operation must be rejected", file: file, line: line) }
        catch { XCTAssertNotNil(error as? AppError, file: file, line: line) }
    }
    private func start(_ context: Context, draft: BlindWorkoutDraft? = nil) async throws -> BlindWorkoutState {
        let sent = try await context.creator.sendBlindWorkout(draft ?? self.draft())
        _ = try await context.recipient.respondToBlindWorkout(id: sent.summary.id, accept: true, equipmentConfirmed: true)
        let started = try await context.recipient.startBlindWorkout(id: sent.summary.id)
        XCTAssertTrue(started.isValid)
        return started
    }
    private func finish(_ context: Context, state: BlindWorkoutState) async throws -> BlindWorkoutState {
        var current = state
        while let exercise = current.currentExercise {
            current = try await context.recipient.saveBlindWorkoutExercise(id: current.summary.id, exerciseID: exercise.id, sets: [], complete: true)
        }
        context.clock.advance(65)
        let completed = try await context.recipient.finishBlindWorkout(id: current.summary.id)
        XCTAssertTrue(completed.isValid)
        return completed
    }
    private func json(_ state: BlindWorkoutState) throws -> String {
        try XCTUnwrap(String(data: JSONEncoder.supabase.encode(state), encoding: .utf8))
    }

    func testInvitationDTOContainsOnlyMetadataAndSendRetryDoesNotDuplicateIt() async throws {
        let context = context()
        let input = draft()
        let creator = try await context.creator.sendBlindWorkout(input)
        let retry = try await context.creator.sendBlindWorkout(input)
        XCTAssertEqual(creator.summary.id, retry.summary.id)
        XCTAssertTrue(creator.isValid)
        XCTAssertEqual(creator.visibleExercises.count, 6)
        XCTAssertNil(creator.activity)
        let received = try await context.recipient.blindWorkout(id: input.id)
        XCTAssertTrue(received.isValid)
        XCTAssertEqual(received.summary.focus, .push)
        XCTAssertEqual(received.summary.exerciseCount, 6)
        XCTAssertEqual(received.summary.estimatedDurationMinutes, 55)
        XCTAssertEqual(Set(received.summary.requiredEquipment), Set([.barbell, .dumbbell]))
        XCTAssertTrue(received.visibleExercises.isEmpty)
        let payload = try json(received)
        for exercise in library {
            XCTAssertFalse(payload.contains(exercise.name))
            XCTAssertFalse(payload.lowercased().contains(exercise.id.uuidString.lowercased()))
        }
        let invitations = try await context.recipient.blindWorkouts()
        let notices = try await context.recipient.blindNotifications()
        XCTAssertEqual(invitations.count, 1)
        XCTAssertEqual(notices.filter { $0.type == "blind_workout_received" }.count, 1)
        var changed = input; changed.estimatedDurationMinutes = 60
        await assertDenied { _ = try await context.creator.sendBlindWorkout(changed) }
    }

    func testAcceptedFriendAndExplicitEquipmentConfirmationAreRequired() async throws {
        let context = context()
        let input = draft()
        _ = try await context.creator.sendBlindWorkout(input)
        let stranger = DemoRepository(userID: UUID(), blindStorage: context.storage)
        await assertDenied { _ = try await stranger.blindWorkout(id: input.id) }
        await assertDenied { _ = try await stranger.copyBlindWorkout(id: input.id) }
        await assertDenied { _ = try await context.creator.respondToBlindWorkout(id: input.id, accept: true, equipmentConfirmed: true) }
        await assertDenied { _ = try await context.recipient.startBlindWorkout(id: input.id) }
        await assertDenied { _ = try await context.recipient.respondToBlindWorkout(id: input.id, accept: true, equipmentConfirmed: false) }
        let unaccepted = try await context.recipient.blindWorkout(id: input.id)
        XCTAssertEqual(unaccepted.summary.status, .sent)
        let declined = try await context.recipient.respondToBlindWorkout(id: input.id, accept: false, equipmentConfirmed: false)
        XCTAssertEqual(declined.summary.status, .declined)
        XCTAssertTrue(declined.visibleExercises.isEmpty)
        let senderNotices = try await context.creator.blindNotifications()
        XCTAssertTrue(senderNotices.isEmpty, "Declining must not create a pressure or failure notification")
    }

    func testServerReturnsOnlyFirstExerciseThenOneMorePerCompletedExercise() async throws {
        let context = context()
        let started = try await start(context)
        let id = started.summary.id
        XCTAssertEqual(started.visibleExercises.count, 1)
        XCTAssertEqual(started.visibleExercises.first?.exercise.name, library[0].name)
        XCTAssertEqual(started.visibleExercises.first?.sets.count, 3)
        XCTAssertTrue(started.visibleExercises.first?.sets.allSatisfy { $0.weight == nil && $0.reps == nil && !$0.completed } == true)
        let creator = try await context.creator.blindWorkout(id: id)
        let hidden = creator.visibleExercises[2]
        await assertDenied { _ = try await context.recipient.saveBlindWorkoutExercise(id: id, exerciseID: hidden.id, sets: [], complete: true) }
        await assertDenied { _ = try await context.recipient.copyBlindWorkout(id: id) }
        let first = try XCTUnwrap(started.currentExercise)
        let revealed = try await context.recipient.saveBlindWorkoutExercise(id: id, exerciseID: first.id, sets: [], complete: true)
        XCTAssertTrue(revealed.isValid)
        XCTAssertEqual(revealed.visibleExercises.count, 2)
        XCTAssertEqual(revealed.summary.completedExercises, 1)
        XCTAssertEqual(revealed.currentExercise?.exercise.name, library[1].name)
        let retry = try await context.recipient.saveBlindWorkoutExercise(id: id, exerciseID: first.id, sets: [], complete: true)
        XCTAssertEqual(retry.visibleExercises.count, 2)
        let payload = try json(retry)
        for exercise in library.dropFirst(2) { XCTAssertFalse(payload.contains(exercise.name)) }
    }

    func testTrackingUsesActualValuesAndKeepsThemPrivateFromCreator() async throws {
        let context = context()
        let started = try await start(context)
        let first = try XCTUnwrap(started.currentExercise)
        let input = WorkoutSetLog(id: UUID(), setNumber: 1, weight: 80, reps: 8, completed: true, completedAt: .distantPast)
        let saved = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [input], complete: false)
        let actual = try XCTUnwrap(saved.currentExercise?.sets.first)
        XCTAssertEqual(actual.weight, 80); XCTAssertEqual(actual.reps, 8)
        XCTAssertNotEqual(actual.id, input.id)
        XCTAssertEqual(actual.completedAt, context.clock.now())
        XCTAssertEqual(saved.visibleExercises.count, 1)
        context.clock.advance(1)
        let confirmed = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [input], complete: true)
        XCTAssertEqual(confirmed.visibleExercises.first?.sets.first?.id, actual.id)
        XCTAssertEqual(confirmed.visibleExercises.first?.sets.first?.completedAt, actual.completedAt)
        let sender = try await context.creator.blindWorkout(id: started.summary.id)
        XCTAssertTrue(sender.isValid)
        XCTAssertNil(sender.activity)
        XCTAssertTrue(sender.visibleExercises.allSatisfy { $0.sets.isEmpty && !$0.completed && $0.completedAt == nil })
        var changed = input; changed.reps = 10
        await assertDenied { _ = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [changed], complete: true) }
        let exact = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [input], complete: true)
        XCTAssertEqual(exact.visibleExercises.count, 2)
    }

    func testGenericCompletionAndLogPathsCannotSkipHiddenExercises() async throws {
        let context = context()
        _ = try await context.recipient.confirmWeeklyGoal(3, timezone: "UTC")
        let started = try await start(context)
        let activityID = try XCTUnwrap(started.summary.activityID)
        context.clock.advance(65)
        await assertDenied { _ = try await context.recipient.finishBlindWorkout(id: started.summary.id) }
        await assertDenied { _ = try await context.recipient.completeActivity(id: activityID, distanceMeters: nil) }
        let visibleOnly = try await context.recipient.workoutLog(activityID: activityID)
        XCTAssertEqual(visibleOnly.exercises.count, 1)
        XCTAssertEqual(visibleOnly.exercises.first?.id, started.currentExercise?.id)
        await assertDenied { _ = try await context.recipient.workoutPlan(id: started.summary.id) }
        let forged = WorkoutLog(activityID: activityID, planName: "Forged reveal", exercises: started.visibleExercises)
        await assertDenied { _ = try await context.recipient.saveWorkoutLog(forged) }
        let weekly = try await context.recipient.weeklyState(userID: momoID, timezone: "UTC")
        XCTAssertEqual(weekly.currentWeek?.completedWorkouts, 0)
        let stillLive = try await context.recipient.blindWorkout(id: started.summary.id)
        XCTAssertEqual(stillLive.summary.status, .live)
        XCTAssertEqual(stillLive.visibleExercises.count, 1)
    }

    func testFinishUsesOneActivityAndOneWeeklyCreditAndNotifiesCreatorOnce() async throws {
        let context = context()
        _ = try await context.recipient.confirmWeeklyGoal(3, timezone: "UTC")
        let started = try await start(context)
        let completed = try await finish(context, state: started)
        XCTAssertEqual(completed.summary.status, .completed)
        XCTAssertEqual(completed.summary.completedExercises, 6)
        XCTAssertEqual(completed.summary.activityID, started.summary.activityID)
        XCTAssertEqual(completed.activity?.status, .completed)
        XCTAssertTrue(completed.visibleExercises.allSatisfy { $0.completed && $0.sets.isEmpty })
        let retried = try await context.recipient.finishBlindWorkout(id: started.summary.id)
        XCTAssertEqual(retried.summary.completedAt, completed.summary.completedAt)
        let weekly = try await context.recipient.weeklyState(userID: momoID, timezone: "UTC")
        XCTAssertEqual(weekly.currentWeek?.completedWorkouts, 1)
        let notices = try await context.creator.blindNotifications()
        XCTAssertEqual(notices.filter { $0.type == "blind_workout_completed" }.count, 1)
        let history = try await context.recipient.recentActivities(userID: momoID)
        XCTAssertEqual(history.filter { $0.id == started.summary.activityID }.count, 1)
    }

    func testPlanningAndLiveRevealStatePersistAcrossRelaunch() async throws {
        let suite = "app.fyrup.tests.blind.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = context(suite: suite)
        let input = draft()
        _ = try await first.creator.sendBlindWorkout(input)
        _ = try await first.recipient.respondToBlindWorkout(id: input.id, accept: true, equipmentConfirmed: true)
        let planned = try await first.recipient.planBlindWorkout(id: input.id, startsAt: first.clock.now().addingTimeInterval(3600))
        XCTAssertTrue(planned.isValid)
        XCTAssertEqual(planned.activity?.status, .planned)
        XCTAssertTrue(planned.visibleExercises.isEmpty)
        let second = context(suite: suite, clock: first.clock)
        let restoredPlan = try await second.recipient.blindWorkout(id: input.id)
        XCTAssertEqual(restoredPlan.summary.status, .planned)
        let started = try await second.recipient.startBlindWorkout(id: input.id)
        XCTAssertEqual(started.summary.activityID, planned.summary.activityID)
        let exercise = try XCTUnwrap(started.currentExercise)
        _ = try await second.recipient.saveBlindWorkoutExercise(id: input.id, exerciseID: exercise.id, sets: [], complete: true)
        let third = context(suite: suite, clock: first.clock)
        let restored = try await third.recipient.blindWorkout(id: input.id)
        XCTAssertEqual(restored.summary.status, .live)
        XCTAssertEqual(restored.visibleExercises.count, 2)
        XCTAssertEqual(restored.summary.activityID, started.summary.activityID)
        await assertDenied {
            _ = try await third.recipient.startActivity(userID: self.momoID, sport: .running, subtype: nil, linkedActivityID: nil, plannedSessionID: nil)
        }
        let completed = try await finish(third, state: restored)
        XCTAssertEqual(completed.summary.status, .completed)
    }

    func testCancelDoesNotRevealFutureExercisesOrCreateCreditOrPressureNotifications() async throws {
        let context = context()
        _ = try await context.recipient.confirmWeeklyGoal(3, timezone: "UTC")
        let started = try await start(context)
        let first = try XCTUnwrap(started.currentExercise)
        _ = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [], complete: true)
        context.clock.advance(120)
        let cancelled = try await context.recipient.cancelBlindWorkout(id: started.summary.id)
        XCTAssertTrue(cancelled.isValid)
        XCTAssertEqual(cancelled.summary.status, .cancelled)
        XCTAssertEqual(cancelled.visibleExercises.count, 2)
        XCTAssertEqual(cancelled.activity?.status, .cancelled)
        await assertDenied { _ = try await context.recipient.copyBlindWorkout(id: started.summary.id) }
        await assertDenied { _ = try await context.recipient.finishBlindWorkout(id: started.summary.id) }
        let weekly = try await context.recipient.weeklyState(userID: momoID, timezone: "UTC")
        XCTAssertEqual(weekly.currentWeek?.completedWorkouts, 0)
        let creatorNotices = try await context.creator.blindNotifications()
        XCTAssertTrue(creatorNotices.isEmpty)
    }

    func testRevocationForbidsFurtherReadingButAlwaysAllowsSafeCancellation() async throws {
        let context = context()
        let started = try await start(context)
        let first = try XCTUnwrap(started.currentExercise)
        try await context.creator.block(momoID)
        await assertDenied { _ = try await context.recipient.blindWorkout(id: started.summary.id) }
        await assertDenied { _ = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: first.id, sets: [], complete: true) }
        await assertDenied { _ = try await context.creator.copyBlindWorkout(id: started.summary.id) }
        let cancelled = try await context.recipient.cancelBlindWorkout(id: started.summary.id)
        XCTAssertTrue(cancelled.isValid)
        XCTAssertEqual(cancelled.summary.status, .cancelled)
        XCTAssertTrue(cancelled.visibleExercises.isEmpty)
        let list = try await context.recipient.blindWorkouts()
        XCTAssertTrue(list.isEmpty)
        let notices = try await context.recipient.blindNotifications()
        XCTAssertTrue(notices.isEmpty)
    }

    func testCompletedCopyIsPrivateIndependentAndRetrySafeIncludingCustomExercises() async throws {
        let context = context()
        let custom = try await context.creator.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest, equipment: .machine))
        var input = draft(count: 1)
        input.exercises.append(WorkoutPlanExercise(exercise: custom, sortOrder: 1))
        input.exercises.append(WorkoutPlanExercise(exercise: custom, sortOrder: 2))
        let started = try await start(context, draft: input)
        _ = try await finish(context, state: started)
        let copy = try await context.recipient.copyBlindWorkout(id: input.id)
        XCTAssertEqual(copy.ownerID, momoID)
        XCTAssertEqual(copy.visibility, .private)
        XCTAssertNil(copy.copiedFromPlanID)
        XCTAssertNotEqual(copy.exercises[1].exercise.id, custom.id)
        XCTAssertEqual(copy.exercises[1].exercise.id, copy.exercises[2].exercise.id)
        XCTAssertEqual(copy.exercises[1].exercise.createdBy, momoID)
        let retry = try await context.recipient.copyBlindWorkout(id: input.id)
        XCTAssertEqual(retry.id, copy.id)
        var edited = custom; edited.name = "Renamed Original"
        _ = try await context.creator.saveExercise(edited)
        try await context.creator.archiveExercise(id: custom.id)
        let sentRetry = try await context.creator.sendBlindWorkout(input)
        XCTAssertEqual(sentRetry.summary.id, input.id, "The original send stays idempotent after a custom exercise is edited or archived")
        let independent = try await context.recipient.workoutPlan(id: copy.id)
        XCTAssertEqual(independent.exercises[1].exercise.name, "Prime Chest Press")
        let frozen = try await context.recipient.blindWorkout(id: input.id)
        XCTAssertEqual(frozen.visibleExercises[1].exercise.name, "Prime Chest Press")
        try await context.recipient.archiveWorkoutPlan(id: copy.id)
        let afterArchive = try await context.recipient.copyBlindWorkout(id: input.id)
        XCTAssertNotEqual(afterArchive.id, copy.id)
    }

    func testCanonicalLibraryValidationRejectsUnknownExercisesAndExtremePrescriptions() async throws {
        let context = context()
        var forged = draft(count: 1)
        forged.exercises[0].exercise.name = "Forged instruction instead of exercise"
        let canonical = try await context.creator.sendBlindWorkout(forged)
        XCTAssertEqual(canonical.visibleExercises.first?.exercise.name, library[0].name)
        var unknown = draft(count: 1); unknown.exercises[0].exercise.id = UUID()
        await assertDenied { _ = try await context.creator.sendBlindWorkout(unknown) }
        var tooMany = draft(count: 1); tooMany.exercises[0].targetSets = 7
        await assertDenied { _ = try await context.creator.sendBlindWorkout(tooMany) }
        var reps = draft(count: 1); reps.exercises[0].targetRepsMax = 999
        await assertDenied { _ = try await context.creator.sendBlindWorkout(reps) }
        var weight = draft(count: 1); weight.exercises[0].targetWeight = .infinity
        await assertDenied { _ = try await context.creator.sendBlindWorkout(weight) }
        let started = try await start(context, draft: draft(count: 1))
        let exercise = try XCTUnwrap(started.currentExercise)
        let excessive = WorkoutSetLog(setNumber: 1, weight: 80, reps: 31, completed: true)
        await assertDenied { _ = try await context.recipient.saveBlindWorkoutExercise(id: started.summary.id, exerciseID: exercise.id, sets: [excessive], complete: true) }
        let body = BlindExerciseUpdateRequest(id: started.summary.id, exerciseID: exercise.id, sets: [], complete: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.supabase.encode(body)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["p_id", "p_exercise_id", "p_sets", "p_complete"]))
        XCTAssertEqual((object["p_sets"] as? [Any])?.count, 0)
    }

    func testNotificationOptOutAndCorruptPersistenceRemainRespected() async throws {
        let context = context()
        var recipientPreferences = NotificationPreferences.standard; recipientPreferences.invitations = false
        var creatorPreferences = NotificationPreferences.standard; creatorPreferences.reactions = false
        try await context.storage.setNotificationPreferences(recipientPreferences, userID: momoID)
        try await context.storage.setNotificationPreferences(creatorPreferences, userID: maxID)
        let started = try await start(context, draft: draft(count: 1))
        _ = try await finish(context, state: started)
        let received = try await context.recipient.blindNotifications()
        let completed = try await context.creator.blindNotifications()
        XCTAssertTrue(received.isEmpty); XCTAssertTrue(completed.isEmpty)
        let suite = "app.fyrup.tests.blind.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("invalid blind workout state".utf8)
        defaults.set(corrupt, forKey: "fyrup.demo.blind-workouts.v1")
        let broken = self.context(suite: suite)
        await assertDenied { _ = try await broken.recipient.blindWorkouts() }
        XCTAssertEqual(defaults.data(forKey: "fyrup.demo.blind-workouts.v1"), corrupt)
    }

    func testCompletedParticipantsCanReactPrivatelyWithDeduplicatedMutedFeedback() async throws {
        let context = context()
        let started = try await start(context, draft: draft(count: 1))
        await assertDenied { _ = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: .fire) }
        _ = try await finish(context, state: started)
        let reacted = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: .fire)
        XCTAssertTrue(reacted.isValid)
        XCTAssertEqual(reacted.myReaction, .fire)
        _ = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: .fire)
        _ = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: .strong)
        let notices = try await context.creator.blindNotifications()
        XCTAssertEqual(notices.filter { $0.type == "blind_reaction" }.count, 1)
        var muted = NotificationPreferences.standard; muted.reactions = false
        try await context.storage.setNotificationPreferences(muted, userID: momoID)
        let reply = try await context.creator.reactToBlindWorkout(id: started.summary.id, reaction: .applause)
        XCTAssertTrue(reply.isValid)
        XCTAssertNil(reply.activity)
        XCTAssertTrue(reply.visibleExercises.allSatisfy { $0.sets.isEmpty })
        XCTAssertEqual(reply.reactionCounts?.reduce(0) { $0 + $1.count }, 2)
        let mutedNotices = try await context.recipient.blindNotifications()
        XCTAssertTrue(mutedNotices.filter { $0.type == "blind_reaction" }.isEmpty)
        let removed = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: nil)
        XCTAssertNil(removed.myReaction)
        XCTAssertEqual(removed.reactionCounts?.reduce(0) { $0 + $1.count }, 1)
        let body = try JSONEncoder.supabase.encode(BlindReactionRequest(id: started.summary.id, reaction: nil))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertTrue(object["p_reaction"] is NSNull)
        try await context.creator.block(momoID)
        await assertDenied { _ = try await context.recipient.reactToBlindWorkout(id: started.summary.id, reaction: .fire) }
    }

    func testCreatorDeletionDoesNotTurnUnfinishedBlindActivityIntoOrdinaryCompletion() async throws {
        let context = context()
        let started = try await start(context, draft: draft(count: 1))
        let activityID = try XCTUnwrap(started.summary.activityID)
        try await context.creator.deleteAccount()
        await assertDenied { _ = try await context.recipient.blindWorkout(id: started.summary.id) }
        await assertDenied { _ = try await context.recipient.completeActivity(id: activityID, distanceMeters: nil) }
        try await context.recipient.cancelActivity(id: activityID)
        let restored = try await context.storage.activities(userID: momoID)
        XCTAssertEqual(restored.first { $0.id == activityID }?.status, .cancelled)
    }
}

private final class BlindRepositoryTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ date: Date) { value = date }
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; value = value.addingTimeInterval(seconds) }
}
