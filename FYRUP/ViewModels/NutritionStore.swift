import Foundation
import Observation

@MainActor @Observable final class NutritionStore {
    private let persistence: any NutritionPersisting
    private(set) var owner: UUID?
    private(set) var diary: NutritionDiary?
    private(set) var errorMessage: String?
    init(persistence: any NutritionPersisting = ProtectedNutritionPersistence()) { self.persistence = persistence }
    func activate(owner: UUID?) {
        self.owner = owner; diary = nil; errorMessage = nil
        guard let owner else { return }
        do {
            let saved = try persistence.load(owner: owner) ?? NutritionDiary()
            guard saved.isValid else { throw AppError.server }
            diary = saved
        } catch { errorMessage = "Dein Ernährungstagebuch konnte nicht geöffnet werden. Entsperre dein iPhone und versuche es erneut." }
    }
    @discardableResult func saveGoal(_ goal: NutritionGoal) -> Bool {
        change { $0.goal = goal }
    }
    @discardableResult func save(_ entry: NutritionEntry) -> Bool {
        change { value in
            // The editor retains the entry ID across retries; repeated saves replace.
            if let index = value.entries.firstIndex(where: { $0.id == entry.id }) { value.entries[index] = entry }
            else { value.entries.append(entry) }
        }
    }
    @discardableResult func remove(_ id: UUID) -> Bool { change { $0.entries.removeAll { $0.id == id } } }
    private func change(_ edit: (inout NutritionDiary) -> Void) -> Bool {
        guard let owner, var next = diary else { return false }
        edit(&next)
        guard next.isValid else { errorMessage = "Prüfe die Menge und Nährwerte. Deine bisherigen Einträge bleiben erhalten."; return false }
        do { try persistence.save(next, owner: owner); diary = next; errorMessage = nil; return true }
        catch { errorMessage = "Noch nicht gespeichert. Deine Eingaben bleiben geöffnet."; return false }
    }
    func deleteAccount() throws {
        if let owner { try persistence.delete(owner: owner) }
        activate(owner: nil)
    }
}
