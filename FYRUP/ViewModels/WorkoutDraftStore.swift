import Foundation
import Observation

struct WorkoutPlanDraft: Codable, Identifiable, Equatable {
    var original: WorkoutPlan
    var edited: WorkoutPlan
    var updatedAt: Date
    var id: UUID { edited.id }
}

/// Local drafts are account-scoped and never published as saved/shared plans.
@MainActor
@Observable
final class WorkoutDraftStore {
    private(set) var drafts: [WorkoutPlanDraft] = []
    private(set) var errorMessage: String?
    private(set) var userID: UUID?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func activate(userID: UUID?) {
        guard self.userID != userID else { return }
        self.userID = userID; drafts = []; errorMessage = nil
        guard let userID, let data = defaults.data(forKey: key(userID)) else { return }
        do {
            let decoded = try JSONDecoder().decode([WorkoutPlanDraft].self, from: data)
                .filter { $0.original.ownerID == userID && $0.edited.ownerID == userID && $0.original.id == $0.edited.id }
                .sorted { $0.updatedAt > $1.updatedAt }
            var seen = Set<UUID>()
            drafts = decoded.filter { seen.insert($0.id).inserted }
        } catch {
            // Preserve the unreadable original before any later edit replaces the main data.
            let recoveryKey = key(userID) + ".recovery"
            if defaults.data(forKey: recoveryKey) == nil { defaults.set(data, forKey: recoveryKey) }
            errorMessage = "Ein lokaler Planentwurf konnte nicht geladen werden. Eine Sicherung wurde behalten; deine gespeicherten Pläne sind davon nicht betroffen."
        }
    }

    func draft(id: UUID) -> WorkoutPlanDraft? { drafts.first { $0.id == id } }

    func save(edited: WorkoutPlan, original: WorkoutPlan, now: Date = Date()) {
        guard let userID, edited.ownerID == userID, original.ownerID == userID, edited.id == original.id else { return }
        guard edited != original else { remove(id: edited.id); return }
        var candidate = drafts.filter { $0.id != edited.id }
        candidate.insert(WorkoutPlanDraft(original: original, edited: edited, updatedAt: now), at: 0)
        persist(candidate, for: userID)
    }

    func remove(id: UUID) {
        guard let userID else { return }
        persist(drafts.filter { $0.id != id }, for: userID)
    }

    /// Explicit sign-out/account deletion removes drafts from this device as well.
    func clearCurrentAccount() {
        if let userID { defaults.removeObject(forKey: key(userID)); defaults.removeObject(forKey: key(userID) + ".recovery") }
        drafts = []; errorMessage = nil; userID = nil
    }

    private func persist(_ candidate: [WorkoutPlanDraft], for userID: UUID) {
        do {
            let data = try JSONEncoder().encode(candidate)
            defaults.set(data, forKey: key(userID))
            drafts = candidate; errorMessage = nil
        } catch { errorMessage = "Der Planentwurf konnte nicht auf diesem Gerät gesichert werden. Lass den Editor geöffnet und versuche es erneut." }
    }

    private func key(_ userID: UUID) -> String { "app.fyrup.workout-drafts.v1.\(userID.uuidString)" }
}
