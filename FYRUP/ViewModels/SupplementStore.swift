import Foundation
import Observation

@MainActor @Observable
final class SupplementStore {
    private struct Envelope: Codable {
        var version = 1
        let ownerID: UUID
        let changes: [SupplementDoseMutation]
    }
    private let repository: any SupplementRepository
    private let persistence: any SupplementPendingPersistence
    private let clock: () -> Date
    private var loadedAt: Date?
    private var epoch = UUID()
    private var request = UUID()
    private var storageBlocked = false
    private(set) var ownerID: UUID?
    private(set) var snapshot: SupplementSnapshot?
    private(set) var pending: [SupplementDoseMutation] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isSyncing = false
    var errorMessage: String?
    var pendingError: String?

    init(repository: any SupplementRepository, persistence: (any SupplementPendingPersistence)? = nil, clock: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.persistence = persistence ?? KeychainSupplementPendingPersistence()
        self.clock = clock
    }
    func activate(userID: UUID?) {
        guard userID != ownerID else { return }
        ownerID = userID; epoch = UUID(); request = UUID(); snapshot = nil; pending = []
        isLoading = false; isSaving = false; isSyncing = false; storageBlocked = false
        loadedAt = nil; errorMessage = nil; pendingError = nil
        reloadPending()
    }
    func reloadPending() {
        guard let userID = ownerID, !isSyncing, !isSaving else { return }
        do {
            guard let data = try persistence.load(owner: userID) else { pending = []; storageBlocked = false; pendingError = nil; return }
            let value = try JSONDecoder().decode(Envelope.self, from: data)
            guard value.version == 1, value.ownerID == userID, value.changes.count <= 200,
                  Set(value.changes.map(\.id)).count == value.changes.count,
                  Set(value.changes.map(\.doseID)).count == value.changes.count,
                  value.changes.allSatisfy({ (1..<1_000_000_000).contains($0.expectedRevision) }) else { throw AppError.server }
            pending = value.changes; storageBlocked = false; pendingError = nil
        } catch {
            storageBlocked = true
            pendingError = "Lokale Bestätigungen sind nicht lesbar. Sie bleiben erhalten; neue Bestätigungen sind gesperrt. Entsperre das iPhone und versuche erneut zu lesen."
        }
    }
    func load(timezone: String = TimeZone.current.identifier) async {
        guard let ownerID, !isLoading, !isSaving, !isSyncing else { return }
        let generation = epoch; let token = UUID(); request = token; isLoading = true
        defer { if epoch == generation, request == token { isLoading = false } }
        do {
            let value = try await repository.supplements(timezone: timezone)
            guard epoch == generation, request == token, !Task.isCancelled else { return }
            guard value.isValid(for: ownerID) else { throw AppError.server }
            snapshot = value; loadedAt = clock(); errorMessage = nil
        } catch {
            if epoch == generation, request == token { errorMessage = "Deine Liste konnte nicht aktualisiert werden. Erneut laden." }
        }
    }
    func refresh() async {
        let generation = epoch
        if storageBlocked { reloadPending() }
        await synchronize()
        guard epoch == generation else { return }
        await load()
    }
    func save(_ value: SupplementPlan) async -> Bool {
        guard let ownerID, let snapshot, !isSaving, !isSyncing, value.ownerID == ownerID else { return false }
        if let message = value.validationMessage { errorMessage = message; return false }
        guard value.revision == (snapshot.plans.first(where: { $0.id == value.id })?.revision ?? 0) else {
            errorMessage = "Der Eintrag wurde inzwischen geändert. Lade die Liste erneut."; return false
        }
        let generation = epoch; isSaving = true; isLoading = false; request = UUID()
        defer { if epoch == generation { isSaving = false } }
        do {
            let saved = try await repository.saveSupplement(value)
            guard epoch == generation, !Task.isCancelled else { return false }
            var expected = value; expected.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            expected.weekdays.sort(); expected.revision = saved.revision
            guard saved.validationMessage == nil, saved == expected, saved.revision > value.revision else { throw AppError.server }
            // Fetch actual server day/doses: never fabricate an empty list after an edit.
            let next = try await repository.supplements(timezone: snapshot.settings.timezone)
            guard epoch == generation, !Task.isCancelled else { return false }
            guard next.isValid(for: ownerID) else { throw AppError.server }
            self.snapshot = next; loadedAt = clock(); errorMessage = nil; return true
        } catch {
            if epoch == generation { errorMessage = "Nicht bestätigt. Deine Eingaben bleiben erhalten. Lade bei einem Konflikt die aktuelle Liste erneut." }
            return false
        }
    }
    func saveSettings(_ value: SupplementSettings) async -> Bool {
        guard let ownerID, let snapshot, !isSaving, !isSyncing, value.isValid,
              value.revision == snapshot.settings.revision, value.timezone == snapshot.settings.timezone else { return false }
        let generation = epoch; isSaving = true; isLoading = false; request = UUID()
        defer { if epoch == generation { isSaving = false } }
        do {
            let saved = try await repository.saveSupplementSettings(value)
            guard epoch == generation, !Task.isCancelled else { return false }
            var expected = value; expected.revision = saved.revision
            guard saved.isValid, saved == expected, saved.revision > value.revision else { throw AppError.server }
            let next = try await repository.supplements(timezone: saved.timezone)
            guard epoch == generation, !Task.isCancelled else { return false }
            guard next.isValid(for: ownerID) else { throw AppError.server }
            self.snapshot = next; loadedAt = clock(); errorMessage = nil; return true
        } catch { if epoch == generation { errorMessage = "Ruhezeiten noch nicht bestätigt. Erneut laden und versuchen." }; return false }
    }
    /// The visible confirmed status never changes until the server receipt arrives.
    func mark(_ doseID: UUID, as status: SupplementDoseStatus, requestID: UUID? = nil) async {
        guard !storageBlocked, !isSaving, !isSyncing, isCurrentDay, let snapshot,
              let dose = snapshot.doses.first(where: { $0.id == doseID && $0.ownerID == ownerID }),
              dose.status != status, !pending.contains(where: { $0.doseID == doseID }), pending.count < 200 else { return }
        let generation = epoch
        let change = SupplementDoseMutation(id: requestID ?? UUID(), doseID: dose.id, status: status, expectedRevision: dose.revision)
        guard persist(pending + [change]) else { return }
        await synchronize()
        guard epoch == generation else { return }
        await load()
    }
    var isCurrentDay: Bool {
        guard let snapshot, let loadedAt else { return false }
        let elapsed = max(0, clock().timeIntervalSince(loadedAt))
        return SupplementDay.key(snapshot.serverNow.addingTimeInterval(elapsed), timezone: snapshot.settings.timezone) == snapshot.day
    }
    var changesDisabled: Bool { storageBlocked || isSaving || isSyncing || !isCurrentDay }
    func synchronize() async {
        guard let ownerID, !isSyncing, !isSaving, !storageBlocked, !pending.isEmpty else { return }
        let generation = epoch; isSyncing = true; isLoading = false; request = UUID()
        defer { if epoch == generation { isSyncing = false } }
        while let change = pending.first {
            do {
                let saved = try await repository.setSupplementDose(change)
                guard epoch == generation, !Task.isCancelled else { return }
                guard saved.id == change.doseID, saved.ownerID == ownerID, saved.revision >= change.expectedRevision,
                      (saved.status == .open) == (saved.changedAt == nil), saved.dueAt.timeIntervalSince1970.isFinite,
                      saved.changedAt.map({ $0.timeIntervalSince1970.isFinite }) ?? true else { throw AppError.server }
                // Remove durably first; a storage failure retains the same idempotency ID for retry.
                guard persist(pending.filter { $0.id != change.id }) else { return }
                if let index = snapshot?.doses.firstIndex(where: { $0.id == saved.id && $0.planID == saved.planID && $0.slotID == saved.slotID && $0.day == saved.day }),
                   saved.changedAt.map({ $0 <= (snapshot?.serverNow ?? .distantPast) }) ?? true {
                    snapshot?.doses[index] = saved
                }
                pendingError = saved.status == change.status ? nil : "Der Eintrag wurde zwischenzeitlich auf einem anderen Gerät geändert. Angezeigt wird der aktuelle Stand."
            } catch {
                if epoch == generation { pendingError = "Lokal vorgemerkt, noch nicht abgeglichen. Bei Verbindung erneut versuchen. Bei einem Konflikt die Vormerkung verwerfen und den aktuellen Stand laden." }
                return
            }
        }
    }
    func discardPending(_ id: UUID) {
        guard !isSyncing else { return }
        _ = persist(pending.filter { $0.id != id })
    }
    /// Explicit account deletion. Merely logging out retains only opaque queued intent for this owner.
    func clearDeletedAccount() {
        guard let ownerID else { return }
        do { try persistence.clear(owner: ownerID); pending = []; storageBlocked = false; pendingError = nil }
        catch { pendingError = "Lokale Vormerkungen konnten nicht entfernt werden." }
    }
    private func persist(_ changes: [SupplementDoseMutation]) -> Bool {
        guard let ownerID, !storageBlocked else { return false }
        do {
            try persistence.save(JSONEncoder().encode(Envelope(ownerID: ownerID, changes: changes)), owner: ownerID)
            pending = changes; pendingError = nil; return true
        } catch {
            pendingError = "Nicht lokal gesichert. Bitte die Ansicht geöffnet lassen und erneut versuchen."
            return false
        }
    }
}
