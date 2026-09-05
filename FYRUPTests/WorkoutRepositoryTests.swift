import XCTest
@testable import FYRUP

@MainActor
final class WorkoutRepositoryTests: XCTestCase {
    private let momoID = DemoRepository.defaultUserID
    private let maxID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private var library: [GymExercise] {
        let names = ["Bankdrücken", "Schrägbank Kurzhantel", "Schulterdrücken", "Seitheben", "Trizeps Pushdown", "Overhead Extension"]
        return names.enumerated().map { index, name in
            GymExercise(id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1))!,
                        name: name, primaryMuscle: index < 2 ? .chest : (index < 4 ? .shoulders : .triceps), isCustom: false)
        }
    }

    private func makePlan(in repository: DemoRepository, ownerID: UUID? = nil) async throws -> WorkoutPlan {
        let exercises = library.enumerated().map { index, exercise in
            WorkoutPlanExercise(exercise: exercise, sortOrder: index, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, targetWeight: index == 0 ? 80 : nil)
        }
        return try await repository.saveWorkoutPlan(WorkoutPlan(ownerID: ownerID ?? momoID, name: "Push Day", category: "Push", exercises: exercises))
    }

    private func assertDenied(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("This operation must fail", file: file, line: line) }
        catch { XCTAssertNotNil(error as? AppError, file: file, line: line) }
    }

    func testPlanCustomExerciseAndFavoritesSurviveRestartButRemainAccountScoped() async throws {
        let suite = "FYRUP.WorkoutRepositoryTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let original = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        var plan = try await makePlan(in: original)
        let custom = try await original.saveExercise(GymExercise(name: "  Prime Chest Press  ", primaryMuscle: .chest,
                                                                secondaryMuscles: [.triceps, .shoulders], equipment: .machine))
        plan.exercises.append(WorkoutPlanExercise(exercise: custom, sortOrder: 99))
        plan = try await original.saveWorkoutPlan(plan)
        try await original.favoriteExercise(id: custom.id, favorite: true)

        let restoredStorage = DemoWorkoutStorage(persistenceSuiteName: suite, library: library)
        let restored = DemoRepository(workoutStorage: restoredStorage)
        let restoredPlans = try await restored.workoutPlans(ownerID: nil)
        let restoredExercises = try await restored.exercises()
        let restoredFavorites = try await restored.exerciseFavorites()
        XCTAssertEqual(restoredPlans, [plan])
        XCTAssertEqual(restoredPlans.first?.exercises.prefix(6).map(\.exercise.name), library.map(\.name))
        XCTAssertEqual(restoredPlans.first?.exercises.map(\.sortOrder), Array(0...6))
        XCTAssertTrue(restoredExercises.contains { $0.name == "Prime Chest Press" && $0.matches(query: "prime chest") })
        XCTAssertEqual(restoredFavorites, [custom.id])

        let max = DemoRepository(userID: maxID, workoutStorage: restoredStorage)
        let maxPlans = try await max.workoutPlans(ownerID: nil)
        let maxExercises = try await max.exercises()
        let maxFavorites = try await max.exerciseFavorites()
        XCTAssertTrue(maxPlans.isEmpty)
        XCTAssertFalse(maxExercises.contains { $0.id == custom.id })
        XCTAssertTrue(maxFavorites.isEmpty)
        await assertDenied { _ = try await max.workoutPlan(id: plan.id) }
    }

    func testDefaultDemoInstancesNeverReuseOtherTestPlans() async throws {
        let first = DemoRepository(workoutStorage: DemoWorkoutStorage(library: library))
        _ = try await makePlan(in: first)
        let second = DemoRepository(workoutStorage: DemoWorkoutStorage(library: library))
        let plans = try await second.workoutPlans(ownerID: nil)
        XCTAssertTrue(plans.isEmpty)
    }

    func testUnreadablePersistenceIsReportedWithoutOverwritingSavedData() async throws {
        let suite = "FYRUP.WorkoutCorruptionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let existing = Data("unreadable-demo-data".utf8)
        defaults.set(existing, forKey: "fyrup.demo.workouts.v1")
        let repository = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        await assertDenied { _ = try await repository.workoutPlans(ownerID: nil) }
        await assertDenied { _ = try await repository.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest)) }
        XCTAssertEqual(defaults.data(forKey: "fyrup.demo.workouts.v1"), existing)
    }

    func testSchedulingRPCIncludesRequiredNullableArguments() throws {
        let request = PlanWorkoutRequest(plan: UUID(), startsAt: Date(timeIntervalSince1970: 1_800_000_000), duration: 60,
                                         note: nil, place: nil, friendsCanJoin: true, friends: [maxID])
        let data = try JSONEncoder.supabase.encode(request)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(body.keys), Set(["p_plan", "p_starts_at", "p_duration", "p_note", "p_place", "p_friends_can_join", "p_friends"]))
        XCTAssertTrue(body["p_note"] is NSNull)
        XCTAssertTrue(body["p_place"] is NSNull)
        XCTAssertEqual(body["p_duration"] as? Int, 60)
        XCTAssertEqual((body["p_friends"] as? [String])?.count, 1)
    }

    func testReorderingAndRemovingExercisesPersistsCanonicalPositions() async throws {
        let repository = DemoRepository(workoutStorage: DemoWorkoutStorage(library: library))
        var plan = try await makePlan(in: repository)
        plan.exercises.reverse()
        plan.exercises.remove(at: 2)
        let saved = try await repository.saveWorkoutPlan(plan)
        let restored = try await repository.workoutPlan(id: saved.id)
        XCTAssertEqual(restored.exercises.map(\.exercise.name), plan.exercises.map(\.exercise.name))
        XCTAssertEqual(restored.exercises.map(\.sortOrder), Array(0..<5))
    }

    func testTrackingPersistsActualSetsAndFrozenSnapshotsThroughCompletionAndRestart() async throws {
        let suite = "FYRUP.WorkoutTrackingTests.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let repository = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        let custom = try await repository.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest))
        var plan = try await makePlan(in: repository)
        plan.exercises.append(WorkoutPlanExercise(exercise: custom))
        plan = try await repository.saveWorkoutPlan(plan)
        let activity = try await repository.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        var log = try await repository.workoutLog(activityID: activity.id)
        XCTAssertEqual(log.exercises[0].targetWeight, 80)
        XCTAssertTrue(log.exercises.flatMap(\.sets).allSatisfy { $0.weight == nil && $0.reps == nil && !$0.completed })
        for index in 0..<3 {
            log.exercises[0].sets[index].weight = 80
            log.exercises[0].sets[index].reps = index == 2 ? 7 : 8
            log.exercises[0].sets[index].completed = true
        }
        log.exercises[0].completed = true
        let saved = try await repository.saveWorkoutLog(log)
        let retried = try await repository.saveWorkoutLog(saved)
        XCTAssertEqual(saved.exercises[0].sets, retried.exercises[0].sets, "A retry must preserve set IDs and completion times")
        _ = try await repository.completeActivity(id: activity.id, distanceMeters: nil)
        var renamed = custom; renamed.name = "A new machine name"
        _ = try await repository.saveExercise(renamed)
        plan.name = "A renamed template"
        _ = try await repository.saveWorkoutPlan(plan)
        try await repository.archiveExercise(id: custom.id)

        let restored = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        let history = try await restored.workoutLog(activityID: activity.id)
        XCTAssertEqual(history.planName, "Push Day")
        XCTAssertEqual(history.exercises.last?.exercise.name, "Prime Chest Press")
        XCTAssertEqual(history.exercises[0].sets.map(\.weight), [80, 80, 80])
        XCTAssertEqual(history.exercises[0].sets.map(\.reps), [8, 8, 7])
        XCTAssertEqual(history.completedExercises, 1)
        XCTAssertEqual(history.completedSets, 3)
        let recent = try await restored.recentActivities(userID: momoID)
        XCTAssertTrue(recent.contains { $0.id == activity.id && $0.status == .completed })
    }

    func testSharedCopiesOwnTheirCustomExercisesAndDoNotChangeOriginal() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let custom = try await momo.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest, secondaryMuscles: [.shoulders, .triceps]))
        let plan = try await momo.saveWorkoutPlan(WorkoutPlan(ownerID: momoID, name: "Private Push", exercises: [WorkoutPlanExercise(exercise: custom), WorkoutPlanExercise(exercise: custom)]))
        try await momo.shareWorkoutPlan(id: plan.id, friendIDs: [maxID, maxID])
        try await momo.shareWorkoutPlan(id: plan.id, friendIDs: [maxID])
        let notifications = try await max.notifications()
        XCTAssertEqual(notifications.filter { $0.type == "workout_plan_shared" }.count, 1)
        let shared = try await max.workoutPlan(id: plan.id)
        XCTAssertEqual(shared.exercises.first?.exercise.name, "Prime Chest Press")
        let maxLibraryBeforeCopy = try await max.exercises()
        XCTAssertFalse(maxLibraryBeforeCopy.contains { $0.id == custom.id }, "Explicit plan access must not expose the creator's private library")
        var copy = try await max.copyWorkoutPlan(id: plan.id, requestID: UUID())
        XCTAssertNotEqual(copy.id, plan.id)
        XCTAssertEqual(copy.ownerID, maxID)
        XCTAssertEqual(copy.visibility, .private)
        XCTAssertEqual(copy.copiedFromPlanID, plan.id)
        XCTAssertNotEqual(copy.exercises[0].exercise.id, custom.id)
        XCTAssertEqual(copy.exercises[0].exercise.id, copy.exercises[1].exercise.id, "A repeated custom exercise is copied only once")
        XCTAssertTrue(Set(copy.exercises.map(\.id)).isDisjoint(with: Set(plan.exercises.map(\.id))))
        var changedExercise = copy.exercises[0].exercise
        changedExercise.name = "Max Chest Press"
        _ = try await max.saveExercise(changedExercise)
        copy.name = "Max Push"; copy.exercises[0].targetSets = 5
        _ = try await max.saveWorkoutPlan(copy)
        let untouched = try await momo.workoutPlan(id: plan.id)
        XCTAssertEqual(untouched.name, "Private Push")
        XCTAssertEqual(untouched.exercises[0].targetSets, 3)
        XCTAssertEqual(untouched.exercises[0].exercise.name, "Prime Chest Press")
        await assertDenied { _ = try await max.saveExercise(custom) }
        await assertDenied { _ = try await max.saveWorkoutPlan(plan) }
    }

    func testInvitationPreviewAndAcceptedCoTrainingHaveIndependentPrivateLogs() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let plan = try await makePlan(in: momo)
        try await momo.planWorkout(planID: plan.id, startsAt: Date().addingTimeInterval(3600), duration: 60,
                                   note: "Together", placeName: "FYRUP Gym", friendsCanJoin: true, friendIDs: [maxID])
        let invitations = try await max.invitations()
        let invitation = try XCTUnwrap(invitations.first)
        XCTAssertEqual(invitation.session.workoutPlanID, plan.id)
        XCTAssertEqual(invitation.session.exerciseCount, 6)
        XCTAssertEqual(invitation.session.durationMinutes, 60)
        XCTAssertEqual(invitation.status, .pending)
        let preview = try await max.workoutPlan(id: plan.id)
        XCTAssertEqual(preview.exercises.count, 6, "An ordinary invited plan is visible before RSVP")
        await assertDenied { _ = try await max.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: invitation.id) }
        try await max.respondToInvitation(sessionID: invitation.id, status: .accepted)
        let planned = try await max.today(userID: maxID)
        XCTAssertEqual(planned.0?.workoutPlanID, plan.id)
        let hostActivity = try await momo.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: invitation.id)
        // Exercise the pre-existing startActivity path too: it must never bypass workout logs.
        let guestActivity = try await max.startActivity(userID: maxID, sport: .gym, subtype: plan.name, linkedActivityID: hostActivity.id, plannedSessionID: invitation.id)
        XCTAssertNotEqual(hostActivity.id, guestActivity.id)
        XCTAssertEqual(guestActivity.workoutPlanID, plan.id)
        var hostLog = try await momo.workoutLog(activityID: hostActivity.id)
        hostLog.exercises[0].completed = true
        _ = try await momo.saveWorkoutLog(hostLog)
        let guestLog = try await max.workoutLog(activityID: guestActivity.id)
        XCTAssertEqual(guestLog.completedExercises, 0)
        XCTAssertTrue(Set(hostLog.exercises.map(\.id)).isDisjoint(with: Set(guestLog.exercises.map(\.id))))
        await assertDenied { _ = try await max.workoutLog(activityID: hostActivity.id) }
        await assertDenied { _ = try await max.saveWorkoutLog(hostLog) }
    }

    func testFriendVisibilityAndRevocationApplyToFutureReadsAndStarts() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let stranger = DemoRepository(userID: UUID(), workoutStorage: storage)
        var plan = try await makePlan(in: momo)
        let privateList = try await max.workoutPlans(ownerID: momoID)
        XCTAssertTrue(privateList.isEmpty)
        plan.visibility = .friends
        plan = try await momo.saveWorkoutPlan(plan)
        let friendList = try await max.workoutPlans(ownerID: momoID)
        let strangerList = try await stranger.workoutPlans(ownerID: momoID)
        XCTAssertEqual(friendList.map(\.id), [plan.id])
        XCTAssertTrue(strangerList.isEmpty)
        await assertDenied { _ = try await stranger.workoutPlan(id: plan.id) }
        try await momo.block(maxID)
        let revokedList = try await max.workoutPlans(ownerID: momoID)
        XCTAssertTrue(revokedList.isEmpty)
        await assertDenied { _ = try await max.workoutPlan(id: plan.id) }
        await assertDenied { _ = try await max.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil) }
    }

    func testArchiveHidesFromSelectionButPreservesExistingPlanAndHistory() async throws {
        let repository = DemoRepository(workoutStorage: DemoWorkoutStorage(library: library))
        let custom = try await repository.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest))
        let plan = try await repository.saveWorkoutPlan(WorkoutPlan(ownerID: momoID, name: "Push", exercises: [WorkoutPlanExercise(exercise: custom)]))
        let activity = try await repository.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        _ = try await repository.completeActivity(id: activity.id, distanceMeters: nil)
        try await repository.favoriteExercise(id: custom.id, favorite: true)
        try await repository.archiveExercise(id: custom.id)
        let exercises = try await repository.exercises()
        let favorites = try await repository.exerciseFavorites()
        XCTAssertFalse(exercises.contains { $0.id == custom.id })
        XCTAssertFalse(favorites.contains(custom.id))
        _ = try await repository.saveWorkoutPlan(plan)
        let newPlan = WorkoutPlan(ownerID: momoID, name: "New Push", exercises: [WorkoutPlanExercise(exercise: custom)])
        await assertDenied { _ = try await repository.saveWorkoutPlan(newPlan) }
        try await repository.archiveWorkoutPlan(id: plan.id)
        let plans = try await repository.workoutPlans(ownerID: nil)
        XCTAssertFalse(plans.contains { $0.id == plan.id })
        let history = try await repository.workoutLog(activityID: activity.id)
        XCTAssertEqual(history.exercises.first?.exercise.name, "Prime Chest Press")
        await assertDenied { _ = try await repository.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil) }
    }

    func testSingleLiveConstraintAndCancelledLogsSurviveRestart() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let first = DemoRepository(workoutStorage: storage)
        let plan = try await makePlan(in: first)
        let activity = try await first.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        let restarted = DemoRepository(workoutStorage: storage)
        await assertDenied { _ = try await restarted.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil) }
        await assertDenied { _ = try await restarted.startActivity(userID: momoID, sport: .running, subtype: nil, linkedActivityID: nil, plannedSessionID: nil) }
        let log = try await restarted.workoutLog(activityID: activity.id)
        try await restarted.cancelActivity(id: activity.id)
        await assertDenied { _ = try await restarted.saveWorkoutLog(log) }
        let next = try await restarted.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        XCTAssertNotEqual(next.id, activity.id)
    }

    func testLogSaveRejectsTamperedIDsButNeverTrustsClientSnapshots() async throws {
        let repository = DemoRepository(workoutStorage: DemoWorkoutStorage(library: library))
        let plan = try await makePlan(in: repository)
        let activity = try await repository.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        let initial = try await repository.workoutLog(activityID: activity.id)
        var forged = initial
        forged.planName = "Forged"; forged.exercises[0].exercise.name = "Forged"
        forged.exercises[0].targetSets = 29; forged.exercises[0].targetWeight = 999
        forged.exercises[0].completed = true; forged.exercises[0].completedAt = .distantPast
        let saved = try await repository.saveWorkoutLog(forged)
        XCTAssertEqual(saved.planName, initial.planName)
        XCTAssertEqual(saved.exercises[0].exercise, initial.exercises[0].exercise)
        XCTAssertEqual(saved.exercises[0].targetSets, initial.exercises[0].targetSets)
        XCTAssertEqual(saved.exercises[0].targetWeight, initial.exercises[0].targetWeight)
        XCTAssertNotEqual(saved.exercises[0].completedAt, .distantPast)
        forged = initial; forged.exercises[0].id = UUID()
        await assertDenied { _ = try await repository.saveWorkoutLog(forged) }
        forged = initial; forged.exercises.removeLast()
        await assertDenied { _ = try await repository.saveWorkoutLog(forged) }
        forged = initial; forged.exercises[0].sets[0].weight = -1
        await assertDenied { _ = try await repository.saveWorkoutLog(forged) }
        forged = initial; forged.exercises[0].sets[1].setNumber = forged.exercises[0].sets[0].setNumber
        await assertDenied { _ = try await repository.saveWorkoutLog(forged) }
    }

    func testDecliningOrCancellingPlanRemovesStalePlannedActivity() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let plan = try await makePlan(in: momo)
        try await momo.planWorkout(planID: plan.id, startsAt: Date().addingTimeInterval(3600), duration: 60,
                                   note: nil, placeName: nil, friendsCanJoin: true, friendIDs: [maxID])
        let invites = try await max.invitations()
        let invitation = try XCTUnwrap(invites.first)
        try await max.respondToInvitation(sessionID: invitation.id, status: .accepted)
        _ = try await max.today(userID: maxID)
        try await max.respondToInvitation(sessionID: invitation.id, status: .declined)
        let afterDecline = try await max.today(userID: maxID)
        XCTAssertNil(afterDecline.0)
        await assertDenied { _ = try await max.workoutPlan(id: plan.id) }
        try await max.respondToInvitation(sessionID: invitation.id, status: .accepted)
        try await momo.cancelPlannedSession(sessionID: invitation.id)
        let afterCancel = try await max.today(userID: maxID)
        XCTAssertNil(afterCancel.0)
    }

    func testAccountDeletionDoesNotDeleteAnIndependentRecipientsCopy() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let custom = try await momo.saveExercise(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest))
        let plan = try await momo.saveWorkoutPlan(WorkoutPlan(ownerID: momoID, name: "Push", exercises: [WorkoutPlanExercise(exercise: custom)]))
        try await momo.shareWorkoutPlan(id: plan.id, friendIDs: [maxID])
        let copy = try await max.copyWorkoutPlan(id: plan.id, requestID: UUID())
        try await momo.deleteAccount()
        let surviving = try await max.workoutPlan(id: copy.id)
        XCTAssertEqual(surviving.exercises[0].exercise.name, "Prime Chest Press")
        XCTAssertEqual(surviving.exercises[0].exercise.createdBy, maxID)
        let deleted = try await momo.workoutPlans(ownerID: nil)
        XCTAssertTrue(deleted.isEmpty)
    }

    func testCopyRequestBodyRequiresBothSourceAndStableRequestID() throws {
        let source = UUID(); let request = UUID()
        let data = try JSONEncoder().encode(CopyWorkoutPlanRequest(id: source, requestID: request))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(body, ["p_id": source.uuidString, "p_request_id": request.uuidString])
    }

    func testCopyRetryKeepsPlanAndCustomIDsAcrossRestart() async throws {
        let suite = "FYRUP.CopyRetry.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let storage = DemoWorkoutStorage(persistenceSuiteName: suite, library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let custom = try await momo.saveExercise(GymExercise(name: "Custom Press", primaryMuscle: .chest))
        let source = try await momo.saveWorkoutPlan(WorkoutPlan(ownerID: momoID, name: "Shared", exercises: [WorkoutPlanExercise(exercise: custom), WorkoutPlanExercise(exercise: custom)]))
        try await momo.shareWorkoutPlan(id: source.id, friendIDs: [maxID])
        let request = UUID()
        let first = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        let restored = DemoRepository(userID: maxID, workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        let retry = try await restored.copyWorkoutPlan(id: source.id, requestID: request)
        XCTAssertEqual(retry, first); XCTAssertEqual(retry.copyRequestID, request)
        XCTAssertEqual(retry.exercises[0].exercise.id, retry.exercises[1].exercise.id)
        let plans = try await restored.workoutPlans(ownerID: nil)
        let customCopies = try await restored.exercises().filter(\.isCustom)
        XCTAssertEqual(plans.map(\.id), [first.id]); XCTAssertEqual(customCopies.count, 1)
        let intentional = try await restored.copyWorkoutPlan(id: source.id, requestID: UUID())
        XCTAssertNotEqual(intentional.id, first.id)
        XCTAssertNotEqual(intentional.exercises[0].exercise.id, first.exercises[0].exercise.id)
    }

    func testCopyRetryAfterRevocationReturnsOnlyAlreadyOwnedCopy() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let source = try await makePlan(in: momo)
        try await momo.shareWorkoutPlan(id: source.id, friendIDs: [maxID])
        let request = UUID(); let first = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        try await momo.block(maxID)
        let retry = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        XCTAssertEqual(first, retry)
        await assertDenied { _ = try await max.copyWorkoutPlan(id: source.id, requestID: UUID()) }
        let stranger = DemoRepository(userID: UUID(), workoutStorage: storage)
        await assertDenied { _ = try await stranger.copyWorkoutPlan(id: source.id, requestID: request) }
    }

    func testCopyRequestCannotChangeSourceAndIsAccountScoped() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let source = try await makePlan(in: momo)
        let second = try await makePlan(in: momo)
        try await momo.shareWorkoutPlan(id: source.id, friendIDs: [maxID])
        let request = UUID()
        let first = try await momo.copyWorkoutPlan(id: source.id, requestID: request)
        await assertDenied { _ = try await momo.copyWorkoutPlan(id: second.id, requestID: request) }
        let otherAccount = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        XCTAssertNotEqual(first.id, otherAccount.id)
        XCTAssertEqual(otherAccount.ownerID, maxID)
        try await max.archiveWorkoutPlan(id: otherAccount.id)
        await assertDenied { _ = try await max.copyWorkoutPlan(id: source.id, requestID: request) }
        let visible = try await max.workoutPlans(ownerID: nil)
        XCTAssertTrue(visible.isEmpty, "Retry must not replace an archived receipt")
    }

    func testCopyRetrySurvivesSourceDeletionAndDoesNotResurrectAccountReceipts() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        let source = try await makePlan(in: momo)
        try await momo.shareWorkoutPlan(id: source.id, friendIDs: [maxID])
        let request = UUID(); let first = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        try await momo.deleteAccount()
        let surviving = try await max.copyWorkoutPlan(id: source.id, requestID: request)
        XCTAssertEqual(surviving.id, first.id); XCTAssertNil(surviving.copiedFromPlanID)
        XCTAssertEqual(surviving.copyRequestID, request)
        try await max.deleteAccount()
        await assertDenied { _ = try await max.copyWorkoutPlan(id: source.id, requestID: request) }
    }

    func testLegacyDemoPersistenceWithoutCopyRequestsStillLoads() async throws {
        let suite = "FYRUP.CopyLegacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        let source = try await makePlan(in: first)
        let original = try XCTUnwrap(defaults.data(forKey: "fyrup.demo.workouts.v1"))
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        legacy.removeValue(forKey: "copyRequests")
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "fyrup.demo.workouts.v1")
        let restored = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite, library: library))
        let copy = try await restored.copyWorkoutPlan(id: source.id, requestID: UUID())
        XCTAssertEqual(copy.ownerID, momoID); XCTAssertNotEqual(copy.id, source.id)
    }

    func testCopyErrorMapperDistinguishesRequestMismatchAndRemovedReceipt() {
        for message in ["copy_request_mismatch", "copy_result_unavailable", "invalid_copy_request"] {
            let error = SupabaseRESTClient.appError(status: 400, code: "P0001", message: message)
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotEqual(error.errorDescription, AppError.server.errorDescription)
        }
    }

    func testPauseIsIdempotentSurvivesRestartAndCannotChangeCompletedOrForeignActivity() async throws {
        let storage = DemoWorkoutStorage(library: library)
        let momo = DemoRepository(workoutStorage: storage)
        let plan = try await makePlan(in: momo)
        let activity = try await momo.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        let paused = try await momo.setActivityPaused(id: activity.id, paused: true)
        let pausedAgain = try await momo.setActivityPaused(id: activity.id, paused: true)
        XCTAssertNotNil(paused.pausedAt)
        XCTAssertEqual(paused.pausedAt, pausedAgain.pausedAt)
        XCTAssertEqual(paused.duration, pausedAgain.duration)
        let restored = DemoRepository(workoutStorage: storage)
        let feed = try await restored.today(userID: momoID)
        XCTAssertEqual(feed.0?.pausedAt, paused.pausedAt)
        let resumed = try await restored.setActivityPaused(id: activity.id, paused: false)
        let resumedAgain = try await restored.setActivityPaused(id: activity.id, paused: false)
        XCTAssertNil(resumed.pausedAt)
        XCTAssertEqual(resumed.pausedSeconds, resumedAgain.pausedSeconds)
        _ = try await restored.setActivityPaused(id: activity.id, paused: true)
        let finished = try await restored.completeActivity(id: activity.id, distanceMeters: nil)
        XCTAssertNil(finished.pausedAt)
        XCTAssertGreaterThanOrEqual(finished.pausedSeconds ?? 0, 0)
        await assertDenied { _ = try await restored.setActivityPaused(id: activity.id, paused: true) }
        let max = DemoRepository(userID: maxID, workoutStorage: storage)
        await assertDenied { _ = try await max.setActivityPaused(id: activity.id, paused: false) }
    }
}
