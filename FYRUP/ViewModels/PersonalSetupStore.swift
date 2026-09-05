import Foundation
import Observation

@MainActor @Observable
final class PersonalSetupStore {
    private let persistence: any PersonalSetupPersisting
    private(set) var userID: UUID?
    private(set) var value: PersonalSetupPreferences?
    private(set) var errorMessage: String?
    init(persistence: any PersonalSetupPersisting = SecurePersonalSetupPersistence()) { self.persistence = persistence }
    var resumePage: Int { value?.completed == true ? 0 : value?.setupPage ?? 0 }
    @discardableResult
    func move(to page: Int) -> Bool {
        guard value != nil, (0...3).contains(page) else { return false }
        if value?.completed == true { return true }
        return update { $0.setupPage = page }
    }
    @discardableResult
    func finishSetup() -> Bool { update { $0.completed = true; $0.setupPage = nil } }
    func activate(userID: UUID?) {
        self.userID = userID; value = nil; errorMessage = nil
        guard let userID else { return }
        do {
            let loaded = try persistence.load(userID: userID) ?? PersonalSetupPreferences()
            guard loaded.validationMessage == nil else { throw AppError.server }
            value = loaded
        } catch { errorMessage = "Deine privaten Einstellungen konnten nicht geladen werden. Entsperre dein iPhone und versuche es erneut." }
    }
    @discardableResult
    func update(_ change: (inout PersonalSetupPreferences) -> Void) -> Bool {
        guard let userID, var edited = value else { return false }
        change(&edited)
        if let message = edited.validationMessage { errorMessage = message; return false }
        do {
            try persistence.save(edited, userID: userID)
            value = edited; errorMessage = nil; return true
        } catch { errorMessage = "Nicht gespeichert. Deine bisherigen privaten Einstellungen bleiben unverändert."; return false }
    }
    @discardableResult
    func deleteMeasurements() -> Bool {
        update { $0.heightCM = nil; $0.weightKG = nil; $0.measurementsUpdatedAt = nil }
    }
    func clearDeletedAccount() throws {
        if let userID { try persistence.delete(userID: userID) }
        activate(userID: nil)
    }
}
