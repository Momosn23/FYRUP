import Foundation
import Observation

@MainActor @Observable
final class SessionIntervalStore {
    private let defaults: UserDefaults
    private(set) var userID: UUID?
    private(set) var clock: SessionIntervalClock?
    private(set) var lastConfiguration: SessionIntervalConfiguration?
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ suffix: String, owner: UUID) -> String { "fyrup.intervals.\(owner.uuidString).\(suffix)" }

    func activate(userID: UUID?) {
        self.userID = userID; clock = nil; lastConfiguration = nil
        guard let userID else { return }
        if let data = defaults.data(forKey: key("clock", owner: userID)),
           let restored = try? JSONDecoder().decode(SessionIntervalClock.self, from: data), restored.isValid { clock = restored }
        if let data = defaults.data(forKey: key("configuration", owner: userID)),
           let restored = try? JSONDecoder().decode(SessionIntervalConfiguration.self, from: data), restored.totalSeconds != nil { lastConfiguration = restored }
    }
    @discardableResult
    func start(activity: Activity, configuration: SessionIntervalConfiguration, now: Date = .now) -> Bool {
        guard let userID, activity.userID == userID, activity.status == .live, activity.pausedAt == nil,
              now.timeIntervalSince1970.isFinite, activity.startedAt?.timeIntervalSince1970.isFinite == true,
              SessionIntervalConfiguration.supports(activity.sport), let elapsed = activity.duration(at: now) else { return false }
        let value = SessionIntervalClock(activityID: activity.id, startedAtActiveSeconds: elapsed, configuration: configuration)
        guard value.isValid, let data = try? JSONEncoder().encode(value), let settings = try? JSONEncoder().encode(configuration) else { return false }
        defaults.set(data, forKey: key("clock", owner: userID))
        defaults.set(settings, forKey: key("configuration", owner: userID))
        clock = value; lastConfiguration = configuration; return true
    }
    func stop(activityID: UUID) {
        guard let userID, clock?.activityID == activityID else { return }
        defaults.removeObject(forKey: key("clock", owner: userID)); clock = nil
    }
    /// Only call with an authoritative response, never with a failed read or
    /// an empty startup cache. Losing the network must not discard the clock.
    func confirmActivity(_ activity: Activity?) {
        guard let clock else { return }
        if activity?.userID != userID || activity?.id != clock.activityID || activity?.status != .live {
            stop(activityID: clock.activityID)
        }
    }
    func clearDeletedAccount() {
        if let userID {
            defaults.removeObject(forKey: key("clock", owner: userID))
            defaults.removeObject(forKey: key("configuration", owner: userID))
        }
        activate(userID: nil)
    }
}
