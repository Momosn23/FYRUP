import XCTest
@testable import FYRUP

@MainActor
final class NotificationPreferenceStoreTests: XCTestCase {
    func testSignedOutAndUnknownNeverReadOrWriteDefaults() async {
        let rig = NotificationPreferenceRig()
        await rig.store.refresh()
        let signedOut = await rig.store.save(.standard, expected: .standard)
        rig.store.activate(userID: rig.owner)
        let unknown = await rig.store.save(.standard, expected: .standard)
        XCTAssertFalse(signedOut); XCTAssertFalse(unknown)
        XCTAssertNil(rig.store.value); XCTAssertNil(rig.store.confirmedValue)
        XCTAssertEqual(rig.api.reads, 0); XCTAssertTrue(rig.api.writes.isEmpty)
    }

    func testInitialReadFailureRemainsUnknownInsteadOfUsingStandard() async {
        let rig = NotificationPreferenceRig()
        rig.api.readOverride = { throw PreferenceTestError.unavailable }
        await rig.activate()
        XCTAssertNil(rig.store.value); XCTAssertFalse(rig.store.isConfirmed)
        XCTAssertNotNil(rig.store.errorMessage); XCTAssertFalse(rig.store.isBusy)
        let saved = await rig.store.save(.standard, expected: .standard)
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
    }

    func testFailedRefreshRetainsOnlyDisabledLastKnownOptOuts() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        rig.api.readOverride = { throw PreferenceTestError.unavailable }
        await rig.store.refresh()
        XCTAssertEqual(rig.store.value, NotificationPreferenceRig.muted)
        XCTAssertNil(rig.store.confirmedValue); XCTAssertFalse(rig.store.isConfirmed)
        let saved = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
    }

    func testExplicitSuccessfulReloadAndSameAccountActivationPreserveConfirmation() async {
        let rig = NotificationPreferenceRig()
        rig.api.readOverride = { throw PreferenceTestError.unavailable }
        await rig.activate()
        rig.api.readOverride = nil
        await rig.store.refresh()
        rig.store.activate(userID: rig.owner)
        XCTAssertEqual(rig.store.confirmedValue, NotificationPreferenceRig.muted)
        XCTAssertNil(rig.store.errorMessage)
    }

    func testSaveChangesOnlyChosenCategoryAndRequiresConfirmedResponse() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        var draft = NotificationPreferenceRig.muted; draft.invitations = true
        let saved = await rig.store.save(draft, expected: NotificationPreferenceRig.muted)
        XCTAssertTrue(saved); XCTAssertEqual(rig.store.confirmedValue, draft)
        XCTAssertEqual(rig.api.writes, [draft]); XCTAssertEqual(rig.api.reads, 2)
        XCTAssertEqual(rig.api.expectedSnapshots, [NotificationPreferenceRig.muted])
        XCTAssertFalse(rig.store.value?.reactions ?? true)
        XCTAssertFalse(rig.store.value?.weeklyGoal ?? true)
        XCTAssertFalse(rig.store.value?.friendRequests ?? true)
    }

    func testUnchangedConfirmedDraftNeedsNoWrite() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        let saved = await rig.store.save(NotificationPreferenceRig.muted, expected: NotificationPreferenceRig.muted)
        XCTAssertTrue(saved); XCTAssertTrue(rig.api.writes.isEmpty)
        XCTAssertEqual(rig.api.reads, 1)
    }

    func testPreflightReadFailureCannotOverwriteOptOuts() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        rig.api.readOverride = { throw PreferenceTestError.unavailable }
        let saved = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
        XCTAssertNil(rig.store.confirmedValue)
        XCTAssertEqual(rig.store.value, NotificationPreferenceRig.muted)
    }

    func testNewRemoteOptOutStopsStaleFullRecordSaveUntilReviewed() async {
        let rig = NotificationPreferenceRig()
        rig.api.stored = .standard
        await rig.activate()
        var staleDraft = NotificationPreferences.standard; staleDraft.reminders = false
        rig.api.stored.reactions = false; rig.api.stored.weeklyGoal = false
        let saved = await rig.store.save(staleDraft, expected: .standard)
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
        XCTAssertEqual(rig.store.confirmedValue, rig.api.stored)
        XCTAssertNotNil(rig.store.errorMessage)
        let unreviewedRetry = await rig.store.save(staleDraft, expected: .standard)
        XCTAssertFalse(unreviewedRetry); XCTAssertEqual(rig.api.reads, 2)
        var reviewed = rig.api.stored; reviewed.reminders = false
        let baseline = rig.api.stored
        let afterReview = await rig.store.save(reviewed, expected: baseline)
        XCTAssertTrue(afterReview)
        XCTAssertEqual(rig.api.writes, [reviewed])
        XCTAssertFalse(reviewed.reactions); XCTAssertFalse(reviewed.weeklyGoal)
    }

    func testLostWriteResponseIsUnknownAndNeverAutomaticallyRetried() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        rig.api.writeOverride = { draft, _ in
            rig.api.stored = draft
            throw PreferenceTestError.unavailable
        }
        let first = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        let retry = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        XCTAssertFalse(first); XCTAssertFalse(retry)
        XCTAssertEqual(rig.api.writes.count, 1); XCTAssertNil(rig.store.confirmedValue)
        await rig.store.refresh()
        XCTAssertEqual(rig.store.confirmedValue, .standard)
        XCTAssertEqual(rig.api.writes.count, 1)
    }

    func testMismatchedWriteReceiptCannotAuthorizeAnotherSave() async {
        let rig = NotificationPreferenceRig()
        await rig.activate()
        rig.api.writeOverride = { _, _ in NotificationPreferenceRig.muted }
        let saved = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        XCTAssertFalse(saved); XCTAssertNil(rig.store.confirmedValue)
        XCTAssertNotNil(rig.store.errorMessage)
        let retry = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        XCTAssertFalse(retry); XCTAssertEqual(rig.api.writes.count, 1)
    }

    func testPendingSaveBlocksSecondTapAndBackgroundRefresh() async {
        let rig = NotificationPreferenceRig(); let gate = PreferenceReplyGate()
        await rig.activate()
        rig.api.writeOverride = { _, _ in try await gate.response() }
        let pending = Task { await rig.store.save(.standard, expected: NotificationPreferenceRig.muted) }
        await gate.waitForRequest()
        XCTAssertTrue(rig.store.isSaving)
        let duplicate = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        await rig.store.refresh()
        XCTAssertFalse(duplicate); XCTAssertEqual(rig.api.writes.count, 1)
        XCTAssertEqual(rig.api.reads, 2)
        gate.resolve(.success(.standard))
        let saved = await pending.value
        XCTAssertTrue(saved); XCTAssertFalse(rig.store.isBusy)
    }

    func testPendingReadBlocksSaveAndDuplicateRead() async {
        let rig = NotificationPreferenceRig(); let gate = PreferenceReplyGate()
        await rig.activate()
        rig.api.readOverride = { try await gate.response() }
        let pending = Task { await rig.store.refresh() }
        await gate.waitForRequest()
        XCTAssertTrue(rig.store.isLoading); XCTAssertNil(rig.store.confirmedValue)
        let saved = await rig.store.save(.standard, expected: NotificationPreferenceRig.muted)
        await rig.store.refresh()
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
        XCTAssertEqual(rig.api.reads, 2)
        gate.resolve(.success(NotificationPreferenceRig.muted)); await pending.value
        XCTAssertTrue(rig.store.isConfirmed)
    }

    func testLateReadCannotRestoreOldAccountOrClearNewAccountLoading() async {
        let rig = NotificationPreferenceRig(); let oldGate = PreferenceReplyGate(); let newGate = PreferenceReplyGate()
        rig.store.activate(userID: rig.owner)
        rig.api.readOverride = { try await oldGate.response() }
        let oldRead = Task { await rig.store.refresh() }; await oldGate.waitForRequest()
        let other = UUID(); rig.store.activate(userID: other)
        rig.api.readOverride = { try await newGate.response() }
        let newRead = Task { await rig.store.refresh() }; await newGate.waitForRequest()
        oldGate.resolve(.success(.standard)); await oldRead.value
        XCTAssertEqual(rig.store.userID, other); XCTAssertNil(rig.store.value)
        XCTAssertTrue(rig.store.isLoading)
        newGate.resolve(.success(NotificationPreferenceRig.muted)); await newRead.value
        XCTAssertEqual(rig.store.confirmedValue, NotificationPreferenceRig.muted)
    }

    func testAccountSwitchDuringPreflightNeverSendsTheOldDraft() async {
        let rig = NotificationPreferenceRig(); let gate = PreferenceReplyGate()
        await rig.activate()
        rig.api.readOverride = { try await gate.response() }
        let pending = Task { await rig.store.save(.standard, expected: NotificationPreferenceRig.muted) }
        await gate.waitForRequest()
        rig.store.activate(userID: UUID())
        gate.resolve(.success(NotificationPreferenceRig.muted))
        let saved = await pending.value
        XCTAssertFalse(saved); XCTAssertTrue(rig.api.writes.isEmpty)
        XCTAssertNil(rig.store.value); XCTAssertNil(rig.store.errorMessage)
    }

    func testLateWriteAfterLogoutCannotConfirmOldAccount() async {
        let rig = NotificationPreferenceRig(); let gate = PreferenceReplyGate()
        await rig.activate()
        rig.api.writeOverride = { _, _ in try await gate.response() }
        let pending = Task { await rig.store.save(.standard, expected: NotificationPreferenceRig.muted) }
        await gate.waitForRequest()
        rig.store.activate(userID: nil)
        XCTAssertNil(rig.store.userID); XCTAssertNil(rig.store.value); XCTAssertFalse(rig.store.isBusy)
        gate.resolve(.success(.standard))
        let saved = await pending.value
        XCTAssertFalse(saved); XCTAssertNil(rig.store.confirmedValue)
        XCTAssertNil(rig.store.errorMessage)
    }

    func testOldReadFailureCannotPoisonNewAccountConfirmation() async {
        let rig = NotificationPreferenceRig(); let gate = PreferenceReplyGate()
        rig.store.activate(userID: rig.owner)
        rig.api.readOverride = { try await gate.response() }
        let pending = Task { await rig.store.refresh() }; await gate.waitForRequest()
        rig.store.activate(userID: UUID()); rig.api.readOverride = nil
        await rig.store.refresh()
        gate.resolve(.failure(PreferenceTestError.unavailable)); await pending.value
        XCTAssertEqual(rig.store.confirmedValue, NotificationPreferenceRig.muted)
        XCTAssertNil(rig.store.errorMessage)
    }

    func testRemoteOptOutBetweenPreflightAndCASCannotBeOverwritten() async {
        let rig = NotificationPreferenceRig()
        rig.api.stored = .standard
        await rig.activate()
        var draft = NotificationPreferences.standard; draft.reminders = false
        rig.api.beforeCAS = { rig.api.stored.reactions = false; rig.api.stored.weeklyGoal = false }
        let rejected = await rig.store.save(draft, expected: .standard)
        XCTAssertFalse(rejected)
        XCTAssertEqual(rig.api.reads, 2)
        XCTAssertEqual(rig.api.expectedSnapshots, [.standard])
        XCTAssertFalse(rig.api.stored.reactions); XCTAssertFalse(rig.api.stored.weeklyGoal)
        XCTAssertTrue(rig.api.stored.reminders)
        XCTAssertNil(rig.store.confirmedValue)
        XCTAssertNotNil(rig.store.errorMessage)
        rig.api.beforeCAS = nil
        await rig.store.refresh()
        let baseline = rig.api.stored
        var reviewed = baseline; reviewed.reminders = false
        let saved = await rig.store.save(reviewed, expected: baseline)
        XCTAssertTrue(saved)
        XCTAssertFalse(rig.api.stored.reactions); XCTAssertFalse(rig.api.stored.weeklyGoal)
        XCTAssertFalse(rig.api.stored.reminders)
    }

    func testCASRequestEncodesBothCompleteEightFieldSnapshots() throws {
        var desired = NotificationPreferenceRig.muted; desired.invitations = true
        let request = NotificationPreferenceSaveRequest(expected: NotificationPreferenceRig.muted, desired: desired)
        let data = try JSONEncoder().encode(request)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String: Bool]])
        XCTAssertEqual(Set(root.keys), Set(["p_expected", "p_desired"]))
        XCTAssertEqual(root["p_expected"]?.count, 8)
        XCTAssertEqual(root["p_desired"]?.count, 8)
        XCTAssertEqual(root["p_expected"]?["invitations"], false)
        XCTAssertEqual(root["p_desired"]?["invitations"], true)
        XCTAssertEqual(root["p_desired"]?["reactions"], false)
        XCTAssertNil(root["p_user"])
    }

    func testDemoCASRejectsStaleSaveAndPreservesExplicitOptOuts() async throws {
        let repository = DemoRepository()
        var deviceB = NotificationPreferences.standard; deviceB.reactions = false; deviceB.weeklyGoal = false
        let saved = try await repository.saveNotificationPreferences(deviceB, expected: .standard)
        XCTAssertEqual(saved, deviceB)
        var staleA = NotificationPreferences.standard; staleA.reminders = false
        do {
            _ = try await repository.saveNotificationPreferences(staleA, expected: .standard)
            XCTFail("A stale device must not overwrite B's opt-outs")
        } catch {
            guard case .conflict = error as? AppError else { XCTFail("Expected a CAS conflict"); return }
        }
        let after = try await repository.notificationPreferences()
        XCTAssertEqual(after, deviceB)
        let retry = try await repository.saveNotificationPreferences(deviceB, expected: .standard)
        XCTAssertEqual(retry, deviceB)
    }

    func testCASBackendErrorsAreActionableWithoutLeakingCodes() {
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "notification_preferences_conflict"),
                       .conflict("Die Einstellungen wurden inzwischen geändert. Bitte prüfe den aktuellen Stand, bevor du speicherst."))
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "invalid_notification_preferences"),
                       .validation("Bitte lade deine Mitteilungseinstellungen erneut und prüfe alle Kategorien."))
    }
}

private enum PreferenceTestError: Error { case unavailable }

@MainActor
private final class NotificationPreferenceRig {
    static let muted = NotificationPreferences(friendStarts: false, fyrup: false, invitations: false,
        reactions: false, friendRequests: false, reminders: false, weeklyGoal: false, crewGoal: false)
    let owner = UUID()
    let api: PreferenceTestAPI
    let store: NotificationPreferenceStore

    init() {
        let api = PreferenceTestAPI(); self.api = api
        store = NotificationPreferenceStore(read: { try await api.read() }, write: { try await api.write($0, expected: $1) })
    }
    func activate() async { store.activate(userID: owner); await store.refresh() }
}

@MainActor
private final class PreferenceTestAPI {
    var stored = NotificationPreferenceRig.muted
    var readOverride: NotificationPreferenceStore.Read?
    var writeOverride: NotificationPreferenceStore.Write?
    var reads = 0
    var writes: [NotificationPreferences] = []
    var expectedSnapshots: [NotificationPreferences] = []
    var beforeCAS: (() -> Void)?
    func read() async throws -> NotificationPreferences {
        reads += 1
        if let readOverride { return try await readOverride() }
        return stored
    }
    func write(_ draft: NotificationPreferences, expected: NotificationPreferences) async throws -> NotificationPreferences {
        writes.append(draft)
        expectedSnapshots.append(expected)
        beforeCAS?()
        guard stored == draft || stored == expected else { throw AppError.conflict("notification_preferences_conflict") }
        if let writeOverride { return try await writeOverride(draft, expected) }
        stored = draft; return draft
    }
}

@MainActor
private final class PreferenceReplyGate {
    private var continuation: CheckedContinuation<NotificationPreferences, Error>?
    private var result: Result<NotificationPreferences, Error>?
    private var requested = false
    func response() async throws -> NotificationPreferences {
        requested = true
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func resolve(_ value: Result<NotificationPreferences, Error>) {
        result = value; continuation?.resume(with: value); continuation = nil
    }
    func waitForRequest(file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !requested && ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(requested, "Expected request did not start", file: file, line: line)
    }
}
