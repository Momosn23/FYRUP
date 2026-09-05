import Foundation
import Observation

/// A failed read is unknown, never consent to the product's default preferences.
@MainActor
@Observable
final class NotificationPreferenceStore {
    typealias Read = @MainActor () async throws -> NotificationPreferences
    typealias Write = @MainActor (NotificationPreferences, NotificationPreferences) async throws -> NotificationPreferences

    private let read: Read
    private let write: Write
    private var generation = UUID()
    private(set) var userID: UUID?
    private(set) var value: NotificationPreferences?
    private(set) var isConfirmed = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var isBusy: Bool { isLoading || isSaving }
    var confirmedValue: NotificationPreferences? { isConfirmed ? value : nil }

    init(read: @escaping Read, write: @escaping Write) {
        self.read = read; self.write = write
    }

    func activate(userID: UUID?) {
        guard self.userID != userID else { return }
        generation = UUID(); self.userID = userID
        value = nil; isConfirmed = false; isLoading = false; isSaving = false; errorMessage = nil
    }

    func refresh() async {
        guard let ownerID = userID, !isBusy else { return }
        let request = generation
        isLoading = true; isConfirmed = false; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let loaded = try await read()
            guard generation == request, userID == ownerID else { return }
            value = loaded; isConfirmed = true
        } catch {
            guard generation == request, userID == ownerID else { return }
            errorMessage = "Deine Mitteilungseinstellungen konnten nicht geladen werden. Es wurde nichts geändert. Bitte versuche es erneut."
        }
    }

    @discardableResult
    func save(_ draft: NotificationPreferences, expected: NotificationPreferences) async -> Bool {
        guard let ownerID = userID, !isBusy, isConfirmed, value == expected else { return false }
        guard draft != expected else { return true }
        let request = generation
        isSaving = true; errorMessage = nil
        defer { if generation == request { isSaving = false } }
        do {
            // A form may have been open while another device changed an opt-out.
            // This preflight is for review/UX only. The server repeats the exact
            // expected-state comparison under its write lock to close the race.
            let latest = try await read()
            guard generation == request, userID == ownerID else { return false }
            value = latest
            guard latest == expected else {
                errorMessage = "Die Einstellungen wurden inzwischen geändert. Bitte prüfe den aktuellen Stand, bevor du speicherst."
                return false
            }
            let saved = try await write(draft, expected)
            guard generation == request, userID == ownerID else { return false }
            guard saved == draft else {
                isConfirmed = false
                errorMessage = "Die Änderung wurde nicht vollständig bestätigt. Bitte lade die Einstellungen erneut."
                return false
            }
            value = saved; isConfirmed = true
            return true
        } catch {
            guard generation == request, userID == ownerID else { return false }
            // A lost response can mean the write committed. Require a fresh read,
            // never retry automatically or report the draft as confirmed.
            isConfirmed = false
            errorMessage = "Die Änderung konnte nicht bestätigt werden. Bitte lade die Einstellungen erneut und prüfe den gespeicherten Stand."
            return false
        }
    }
}
