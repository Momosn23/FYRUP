import Foundation

/// Exact coordinates never leave the device. Only `name` is sent as the
/// deliberately shared meeting point of a planned Session.
struct SessionPlace: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let detail: String?
    let latitude: Double
    let longitude: Double

    var id: String { "\(latitude),\(longitude),\(name)" }
    var validationMessage: String? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty || cleanName.count > 120 || cleanName != name { return "Wähle einen gültigen Ort." }
        if !latitude.isFinite || !longitude.isFinite || !(-90...90).contains(latitude) || !(-180...180).contains(longitude) {
            return "Die Koordinaten dieses Orts sind ungültig."
        }
        return nil
    }
}

struct ArrivalReminderRecord: Codable, Equatable, Identifiable, Sendable {
    let ownerID: UUID
    let sessionID: UUID
    let place: SessionPlace
    let startsAt: Date
    let createdAt: Date
    var id: UUID { sessionID }

    var validationMessage: String? {
        if place.validationMessage != nil || !startsAt.timeIntervalSince1970.isFinite || !createdAt.timeIntervalSince1970.isFinite {
            return "Diese Ankunftserinnerung ist ungültig. Wähle den Ort erneut."
        }
        return nil
    }
}
