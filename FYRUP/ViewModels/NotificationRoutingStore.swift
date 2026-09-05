import Foundation
import Observation

/// A memory-only, latest-tap queue. It retains IDs through login/onboarding,
/// never cached content or a permission grant from an older account.
@MainActor @Observable
final class NotificationRoutingStore {
    private let repository: any NotificationRoutingRepository
    private var generation = UUID()
    private var ticket = UUID()
    private var accountID: UUID?
    private var mainReady = false
    private var lastDelivered: NotificationTapPayload?
    private(set) var pending: NotificationTapPayload?
    private(set) var presentation: NotificationPresentation?
    private(set) var isResolving = false
    var errorMessage: String?

    init(repository: any NotificationRoutingRepository) { self.repository = repository }

    func accountChanged(to userID: UUID?) {
        guard accountID != userID else { return }
        let previous = accountID
        generation = UUID(); ticket = UUID(); accountID = userID
        mainReady = false; presentation = nil; isResolving = false; errorMessage = nil; lastDelivered = nil
        // nil -> first restored/login account may consume a cold-start tap, but
        // explicit logout/account replacement must retire the previous intent.
        if previous != nil || (pending?.recipientID != nil && pending?.recipientID != userID) { pending = nil }
    }

    func setMainReady(_ ready: Bool) {
        mainReady = ready && accountID != nil
        if !mainReady { ticket = UUID(); presentation = nil; isResolving = false }
    }

    func dismiss() { presentation = nil }

    func revokeSocialDestinations() {
        ticket = UUID(); presentation = nil; pending = nil; lastDelivered = nil; isResolving = false
    }

    func isCurrent(_ value: NotificationPresentation) -> Bool {
        mainReady && accountID == value.userID && presentation?.id == value.id
    }

    func receive(_ payload: NotificationTapPayload) async {
        if let recipient = payload.recipientID, let accountID, recipient != accountID {
            ticket = UUID(); pending = nil; presentation = nil; isResolving = false
            errorMessage = "Diese Mitteilung gehört zu einem anderen Konto."; return
        }
        if lastDelivered == payload, presentation != nil { return }
        ticket = UUID(); pending = payload; presentation = nil; isResolving = false; errorMessage = nil
        await deliverPending()
    }

    func deliverPending() async {
        guard mainReady, let owner = accountID, let payload = pending, !isResolving, !Task.isCancelled else { return }
        if let recipient = payload.recipientID, recipient != owner { pending = nil; return }
        let request = generation; let read = ticket
        isResolving = true
        defer { if generation == request, ticket == read { isResolving = false } }
        do {
            let note: AppNotification?
            if let id = payload.notificationID { note = try await repository.notificationForRouting(id: id) }
            else {
                // Old installed pushes lacked receipt IDs. Never trust them across
                // login: match an actually authorized notification before routing.
                note = try await repository.notifications().first { item in
                    guard let trusted = NotificationTapPayload(notification: item, recipientID: owner) else { return false }
                    return trusted.type == payload.type && trusted.destination == payload.destination
                }
            }
            guard generation == request, ticket == read, accountID == owner, mainReady, !Task.isCancelled else { return }
            guard let note, payload.notificationID == nil || note.id == payload.notificationID,
                  let trusted = NotificationTapPayload(notification: note, recipientID: owner),
                  trusted.type == payload.type, trusted.destination == payload.destination else { throw AppError.accessDenied }
            pending = nil; lastDelivered = payload; errorMessage = nil
            presentation = NotificationPresentation(id: UUID(), userID: owner, destination: trusted.destination)
        } catch {
            guard generation == request, ticket == read, accountID == owner, mainReady, !Task.isCancelled else { return }
            // Keep the IDs for an explicit retry, but no old detail can remain visible.
            presentation = nil
            errorMessage = "Diese Mitteilung ist gerade nicht verfügbar. Sie wurde möglicherweise entfernt oder der Zugriff hat sich geändert."
        }
    }
}
