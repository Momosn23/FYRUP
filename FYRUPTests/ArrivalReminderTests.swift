import XCTest
@testable import FYRUP

@MainActor
final class ArrivalReminderTests: XCTestCase {
    func testPlaceRejectsInvalidCoordinatesAndBlankName() {
        XCTAssertNotNil(SessionPlace(name: "", detail: nil, latitude: 50, longitude: 7).validationMessage)
        XCTAssertNotNil(SessionPlace(name: "Gym", detail: nil, latitude: 91, longitude: 7).validationMessage)
        XCTAssertNil(SessionPlace(name: "FYRUP Gym", detail: "Köln", latitude: 50.94, longitude: 6.95).validationMessage)
    }

    func testReminderIsAccountIsolatedAndRemovedWhenSessionChanges() async {
        let suite = "app.fyrup.tests.arrival.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = ArrivalNotificationSpy()
        let store = ArrivalReminderStore(defaults: defaults, notifications: notifications)
        let owner = UUID(), other = UUID(), sessionID = UUID()
        let place = SessionPlace(name: "FYRUP Gym", detail: nil, latitude: 50.94, longitude: 6.95)
        let session = PlannedSession(id: sessionID, hostID: owner, sport: .gym, subtype: "Push", startsAt: Date(timeIntervalSince1970: 2_000_000_000), durationMinutes: 60, note: nil, placeName: place.name, friendsCanJoin: false, status: "planned")

        store.activate(userID: owner)
        let scheduled = await store.schedule(session: session, place: place)
        XCTAssertTrue(scheduled)
        XCTAssertEqual(store.records[sessionID]?.place, place)

        store.activate(userID: other)
        XCTAssertTrue(store.records.isEmpty)
        store.activate(userID: owner)
        XCTAssertEqual(store.records[sessionID]?.ownerID, owner)

        var changed = session; changed.startsAt = session.startsAt.addingTimeInterval(60)
        store.reconcile([changed])
        XCTAssertNil(store.records[sessionID])
        XCTAssertTrue(notifications.removed.contains(sessionID))
    }

    func testReminderNeverSchedulesForAnotherOwnerOrNonPlannedSession() async {
        let notifications = ArrivalNotificationSpy()
        let store = ArrivalReminderStore(defaults: UserDefaults(suiteName: "app.fyrup.tests.arrival.\(UUID().uuidString)")!, notifications: notifications)
        let owner = UUID()
        store.activate(userID: owner)
        let place = SessionPlace(name: "Gym", detail: nil, latitude: 50, longitude: 7)
        var session = PlannedSession(id: UUID(), hostID: UUID(), sport: .gym, subtype: nil, startsAt: Date(), durationMinutes: nil, note: nil, placeName: "Gym", friendsCanJoin: false, status: "planned")
        let foreignScheduled = await store.schedule(session: session, place: place)
        XCTAssertFalse(foreignScheduled)
        session = PlannedSession(id: UUID(), hostID: owner, sport: .gym, subtype: nil, startsAt: Date(), durationMinutes: nil, note: nil, placeName: "Gym", friendsCanJoin: false, status: "cancelled")
        let cancelledScheduled = await store.schedule(session: session, place: place)
        XCTAssertFalse(cancelledScheduled)
        XCTAssertTrue(notifications.replaced.isEmpty)
    }

    func testTapAcceptsOnlyExactOwnedFYRUPRequestShape() {
        let owner = UUID(), session = UUID()
        let info: [AnyHashable: Any] = ["fyrup_local_type": "arrival", "owner_id": owner.uuidString, "session_id": session.uuidString]
        XCTAssertEqual(ArrivalReminderTap(requestIdentifier: "fyrup.arrival.\(session.uuidString.lowercased())", userInfo: info), ArrivalReminderTap(ownerID: owner, sessionID: session))
        XCTAssertNil(ArrivalReminderTap(requestIdentifier: "other", userInfo: info))
        XCTAssertNil(ArrivalReminderTap(requestIdentifier: "fyrup.arrival.\(session.uuidString.lowercased())", userInfo: ["fyrup_local_type": "arrival", "owner_id": owner.uuidString]))
    }
}

@MainActor
private final class ArrivalNotificationSpy: ArrivalNotificationScheduling {
    var replaced: [ArrivalReminderRecord] = []
    var removed: [UUID] = []
    func replace(_ record: ArrivalReminderRecord?) async throws { if let record { replaced.append(record) } }
    func remove(sessionID: UUID) async { removed.append(sessionID) }
}
