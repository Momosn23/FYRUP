import XCTest
@testable import FYRUP

@MainActor
final class WorkoutStoreTests: XCTestCase {
    private let owner = UUID(uuidString: "a2000000-0000-0000-0000-000000000001")!
    private let otherOwner = UUID(uuidString: "a2000000-0000-0000-0000-000000000002")!

    private func exercise(name: String = "Bankdrücken") -> GymExercise {
        GymExercise(name: name, primaryMuscle: .chest, equipment: .barbell, isCustom: false)
    }

    private func plan(name: String = "Push Day") -> WorkoutPlan {
        WorkoutPlan(ownerID: owner, name: name, exercises: [WorkoutPlanExercise(exercise: exercise())])
    }

    private func log() -> WorkoutLog {
        WorkoutLog(activityID: UUID(), planName: "Push Day", exercises: [
            WorkoutExerciseLog(exercise: exercise(), sortOrder: 0, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12,
                               sets: [WorkoutSetLog(setNumber: 1), WorkoutSetLog(setNumber: 2), WorkoutSetLog(setNumber: 3)])
        ])
    }

    private func store(_ repository: WorkoutStoreRepositoryStub) -> WorkoutStore {
        let value = WorkoutStore(repository: repository)
        value.activate(userID: owner)
        return value
    }

    func testActivatingAnotherAccountClearsEveryPrivateResourceAndError() {
        let value = store(WorkoutStoreRepositoryStub())
        let training = log()
        value.plans = [plan()]; value.exercises = [exercise()]; value.favorites = [UUID()]
        value.logs[training.activityID] = training
        value.errorMessage = "Old account error"
        value.activate(userID: otherOwner)
        XCTAssertEqual(value.userID, otherOwner)
        XCTAssertTrue(value.plans.isEmpty); XCTAssertTrue(value.exercises.isEmpty)
        XCTAssertTrue(value.favorites.isEmpty); XCTAssertTrue(value.logs.isEmpty)
        XCTAssertNil(value.errorMessage); XCTAssertFalse(value.isBusy)
    }

    func testReactivatingSameAccountDoesNotEraseItsData() {
        let value = store(WorkoutStoreRepositoryStub())
        let saved = plan()
        value.plans = [saved]
        value.activate(userID: owner)
        XCTAssertEqual(value.plans, [saved])
    }

    func testLatePlanLoadCannotRestorePreviousAccountData() async {
        let repository = WorkoutStoreRepositoryStub(plans: [plan()], held: [.plans])
        let value = store(repository)
        let request = Task { await value.loadPlans() }
        await repository.waitUntilStarted(.plans)
        XCTAssertTrue(value.isLoadingPlans)
        value.activate(userID: otherOwner)
        await repository.release(.plans)
        await request.value
        XCTAssertTrue(value.plans.isEmpty)
        XCTAssertFalse(value.isLoadingPlans)
        XCTAssertNil(value.errorMessage)
    }

    func testLateLibraryAndFavoritesCannotRestoreLoggedOutAccountData() async {
        let item = exercise()
        let repository = WorkoutStoreRepositoryStub(exercises: [item], favorites: [item.id], held: [.library])
        let value = store(repository)
        let request = Task { await value.loadLibrary() }
        await repository.waitUntilStarted(.library)
        value.activate(userID: nil)
        await repository.release(.library)
        await request.value
        XCTAssertTrue(value.exercises.isEmpty); XCTAssertTrue(value.favorites.isEmpty)
        XCTAssertFalse(value.isLoadingLibrary)
    }

    func testLateLogLoadCannotRestorePreviousAccountData() async {
        let training = log()
        let repository = WorkoutStoreRepositoryStub(logs: [training.activityID: training], held: [.log])
        let value = store(repository)
        let request = Task { await value.loadLog(activityID: training.activityID) }
        await repository.waitUntilStarted(.log)
        value.activate(userID: otherOwner)
        await repository.release(.log)
        let result = await request.value
        XCTAssertNil(result)
        XCTAssertTrue(value.logs.isEmpty)
    }

    func testLateMutationCannotInsertPreviousAccountPlanOrClearNewBusyFlag() async {
        let first = plan(name: "First account")
        var second = plan(name: "Second account"); second.ownerID = otherOwner
        let repository = WorkoutStoreRepositoryStub(held: [.savePlan])
        let value = store(repository)
        let firstRequest = Task { await value.savePlan(first) }
        await repository.waitUntilStarted(.savePlan)
        value.activate(userID: otherOwner)
        let secondRequest = Task { await value.savePlan(second) }
        await repository.waitUntilStarted(.savePlan, count: 2)
        await repository.releaseFirst(.savePlan)
        let obsolete = await firstRequest.value
        XCTAssertNil(obsolete)
        XCTAssertTrue(value.plans.isEmpty)
        XCTAssertTrue(value.isBusy, "Old response must not clear newer account's in-flight mutation")
        await repository.release(.savePlan)
        let current = await secondRequest.value
        XCTAssertEqual(current?.id, second.id)
        XCTAssertEqual(value.plans.map(\.id), [second.id])
        XCTAssertFalse(value.isBusy)
    }

    func testLateFailureDoesNotShowPreviousAccountError() async {
        let repository = WorkoutStoreRepositoryStub(held: [.savePlan], failing: [.savePlan])
        let value = store(repository)
        let draft = plan()
        let request = Task { await value.savePlan(draft) }
        await repository.waitUntilStarted(.savePlan)
        value.activate(userID: otherOwner)
        await repository.release(.savePlan)
        let result = await request.value
        XCTAssertNil(result); XCTAssertNil(value.errorMessage); XCTAssertFalse(value.isBusy)
    }

    func testSaveFailurePreservesExistingPlanAndDraftAndShowsRetryError() async {
        let existing = plan()
        var draft = existing; draft.name = "Unsaved change"
        let repository = WorkoutStoreRepositoryStub(failing: [.savePlan])
        let value = store(repository); value.plans = [existing]
        let result = await value.savePlan(draft)
        XCTAssertNil(result)
        XCTAssertEqual(value.plans, [existing])
        XCTAssertEqual(draft.name, "Unsaved change")
        XCTAssertEqual(value.errorMessage, WorkoutStoreStubError.failed.errorDescription)
        XCTAssertFalse(value.isBusy)
    }

    func testLogSaveFailurePreservesPreviousLogAndUserDraft() async {
        let original = log()
        var draft = original; draft.exercises[0].sets[0].weight = 80; draft.exercises[0].sets[0].reps = 8
        let value = store(WorkoutStoreRepositoryStub(failing: [.saveLog]))
        value.logs[original.activityID] = original
        let result = await value.saveLog(draft)
        XCTAssertNil(result)
        XCTAssertEqual(value.logs[original.activityID]?.exercises, original.exercises)
        XCTAssertEqual(draft.exercises[0].sets[0].weight, 80)
        XCTAssertNotNil(value.errorMessage)
    }

    func testReadFailureKeepsAlreadyVisibleCollection() async {
        let old = plan()
        let value = store(WorkoutStoreRepositoryStub(failing: [.plans]))
        value.plans = [old]
        await value.loadPlans()
        XCTAssertEqual(value.plans, [old])
        XCTAssertNotNil(value.errorMessage)
        XCTAssertFalse(value.isLoadingPlans)
    }

    func testMutationsDoNotOverlapOrSilentlyChangeSecondResourceWhileBusy() async {
        let draft = plan()
        let repository = WorkoutStoreRepositoryStub(held: [.savePlan])
        let value = store(repository)
        let first = Task { await value.savePlan(draft) }
        await repository.waitUntilStarted(.savePlan)
        let ignored = await value.saveExercise(exercise(name: "Second action"))
        XCTAssertNil(ignored)
        let calls = await repository.count(.saveExercise)
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(value.isBusy)
        await repository.release(.savePlan)
        _ = await first.value
        XCTAssertFalse(value.isBusy)
        let accepted = await value.saveExercise(exercise(name: "Second action"))
        XCTAssertNotNil(accepted)
        let finalCalls = await repository.count(.saveExercise)
        XCTAssertEqual(finalCalls, 1)
    }

    func testSuccessfulSavesUseCanonicalResponsesAndReplaceRatherThanDuplicate() async {
        let repository = WorkoutStoreRepositoryStub()
        let value = store(repository)
        var draft = plan(name: "  Push Day  ")
        let first = await value.savePlan(draft)
        XCTAssertEqual(first?.name, "Push Day")
        draft.name = "Updated Push"
        let second = await value.savePlan(draft)
        XCTAssertEqual(value.plans.count, 1)
        XCTAssertEqual(value.plans.first, second)
        let custom = GymExercise(name: "  Custom Press  ", primaryMuscle: .chest, createdBy: owner)
        let savedExercise = await value.saveExercise(custom)
        XCTAssertEqual(savedExercise?.name, "Custom Press")
        XCTAssertEqual(value.exercises.map(\.id), [custom.id])
        _ = await value.saveExercise(custom)
        XCTAssertEqual(value.exercises.count, 1)
        let training = log()
        let savedLog = await value.saveLog(training)
        XCTAssertEqual(value.logs[training.activityID]?.exercises, savedLog?.exercises)
        XCTAssertNil(value.errorMessage)
    }

    func testFavoriteAndArchiveOnlyUpdateAfterServerSuccess() async {
        let item = exercise()
        let saved = plan()
        let repository = WorkoutStoreRepositoryStub(exercises: [item])
        let value = store(repository); value.exercises = [item]; value.plans = [saved]
        await value.toggleFavorite(id: item.id)
        XCTAssertTrue(value.favorites.contains(item.id))
        await repository.setFailure(.archiveExercise, enabled: true)
        let failed = await value.archiveExercise(id: item.id)
        XCTAssertFalse(failed); XCTAssertEqual(value.exercises, [item]); XCTAssertTrue(value.favorites.contains(item.id))
        await repository.setFailure(.archiveExercise, enabled: false)
        let archived = await value.archiveExercise(id: item.id)
        XCTAssertTrue(archived); XCTAssertTrue(value.exercises.isEmpty); XCTAssertTrue(value.favorites.isEmpty)
        let planArchived = await value.archivePlan(id: saved.id)
        XCTAssertTrue(planArchived); XCTAssertTrue(value.plans.isEmpty)
    }

    func testStalePlanLoadCannotEraseSuccessfulSave() async {
        let saved = plan()
        let repository = WorkoutStoreRepositoryStub(held: [.plans])
        let value = store(repository)
        let request = Task { await value.loadPlans() }
        await repository.waitUntilStarted(.plans)
        _ = await value.savePlan(saved)
        await repository.release(.plans)
        await request.value
        XCTAssertEqual(value.plans.map(\.id), [saved.id], "Old empty list must not erase a newly saved plan")
    }

    func testEarlierReadSuccessCannotHideNewerSaveFailure() async {
        let repository = WorkoutStoreRepositoryStub(held: [.plans], failing: [.savePlan])
        let value = store(repository)
        let request = Task { await value.loadPlans() }
        await repository.waitUntilStarted(.plans)
        let saved = await value.savePlan(plan())
        XCTAssertNil(saved)
        XCTAssertEqual(value.errorMessage, WorkoutStoreStubError.failed.errorDescription)
        await repository.release(.plans)
        await request.value
        XCTAssertEqual(value.errorMessage, WorkoutStoreStubError.failed.errorDescription,
                       "An older list response must not hide the failed save's retry message")
    }

    func testStaleLibraryLoadCannotEraseSuccessfulCustomExerciseAndFavorite() async {
        let item = exercise()
        let repository = WorkoutStoreRepositoryStub(held: [.library])
        let value = store(repository)
        let request = Task { await value.loadLibrary() }
        await repository.waitUntilStarted(.library)
        _ = await value.saveExercise(item)
        await value.toggleFavorite(id: item.id)
        await repository.release(.library)
        await request.value
        XCTAssertEqual(value.exercises.map(\.id), [item.id])
        XCTAssertTrue(value.favorites.contains(item.id))
    }

    func testStaleLogLoadCannotEraseSuccessfulSetSave() async {
        let original = log()
        let repository = WorkoutStoreRepositoryStub(logs: [original.activityID: original], held: [.log])
        let value = store(repository)
        let request = Task { await value.loadLog(activityID: original.activityID) }
        await repository.waitUntilStarted(.log)
        var edited = original; edited.exercises[0].sets[0].weight = 80; edited.exercises[0].sets[0].reps = 8
        _ = await value.saveLog(edited)
        await repository.release(.log)
        _ = await request.value
        XCTAssertEqual(value.logs[original.activityID]?.exercises[0].sets[0].weight, 80)
        XCTAssertEqual(value.logs[original.activityID]?.exercises[0].sets[0].reps, 8)
    }

    func testConcurrentPlanLoadsAreCoalesced() async {
        let repository = WorkoutStoreRepositoryStub(held: [.plans])
        let value = store(repository)
        let request = Task { await value.loadPlans() }
        await repository.waitUntilStarted(.plans)
        await value.loadPlans()
        let calls = await repository.count(.plans)
        XCTAssertEqual(calls, 1)
        await repository.release(.plans)
        await request.value
        XCTAssertFalse(value.isLoadingPlans)
    }

    func testSignedOutStoreDoesNotSendMutations() async {
        let repository = WorkoutStoreRepositoryStub()
        let value = WorkoutStore(repository: repository)
        let saved = await value.savePlan(plan())
        XCTAssertNil(saved)
        let calls = await repository.count(.savePlan)
        XCTAssertEqual(calls, 0)
    }

    func testRevocationDiscardsInflightForeignPlanAndPreventsAnotherSharedRead() async {
        var foreign = plan(); foreign.ownerID = otherOwner
        let repository = WorkoutStoreRepositoryStub(plans: [foreign], held: [.plan])
        let value = store(repository)
        let request = Task { await value.plan(id: foreign.id) }
        await repository.waitUntilStarted(.plan)
        value.removeFriend(userID: otherOwner)
        await repository.release(.plan)
        let stale = await request.value
        XCTAssertNil(stale)
        let privatePlans = await value.sharedPlans(ownerID: otherOwner)
        XCTAssertNil(privatePlans)
        let calls = await repository.count(.plans)
        XCTAssertEqual(calls, 0)
        value.restoreFriend(userID: otherOwner)
        let restored = await value.sharedPlans(ownerID: otherOwner)
        XCTAssertEqual(restored?.map(\.id), [foreign.id])
    }

    func testCopyRetryAfterLostResponseUsesSameRequestAcrossStoreRestart() async throws {
        let suite = "FYRUP.CopyStore.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let source = plan(); let repository = WorkoutStoreRepositoryStub(plans: [source])
        await repository.loseNextCopyResponse()
        let initial = WorkoutStore(repository: repository, copyRequests: WorkoutCopyRequestStore(defaults: defaults))
        initial.activate(userID: owner)
        let lost = await initial.copyPlan(id: source.id)
        XCTAssertNil(lost); XCTAssertTrue(initial.plans.isEmpty)
        let relaunched = WorkoutStore(repository: repository, copyRequests: WorkoutCopyRequestStore(defaults: defaults))
        relaunched.activate(userID: owner)
        let retry = await relaunched.copyPlan(id: source.id)
        XCTAssertNotNil(retry); XCTAssertEqual(relaunched.plans.count, 1)
        let requests = await repository.copyIDs()
        XCTAssertEqual(requests.count, 2); XCTAssertEqual(requests.first, requests.last)
        let intentional = await relaunched.copyPlan(id: source.id)
        XCTAssertNotEqual(intentional?.id, retry?.id)
        let allRequests = await repository.copyIDs()
        XCTAssertNotEqual(allRequests[1], allRequests[2])
    }

    func testPendingCopyBlocksSecondTapAndConfirmationDeduplicatesPlanList() async {
        let source = plan(); let repository = WorkoutStoreRepositoryStub(plans: [source], held: [.copy])
        let value = store(repository)
        let pending = Task { await value.copyPlan(id: source.id) }
        await repository.waitUntilStarted(.copy)
        let secondTap = await value.copyPlan(id: source.id)
        XCTAssertNil(secondTap)
        let count = await repository.count(.copy); XCTAssertEqual(count, 1)
        await repository.release(.copy)
        let copy = await pending.value
        XCTAssertNotNil(copy); XCTAssertEqual(value.plans.count, 1)
    }

    func testWrongOwnerSourceOrRequestReceiptRemainsPending() async throws {
        for invalid in 0..<4 {
            let source = plan(); let repository = WorkoutStoreRepositoryStub(plans: [source])
            let requests = WorkoutCopyRequestStore()
            let request = try requests.requestID(sourceID: source.id, ownerID: owner)
            var forged = source.independentCopy(ownerID: owner); forged.copyRequestID = request
            if invalid == 0 { forged.ownerID = otherOwner }
            if invalid == 1 { forged.copyRequestID = UUID() }
            if invalid == 2 { forged.copiedFromPlanID = UUID() }
            if invalid == 3 { forged.id = source.id }
            await repository.overrideCopy(with: forged)
            let value = WorkoutStore(repository: repository, copyRequests: requests); value.activate(userID: owner)
            let rejected = await value.copyPlan(id: source.id)
            XCTAssertNil(rejected); XCTAssertTrue(value.plans.isEmpty)
            XCTAssertEqual(try requests.requestID(sourceID: source.id, ownerID: owner), request)
            await repository.overrideCopy(with: nil)
            let retry = await value.copyPlan(id: source.id)
            XCTAssertNotNil(retry)
            XCTAssertNotEqual(try requests.requestID(sourceID: source.id, ownerID: owner), request)
        }
    }

    func testLateCopyAfterAccountSwitchCannotClearOldPendingIntent() async throws {
        let source = plan(); let repository = WorkoutStoreRepositoryStub(plans: [source], held: [.copy])
        let requests = WorkoutCopyRequestStore()
        let request = try requests.requestID(sourceID: source.id, ownerID: owner)
        let value = WorkoutStore(repository: repository, copyRequests: requests); value.activate(userID: owner)
        let pending = Task { await value.copyPlan(id: source.id) }
        await repository.waitUntilStarted(.copy)
        value.activate(userID: otherOwner)
        await repository.release(.copy)
        let late = await pending.value
        XCTAssertNil(late); XCTAssertTrue(value.plans.isEmpty); XCTAssertFalse(value.isBusy)
        XCTAssertEqual(try requests.requestID(sourceID: source.id, ownerID: owner), request)
        value.activate(userID: owner)
        let retry = await value.copyPlan(id: source.id)
        XCTAssertNotNil(retry)
    }

    func testPendingIntentsAreAccountScopedAndOnlyConfirmationRetiresMatchingID() throws {
        let requests = WorkoutCopyRequestStore(); let source = UUID()
        let first = try requests.requestID(sourceID: source, ownerID: owner)
        let second = try requests.requestID(sourceID: source, ownerID: otherOwner)
        XCTAssertNotEqual(first, second)
        try requests.confirm(sourceID: source, ownerID: owner, requestID: second)
        XCTAssertEqual(try requests.requestID(sourceID: source, ownerID: owner), first)
        requests.clearAccount(ownerID: owner)
        XCTAssertNotEqual(try requests.requestID(sourceID: source, ownerID: owner), first)
        XCTAssertEqual(try requests.requestID(sourceID: source, ownerID: otherOwner), second)
    }

    func testUnreadablePendingIntentsDoNotCreateAnotherRemoteCopy() async throws {
        let suite = "FYRUP.CopyStoreCorrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "fyrup.workout-copy-requests.v1." + owner.uuidString
        for corrupt in [Data("broken".utf8), Data("{\"bad-source\":\"00000000-0000-0000-0000-000000000001\"}".utf8)] {
            defaults.set(corrupt, forKey: key)
            let source = plan(); let repository = WorkoutStoreRepositoryStub(plans: [source])
            let value = WorkoutStore(repository: repository, copyRequests: WorkoutCopyRequestStore(defaults: defaults)); value.activate(userID: owner)
            let copy = await value.copyPlan(id: source.id)
            XCTAssertNil(copy); XCTAssertEqual(defaults.data(forKey: key), corrupt)
            let count = await repository.count(.copy); XCTAssertEqual(count, 0)
        }
    }

    func testSeparatePersistenceSuitesCannotReuseAnotherDemoIntent() throws {
        let firstSuite = "FYRUP.CopyIsolation.\(UUID().uuidString)"
        let secondSuite = "FYRUP.CopyIsolation.\(UUID().uuidString)"
        let firstDefaults = try XCTUnwrap(UserDefaults(suiteName: firstSuite)); let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondSuite))
        defer { firstDefaults.removePersistentDomain(forName: firstSuite); secondDefaults.removePersistentDomain(forName: secondSuite) }
        let source = UUID()
        let first = try WorkoutCopyRequestStore(defaults: firstDefaults).requestID(sourceID: source, ownerID: owner)
        let second = try WorkoutCopyRequestStore(defaults: secondDefaults).requestID(sourceID: source, ownerID: owner)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try WorkoutCopyRequestStore(defaults: firstDefaults).requestID(sourceID: source, ownerID: owner), first)
    }

    func testRevocationCannotRepopulateInflightSharedPlans() async {
        var foreign = plan(); foreign.ownerID = otherOwner
        let repository = WorkoutStoreRepositoryStub(plans: [foreign], held: [.plans])
        let value = store(repository)
        let request = Task { await value.sharedPlans(ownerID: otherOwner) }
        await repository.waitUntilStarted(.plans)
        value.removeFriend(userID: otherOwner)
        await repository.release(.plans)
        let stale = await request.value
        XCTAssertNil(stale)
    }
}

private enum WorkoutStoreStubOperation: Hashable, Sendable {
    case plans, plan, library, favorites, log, savePlan, saveExercise, saveLog
    case archivePlan, archiveExercise, favorite, copy, share
}

private enum WorkoutStoreStubError: LocalizedError {
    case failed
    var errorDescription: String? { "Testverbindung fehlgeschlagen. Deine Eingaben bleiben erhalten." }
}

/// Deterministic suspension points; tests do not rely on sleeps or network timing.
private actor WorkoutStoreRepositoryStub: WorkoutRepository {
    private var savedPlans: [WorkoutPlan]
    private var savedExercises: [GymExercise]
    private var savedFavorites: Set<UUID>
    private var savedLogs: [UUID: WorkoutLog]
    private var held: Set<WorkoutStoreStubOperation>
    private var failing: Set<WorkoutStoreStubOperation>
    private var calls: [WorkoutStoreStubOperation: Int] = [:]
    private var gates: [WorkoutStoreStubOperation: [CheckedContinuation<Void, Never>]] = [:]
    private var observers: [WorkoutStoreStubOperation: [(id: UUID, count: Int, continuation: CheckedContinuation<Void, Never>)]] = [:]
    private var recordedCopyIDs: [UUID] = []
    private var copyReceipts: [UUID: WorkoutPlan] = [:]
    private var lostCopyReplies = 0
    private var copyOverride: WorkoutPlan?

    init(plans: [WorkoutPlan] = [], exercises: [GymExercise] = [], favorites: Set<UUID> = [], logs: [UUID: WorkoutLog] = [:],
         held: Set<WorkoutStoreStubOperation> = [], failing: Set<WorkoutStoreStubOperation> = []) {
        savedPlans = plans; savedExercises = exercises; savedFavorites = favorites; savedLogs = logs
        self.held = held; self.failing = failing
    }

    func count(_ operation: WorkoutStoreStubOperation) -> Int { calls[operation, default: 0] }
    func copyIDs() -> [UUID] { recordedCopyIDs }
    func loseNextCopyResponse() { lostCopyReplies += 1 }
    func overrideCopy(with value: WorkoutPlan?) { copyOverride = value }
    func setFailure(_ operation: WorkoutStoreStubOperation, enabled: Bool) {
        if enabled { failing.insert(operation) } else { failing.remove(operation) }
    }
    func waitUntilStarted(_ operation: WorkoutStoreStubOperation, count: Int = 1) async {
        if calls[operation, default: 0] >= count { return }
        let id = UUID()
        await withCheckedContinuation { continuation in
            observers[operation, default: []].append((id, count, continuation))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.timeoutObserver(id, operation: operation)
            }
        }
    }
    private func timeoutObserver(_ id: UUID, operation: WorkoutStoreStubOperation) {
        guard let waiting = observers[operation]?.first(where: { $0.id == id }) else { return }
        observers[operation]?.removeAll { $0.id == id }
        XCTFail("Repository operation \(operation) did not start within 3 seconds")
        waiting.continuation.resume()
    }
    func releaseFirst(_ operation: WorkoutStoreStubOperation) {
        guard var waiting = gates[operation], !waiting.isEmpty else { return }
        let first = waiting.removeFirst(); gates[operation] = waiting; first.resume()
    }
    func release(_ operation: WorkoutStoreStubOperation) {
        held.remove(operation)
        let waiting = gates.removeValue(forKey: operation) ?? []
        for continuation in waiting { continuation.resume() }
    }
    private func checkpoint(_ operation: WorkoutStoreStubOperation) async throws {
        calls[operation, default: 0] += 1
        let ready = observers[operation, default: []].filter { $0.count <= calls[operation, default: 0] }
        observers[operation] = observers[operation, default: []].filter { $0.count > calls[operation, default: 0] }
        for observer in ready { observer.continuation.resume() }
        if held.contains(operation) { await withCheckedContinuation { gates[operation, default: []].append($0) } }
        if failing.contains(operation) { throw WorkoutStoreStubError.failed }
    }

    func exercises() async throws -> [GymExercise] {
        let snapshot = savedExercises; try await checkpoint(.library); return snapshot
    }
    func exerciseFavorites() async throws -> [UUID] {
        let snapshot = Array(savedFavorites); try await checkpoint(.favorites); return snapshot
    }
    func workoutPlans(ownerID: UUID?) async throws -> [WorkoutPlan] {
        let snapshot = savedPlans.filter { ownerID == nil || $0.ownerID == ownerID }
        try await checkpoint(.plans); return snapshot
    }
    func workoutPlan(id: UUID) async throws -> WorkoutPlan {
        let snapshot = savedPlans.first { $0.id == id }; try await checkpoint(.plan)
        guard let snapshot else { throw WorkoutStoreStubError.failed }; return snapshot
    }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws -> WorkoutPlan {
        try await checkpoint(.savePlan)
        let saved = plan.normalizedForSaving()
        savedPlans.removeAll { $0.id == saved.id }; savedPlans.append(saved); return saved
    }
    func saveExercise(_ exercise: GymExercise) async throws -> GymExercise {
        try await checkpoint(.saveExercise)
        let saved = exercise.normalizedForSaving()
        savedExercises.removeAll { $0.id == saved.id }; savedExercises.append(saved); return saved
    }
    func archiveWorkoutPlan(id: UUID) async throws { try await checkpoint(.archivePlan); savedPlans.removeAll { $0.id == id } }
    func archiveExercise(id: UUID) async throws { try await checkpoint(.archiveExercise); savedExercises.removeAll { $0.id == id } }
    func favoriteExercise(id: UUID, favorite: Bool) async throws {
        try await checkpoint(.favorite)
        if favorite { savedFavorites.insert(id) } else { savedFavorites.remove(id) }
    }
    func copyWorkoutPlan(id: UUID, requestID: UUID) async throws -> WorkoutPlan {
        recordedCopyIDs.append(requestID)
        try await checkpoint(.copy)
        if let copyOverride { return copyOverride }
        if let receipt = copyReceipts[requestID] { return receipt }
        guard let source = savedPlans.first(where: { $0.id == id }) else { throw WorkoutStoreStubError.failed }
        var copied = source.independentCopy(ownerID: source.ownerID); copied.copyRequestID = requestID
        savedPlans.append(copied); copyReceipts[requestID] = copied
        if lostCopyReplies > 0 { lostCopyReplies -= 1; throw WorkoutStoreStubError.failed }
        return copied
    }
    func shareWorkoutPlan(id: UUID, friendIDs: [UUID]) async throws { try await checkpoint(.share) }
    func workoutLog(activityID: UUID) async throws -> WorkoutLog {
        let snapshot = savedLogs[activityID]; try await checkpoint(.log)
        guard let snapshot else { throw WorkoutStoreStubError.failed }; return snapshot
    }
    func saveWorkoutLog(_ log: WorkoutLog) async throws -> WorkoutLog {
        try await checkpoint(.saveLog); savedLogs[log.activityID] = log; return log
    }
    func startWorkout(planID: UUID, linkedActivityID: UUID?, sessionID: UUID?, placeName: String?) async throws -> Activity { throw WorkoutStoreStubError.failed }
    func planWorkout(planID: UUID, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws -> PlannedSession { throw WorkoutStoreStubError.failed }
}
