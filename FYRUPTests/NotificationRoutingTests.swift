import XCTest
@testable import FYRUP

@MainActor
final class NotificationRoutingTests: XCTestCase {
    func testTypedPayloadPreservesEverySupportedDetailIdentifier() throws {
        let id = RoutingFixture.detail
        let cases: [(String, [String: String], NotificationDestination)] = [
            ("blind_workout_received", ["blind_workout_id": id.uuidString], .blindWorkout(id)),
            ("blind_workout_completed", ["blind_workout_id": id.uuidString], .blindWorkout(id)),
            ("blind_reaction", ["blind_workout_id": id.uuidString], .blindWorkout(id)),
            ("workout_plan_shared", ["plan_id": id.uuidString], .workoutPlan(id)),
            ("session_invite", ["session_id": id.uuidString], .session(id)),
            ("invite_response", ["session_id": id.uuidString], .session(id)),
            ("session_reminder", ["session_id": id.uuidString], .session(id)),
            ("supplement_reminder", ["dose_id": id.uuidString], .supplement(id)),
            ("activity_started", ["activity_id": id.uuidString], .activity(id)),
            ("reaction", ["activity_id": id.uuidString], .activity(id)),
            ("weekly_goal", ["week_id": id.uuidString], .weekly(userID: nil, weekID: id, commitmentID: nil)),
            ("flame_reaction", ["week_id": id.uuidString], .weekly(userID: nil, weekID: id, commitmentID: nil)),
            ("shot_achieved", ["week_id": id.uuidString, "user_id": RoutingFixture.other.uuidString, "commitment_id": RoutingFixture.commitment.uuidString],
             .weekly(userID: RoutingFixture.other, weekID: id, commitmentID: RoutingFixture.commitment)),
            ("friend_request", [:], .friends)
        ]
        for (type, data, expected) in cases {
            let payload = try XCTUnwrap(NotificationTapPayload(notification: RoutingFixture.note(type: type, data: data), recipientID: RoutingFixture.owner))
            XCTAssertEqual(payload.destination, expected)
            XCTAssertEqual(payload.notificationID, RoutingFixture.noteID)
            XCTAssertEqual(payload.recipientID, RoutingFixture.owner)
        }
    }

    func testNonUUIDAndNonStringIdentifiersAreRejected() {
        for bad: Any in ["not-a-uuid", "", "\(RoutingFixture.detail.uuidString) ", 123, ["id": RoutingFixture.detail.uuidString]] {
            XCTAssertNil(NotificationTapPayload(userInfo: ["fyrup_type": "session_invite", "session_id": bad]))
            XCTAssertNil(NotificationTapPayload(userInfo: ["fyrup_type": "supplement_reminder", "dose_id": bad]))
            XCTAssertNil(NotificationTapPayload(userInfo: ["fyrup_type": "friend_request", "fyrup_recipient_id": bad]))
        }
        XCTAssertNil(NotificationTapPayload(userInfo: ["fyrup_type": 42]))
        XCTAssertNil(NotificationTapPayload(userInfo: [:]))
    }

    func testMissingIDsAndUnknownTypesNeverGuessAnotherDetail() throws {
        let missing = try XCTUnwrap(NotificationTapPayload(userInfo: ["fyrup_type": "workout_plan_shared"]))
        XCTAssertEqual(missing.destination, .inbox)
        let unknown = try XCTUnwrap(NotificationTapPayload(userInfo: ["fyrup_type": "new_server_event", "blind_workout_id": RoutingFixture.detail.uuidString]))
        XCTAssertEqual(unknown.destination, .inbox)
    }

    func testInAppNotificationCannotOverrideReservedReceiptAndRecipient() throws {
        let note = RoutingFixture.note(data: ["session_id": RoutingFixture.detail.uuidString,
                                             "fyrup_notification_id": UUID().uuidString, "fyrup_recipient_id": RoutingFixture.other.uuidString])
        let payload = try XCTUnwrap(NotificationTapPayload(notification: note, recipientID: RoutingFixture.owner))
        XCTAssertEqual(payload.notificationID, note.id)
        XCTAssertEqual(payload.recipientID, RoutingFixture.owner)
    }

    func testColdTapWaitsThroughLoginAndOnboardingUntilMainIsReady() async throws {
        let repo = RoutingRepositoryStub(); let store = NotificationRoutingStore(repository: repo)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        XCTAssertEqual(store.pending, payload)
        XCTAssertNil(store.presentation)
        store.accountChanged(to: RoutingFixture.owner)
        await store.deliverPending()
        var calls = await repo.calls
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(store.pending, payload)
        store.setMainReady(true)
        await store.deliverPending()
        XCTAssertEqual(store.presentation?.destination, .session(RoutingFixture.detail))
        XCTAssertNil(store.pending)
        calls = await repo.calls
        XCTAssertEqual(calls, 1)
    }

    func testWrongLoginAccountDropsRecipientBoundColdTapWithoutFetching() async throws {
        let repo = RoutingRepositoryStub(); let store = NotificationRoutingStore(repository: repo)
        await store.receive(try RoutingFixture.payload())
        store.accountChanged(to: RoutingFixture.other); store.setMainReady(true)
        await store.deliverPending()
        XCTAssertNil(store.pending); XCTAssertNil(store.presentation)
        let calls = await repo.calls
        XCTAssertEqual(calls, 0)
    }

    func testMainTapForAnotherAccountDoesNotOpenAnything() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try XCTUnwrap(NotificationTapPayload(notification: RoutingFixture.note(), recipientID: RoutingFixture.other))
        await store.receive(payload)
        XCTAssertNil(store.presentation); XCTAssertNil(store.pending)
        XCTAssertNotNil(store.errorMessage)
        let calls = await repo.calls
        XCTAssertEqual(calls, 0)
    }

    func testWrongAccountTapAlsoRetiresPreviouslyPendingNavigation() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.holdNext()
        let original = try RoutingFixture.payload()
        let old = Task { await store.receive(original) }
        await repo.waitUntilHeld()
        let wrong = try XCTUnwrap(NotificationTapPayload(notification: RoutingFixture.note(), recipientID: RoutingFixture.other))
        await store.receive(wrong)
        await repo.release(); await old.value
        XCTAssertNil(store.presentation); XCTAssertNil(store.pending)
        XCTAssertNotNil(store.errorMessage)
    }

    func testValidReceiptIsFetchedExactlyByIDAndReusedByInAppRoute() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await store.receive(try RoutingFixture.payload())
        XCTAssertEqual(store.presentation?.userID, RoutingFixture.owner)
        XCTAssertEqual(store.presentation?.destination, .session(RoutingFixture.detail))
        let ids = await repo.requestedIDs
        XCTAssertEqual(ids, [RoutingFixture.noteID])
        let listReads = await repo.listReads
        XCTAssertEqual(listReads, 0)
    }

    func testTamperedDetailCannotOverrideAuthenticatedNotification() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try XCTUnwrap(NotificationTapPayload(userInfo: [
            "fyrup_type": "session_invite", "session_id": UUID().uuidString,
            "fyrup_notification_id": RoutingFixture.noteID.uuidString, "fyrup_recipient_id": RoutingFixture.owner.uuidString
        ]))
        await store.receive(payload)
        XCTAssertNil(store.presentation)
        XCTAssertNotNil(store.errorMessage)
    }

    func testWrongReceiptReturnedByRepositoryIsRejected() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.setReplyOverride(RoutingFixture.note(id: UUID()))
        await store.receive(try RoutingFixture.payload())
        XCTAssertNil(store.presentation)
        XCTAssertNotNil(store.errorMessage)
    }

    func testDeletedReceiptCannotUsePreviouslyRenderedInboxRow() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let renderedPayload = try RoutingFixture.payload()
        await repo.setNotes([])
        await store.receive(renderedPayload)
        XCTAssertNil(store.presentation)
        XCTAssertNotNil(store.errorMessage)
    }

    func testLegacyUnboundPayloadNeedsMatchingAuthorizedAccountReceipt() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try XCTUnwrap(NotificationTapPayload(userInfo: ["fyrup_type": "session_invite", "session_id": RoutingFixture.detail.uuidString]))
        await repo.setNotes([])
        await store.receive(payload)
        XCTAssertNil(store.presentation)
        await repo.setNotes([RoutingFixture.note()])
        await store.deliverPending()
        XCTAssertEqual(store.presentation?.destination, .session(RoutingFixture.detail))
        let listReads = await repo.listReads
        XCTAssertEqual(listReads, 2)
    }

    func testLogoutDuringReadRetiresPendingAndLateResponse() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.holdNext()
        let payload = try RoutingFixture.payload()
        let pending = Task { await store.receive(payload) }
        await repo.waitUntilHeld()
        store.accountChanged(to: nil)
        await repo.release()
        await pending.value
        XCTAssertNil(store.pending); XCTAssertNil(store.presentation)
        XCTAssertFalse(store.isResolving)
        XCTAssertNil(store.errorMessage)
    }

    func testAccountSwitchCannotPublishOldUsersNotification() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.holdNext()
        let payload = try RoutingFixture.payload()
        let pending = Task { await store.receive(payload) }
        await repo.waitUntilHeld()
        store.accountChanged(to: RoutingFixture.other); store.setMainReady(true)
        await repo.release(); await pending.value
        XCTAssertNil(store.presentation)
        XCTAssertNil(store.pending)
    }

    func testNewerTapWinsWhenFirstResponseArrivesLast() async throws {
        let second = RoutingFixture.note(id: UUID(), type: "workout_plan_shared", data: ["plan_id": UUID().uuidString])
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.setNotes([RoutingFixture.note(), second]); await repo.holdNext()
        let firstPayload = try RoutingFixture.payload()
        let old = Task { await store.receive(firstPayload) }
        await repo.waitUntilHeld()
        let secondPayload = try XCTUnwrap(NotificationTapPayload(notification: second, recipientID: RoutingFixture.owner))
        await store.receive(secondPayload)
        let newest = store.presentation
        XCTAssertEqual(newest?.destination, secondPayload.destination)
        await repo.release(); await old.value
        XCTAssertEqual(store.presentation, newest)
        XCTAssertFalse(store.isResolving)
    }

    func testLeavingMainDuringReadRetainsIntentButNeverPresentsOnOnboarding() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.holdNext()
        let payload = try RoutingFixture.payload()
        let pending = Task { await store.receive(payload) }
        await repo.waitUntilHeld()
        store.setMainReady(false)
        await repo.release(); await pending.value
        XCTAssertNil(store.presentation)
        XCTAssertEqual(store.pending, payload)
        store.setMainReady(true)
        await store.deliverPending()
        XCTAssertNotNil(store.presentation)
    }

    func testExplicitSocialRevocationDropsResolverAndExistingDetail() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        let previous = try XCTUnwrap(store.presentation)
        store.revokeSocialDestinations()
        XCTAssertFalse(store.isCurrent(previous))
        await repo.holdNext()
        let pending = Task { await store.receive(payload) }
        await repo.waitUntilHeld()
        store.revokeSocialDestinations()
        await repo.release(); await pending.value
        XCTAssertNil(store.pending); XCTAssertNil(store.presentation)
    }

    func testTransportFailureRetainsOnlyIdentifiersForExplicitRetry() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.fail(true)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        XCTAssertEqual(store.pending, payload)
        XCTAssertNil(store.presentation)
        XCTAssertNotNil(store.errorMessage)
        await repo.fail(false)
        await store.deliverPending()
        XCTAssertNotNil(store.presentation)
        XCTAssertNil(store.pending)
        XCTAssertNil(store.errorMessage)
    }

    func testLaunchAndDelegateDuplicateDoNotOpenSameDetailTwice() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        let presentation = store.presentation
        await store.receive(payload)
        XCTAssertEqual(store.presentation, presentation)
        let calls = await repo.calls
        XCTAssertEqual(calls, 1)
    }

    func testDismissedDetailRequiresFreshAuthorizationWhenReopened() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        store.dismiss()
        await repo.setNotes([])
        await store.receive(payload)
        XCTAssertNil(store.presentation)
        let calls = await repo.calls
        XCTAssertEqual(calls, 2)
    }

    func testSameAccountSessionRefreshDoesNotEraseColdIntent() async throws {
        let repo = RoutingRepositoryStub(); let store = NotificationRoutingStore(repository: repo)
        store.accountChanged(to: RoutingFixture.owner)
        let payload = try RoutingFixture.payload()
        await store.receive(payload)
        store.accountChanged(to: RoutingFixture.owner)
        XCTAssertEqual(store.pending, payload)
        store.setMainReady(true); await store.deliverPending()
        XCTAssertNotNil(store.presentation)
    }

    func testCancelledLookupCannotPresentOrLeaveBusyFlag() async throws {
        let repo = RoutingRepositoryStub(); let store = active(repo)
        await repo.holdNext()
        let payload = try RoutingFixture.payload()
        let pending = Task { await store.receive(payload) }
        await repo.waitUntilHeld()
        pending.cancel(); await repo.release(); await pending.value
        XCTAssertNil(store.presentation)
        XCTAssertFalse(store.isResolving)
        XCTAssertNil(store.errorMessage)
    }

    func testAppStoreColdStartBootstrapRoutesAndLogoutClearsPresentation() async throws {
        let repo = DemoRepository(includesSocialFixtures: true)
        let values = try await repo.notifications()
        let note = try XCTUnwrap(values.first { $0.type == "fyrup" })
        let payload = try XCTUnwrap(NotificationTapPayload(notification: note, recipientID: DemoRepository.defaultUserID))
        let store = AppStore(repository: repo)
        await store.handleNotificationTap(payload)
        XCTAssertEqual(store.route, .loading)
        XCTAssertEqual(store.notificationRouting.pending, payload)
        await store.bootstrap()
        XCTAssertEqual(store.route, .main)
        await store.deliverPendingNotification()
        XCTAssertEqual(store.notificationRouting.presentation?.destination, .friends)
        await store.logout()
        XCTAssertEqual(store.route, .signedOut)
        XCTAssertNil(store.notificationRouting.presentation)
        XCTAssertNil(store.notificationRouting.pending)
    }

    func testAppStoreOnboardingKeepsTapWithoutPrematureMainNavigation() async throws {
        let repo = DemoRepository(startsWithoutProfile: true, includesSocialFixtures: true)
        let values = try await repo.notifications()
        let note = try XCTUnwrap(values.first { $0.type == "fyrup" })
        let payload = try XCTUnwrap(NotificationTapPayload(notification: note, recipientID: DemoRepository.defaultUserID))
        let store = AppStore(repository: repo)
        await store.handleNotificationTap(payload)
        await store.bootstrap()
        XCTAssertEqual(store.route, .profileSetup)
        await store.deliverPendingNotification()
        XCTAssertNil(store.notificationRouting.presentation)
        XCTAssertEqual(store.notificationRouting.pending, payload)
    }

    private func active(_ repository: RoutingRepositoryStub) -> NotificationRoutingStore {
        let store = NotificationRoutingStore(repository: repository)
        store.accountChanged(to: RoutingFixture.owner); store.setMainReady(true)
        return store
    }

    func testSupplementActionNeedsAuthorizedReceiptAndCannotComeFromPayloadData() async throws {
        let repo = RoutingRepositoryStub(); let routing = active(repo)
        let note = RoutingFixture.note(type: "supplement_reminder", data: ["dose_id": RoutingFixture.detail.uuidString])
        var payload = try XCTUnwrap(NotificationTapPayload(userInfo: ["fyrup_type": note.type,
            "dose_id": RoutingFixture.detail.uuidString, "fyrup_notification_id": note.id.uuidString,
            "fyrup_recipient_id": RoutingFixture.owner.uuidString, "marksSupplementTaken": true]))
        XCTAssertFalse(payload.marksSupplementTaken, "Only the native user action may set the intent")
        payload.marksSupplementTaken = true
        await repo.setNotes([]); await routing.receive(payload)
        XCTAssertNil(routing.presentation)
        await repo.setNotes([note]); await routing.receive(payload)
        XCTAssertEqual(routing.presentation?.destination, .supplement(RoutingFixture.detail))
        XCTAssertEqual(routing.presentation?.marksSupplementTaken, true)
        XCTAssertEqual(routing.presentation?.notificationID, note.id)
        routing.accountChanged(to: RoutingFixture.other)
        XCTAssertNil(routing.presentation); XCTAssertNil(routing.pending)
    }
}

private enum RoutingFixture {
    static let owner = UUID(uuidString: "83000000-0000-0000-0000-000000000001")!
    static let other = UUID(uuidString: "83000000-0000-0000-0000-000000000002")!
    static let noteID = UUID(uuidString: "83000000-0000-0000-0001-000000000001")!
    static let detail = UUID(uuidString: "83000000-0000-0000-0002-000000000001")!
    static let commitment = UUID(uuidString: "83000000-0000-0000-0003-000000000001")!
    static func note(id: UUID = noteID, type: String = "session_invite", data: [String: String]? = nil) -> AppNotification {
        AppNotification(id: id, type: type, title: "Nicht für das Routing verwenden", body: "Kein Contentcache", data: data ?? ["session_id": detail.uuidString], createdAt: Date(), readAt: nil)
    }
    @MainActor static func payload() throws -> NotificationTapPayload {
        try XCTUnwrap(NotificationTapPayload(notification: note(), recipientID: owner))
    }
}

private actor RoutingRepositoryStub: NotificationRoutingRepository {
    private var notes = [RoutingFixture.note()]
    private var failure = false
    private var replyOverride: AppNotification?
    private var holdNextRead = false
    private var gate: (id: UUID, continuation: CheckedContinuation<Void, Never>)?
    private var observers: [(UUID, CheckedContinuation<Void, Never>)] = []
    private(set) var calls = 0
    private(set) var listReads = 0
    private(set) var requestedIDs: [UUID] = []
    func setNotes(_ notes: [AppNotification]) { self.notes = notes }
    func setReplyOverride(_ note: AppNotification?) { replyOverride = note }
    func fail(_ value: Bool) { failure = value }
    func holdNext() { holdNextRead = true }

    func notificationForRouting(id: UUID) async throws -> AppNotification? {
        calls += 1; requestedIDs.append(id)
        let captured = replyOverride ?? notes.first { $0.id == id }
        await checkpoint()
        if failure { throw AppError.network }
        return captured
    }
    func notifications() async throws -> [AppNotification] {
        listReads += 1
        if failure { throw AppError.network }
        return notes
    }
    func activityForNotification(id: UUID, userID: UUID) async throws -> NotificationActivityDetail? { nil }

    func waitUntilHeld() async {
        if gate != nil { return }
        let id = UUID()
        await withCheckedContinuation { continuation in
            observers.append((id, continuation))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.timeoutObserver(id)
            }
        }
    }
    func release() { let value = gate; gate = nil; value?.continuation.resume() }
    private func checkpoint() async {
        guard holdNextRead else { return }
        holdNextRead = false
        let id = UUID()
        await withCheckedContinuation { continuation in
            gate = (id, continuation)
            let waiting = observers; observers = []
            for (_, observer) in waiting { observer.resume() }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                await self?.timeoutGate(id)
            }
        }
    }
    private func timeoutGate(_ id: UUID) {
        guard gate?.id == id else { return }
        XCTFail("Notification read gate was not released within 3 seconds"); release()
    }
    private func timeoutObserver(_ id: UUID) {
        guard let observer = observers.first(where: { $0.0 == id }) else { return }
        observers.removeAll { $0.0 == id }
        XCTFail("Notification read did not begin within 3 seconds"); observer.1.resume()
    }
}
