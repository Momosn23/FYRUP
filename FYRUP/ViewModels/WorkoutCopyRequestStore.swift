import Foundation

/// Only account/source/request UUIDs are retained. No friend's plan or exercise data
/// is cached here. Persist intent before dispatch, and remove it only after a receipt.
@MainActor
final class WorkoutCopyRequestStore {
    private let defaults: UserDefaults?
    private var memory: [UUID: [String: UUID]] = [:]
    private let prefix = "fyrup.workout-copy-requests.v1."

    /// No defaults means isolated in-memory storage, useful for ordinary test fixtures.
    init(defaults: UserDefaults? = nil) { self.defaults = defaults }

    func requestID(sourceID: UUID, ownerID: UUID) throws -> UUID {
        var requests = try load(ownerID: ownerID)
        if let existing = requests[sourceID.uuidString] { return existing }
        let request = UUID()
        requests[sourceID.uuidString] = request
        try save(requests, ownerID: ownerID)
        return request
    }

    func confirm(sourceID: UUID, ownerID: UUID, requestID: UUID) throws {
        var requests = try load(ownerID: ownerID)
        guard requests[sourceID.uuidString] == requestID else { return }
        requests.removeValue(forKey: sourceID.uuidString)
        try save(requests, ownerID: ownerID)
    }

    func clearAccount(ownerID: UUID) {
        memory.removeValue(forKey: ownerID)
        defaults?.removeObject(forKey: prefix + ownerID.uuidString)
    }

    private func load(ownerID: UUID) throws -> [String: UUID] {
        guard let defaults else { return memory[ownerID, default: [:]] }
        let key = prefix + ownerID.uuidString
        guard defaults.object(forKey: key) != nil else { return [:] }
        guard let data = defaults.data(forKey: key),
              let requests = try? JSONDecoder().decode([String: UUID].self, from: data),
              requests.keys.allSatisfy({ UUID(uuidString: $0)?.uuidString == $0 }) else {
            throw AppError.conflict("Die gespeicherte Kopieranfrage konnte nicht gelesen werden. Zur Sicherheit wurde keine weitere Kopie angelegt.")
        }
        return requests
    }

    private func save(_ requests: [String: UUID], ownerID: UUID) throws {
        guard let defaults else { memory[ownerID] = requests; return }
        let data = try JSONEncoder().encode(requests)
        defaults.set(data, forKey: prefix + ownerID.uuidString)
        // Flush the tiny intent before the remote mutation can commit. A failed
        // local write must not start a request whose retry identity could be lost.
        guard defaults.synchronize() else {
            throw AppError.conflict("Die Kopieranfrage konnte nicht sicher gespeichert werden. Bitte versuche es erneut.")
        }
    }
}
