import XCTest
@testable import FYRUP

@MainActor
final class DemoNotificationPreferenceStorageTests: XCTestCase {
    private let owner = DemoRepository.defaultUserID
    private let friend = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private var muted: NotificationPreferences {
        NotificationPreferences(friendStarts: false, fyrup: false, invitations: false, reactions: false,
                                friendRequests: false, reminders: false, weeklyGoal: false, crewGoal: false)
    }
    private func persistentSuite() throws -> (String, UserDefaults) {
        let name = "app.fyrup.tests.shared-preferences.\(UUID().uuidString)"
        return (name, try XCTUnwrap(UserDefaults(suiteName: name)))
    }

    func testRelaunchReadsTheSavedOptOutFromTheSameSuite() async throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = DemoRepository(weeklyStorage: DemoWeeklyFlameStorage(persistenceSuiteName: suite),
                                   blindStorage: DemoBlindWorkoutStorage(persistenceSuiteName: suite))
        _ = try await first.saveNotificationPreferences(muted, expected: .standard)
        let reopened = DemoRepository(weeklyStorage: DemoWeeklyFlameStorage(persistenceSuiteName: suite),
                                      blindStorage: DemoBlindWorkoutStorage(persistenceSuiteName: suite))
        let value = try await reopened.notificationPreferences()
        XCTAssertEqual(value, muted)
        XCTAssertNotNil(defaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey))
    }

    func testDifferentRepositoriesRejectAStaleFullRecordSave() async throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = DemoRepository(weeklyStorage: DemoWeeklyFlameStorage(persistenceSuiteName: suite))
        let second = DemoRepository(blindStorage: DemoBlindWorkoutStorage(persistenceSuiteName: suite))
        var changed = NotificationPreferences.standard; changed.reactions = false
        _ = try await first.saveNotificationPreferences(changed, expected: .standard)
        var stale = NotificationPreferences.standard; stale.reminders = false
        do {
            _ = try await second.saveNotificationPreferences(stale, expected: .standard)
            XCTFail("A different repository must compare against the same authority")
        } catch { XCTAssertNotNil(error as? AppError) }
        let after = try await second.notificationPreferences()
        XCTAssertEqual(after, changed)
        let exactRetry = try await second.saveNotificationPreferences(changed, expected: .standard)
        XCTAssertEqual(exactRetry, changed)
    }

    func testConcurrentCASHasOnlyOneWinnerAndNeverCombinesStaleRecords() async throws {
        let source = DemoNotificationPreferenceStorage.shared()
        let userID = owner
        var first = NotificationPreferences.standard; first.reactions = false
        var second = NotificationPreferences.standard; second.invitations = false
        let candidates = [first, second]
        let winners = await withTaskGroup(of: NotificationPreferences?.self, returning: [NotificationPreferences].self) { group in
            for desired in candidates {
                group.addTask { try? source.compareAndSave(desired, expected: .standard, userID: userID) }
            }
            var result: [NotificationPreferences] = []
            for await value in group { if let value { result.append(value) } }
            return result
        }
        XCTAssertEqual(winners.count, 1)
        XCTAssertEqual(try source.value(userID: owner), winners.first)
    }

    func testEphemeralAccountsStayIsolatedUnlessTheirFeatureStoreIsShared() async throws {
        let first = DemoRepository()
        _ = try await first.saveNotificationPreferences(muted, expected: .standard)
        let unrelated = DemoRepository()
        let unrelatedValue = try await unrelated.notificationPreferences()
        XCTAssertEqual(unrelatedValue, .standard)
        let weekly = DemoWeeklyFlameStorage()
        let own = DemoRepository(weeklyStorage: weekly)
        let other = DemoRepository(userID: friend, weeklyStorage: weekly)
        _ = try await own.saveNotificationPreferences(muted, expected: .standard)
        let otherValue = try await other.notificationPreferences()
        XCTAssertEqual(otherValue, .standard)
        let ownValue = try await own.notificationPreferences()
        XCTAssertEqual(ownValue, muted)
    }

    func testSharingOnlyWeeklyStorageAlsoSharesPreferenceAuthority() async throws {
        let weekly = DemoWeeklyFlameStorage()
        let first = DemoRepository(weeklyStorage: weekly)
        _ = try await first.saveNotificationPreferences(muted, expected: .standard)
        let second = DemoRepository(weeklyStorage: weekly)
        let loaded = try await second.notificationPreferences()
        XCTAssertEqual(loaded, muted)
        _ = try await second.saveNotificationPreferences(.standard, expected: muted)
        let oldHolder = try await first.notificationPreferences()
        XCTAssertEqual(oldHolder, .standard)
    }

    func testSharingOnlyBlindStorageAlsoSharesPreferenceAuthority() async throws {
        let blind = DemoBlindWorkoutStorage()
        let first = DemoRepository(blindStorage: blind)
        _ = try await first.saveNotificationPreferences(muted, expected: .standard)
        let second = DemoRepository(blindStorage: blind)
        let loaded = try await second.notificationPreferences()
        XCTAssertEqual(loaded, muted)
        _ = try await second.saveNotificationPreferences(.standard, expected: muted)
        let oldHolder = try await first.notificationPreferences()
        XCTAssertEqual(oldHolder, .standard)
    }

    func testLegacyCopiesMergeOptOutsAndCannotUndoAnExplicitLaterReenable() throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        struct Legacy: Encodable { let preferences: [UUID: NotificationPreferences] }
        var first = NotificationPreferences.standard; first.reactions = false
        var second = NotificationPreferences.standard; second.invitations = false
        defaults.set(try JSONEncoder().encode(Legacy(preferences: [owner: first])), forKey: "fyrup.demo.weekly-flames.v1")
        defaults.set(try JSONEncoder().encode(Legacy(preferences: [owner: second])), forKey: "fyrup.demo.blind-workouts.v1")
        let source = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        let merged = try source.value(userID: owner)
        XCTAssertFalse(merged.reactions); XCTAssertFalse(merged.invitations)
        _ = try source.compareAndSave(.standard, expected: merged, userID: owner)
        let reopened = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        XCTAssertEqual(try reopened.value(userID: owner), .standard)
        // The migration leaves original feature data intact.
        XCTAssertNotNil(defaults.data(forKey: "fyrup.demo.blind-workouts.v1"))
    }

    func testCorruptCanonicalDataIsNotTreatedAsDefaultsOrOverwritten() throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        let source = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        _ = try source.compareAndSave(muted, expected: .standard, userID: owner)
        let corrupt = Data("unreadable preferences".utf8)
        defaults.set(corrupt, forKey: DemoNotificationPreferenceStorage.persistenceKey)
        XCTAssertThrowsError(try source.value(userID: owner))
        XCTAssertThrowsError(try source.compareAndSave(.standard, expected: muted, userID: owner))
        XCTAssertEqual(defaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey), corrupt)
    }

    func testUnexpectedStoredTypeCannotBecomeImplicitConsent() throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("old unreadable value", forKey: DemoNotificationPreferenceStorage.persistenceKey)
        let source = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        XCTAssertThrowsError(try source.value(userID: owner))
        XCTAssertThrowsError(try source.compareAndSave(muted, expected: .standard, userID: owner))
        XCTAssertEqual(defaults.string(forKey: DemoNotificationPreferenceStorage.persistenceKey), "old unreadable value")
    }

    func testCorruptLegacyDataCannotCreateAConfirmedDefault() throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("unreadable old state".utf8)
        defaults.set(corrupt, forKey: "fyrup.demo.weekly-flames.v1")
        let source = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        XCTAssertThrowsError(try source.value(userID: owner))
        XCTAssertThrowsError(try source.compareAndSave(muted, expected: .standard, userID: owner))
        XCTAssertNil(defaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey))
        XCTAssertEqual(defaults.data(forKey: "fyrup.demo.weekly-flames.v1"), corrupt)
    }

    func testAccountRemovalDoesNotResurrectLegacyPreferencesOrTouchAnotherAccount() throws {
        let (suite, defaults) = try persistentSuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        struct Legacy: Encodable { let preferences: [UUID: NotificationPreferences] }
        defaults.set(try JSONEncoder().encode(Legacy(preferences: [owner: muted, friend: muted])), forKey: "fyrup.demo.weekly-flames.v1")
        let source = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: suite)
        try source.remove(userID: owner)
        XCTAssertEqual(try source.value(userID: owner), .standard)
        XCTAssertEqual(try source.value(userID: friend), muted)
    }

    func testDifferentPersistentSuitesCannotBeAccidentallyJoined() throws {
        let (firstSuite, firstDefaults) = try persistentSuite()
        let (secondSuite, secondDefaults) = try persistentSuite()
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuite)
            secondDefaults.removePersistentDomain(forName: secondSuite)
        }
        let first = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: firstSuite)
        let second = DemoNotificationPreferenceStorage.shared(persistenceSuiteName: secondSuite)
        _ = try first.compareAndSave(muted, expected: .standard, userID: owner)
        let before = firstDefaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey)
        let invalid = first.joined(with: second)
        XCTAssertThrowsError(try invalid.value(userID: owner))
        XCTAssertEqual(firstDefaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey), before)
        XCTAssertNil(secondDefaults.data(forKey: DemoNotificationPreferenceStorage.persistenceKey))
    }

    func testOneSavedPreferenceControlsBothWeeklyAndBlindNotifications() async throws {
        let weekly = DemoWeeklyFlameStorage(), blind = DemoBlindWorkoutStorage()
        let exercise = GymExercise(id: UUID(), name: "Bankdrücken", primaryMuscle: .chest, equipment: .barbell, isCustom: false)
        let workouts = DemoWorkoutStorage(library: [exercise])
        let recipient = DemoRepository(workoutStorage: workouts, weeklyStorage: weekly, blindStorage: blind)
        let creator = DemoRepository(userID: friend, workoutStorage: workouts, weeklyStorage: weekly, blindStorage: blind)
        _ = try await recipient.saveNotificationPreferences(muted, expected: .standard)
        let row = WorkoutPlanExercise(exercise: exercise, sortOrder: 0, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12)
        _ = try await creator.sendBlindWorkout(BlindWorkoutDraft(recipientID: owner, title: "Push", focus: .push,
            estimatedDurationMinutes: 30, exercises: [row]))
        let ownWeek = try await creator.weeklyState(userID: friend, timezone: "UTC")
        let weekID = try XCTUnwrap(ownWeek.currentWeek?.id)
        _ = try await creator.callMyShot(expectedWeekID: weekID)
        let blindNotes = try await recipient.blindNotifications()
        let weeklyNotes = try await recipient.weeklyNotifications()
        XCTAssertTrue(blindNotes.isEmpty); XCTAssertTrue(weeklyNotes.isEmpty)
        XCTAssertEqual(try weekly.notificationPreferenceStorage.value(userID: owner), muted)
        XCTAssertEqual(try blind.notificationPreferenceStorage.value(userID: owner), muted)
    }
}
