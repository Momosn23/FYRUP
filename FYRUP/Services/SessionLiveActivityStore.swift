import ActivityKit
import Foundation
import Observation
import UIKit

@MainActor @Observable
final class SessionLiveActivityStore {
    struct Input: Equatable, Sendable {
        let ownerID: UUID
        let sessionID: UUID
        let state: SessionLiveAttributes.ContentState
    }
    private let defaults: UserDefaults
    private var desired: Input?
    private var revision = 0
    private var worker: Task<Void, Never>?
    private(set) var errorMessage: String?
    private(set) var systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    init(defaults: UserDefaults = FYRUPWidgetState.defaults) { self.defaults = defaults }
    func synchronize(activity: Activity?, ownerID: UUID?, enabled: Bool, rest: WorkoutRestClock?, retry: Bool = false, now: Date = .now) {
        systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        var next: Input?
        if enabled, systemEnabled, let activity, activity.userID == ownerID, activity.status == .live,
           let elapsed = activity.duration(at: now), elapsed.isFinite, (0...604800).contains(elapsed) {
            let ownRest = rest.flatMap { $0.activityID == activity.id && $0.isValid ? $0 : nil }
            next = Input(ownerID: activity.userID, sessionID: activity.id, state: .init(
                sport: activity.sport.title, symbol: activity.sport.symbol,
                timerReference: activity.startedAt?.addingTimeInterval(Double(activity.pausedSeconds ?? 0)) ?? now,
                pausedSeconds: activity.pausedAt != nil ? Int(elapsed) : nil,
                restStartedAt: ownRest?.startedAt, restEndsAt: ownRest?.endsAt, isGym: activity.sport == .gym))
            if retry { defaults.removeObject(forKey: attemptedKey(activity.id)) }
        }
        FYRUPWidgetState.save(next.map { FYRUPWidgetSnapshot(ownerID: $0.ownerID, sessionID: $0.sessionID, state: $0.state) }, to: defaults)
        if next == desired, !retry, worker != nil { return }
        desired = next; revision += 1
        guard worker == nil else { return }
        worker = Task { await drain() }
    }
    private func attemptedKey(_ id: UUID) -> String { "fyrup.live.requested.\(id.uuidString)" }
    /// A single worker orders lifecycle calls. An old suspended update cannot win
    /// over a later logout, opt-out, completion or account change.
    private func drain() async {
        while !Task.isCancelled {
            let version = revision, input = desired
            await Self.endOtherActivities(keeping: input?.sessionID)
            if version != revision { continue }
            if let input {
                let content = ActivityContent(state: input.state, staleDate: nil)
                let alreadyExists = await Self.updateExistingActivity(input)
                if version != revision { continue }
                if !alreadyExists, UIApplication.shared.applicationState == .active, !defaults.bool(forKey: attemptedKey(input.sessionID)) {
                    do {
                        _ = try ActivityKit.Activity<SessionLiveAttributes>.request(attributes: .init(sessionID: input.sessionID, ownerID: input.ownerID), content: content, pushType: nil)
                        defaults.set(true, forKey: attemptedKey(input.sessionID)); errorMessage = nil
                    } catch { errorMessage = "Die Live-Anzeige konnte nicht gestartet werden. Deine Session läuft in FYRUP weiter." }
                }
            } else { errorMessage = nil }
            if version == revision { break }
        }
        worker = nil
    }

    // The older iOS SDK does not declare Activity handles Sendable. Obtain and
    // consume them inside one nonisolated task; never send a main-actor handle
    // across an await. Only our immutable Sendable snapshot crosses the boundary.
    nonisolated private static func endOtherActivities(keeping sessionID: UUID?) async {
        for existing in ActivityKit.Activity<SessionLiveAttributes>.activities where existing.attributes.sessionID != sessionID {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
    }
    nonisolated private static func updateExistingActivity(_ input: Input) async -> Bool {
        guard let existing = ActivityKit.Activity<SessionLiveAttributes>.activities.first(where: { $0.attributes.sessionID == input.sessionID }) else { return false }
        if existing.activityState == .active || existing.activityState == .stale {
            await existing.update(ActivityContent(state: input.state, staleDate: nil))
        }
        return true
    }
}
