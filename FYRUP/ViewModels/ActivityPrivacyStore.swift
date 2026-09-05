import Foundation
import Observation

enum ActivityVisibility: String, CaseIterable, Sendable {
    case friends, nobody
    var title: String { self == .friends ? "Freunde" : "Niemand" }
}

/// A choice is not confirmed until the server acknowledges this account's
/// exact change. Uncertain writes require a fresh read, never an automatic retry.
@MainActor
@Observable
final class ActivityPrivacyStore {
    typealias Read = @MainActor (UUID) async throws -> Profile
    typealias Write = @MainActor (UUID, ActivityVisibility, ActivityVisibility) async throws -> Profile
    private let read: Read
    private let write: Write
    private var generation = UUID()
    private(set) var userID: UUID?
    private(set) var value: ActivityVisibility?
    private(set) var isConfirmed = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var isBusy: Bool { isLoading || isSaving }
    var confirmedValue: ActivityVisibility? { isConfirmed ? value : nil }

    init(read: @escaping Read, write: @escaping Write) {
        self.read = read; self.write = write
    }

    func activate(userID: UUID?) {
        generation = UUID(); self.userID = userID
        value = nil; isConfirmed = false; isLoading = false; isSaving = false; errorMessage = nil
    }

    func refresh() async {
        guard let owner = userID, !isBusy else { return }
        let request = generation
        isLoading = true; isConfirmed = false; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let profile = try await read(owner)
            guard generation == request, userID == owner else { return }
            guard profile.id == owner, let loaded = ActivityVisibility(rawValue: profile.activityVisibility) else { throw AppError.server }
            value = loaded; isConfirmed = true
        } catch {
            guard generation == request, userID == owner else { return }
            errorMessage = "Deine Sichtbarkeit konnte nicht geladen werden. Bitte versuche es erneut."
        }
    }

    @discardableResult
    func save(_ draft: ActivityVisibility) async -> Bool {
        guard let owner = userID, let expected = confirmedValue, !isBusy else { return false }
        guard draft != expected else { return true }
        let request = generation
        isSaving = true; errorMessage = nil
        defer { if generation == request { isSaving = false } }
        do {
            // The write filters both owner and previous value in one database
            // statement. It cannot overwrite a newer choice on another device.
            let profile = try await write(owner, draft, expected)
            guard generation == request, userID == owner else { return false }
            guard profile.id == owner, profile.activityVisibility == draft.rawValue else { throw AppError.server }
            value = draft; isConfirmed = true
            return true
        } catch {
            guard generation == request, userID == owner else { return false }
            isConfirmed = false
            errorMessage = "Die Änderung wurde nicht bestätigt. Lade deine Sichtbarkeit erneut und prüfe den gespeicherten Stand."
            return false
        }
    }
}
