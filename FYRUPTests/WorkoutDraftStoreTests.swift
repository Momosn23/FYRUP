import XCTest
@testable import FYRUP

@MainActor
final class WorkoutDraftStoreTests: XCTestCase {
    private let owner = DemoRepository.defaultUserID
    private let otherOwner = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private func isolatedDefaults() throws -> (suite: String, defaults: UserDefaults) {
        let suite = "FYRUP.WorkoutDraftStoreTests.\(UUID().uuidString)"
        return (suite, try XCTUnwrap(UserDefaults(suiteName: suite)))
    }

    private func key(for userID: UUID) -> String { "app.fyrup.workout-drafts.v1.\(userID.uuidString)" }

    private func edited(_ original: WorkoutPlan, name: String = "Push Day") -> WorkoutPlan {
        var value = original
        value.name = name
        value.category = "Push"
        value.exercises = [WorkoutPlanExercise(exercise: GymExercise(name: "Bankdrücken Langhantel", primaryMuscle: .chest,
                                                                    secondaryMuscles: [.triceps, .shoulders], equipment: .barbell, isCustom: false),
                                               targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 80)]
        return value
    }

    func testReconstructionFromSameDefaultsRestoresNameExercisesAndOriginal() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        let original = WorkoutPlan(ownerID: owner)
        let draft = edited(original)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        store.save(edited: draft, original: original, now: timestamp)

        let reconstructed = WorkoutDraftStore(defaults: fixture.defaults)
        reconstructed.activate(userID: owner)
        let restored = try XCTUnwrap(reconstructed.draft(id: draft.id))
        XCTAssertEqual(restored.original, original)
        XCTAssertEqual(restored.edited, draft)
        XCTAssertEqual(restored.updatedAt, timestamp)
        XCTAssertEqual(reconstructed.drafts.count, 1)
        XCTAssertNil(reconstructed.errorMessage)

        let freshDefaults = try XCTUnwrap(UserDefaults(suiteName: fixture.suite))
        let freshStore = WorkoutDraftStore(defaults: freshDefaults)
        freshStore.activate(userID: owner)
        XCTAssertEqual(freshStore.draft(id: draft.id), restored)
    }

    func testAccountSwitchHidesPreviousDraftsWithoutDeletingTheOtherAccount() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        let original = WorkoutPlan(ownerID: owner)
        let otherOriginal = WorkoutPlan(ownerID: otherOwner)
        store.activate(userID: owner)
        store.save(edited: edited(original), original: original)
        store.activate(userID: otherOwner)
        XCTAssertTrue(store.drafts.isEmpty)
        XCTAssertNil(store.draft(id: original.id))
        store.save(edited: edited(otherOriginal, name: "Max Push"), original: otherOriginal)
        XCTAssertEqual(store.drafts.map(\.id), [otherOriginal.id])
        store.activate(userID: nil)
        XCTAssertTrue(store.drafts.isEmpty)
        store.activate(userID: owner)
        XCTAssertEqual(store.drafts.map(\.id), [original.id])
        store.activate(userID: otherOwner)
        XCTAssertEqual(store.drafts.map(\.id), [otherOriginal.id])
    }

    func testSavingSameDraftReplacesItAndKeepsOtherDrafts() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        let first = WorkoutPlan(ownerID: owner)
        let second = WorkoutPlan(ownerID: owner)
        store.save(edited: edited(first), original: first, now: Date(timeIntervalSince1970: 100))
        store.save(edited: edited(second, name: "Pull Day"), original: second, now: Date(timeIntervalSince1970: 200))
        store.save(edited: edited(first, name: "Push Updated"), original: first, now: Date(timeIntervalSince1970: 300))
        XCTAssertEqual(store.drafts.map(\.id), [first.id, second.id])
        XCTAssertEqual(store.draft(id: first.id)?.edited.name, "Push Updated")
        XCTAssertEqual(store.draft(id: first.id)?.original, first)
    }

    func testSavedOrExplicitlyDiscardedDraftIsRemovedPersistently() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        let savedPlan = WorkoutPlan(ownerID: owner)
        let discardedPlan = WorkoutPlan(ownerID: owner)
        let retainedPlan = WorkoutPlan(ownerID: owner)
        for original in [savedPlan, discardedPlan, retainedPlan] { store.save(edited: edited(original), original: original) }
        // Both successful server save and the explicit discard button use remove(id:).
        store.remove(id: savedPlan.id)
        store.remove(id: discardedPlan.id)
        store.remove(id: discardedPlan.id)
        let restored = WorkoutDraftStore(defaults: fixture.defaults)
        restored.activate(userID: owner)
        XCTAssertEqual(restored.drafts.map(\.id), [retainedPlan.id])
    }

    func testReturningToOriginalRemovesDraftInsteadOfLeavingAnEmptyResumeCard() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        let original = WorkoutPlan(ownerID: owner)
        store.save(edited: edited(original), original: original)
        store.save(edited: original, original: original)
        XCTAssertTrue(store.drafts.isEmpty)
        let restored = WorkoutDraftStore(defaults: fixture.defaults)
        restored.activate(userID: owner)
        XCTAssertTrue(restored.drafts.isEmpty)
    }

    func testClearCurrentAccountRemovesOnlyItsPersistedData() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        let original = WorkoutPlan(ownerID: owner)
        let other = WorkoutPlan(ownerID: otherOwner)
        store.activate(userID: otherOwner)
        store.save(edited: edited(other), original: other)
        store.activate(userID: owner)
        store.save(edited: edited(original), original: original)
        store.clearCurrentAccount()
        XCTAssertNil(store.userID)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.drafts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: key(for: owner)))
        store.activate(userID: owner)
        XCTAssertTrue(store.drafts.isEmpty)
        store.activate(userID: otherOwner)
        XCTAssertEqual(store.drafts.map(\.id), [other.id])
    }

    func testAppStoreLogoutClearsDraftsFromTheDevice() async throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let drafts = WorkoutDraftStore(defaults: fixture.defaults)
        let appStore = AppStore(repository: DemoRepository(), workoutDrafts: drafts)
        await appStore.bootstrap()
        XCTAssertEqual(drafts.userID, owner)
        let original = WorkoutPlan(ownerID: owner)
        drafts.save(edited: edited(original), original: original)
        await appStore.logout()
        XCTAssertNil(drafts.userID)
        XCTAssertNil(appStore.session)
        XCTAssertTrue(drafts.drafts.isEmpty)
        let reconstructed = WorkoutDraftStore(defaults: fixture.defaults)
        reconstructed.activate(userID: owner)
        XCTAssertTrue(reconstructed.drafts.isEmpty)
    }

    func testSaveRejectsUnownedPlansMismatchedIDsAndMissingAccount() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        let original = WorkoutPlan(ownerID: owner)
        let foreign = WorkoutPlan(ownerID: otherOwner)
        store.save(edited: edited(original), original: original)
        XCTAssertTrue(store.drafts.isEmpty)
        store.activate(userID: owner)
        store.save(edited: edited(foreign), original: foreign)
        var mismatchedID = edited(original); mismatchedID.id = UUID()
        store.save(edited: mismatchedID, original: original)
        var mismatchedOwner = edited(original); mismatchedOwner.ownerID = otherOwner
        store.save(edited: mismatchedOwner, original: original)
        var foreignOriginal = original; foreignOriginal.ownerID = otherOwner
        store.save(edited: edited(original), original: foreignOriginal)
        XCTAssertTrue(store.drafts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: key(for: owner)))
    }

    func testLoadingFiltersMismatchedAccountAndPlanIDs() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let original = WorkoutPlan(ownerID: owner)
        let foreign = WorkoutPlan(ownerID: otherOwner)
        let now = Date()
        let valid = WorkoutPlanDraft(original: original, edited: edited(original), updatedAt: now)
        var wrongID = edited(original); wrongID.id = UUID()
        let payload = [valid,
                       WorkoutPlanDraft(original: original, edited: wrongID, updatedAt: now),
                       WorkoutPlanDraft(original: foreign, edited: edited(foreign), updatedAt: now),
                       WorkoutPlanDraft(original: foreign, edited: edited(original), updatedAt: now)]
        fixture.defaults.set(try JSONEncoder().encode(payload), forKey: key(for: owner))
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        XCTAssertEqual(store.drafts, [valid])
    }

    func testDamagedSavedJSONReportsErrorAndLeavesRawDataUntouchedOnLoad() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let corrupted = Data("{ incomplete draft data".utf8)
        fixture.defaults.set(corrupted, forKey: key(for: owner))
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        XCTAssertTrue(store.drafts.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: owner)), corrupted)
        store.activate(userID: otherOwner)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.drafts.isEmpty)
    }

    func testDuplicateDraftIDsRestoreOnlyTheNewestSnapshot() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let original = WorkoutPlan(ownerID: owner)
        let otherOriginal = WorkoutPlan(ownerID: owner)
        let oldest = WorkoutPlanDraft(original: original, edited: edited(original, name: "Old Push"), updatedAt: Date(timeIntervalSince1970: 100))
        let newest = WorkoutPlanDraft(original: original, edited: edited(original, name: "Newest Push"), updatedAt: Date(timeIntervalSince1970: 300))
        let separate = WorkoutPlanDraft(original: otherOriginal, edited: edited(otherOriginal, name: "Pull"), updatedAt: Date(timeIntervalSince1970: 200))
        fixture.defaults.set(try JSONEncoder().encode([oldest, separate, newest, oldest]), forKey: key(for: owner))
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        XCTAssertEqual(store.drafts, [newest, separate])
        XCTAssertEqual(Set(store.drafts.map(\.id)).count, store.drafts.count)
        XCTAssertEqual(store.draft(id: original.id)?.edited.name, "Newest Push")
    }

    func testCorruptDraftIsBackedUpBeforeNewEditsReplaceTheMainData() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let corrupted = Data("{ damaged but potentially recoverable".utf8)
        fixture.defaults.set(corrupted, forKey: key(for: owner))
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: owner) + ".recovery"), corrupted)
        let original = WorkoutPlan(ownerID: owner)
        let good = edited(original)
        store.save(edited: good, original: original)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.draft(id: original.id)?.edited, good)
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: owner) + ".recovery"), corrupted)
        let savedData = try XCTUnwrap(fixture.defaults.data(forKey: key(for: owner)))
        let savedDrafts = try JSONDecoder().decode([WorkoutPlanDraft].self, from: savedData)
        XCTAssertEqual(savedDrafts.first?.edited, good)
    }

    func testClearingAccountRemovesItsRecoveryBackupButNotAnotherAccountsBackup() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let corruptOwnerData = Data("broken owner".utf8)
        let corruptOtherData = Data("broken other".utf8)
        fixture.defaults.set(corruptOwnerData, forKey: key(for: owner))
        fixture.defaults.set(corruptOtherData, forKey: key(for: otherOwner))
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: otherOwner)
        store.activate(userID: owner)
        XCTAssertNotNil(store.errorMessage)
        store.clearCurrentAccount()
        XCTAssertNil(fixture.defaults.data(forKey: key(for: owner)))
        XCTAssertNil(fixture.defaults.data(forKey: key(for: owner) + ".recovery"))
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: otherOwner)), corruptOtherData)
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: otherOwner) + ".recovery"), corruptOtherData)
        XCTAssertNil(store.errorMessage)
    }

    func testUnencodableDraftPreservesTheLastRecoverableSnapshot() throws {
        let fixture = try isolatedDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let store = WorkoutDraftStore(defaults: fixture.defaults)
        store.activate(userID: owner)
        let original = WorkoutPlan(ownerID: owner)
        let good = edited(original)
        store.save(edited: good, original: original)
        let dataBefore = fixture.defaults.data(forKey: key(for: owner))
        var invalid = good; invalid.exercises[0].targetWeight = .infinity
        store.save(edited: invalid, original: original)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.draft(id: original.id)?.edited, good)
        XCTAssertEqual(fixture.defaults.data(forKey: key(for: owner)), dataBefore)
    }
}
