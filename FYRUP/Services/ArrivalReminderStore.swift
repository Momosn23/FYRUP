@preconcurrency import CoreLocation
import Foundation
import Observation
import UserNotifications

@MainActor
protocol ArrivalNotificationScheduling {
    func replace(_ record: ArrivalReminderRecord?) async throws
    func remove(sessionID: UUID) async
}

@MainActor
struct SilentArrivalNotifications: ArrivalNotificationScheduling {
    func replace(_ record: ArrivalReminderRecord?) async throws {}
    func remove(sessionID: UUID) async {}
}

@MainActor
struct SystemArrivalNotifications: ArrivalNotificationScheduling {
    static func identifier(_ sessionID: UUID) -> String { "fyrup.arrival.\(sessionID.uuidString.lowercased())" }

    func replace(_ record: ArrivalReminderRecord?) async throws {
        guard let record else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = Self.identifier(record.sessionID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        guard record.validationMessage == nil else { throw AppError.validation("Wähle den Ort erneut.") }
        let notificationStatus = UNAuthorizationStatus(rawValue: await SystemNotificationAuthorization.rawStatus())
        guard notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .ephemeral else {
            throw AppError.validation("Erlaube Mitteilungen, damit FYRUP dich bei der Ankunft erinnern kann.")
        }
        let locationStatus = CLLocationManager().authorizationStatus
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            throw AppError.validation("Erlaube den Standortzugriff, damit die Ankunftserinnerung funktioniert.")
        }
        let coordinate = CLLocationCoordinate2D(latitude: record.place.latitude, longitude: record.place.longitude)
        let region = CLCircularRegion(center: coordinate, radius: 180, identifier: identifier)
        region.notifyOnEntry = true; region.notifyOnExit = false
        let content = UNMutableNotificationContent()
        content.title = "Du bist angekommen"
        content.body = "Öffne FYRUP für deine geplante Session."
        content.sound = .default
        content.userInfo = ["fyrup_local_type": "arrival", "owner_id": record.ownerID.uuidString,
                            "session_id": record.sessionID.uuidString]
        try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                   trigger: UNLocationNotificationTrigger(region: region, repeats: false)))
    }

    func remove(sessionID: UUID) async {
        let identifier = Self.identifier(sessionID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

struct ArrivalReminderTap: Equatable, Sendable {
    let ownerID: UUID
    let sessionID: UUID
    init(ownerID: UUID, sessionID: UUID) { self.ownerID = ownerID; self.sessionID = sessionID }
    init?(requestIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard userInfo["fyrup_local_type"] as? String == "arrival",
              let owner = userInfo["owner_id"] as? String, let ownerID = UUID(uuidString: owner),
              let session = userInfo["session_id"] as? String, let sessionID = UUID(uuidString: session),
              requestIdentifier == "fyrup.arrival.\(sessionID.uuidString.lowercased())" else { return nil }
        self.ownerID = ownerID; self.sessionID = sessionID
    }
}

@MainActor
@Observable
final class ArrivalReminderStore {
    private(set) var userID: UUID?
    private(set) var records: [UUID: ArrivalReminderRecord] = [:]
    private(set) var errorMessage: String?
    private let defaults: UserDefaults
    private let notifications: any ArrivalNotificationScheduling

    init(defaults: UserDefaults = .standard, notifications: any ArrivalNotificationScheduling = SystemArrivalNotifications()) {
        self.defaults = defaults; self.notifications = notifications
    }

    func activate(userID: UUID?) {
        let oldIDs = Array(records.keys)
        self.userID = userID; errorMessage = nil; records = load(userID: userID)
        Task { for id in oldIDs where records[id] == nil { await notifications.remove(sessionID: id) } }
    }

    @discardableResult
    func schedule(session: PlannedSession, place: SessionPlace) async -> Bool {
        guard let owner = userID, session.hostID == owner, session.status == "planned",
              session.startsAt > Date(), session.placeName == place.name else { return false }
        let record = ArrivalReminderRecord(ownerID: owner, sessionID: session.id, place: place,
                                           startsAt: session.startsAt, createdAt: Date())
        guard record.validationMessage == nil else { errorMessage = record.validationMessage; return false }
        do {
            try await notifications.replace(record)
            records[session.id] = record; save(); errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Die Ankunftserinnerung konnte nicht gespeichert werden."
            return false
        }
    }

    func remove(sessionID: UUID) {
        records.removeValue(forKey: sessionID); save()
        Task { await notifications.remove(sessionID: sessionID) }
    }

    func clearCurrentAccount() {
        guard let userID else { return }
        let ids = Array(records.keys)
        records = [:]; defaults.removeObject(forKey: key(userID)); errorMessage = nil
        Task { for id in ids { await notifications.remove(sessionID: id) } }
    }

    func reconcile(_ sessions: [PlannedSession]) {
        guard let owner = userID else { return }
        let active = Dictionary(uniqueKeysWithValues: sessions.filter { $0.hostID == owner && $0.status == "planned" }.map { ($0.id, $0) })
        for (id, record) in records {
            guard let session = active[id], session.startsAt == record.startsAt,
                  session.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) == record.place.name else {
                remove(sessionID: id); continue
            }
        }
    }

    private func key(_ owner: UUID) -> String { "fyrup.arrival.\(owner.uuidString.lowercased())" }
    private func load(userID: UUID?) -> [UUID: ArrivalReminderRecord] {
        guard let userID, let data = defaults.data(forKey: key(userID)),
              let values = try? JSONDecoder().decode([ArrivalReminderRecord].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: values.filter { $0.ownerID == userID && $0.validationMessage == nil }.map { ($0.sessionID, $0) })
    }
    private func save() {
        guard let userID else { return }
        if records.isEmpty { defaults.removeObject(forKey: key(userID)); return }
        if let data = try? JSONEncoder().encode(Array(records.values)) { defaults.set(data, forKey: key(userID)) }
    }
}

@MainActor
@Observable
final class ArrivalPermissionStore: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var locationStatus: CLAuthorizationStatus
    private(set) var notificationAllowed = false

    override init() {
        locationStatus = manager.authorizationStatus
        super.init(); manager.delegate = self
    }
    var isReady: Bool { notificationAllowed && (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways) }
    func refresh() async {
        locationStatus = manager.authorizationStatus
        let raw = await SystemNotificationAuthorization.rawStatus()
        notificationAllowed = [.authorized, .provisional, .ephemeral].contains(UNAuthorizationStatus(rawValue: raw) ?? .notDetermined)
    }
    func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        manager.requestWhenInUseAuthorization()
        await refresh()
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.locationStatus = status }
    }
}
