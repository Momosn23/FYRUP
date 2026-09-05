import ActivityKit
import Foundation
import Observation
import UIKit

@MainActor @Observable
final class SessionLiveActivityStore {
    struct Input: Equatable {
        let sessionID: UUID
        let state: SessionLiveAttributes.ContentState
    }
    private let defaults: UserDefaults
    private var desired: Input?
    private var revision = 0
    private var worker: Task<Void, Never>?
    private(set) var errorMessage: String?
    private(set) var systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func synchronize(activity: Activity?, ownerID: UUID?, enabled: Bool, rest: WorkoutRestClock?, retry: Bool = false, now: Date = .now) {
        systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        var next: Input?
        if enabled, systemEnabled, let activity, activity.userID == ownerID, activity.status == .live,
           let elapsed = activity.duration(at: now), elapsed.isFinite, (0...604800).contains(elapsed) {
            let ownRest = rest.flatMap { $0.activityID == activity.id && $0.isValid ? $0 : nil }
            next = Input(sessionID: activity.id, state: .init(
                sport: activity.sport.title, symbol: activity.sport.symbol,
                timerReference: activity.startedAt?.addingTimeInterval(Double(activity.pausedSeconds ?? 0)) ?? now,
                pausedSeconds: activity.pausedAt != nil ? Int(elapsed) : nil,
                restStartedAt: ownRest?.startedAt, restEndsAt: ownRest?.endsAt, isGym: activity.sport == .gym))
            if retry { defaults.removeObject(forKey: attemptedKey(activity.id)) }
        }
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
            for existing in ActivityKit.Activity<SessionLiveAttributes>.activities where existing.attributes.sessionID != input?.sessionID {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            if version != revision { continue }
            if let input {
                let content = ActivityContent(state: input.state, staleDate: nil)
                if let existing = ActivityKit.Activity<SessionLiveAttributes>.activities.first(where: { $0.attributes.sessionID == input.sessionID }) {
                    if existing.activityState == .active || existing.activityState == .stale { await existing.update(content) }
                } else if UIApplication.shared.applicationState == .active, !defaults.bool(forKey: attemptedKey(input.sessionID)) {
                    do {
                        _ = try ActivityKit.Activity<SessionLiveAttributes>.request(attributes: .init(sessionID: input.sessionID), content: content, pushType: nil)
                        defaults.set(true, forKey: attemptedKey(input.sessionID)); errorMessage = nil
                    } catch { errorMessage = "Die Live-Anzeige konnte nicht gestartet werden. Deine Session läuft in FYRUP weiter." }
                }
            } else { errorMessage = nil }
            if version == revision { break }
        }
        worker = nil
    }
}
