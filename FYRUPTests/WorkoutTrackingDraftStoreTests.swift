import XCTest
@testable import FYRUP

@MainActor
final class WorkoutTrackingDraftStoreTests: XCTestCase {
    func testRawInvalidTextAndWhitespaceSurviveRelaunchWithoutBecomingMeasurements() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let context = try rig.context()
        let input = WorkoutSetEntryInput(weight: " 80, ", reps: "acht?")
        XCTAssertNotNil(input.validationMessage)
        XCTAssertTrue(rig.store.saveInput(input, context: context))
        let restored = rig.relaunch()
        guard case .restored(let value) = restored.input(for: context) else { return XCTFail("Raw draft missing") }
        XCTAssertEqual(value, input)
        XCTAssertNil(context.baseline.weight); XCTAssertNil(context.baseline.reps)
    }

    func testIntentionallyClearedFieldsRemainEmptyAfterRelaunch() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        var log = TrackingDraftFixture.log(); log.exercises[0].sets[0].weight = 80; log.exercises[0].sets[0].reps = 8
        let context = try rig.context(log: log)
        XCTAssertTrue(rig.store.saveInput(WorkoutSetEntryInput(), context: context))
        guard case .restored(let value) = rig.relaunch().input(for: context) else { return XCTFail("Empty edit missing") }
        XCTAssertEqual(value.weight, ""); XCTAssertEqual(value.reps, "")
    }

    func testAccountSwitchAndOldContextsCannotReadOrWriteAnotherAccount() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let context = try rig.context(); let input = WorkoutSetEntryInput(weight: "81", reps: "9")
        XCTAssertTrue(rig.store.saveInput(input, context: context))
        rig.store.activate(userID: UUID())
        guard case .none = rig.store.input(for: context) else { return XCTFail("Foreign draft visible") }
        XCTAssertFalse(rig.store.saveInput(input, context: context))
        rig.store.removeInput(context: context)
        rig.store.activate(userID: TrackingDraftFixture.owner)
        guard case .restored(let value) = rig.store.input(for: context) else { return XCTFail("Other account removed original draft") }
        XCTAssertEqual(value, input)
    }

    func testExplicitDiscardAndAccountCleanupPersistAndDoNotLeaveRecoveryCopies() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let context = try rig.context()
        XCTAssertTrue(rig.store.saveInput(.init(weight: "82", reps: "10"), context: context))
        rig.store.removeInput(context: context)
        guard case .none = rig.relaunch().input(for: context) else { return XCTFail("Discard was not persisted") }
        XCTAssertTrue(rig.store.saveInput(.init(weight: "83"), context: context))
        rig.store.clearCurrentAccount()
        XCTAssertNil(rig.store.userID); XCTAssertNil(rig.defaults.data(forKey: rig.key))
        guard case .none = rig.relaunch().input(for: context) else { return XCTFail("Logout retained draft") }
    }

    func testChangedServerSetRequiresReviewInsteadOfReplacingNewValues() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let initial = try rig.context(); let raw = WorkoutSetEntryInput(weight: "80,25", reps: "8")
        XCTAssertTrue(rig.store.saveInput(raw, context: initial))
        var log = TrackingDraftFixture.log(); log.exercises[0].sets[0].weight = 90
        let fresh = try rig.context(log: log)
        guard case .conflict(let preserved) = rig.relaunch().input(for: fresh) else { return XCTFail("Changed baseline silently replaced") }
        XCTAssertEqual(preserved, raw)
        XCTAssertEqual(fresh.baseline.weight, 90)
    }

    func testOnlyFreshCurrentRecipientBlindSetCanConstructRecoveryContext() throws {
        let state = TrackingDraftFixture.blind()
        XCTAssertTrue(state.isValid)
        let current = try XCTUnwrap(state.currentExercise)
        let set = try XCTUnwrap(current.sets.first)
        XCTAssertNotNil(WorkoutSetDraftContext.blind(ownerID: TrackingDraftFixture.owner, state: state, exerciseID: current.id, setID: set.id))
        XCTAssertNil(WorkoutSetDraftContext.blind(ownerID: UUID(), state: state, exerciseID: current.id, setID: set.id))
        XCTAssertNil(WorkoutSetDraftContext.blind(ownerID: TrackingDraftFixture.owner, state: state, exerciseID: TrackingDraftFixture.row(1).id, setID: TrackingDraftFixture.row(1).sets[0].id))
        let advanced = TrackingDraftFixture.blind(completed: 1)
        XCTAssertTrue(advanced.isValid)
        XCTAssertNil(WorkoutSetDraftContext.blind(ownerID: TrackingDraftFixture.owner, state: advanced, exerciseID: current.id, setID: set.id))
        let creator = TrackingDraftFixture.blind(creator: true)
        XCTAssertTrue(creator.isValid)
        XCTAssertNil(WorkoutSetDraftContext.blind(ownerID: TrackingDraftFixture.creator, state: creator, exerciseID: current.id, setID: set.id))
    }

    func testBlindDraftPersistsOnlyOwnRawInputAndSetBaselineNotPlanDetails() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let state = TrackingDraftFixture.blind(); let row = try XCTUnwrap(state.currentExercise)
        let context = try XCTUnwrap(WorkoutSetDraftContext.blind(ownerID: TrackingDraftFixture.owner, state: state, exerciseID: row.id, setID: row.sets[0].id))
        XCTAssertTrue(rig.store.saveInput(.init(weight: "75,5", reps: " 8 "), context: context))
        let text = String(decoding: try XCTUnwrap(rig.defaults.data(forKey: rig.key)), as: UTF8.self)
        XCTAssertFalse(text.contains("Geheime Übung")); XCTAssertFalse(text.contains("Unsichtbare Übung"))
        XCTAssertFalse(text.contains("targetWeight")); XCTAssertFalse(text.contains("target_weight")); XCTAssertFalse(text.contains("Privater Hinweis"))
        guard case .restored(let restored) = rig.relaunch().input(for: context) else { return XCTFail("Blind raw input missing") }
        XCTAssertEqual(restored.weight, "75,5"); XCTAssertEqual(restored.reps, " 8 ")
    }

    func testPendingLogSurvivesTerminationButIsNotMarkedConfirmed() {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let baseline = TrackingDraftFixture.log(); var candidate = baseline
        candidate.exercises[0].sets[0].weight = 80; candidate.exercises[0].completed = true
        XCTAssertTrue(rig.store.savePending(candidate, baseline: baseline, activity: TrackingDraftFixture.activity()))
        guard case .restored(let restored) = rig.relaunch().recoverPending(activity: TrackingDraftFixture.activity(), confirmed: baseline) else { return XCTFail("Pending log missing") }
        XCTAssertEqual(restored.exercises[0].sets[0].weight, 80)
        XCTAssertTrue(restored.exercises[0].completed)
        XCTAssertNil(baseline.exercises[0].sets[0].weight); XCTAssertFalse(baseline.exercises[0].completed)
    }

    func testLostSaveResponseRecognizesServerReceiptWithoutAnotherUpload() {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let baseline = TrackingDraftFixture.log(); var candidate = baseline
        candidate.exercises[0].completed = true; candidate.exercises[0].sets[0].completed = true
        candidate.exercises[0].sets[0].weight = 80
        XCTAssertTrue(rig.store.savePending(candidate, baseline: baseline, activity: TrackingDraftFixture.activity()))
        var server = candidate
        server.exercises[0].completedAt = TrackingDraftFixture.now
        server.exercises[0].sets[0].completedAt = TrackingDraftFixture.now
        let restored = rig.relaunch()
        guard case .alreadySaved = restored.recoverPending(activity: TrackingDraftFixture.activity(), confirmed: server) else { return XCTFail("Matching server receipt not recognized") }
        guard case .none = rig.relaunch().recoverPending(activity: TrackingDraftFixture.activity(), confirmed: server) else { return XCTFail("Confirmed pending draft not cleared") }
    }

    func testDifferentServerLogNeverReceivesOldPendingDataAutomatically() {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let baseline = TrackingDraftFixture.log(); var candidate = baseline; candidate.exercises[0].sets[0].weight = 80
        XCTAssertTrue(rig.store.savePending(candidate, baseline: baseline, activity: TrackingDraftFixture.activity()))
        var server = baseline; server.exercises[0].sets[0].weight = 100
        guard case .conflict = rig.relaunch().recoverPending(activity: TrackingDraftFixture.activity(), confirmed: server) else { return XCTFail("Stale draft replaced newer values") }
        guard case .conflict = rig.relaunch().recoverPending(activity: TrackingDraftFixture.activity(), confirmed: server) else { return XCTFail("Conflict was silently discarded") }
        XCTAssertEqual(server.exercises[0].sets[0].weight, 100)
    }

    func testPendingLogCannotAlterExerciseIdentityTargetsOrEnterBlindFlow() {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let baseline = TrackingDraftFixture.log(); var changed = baseline
        changed.exercises[0].targetWeight = 999
        XCTAssertFalse(rig.store.savePending(changed, baseline: baseline, activity: TrackingDraftFixture.activity()))
        changed = baseline; changed.exercises[0].exercise.name = "Fremde Übung"
        XCTAssertFalse(rig.store.savePending(changed, baseline: baseline, activity: TrackingDraftFixture.activity()))
        var activity = TrackingDraftFixture.activity(); activity.blindWorkoutID = UUID()
        XCTAssertFalse(rig.store.savePending(baseline, baseline: baseline, activity: activity))
        activity = TrackingDraftFixture.activity(); activity.status = .completed
        XCTAssertFalse(rig.store.savePending(baseline, baseline: baseline, activity: activity))
    }

    func testCorruptStorageIsPreservedAndCannotBeSilentlyOverwritten() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let original = Data("unreadable draft bytes".utf8); rig.defaults.set(original, forKey: rig.key)
        let restored = rig.relaunch(); let context = try rig.context()
        XCTAssertNotNil(restored.errorMessage)
        XCTAssertFalse(restored.saveInput(.init(weight: "80"), context: context))
        XCTAssertEqual(rig.defaults.data(forKey: rig.key), original)
        restored.clearCurrentAccount()
        XCTAssertNil(rig.defaults.data(forKey: rig.key))
    }

    func testExistingNonDataStorageIsNotMistakenForMissingAndOverwritten() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        rig.defaults.set("unexpected old storage type", forKey: rig.key)
        let restored = rig.relaunch()
        XCTAssertNotNil(restored.errorMessage)
        XCTAssertFalse(restored.saveInput(.init(weight: "90"), context: try rig.context()))
        XCTAssertEqual(rig.defaults.string(forKey: rig.key), "unexpected old storage type")
    }

    func testLostAddSetReceiptUsesServerIDAndKeepsNewRawDraftOnItsConfirmedSet() throws {
        let rig = TrackingDraftRig(); defer { rig.cleanUp() }
        let baseline = TrackingDraftFixture.log(); var candidate = baseline
        let clientSet = WorkoutSetLog(setNumber: 2)
        candidate.exercises[0].sets.append(clientSet)
        XCTAssertTrue(rig.store.savePending(candidate, baseline: baseline, activity: TrackingDraftFixture.activity()))
        let context = try XCTUnwrap(WorkoutSetDraftContext.workout(ownerID: TrackingDraftFixture.owner, activity: TrackingDraftFixture.activity(), log: candidate,
            exerciseID: candidate.exercises[0].id, setID: clientSet.id))
        XCTAssertTrue(rig.store.saveInput(.init(weight: "85,5", reps: "9?"), context: context))
        var receipt = candidate; receipt.exercises[0].sets[1].id = UUID()
        let restored = rig.relaunch()
        guard case .alreadySaved = restored.recoverPending(activity: TrackingDraftFixture.activity(), confirmed: receipt) else { return XCTFail("New server set ID incorrectly treated as conflict") }
        let freshContext = try XCTUnwrap(WorkoutSetDraftContext.workout(ownerID: TrackingDraftFixture.owner, activity: TrackingDraftFixture.activity(), log: receipt,
            exerciseID: receipt.exercises[0].id, setID: receipt.exercises[0].sets[1].id))
        guard case .restored(let raw) = rig.relaunch().input(for: freshContext) else { return XCTFail("Unsaved raw draft was stranded on client-only set ID") }
        XCTAssertEqual(raw.weight, "85,5"); XCTAssertEqual(raw.reps, "9?")
        XCTAssertNil(receipt.exercises[0].sets[1].weight)
    }
}

private enum TrackingDraftFixture {
    static let owner = UUID(uuidString: "84000000-0000-0000-0000-000000000001")!
    static let creator = UUID(uuidString: "84000000-0000-0000-0000-000000000002")!
    static let activityID = UUID(uuidString: "84000000-0000-0000-0000-000000000003")!
    static let blindID = UUID(uuidString: "84000000-0000-0000-0000-000000000004")!
    static let now = Date(timeIntervalSince1970: 1_788_609_600)
    static func activity() -> Activity {
        Activity(id: activityID, userID: owner, sport: .gym, subtype: "Privater Plan", status: .live,
                 plannedAt: nil, startedAt: now, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil,
                 workoutPlanID: UUID(uuidString: "84000000-0000-0000-0000-000000000005")!)
    }
    static func row(_ index: Int, completed: Bool = false) -> WorkoutExerciseLog {
        let exercise = GymExercise(id: UUID(uuidString: String(format: "84000000-0000-0000-0001-%012d", index + 1))!,
                                   name: index == 0 ? "Geheime Übung" : "Unsichtbare Übung", primaryMuscle: .chest, equipment: .barbell, isCustom: false)
        let set = WorkoutSetLog(id: UUID(uuidString: String(format: "84000000-0000-0000-0003-%012d", index + 1))!, setNumber: 1)
        return WorkoutExerciseLog(id: UUID(uuidString: String(format: "84000000-0000-0000-0002-%012d", index + 1))!, exercise: exercise,
                                  sortOrder: index, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, targetWeight: 80,
                                  note: "Privater Hinweis", completed: completed, completedAt: completed ? now : nil, sets: [set])
    }
    static func log() -> WorkoutLog { WorkoutLog(activityID: activityID, planName: "Privater Plan", exercises: [row(0), row(1)]) }
    static func blind(completed: Int = 0, creator: Bool = false) -> BlindWorkoutState {
        let summary = BlindWorkoutSummary(id: blindID, creatorID: Self.creator, recipientID: owner, creatorName: "Max", recipientName: "Momo",
            title: "Überraschung", focus: .push, estimatedDurationMinutes: 45, exerciseCount: 2, requiredEquipment: [.barbell], muscleGroups: [.chest],
            status: .live, createdAt: now.addingTimeInterval(-300), scheduledAt: nil, acceptedAt: now.addingTimeInterval(-100), startedAt: now,
            completedAt: nil, activityID: activityID, completedExercises: completed)
        var activity = Self.activity(); activity.workoutPlanID = nil; activity.blindWorkoutID = blindID
        let rows: [WorkoutExerciseLog]
        if creator { rows = (0..<2).map { index in var value = row(index); value.sets = []; return value } }
        else { rows = (0..<min(completed + 1, 2)).map { row($0, completed: $0 < completed) } }
        return BlindWorkoutState(summary: summary, viewerRole: creator ? .creator : .recipient, visibleExercises: rows, activity: creator ? nil : activity)
    }
}

@MainActor
private struct TrackingDraftRig {
    let defaults: UserDefaults
    let suite: String
    let store: WorkoutTrackingDraftStore
    var key: String { "app.fyrup.tracking-drafts.v1.\(TrackingDraftFixture.owner.uuidString)" }
    init() {
        let suite = "FYRUP.TrackingDraftTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        self.suite = suite; self.defaults = defaults
        store = WorkoutTrackingDraftStore(defaults: defaults); store.activate(userID: TrackingDraftFixture.owner)
    }
    func context(log: WorkoutLog = TrackingDraftFixture.log()) throws -> WorkoutSetDraftContext {
        try XCTUnwrap(WorkoutSetDraftContext.workout(ownerID: TrackingDraftFixture.owner, activity: TrackingDraftFixture.activity(), log: log,
                     exerciseID: log.exercises[0].id, setID: log.exercises[0].sets[0].id))
    }
    func relaunch() -> WorkoutTrackingDraftStore {
        let value = WorkoutTrackingDraftStore(defaults: defaults); value.activate(userID: TrackingDraftFixture.owner); return value
    }
    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}
