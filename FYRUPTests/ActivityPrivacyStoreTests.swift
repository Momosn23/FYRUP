import XCTest
@testable import FYRUP

@MainActor
final class ActivityPrivacyStoreTests: XCTestCase {
    func testSignedOutAndUnknownNeverWriteADefault() async {
        let rig = PrivacyRig()
        await rig.store.refresh()
        let signedOut = await rig.store.save(.nobody)
        rig.store.activate(userID: rig.owner)
        let unknown = await rig.store.save(.nobody)
        XCTAssertFalse(signedOut); XCTAssertFalse(unknown)
        XCTAssertEqual(rig.reads, 0); XCTAssertEqual(rig.writes, 0)
        XCTAssertNil(rig.store.confirmedValue)
    }

    func testReadFailureIsUnknownAndCanBeReloaded() async {
        let rig = PrivacyRig()
        rig.readOverride = { _ in throw AppError.network }
        await rig.activate()
        XCTAssertNil(rig.store.value); XCTAssertNotNil(rig.store.errorMessage)
        rig.readOverride = nil; await rig.store.refresh()
        XCTAssertEqual(rig.store.confirmedValue, .friends); XCTAssertNil(rig.store.errorMessage)
    }

    func testWrongOwnerAndInvalidReadAreRejected() async {
        let rig = PrivacyRig()
        rig.readOverride = { _ in PrivacyRig.profile(owner: UUID()) }
        await rig.activate()
        XCTAssertNil(rig.store.confirmedValue)
        rig.readOverride = { owner in var value = PrivacyRig.profile(owner: owner); value.activityVisibility = "public"; return value }
        await rig.store.refresh()
        XCTAssertNil(rig.store.confirmedValue); XCTAssertNotNil(rig.store.errorMessage)
    }

    func testAcknowledgedSaveAndNoOp() async {
        let rig = PrivacyRig(); await rig.activate()
        let unchanged = await rig.store.save(.friends)
        XCTAssertTrue(unchanged); XCTAssertEqual(rig.writes, 0)
        let saved = await rig.store.save(.nobody)
        XCTAssertTrue(saved); XCTAssertEqual(rig.store.confirmedValue, .nobody)
        XCTAssertEqual(rig.expected, [.friends]); XCTAssertEqual(rig.writes, 1)
    }

    func testLostWriteResponseRequiresReloadAndNeverRetries() async {
        let rig = PrivacyRig(); await rig.activate()
        rig.writeOverride = { _, value, _ in rig.stored.activityVisibility = value.rawValue; throw AppError.network }
        let saved = await rig.store.save(.nobody)
        let retry = await rig.store.save(.nobody)
        XCTAssertFalse(saved); XCTAssertFalse(retry)
        XCTAssertEqual(rig.writes, 1); XCTAssertNil(rig.store.confirmedValue)
        XCTAssertNotNil(rig.store.errorMessage)
        await rig.store.refresh()
        XCTAssertEqual(rig.store.confirmedValue, .nobody); XCTAssertEqual(rig.writes, 1)
    }

    func testWrongOwnerAndMismatchedWriteReceiptsNeverConfirm() async {
        let rig = PrivacyRig(); await rig.activate()
        rig.writeOverride = { _, _, _ in PrivacyRig.profile(owner: UUID(), visibility: .nobody) }
        let wrongOwner = await rig.store.save(.nobody)
        XCTAssertFalse(wrongOwner); XCTAssertNil(rig.store.confirmedValue)
        await rig.store.refresh()
        rig.writeOverride = { owner, _, _ in PrivacyRig.profile(owner: owner) }
        let wrongValue = await rig.store.save(.nobody)
        XCTAssertFalse(wrongValue); XCTAssertNil(rig.store.confirmedValue)
    }

    func testNewerRemoteChoiceCannotBeOverwritten() async {
        let rig = PrivacyRig(); await rig.activate()
        rig.stored.activityVisibility = "nobody"
        let saved = await rig.store.save(.nobody)
        XCTAssertFalse(saved); XCTAssertNil(rig.store.confirmedValue)
        XCTAssertEqual(rig.stored.activityVisibility, "nobody")
        await rig.store.refresh()
        XCTAssertEqual(rig.store.confirmedValue, .nobody)
    }

    func testPendingWriteRetainsOldChoiceAndBlocksDuplicateAndRefresh() async {
        let rig = PrivacyRig(); let gate = PrivacyGate(); await rig.activate()
        rig.writeOverride = { _, _, _ in try await gate.response() }
        let task = Task { await rig.store.save(.nobody) }; await gate.waitForRequest()
        XCTAssertEqual(rig.store.confirmedValue, .friends); XCTAssertTrue(rig.store.isSaving)
        let duplicate = await rig.store.save(.nobody); await rig.store.refresh()
        XCTAssertFalse(duplicate); XCTAssertEqual(rig.writes, 1); XCTAssertEqual(rig.reads, 1)
        gate.resolve(.success(PrivacyRig.profile(owner: rig.owner, visibility: .nobody)))
        let saved = await task.value
        XCTAssertTrue(saved); XCTAssertEqual(rig.store.confirmedValue, .nobody); XCTAssertFalse(rig.store.isBusy)
    }

    func testLateWriteAfterLogoutCannotRestoreValueOrError() async {
        for fail in [false, true] {
            let rig = PrivacyRig(); let gate = PrivacyGate(); await rig.activate()
            rig.writeOverride = { _, _, _ in try await gate.response() }
            let task = Task { await rig.store.save(.nobody) }; await gate.waitForRequest()
            rig.store.activate(userID: nil)
            gate.resolve(fail ? .failure(AppError.network) : .success(PrivacyRig.profile(owner: rig.owner, visibility: .nobody)))
            let saved = await task.value
            XCTAssertFalse(saved); XCTAssertNil(rig.store.value); XCTAssertNil(rig.store.errorMessage)
            XCTAssertFalse(rig.store.isBusy)
        }
    }

    func testLateReadCannotReplaceNewAccountOrClearItsLoading() async {
        let rig = PrivacyRig(); let oldGate = PrivacyGate(); let newGate = PrivacyGate()
        rig.store.activate(userID: rig.owner)
        rig.readOverride = { _ in try await oldGate.response() }
        let oldTask = Task { await rig.store.refresh() }; await oldGate.waitForRequest()
        let other = UUID(); rig.store.activate(userID: other)
        rig.readOverride = { _ in try await newGate.response() }
        let newTask = Task { await rig.store.refresh() }; await newGate.waitForRequest()
        oldGate.resolve(.success(rig.stored)); await oldTask.value
        XCTAssertTrue(rig.store.isLoading); XCTAssertNil(rig.store.value)
        newGate.resolve(.success(PrivacyRig.profile(owner: other, visibility: .nobody))); await newTask.value
        XCTAssertEqual(rig.store.confirmedValue, .nobody); XCTAssertEqual(rig.store.userID, other)
    }

    func testSameUserReauthenticationStillRejectsEarlierResponse() async {
        let rig = PrivacyRig(); let gate = PrivacyGate()
        rig.store.activate(userID: rig.owner)
        rig.readOverride = { _ in try await gate.response() }
        let task = Task { await rig.store.refresh() }; await gate.waitForRequest()
        rig.store.activate(userID: rig.owner)
        gate.resolve(.success(rig.stored)); await task.value
        XCTAssertNil(rig.store.confirmedValue); XCTAssertFalse(rig.store.isBusy)
    }

    func testDemoWriteChangesOnlyVisibilityAndRejectsStaleAndForeignOwners() async throws {
        let repository = DemoRepository()
        let owner = DemoRepository.defaultUserID
        let loaded = try await repository.profile(userID: owner)
        var expected = try XCTUnwrap(loaded)
        expected.activityVisibility = "nobody"
        let saved = try await repository.saveActivityVisibility(userID: owner, value: .nobody, expected: .friends)
        XCTAssertEqual(saved, expected)
        do { _ = try await repository.saveActivityVisibility(userID: owner, value: .friends, expected: .friends); XCTFail("Stale write") }
        catch { XCTAssertNotNil(error as? AppError) }
        do { _ = try await repository.saveActivityVisibility(userID: UUID(), value: .friends, expected: .nobody); XCTFail("Foreign owner") }
        catch { XCTAssertEqual(error as? AppError, .accessDenied) }
    }

    func testAppStoreMirrorsConfirmedValueAndClearsItOnLogout() async {
        let app = AppStore(repository: DemoRepository())
        await app.bootstrap(); await app.refreshActivityPrivacy()
        await app.saveActivityPrivacy(.nobody)
        XCTAssertEqual(app.profile?.activityVisibility, "nobody")
        XCTAssertEqual(app.activityPrivacy.confirmedValue, .nobody)
        await app.logout()
        XCTAssertNil(app.profile); XCTAssertNil(app.activityPrivacy.value)
    }
}

@MainActor
private final class PrivacyRig {
    let owner = UUID()
    lazy var stored = Self.profile(owner: owner)
    var reads = 0; var writes = 0
    var expected: [ActivityVisibility] = []
    var readOverride: ActivityPrivacyStore.Read?
    var writeOverride: ActivityPrivacyStore.Write?
    lazy var store = ActivityPrivacyStore(read: { owner in
        self.reads += 1
        if let read = self.readOverride { return try await read(owner) }
        return self.stored
    }, write: { owner, value, expected in
        self.writes += 1; self.expected.append(expected)
        if let write = self.writeOverride { return try await write(owner, value, expected) }
        guard self.stored.id == owner, self.stored.activityVisibility == expected.rawValue else { throw AppError.conflict("Changed") }
        self.stored.activityVisibility = value.rawValue; return self.stored
    })
    func activate() async { store.activate(userID: owner); await store.refresh() }
    static func profile(owner: UUID, visibility: ActivityVisibility = .friends) -> Profile {
        Profile(id: owner, username: "tester", displayName: "Tester", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.gym], weeklyGoal: 4, activityVisibility: visibility.rawValue)
    }
}

@MainActor
private final class PrivacyGate {
    private var continuation: CheckedContinuation<Profile, Error>?
    private var requested = false
    func response() async throws -> Profile {
        requested = true
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func resolve(_ result: Result<Profile, Error>) { continuation?.resume(with: result); continuation = nil }
    func waitForRequest(file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !requested && ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(requested, "Expected request did not start", file: file, line: line)
    }
}
