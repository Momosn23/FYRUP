import XCTest
@testable import FYRUP

@MainActor
final class CallMyShotRepositoryTests: XCTestCase {
    private let momoID = DemoRepository.defaultUserID
    private let maxID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let noon = Date(timeIntervalSince1970: 1_788_609_600)

    private func repository(_ clock: ShotRepositoryClock, storage: DemoWeeklyFlameStorage,
                            userID: UUID = DemoRepository.defaultUserID) -> DemoRepository {
        DemoRepository(startsWithoutProfile: true, userID: userID, weeklyStorage: storage, now: { clock.now() })
    }
    private func state(_ repository: DemoRepository, userID: UUID? = nil) async throws -> WeeklyFlameState {
        let value = try await repository.weeklyState(userID: userID ?? momoID, timezone: userID == nil ? "UTC" : nil)
        XCTAssertTrue(value.isValid)
        return value
    }
    private func callCurrentWeek(_ repository: DemoRepository) async throws -> WeeklyCommitment {
        // Mirrors viewing a fresh goal and explicitly confirming that period.
        // Boundary tests pass a previously captured ID directly instead.
        let current = try await state(repository)
        let week = try XCTUnwrap(current.currentWeek)
        return try await repository.callMyShot(expectedWeekID: week.id)
    }
    @discardableResult
    private func complete(_ repository: DemoRepository, clock: ShotRepositoryClock, seconds: TimeInterval = 60) async throws -> Activity {
        let activity = try await repository.startActivity(userID: momoID, sport: .gym, subtype: nil,
                                                         linkedActivityID: nil, plannedSessionID: nil)
        clock.advance(seconds)
        return try await repository.completeActivity(id: activity.id, distanceMeters: nil)
    }
    private func assertDenied(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("This request must be rejected", file: file, line: line) }
        catch { XCTAssertNotNil(error as? AppError, file: file, line: line) }
    }

    func testReactionRPCExplicitlyEncodesNullWithoutClientWeekGoalOrSuccess() throws {
        let callBody = try JSONEncoder.supabase.encode(CallMyShotRequest(expectedWeekID: momoID))
        let callJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: callBody) as? [String: Any])
        XCTAssertEqual(Set(callJSON.keys), Set(["p_expected_week"]))
        XCTAssertEqual(callJSON["p_expected_week"] as? String, momoID.uuidString)
        let body = try JSONEncoder.supabase.encode(ShotReactionRequest(commitmentID: maxID, reaction: nil))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["p_commitment", "p_reaction"]))
        XCTAssertTrue(json["p_reaction"] is NSNull)
        let selected = try JSONEncoder.supabase.encode(ShotReactionRequest(commitmentID: maxID, reaction: .target))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: selected) as? [String: Any])
        XCTAssertEqual(value["p_reaction"] as? String, "🎯")
        XCTAssertEqual(Set(ShotReaction.allCases.map(\.rawValue)), Set(["🔥", "🎯", "💪"]))
    }

    func testExplicitConfirmedGoalIsRequiredAndNoCreditIsCreatedByCalling() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        await assertDenied { _ = try await momo.callMyShot(expectedWeekID: UUID()) }
        let confirmed = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        let current = try await state(momo)
        XCTAssertTrue(called.isValid)
        XCTAssertEqual(called.weekID, confirmed.currentWeek?.id)
        XCTAssertEqual(called.weeklyGoal, 4)
        XCTAssertEqual(called.calledAt, clock.now())
        XCTAssertFalse(called.achieved)
        XCTAssertNil(called.achievedAt)
        XCTAssertEqual(current.currentWeek?.completedWorkouts, 0)
        XCTAssertEqual(current.currentWeek?.commitment, called)
        XCTAssertFalse(current.currentWeek?.flameEarned ?? true)
    }

    func testCallAtTwoOfFourUsesFrozenTargetAndPendingChangesCannotRewriteIt() async throws {
        let clock = ShotRepositoryClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        _ = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        _ = try await complete(momo, clock: clock)
        _ = try await complete(momo, clock: clock)
        let called = try await callCurrentWeek(momo)
        _ = try await momo.setNextWeeklyGoal(7)
        let current = try await state(momo)
        XCTAssertEqual(current.currentWeek?.completedWorkouts, 2)
        XCTAssertEqual(current.currentWeek?.weeklyGoal, 4)
        XCTAssertEqual(current.nextWeeklyGoal, 7)
        XCTAssertEqual(current.currentWeek?.commitment, called)
        await assertDenied { _ = try await self.callCurrentWeek(momo) }
    }

    func testCompletionAtomicallyEarnsFlameAndShotWithSameTimestampAndRetriesDoNotDuplicate() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let exercise = GymExercise(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                                   name: "Bankdrücken", primaryMuscle: .chest, equipment: .barbell, isCustom: false)
        let workouts = DemoWorkoutStorage(library: [exercise])
        let blind = DemoBlindWorkoutStorage(now: { clock.now() })
        let momo = DemoRepository(startsWithoutProfile: true, workoutStorage: workouts, weeklyStorage: storage,
                                  blindStorage: blind, now: { clock.now() })
        let max = DemoRepository(startsWithoutProfile: true, userID: maxID, workoutStorage: workouts, weeklyStorage: storage,
                                 blindStorage: blind, now: { clock.now() })
        _ = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        let draft = BlindWorkoutDraft(recipientID: momoID, title: "Push von Max", focus: .push,
                                      exercises: [WorkoutPlanExercise(exercise: exercise, sortOrder: 0, targetSets: 1,
                                                                     targetRepsMin: 8, targetRepsMax: 12)])
        _ = try await max.sendBlindWorkout(draft)
        _ = try await momo.respondToBlindWorkout(id: draft.id, accept: true, equipmentConfirmed: true)
        let live = try await momo.startBlindWorkout(id: draft.id)
        let currentExercise = try XCTUnwrap(live.currentExercise)
        _ = try await momo.saveBlindWorkoutExercise(id: draft.id, exerciseID: currentExercise.id, sets: [], complete: true)
        clock.advance(60)
        let completed = try await momo.finishBlindWorkout(id: draft.id)
        let last = try XCTUnwrap(completed.activity)
        let earned = try await state(momo)
        let week = try XCTUnwrap(earned.currentWeek)
        let shot = try XCTUnwrap(week.commitment)
        XCTAssertEqual(shot.id, called.id)
        XCTAssertTrue(shot.achieved)
        XCTAssertEqual(shot.achievedAt, last.endedAt)
        XCTAssertEqual(shot.achievedAt, week.flameEarnedAt)
        XCTAssertEqual(shot.title, "CALLED IT ✓")
        _ = try await momo.finishBlindWorkout(id: draft.id)
        await assertDenied { _ = try await momo.completeActivity(id: last.id, distanceMeters: nil) }
        await assertDenied { _ = try await self.callCurrentWeek(momo) }
        let retryState = try await state(momo)
        let friendNotifications = try await max.weeklyNotifications()
        let ownNotifications = try await momo.weeklyNotifications()
        XCTAssertEqual(retryState.currentWeek?.completedWorkouts, 4)
        XCTAssertEqual(retryState.currentWeek?.commitment, shot)
        XCTAssertEqual(friendNotifications.filter { $0.type == "shot_called" }.count, 1)
        XCTAssertEqual(friendNotifications.filter { $0.type == "shot_achieved" }.count, 1)
        XCTAssertTrue(ownNotifications.isEmpty, "The shot must not duplicate the existing owner's flame celebration")
    }

    func testFirstCallAfterAlreadyEarnedIsRejectedAndDoesNotAnnounceRetroactively() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        await assertDenied { _ = try await self.callCurrentWeek(momo) }
        let current = try await state(momo)
        let friendNotifications = try await repository(clock, storage: storage, userID: maxID).weeklyNotifications()
        XCTAssertTrue(current.currentWeek?.flameEarned ?? false)
        XCTAssertNil(current.currentWeek?.commitment)
        XCTAssertTrue(friendNotifications.isEmpty)
    }

    func testPlannedLiveCancelledAndShortWorkoutsNeverAchieveShot() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        try await momo.planSession(userID: momoID, sport: .gym, subtype: nil, startsAt: noon.addingTimeInterval(3600),
                                   duration: 60, note: nil, placeName: nil, friendsCanJoin: false, friendIDs: [])
        let live = try await momo.startActivity(userID: momoID, sport: .running, subtype: nil, linkedActivityID: nil, plannedSessionID: nil)
        clock.advance(180)
        let whileLive = try await state(momo)
        XCTAssertEqual(whileLive.currentWeek?.commitment, called)
        try await momo.cancelActivity(id: live.id)
        _ = try await complete(momo, clock: clock, seconds: 59)
        let current = try await state(momo)
        XCTAssertEqual(current.currentWeek?.completedWorkouts, 0)
        XCTAssertEqual(current.currentWeek?.commitment, called)
    }

    func testMissedWeekFinalizesNeutrallyAndNewWeekCanBeCalledWithPendingGoal() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        _ = try await momo.setNextWeeklyGoal(5)
        let before = try await state(momo)
        clock.set(try XCTUnwrap(before.currentWeek).endsAt)
        let nextCall = try await callCurrentWeek(momo)
        let next = try await state(momo)
        let missed = try XCTUnwrap(next.history.first?.commitment)
        XCTAssertEqual(missed.id, called.id)
        XCTAssertTrue(missed.finalized)
        XCTAssertFalse(missed.achieved)
        XCTAssertEqual(missed.statusText, "Neue Woche, neue Chance.")
        XCTAssertNotEqual(nextCall.weekID, called.weekID)
        XCTAssertNotEqual(nextCall.id, called.id)
        XCTAssertEqual(nextCall.weeklyGoal, 5)
        XCTAssertEqual(next.currentStreak, 0)
        let notifications = try await repository(clock, storage: storage, userID: maxID).weeklyNotifications()
        XCTAssertEqual(notifications.count, 2)
        XCTAssertTrue(notifications.allSatisfy { $0.type == "shot_called" }, "No missed-goal or pressure notification")
    }

    func testWeekBoundaryRejectsOldConsentWithoutCallingChangedNextGoalOrNotifyingFriends() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        let max = repository(clock, storage: storage, userID: maxID)
        let initial = try await momo.confirmWeeklyGoal(4, timezone: "UTC")
        let displayedWeek = try XCTUnwrap(initial.currentWeek)
        _ = try await momo.setNextWeeklyGoal(5)

        // An arbitrary ID is not an override selecting which week to call.
        await assertDenied { _ = try await momo.callMyShot(expectedWeekID: UUID()) }
        let beforeBoundary = try await state(momo)
        XCTAssertNil(beforeBoundary.currentWeek?.commitment)
        clock.set(displayedWeek.endsAt)

        // Exercise the storage's atomic guard itself before any read rolls it.
        await assertDenied {
            _ = try await storage.callMyShot(userID: self.momoID, expectedWeekID: displayedWeek.id,
                                             friends: [self.maxID], displayName: "Momo")
        }
        // The public repository must keep the same stale ID, not silently refresh
        // it and announce a goal that the person never confirmed on this sheet.
        await assertDenied { _ = try await momo.callMyShot(expectedWeekID: displayedWeek.id) }
        let current = try await state(momo)
        let newWeek = try XCTUnwrap(current.currentWeek)
        XCTAssertNotEqual(newWeek.id, displayedWeek.id)
        XCTAssertEqual(displayedWeek.weeklyGoal, 4)
        XCTAssertEqual(newWeek.weeklyGoal, 5)
        XCTAssertNil(newWeek.commitment)
        XCTAssertNil(current.history.first?.commitment)
        let beforeReconfirmation = try await max.weeklyNotifications()
        XCTAssertTrue(beforeReconfirmation.isEmpty)

        let explicitlyConfirmed = try await momo.callMyShot(expectedWeekID: newWeek.id)
        XCTAssertEqual(explicitlyConfirmed.weekID, newWeek.id)
        XCTAssertEqual(explicitlyConfirmed.weeklyGoal, 5)
        await assertDenied { _ = try await momo.callMyShot(expectedWeekID: displayedWeek.id) }
        let afterRetry = try await state(momo)
        XCTAssertEqual(afterRetry.currentWeek?.commitment?.id, explicitlyConfirmed.id)
        let afterReconfirmation = try await max.weeklyNotifications()
        XCTAssertEqual(afterReconfirmation.filter { $0.type == "shot_called" }.count, 1)
    }

    func testAcceptedFriendReactionsAreToggleableIdempotentAndForbiddenForOwnerOrStranger() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        let max = repository(clock, storage: storage, userID: maxID)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        await assertDenied { _ = try await momo.setShotReaction(commitmentID: called.id, reaction: .fire) }
        await assertDenied { _ = try await storage.reactToShot(commitmentID: called.id, viewer: UUID(), friends: [], reaction: .fire, displayName: "Stranger") }
        let first = try await max.setShotReaction(commitmentID: called.id, reaction: .target)
        let same = try await max.setShotReaction(commitmentID: called.id, reaction: .target)
        XCTAssertTrue(first && same)
        let friendState = try await state(max, userID: momoID)
        XCTAssertEqual(friendState.currentWeek?.commitment?.myReaction, .target)
        XCTAssertEqual(friendState.currentWeek?.commitment?.reactionCounts, [ShotReactionCount(reaction: .target, count: 1)])
        _ = try await max.setShotReaction(commitmentID: called.id, reaction: .strong)
        _ = try await max.setShotReaction(commitmentID: called.id, reaction: nil)
        let removed = try await state(momo)
        let notifications = try await momo.weeklyNotifications()
        XCTAssertTrue(removed.currentWeek?.commitment?.reactionCounts.isEmpty ?? false)
        XCTAssertEqual(notifications.filter { $0.type == "shot_reaction" }.count, 1)
        clock.set(try XCTUnwrap(removed.currentWeek).endsAt)
        let afterFinalization = try await max.setShotReaction(commitmentID: called.id, reaction: .fire)
        let finalRemoval = try await max.setShotReaction(commitmentID: called.id, reaction: nil)
        XCTAssertTrue(afterFinalization && finalRemoval)
    }

    func testBlockRevokesReadsReactionsAndExistingNotificationsWithoutChangingOwnCommitment() async throws {
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(now: { clock.now() })
        let momo = repository(clock, storage: storage)
        let max = repository(clock, storage: storage, userID: maxID)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        _ = try await max.setShotReaction(commitmentID: called.id, reaction: .fire)
        try await storage.revokeFriendship(momoID, maxID)
        await assertDenied { _ = try await max.weeklyState(userID: self.momoID, timezone: nil) }
        await assertDenied { _ = try await max.setShotReaction(commitmentID: called.id, reaction: nil) }
        let own = try await state(momo)
        let ownerNotes = try await momo.weeklyNotifications()
        let friendNotes = try await max.weeklyNotifications()
        XCTAssertEqual(own.currentWeek?.commitment?.id, called.id)
        XCTAssertTrue(own.currentWeek?.commitment?.reactionCounts.isEmpty ?? false)
        XCTAssertTrue(ownerNotes.isEmpty)
        XCTAssertTrue(friendNotes.isEmpty)
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        let afterSuccess = try await max.weeklyNotifications()
        XCTAssertTrue(afterSuccess.isEmpty)
    }

    func testNotificationMuteAndRelaunchPersistCommitmentReactionAndOneTimeAchievement() async throws {
        let suite = "app.fyrup.tests.shot.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let momo = repository(clock, storage: storage)
        let max = repository(clock, storage: storage, userID: maxID)
        var muted = NotificationPreferences.standard; muted.weeklyGoal = false
        try await storage.setNotificationPreferences(muted, userID: maxID)
        var ownerMuted = NotificationPreferences.standard; ownerMuted.reactions = false
        try await storage.setNotificationPreferences(ownerMuted, userID: momoID)
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        _ = try await max.setShotReaction(commitmentID: called.id, reaction: .target)
        let mutedOwnNotes = try await momo.weeklyNotifications()
        XCTAssertTrue(mutedOwnNotes.isEmpty)
        for _ in 0..<3 { _ = try await complete(momo, clock: clock) }
        let restoredStorage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let restored = repository(clock, storage: restoredStorage)
        let current = try await state(restored)
        XCTAssertEqual(current.currentWeek?.commitment?.id, called.id)
        XCTAssertEqual(current.currentWeek?.commitment?.achieved, true)
        XCTAssertEqual(current.currentWeek?.commitment?.reactionCounts, [ShotReactionCount(reaction: .target, count: 1)])
        await assertDenied { _ = try await self.callCurrentWeek(restored) }
        let friendNotes = try await repository(clock, storage: restoredStorage, userID: maxID).weeklyNotifications()
        XCTAssertTrue(friendNotes.isEmpty)
        try await restoredStorage.deleteAccount(userID: momoID)
        let deleted = try await state(repository(clock, storage: restoredStorage))
        XCTAssertFalse(deleted.goalConfirmed)
        XCTAssertNil(deleted.currentWeek)
    }

    func testPreviouslyPersistedWeeklyStateWithoutNewKeysStillLoadsAndCorruptDataIsPreserved() async throws {
        let suite = "app.fyrup.tests.shot-compatibility.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock = ShotRepositoryClock(noon)
        let storage = DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() })
        let original = repository(clock, storage: storage)
        _ = try await original.confirmWeeklyGoal(4, timezone: "UTC")
        let originalData = try XCTUnwrap(defaults.data(forKey: "fyrup.demo.weekly-flames.v1"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: originalData) as? [String: Any])
        json.removeValue(forKey: "notifications"); json.removeValue(forKey: "preferences")
        // Empty optional commitment fields are omitted by synthesized Codable, as in the old version.
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "fyrup.demo.weekly-flames.v1")
        let restored = repository(clock, storage: DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() }))
        let before = try await state(restored)
        XCTAssertEqual(before.currentWeek?.weeklyGoal, 4)
        XCTAssertNil(before.currentWeek?.commitment)
        _ = try await callCurrentWeek(restored)
        let corrupt = Data("not a weekly document".utf8)
        defaults.set(corrupt, forKey: "fyrup.demo.weekly-flames.v1")
        let broken = repository(clock, storage: DemoWeeklyFlameStorage(persistenceSuiteName: suite, now: { clock.now() }))
        await assertDenied { _ = try await broken.callMyShot(expectedWeekID: try XCTUnwrap(before.currentWeek).id) }
        XCTAssertEqual(defaults.data(forKey: "fyrup.demo.weekly-flames.v1"), corrupt)
    }

    func testCommitmentValidationRejectsForeignOwnerWeekGoalAndForgedSuccess() async throws {
        let clock = ShotRepositoryClock(noon)
        let momo = repository(clock, storage: DemoWeeklyFlameStorage(now: { clock.now() }))
        _ = try await momo.confirmWeeklyGoal(3, timezone: "UTC")
        let called = try await callCurrentWeek(momo)
        let current = try await state(momo)
        let week = try XCTUnwrap(current.currentWeek)
        XCTAssertTrue(called.isValid(for: week))
        let encoded = try JSONEncoder.supabase.encode(called)
        let base = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let mutations: [(String, Any)] = [("user_id", maxID.uuidString), ("week_id", UUID().uuidString), ("weekly_goal", 7),
                                         ("week_start_date", "1900-01-01"), ("finalized", true), ("achieved", true)]
        for (key, value) in mutations {
            var changed = base; changed[key] = value
            let result = try JSONDecoder.supabase.decode(WeeklyCommitment.self, from: JSONSerialization.data(withJSONObject: changed))
            XCTAssertFalse(result.isValid(for: week), key)
            var changedWeek = week; changedWeek.commitment = result
            XCTAssertFalse(changedWeek.isValid, key)
        }
        var oldWeek = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.supabase.encode(week)) as? [String: Any])
        oldWeek.removeValue(forKey: "commitment")
        let olderDTO = try JSONDecoder.supabase.decode(WeeklyProgress.self, from: JSONSerialization.data(withJSONObject: oldWeek))
        XCTAssertNil(olderDTO.commitment)
        XCTAssertTrue(olderDTO.isValid)
    }
}

private final class ShotRepositoryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ value: Date) { self.value = value }
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); value.addTimeInterval(seconds); lock.unlock() }
    func set(_ date: Date) { lock.lock(); value = date; lock.unlock() }
}
