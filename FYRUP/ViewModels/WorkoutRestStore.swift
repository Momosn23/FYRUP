import Foundation
import Observation

/// One device-local rest clock per account. A set pause does not pause the whole
/// session or change any recorded set. Dates keep it correct across backgrounding.
@MainActor @Observable
final class WorkoutRestStore {
    private let defaults: UserDefaults
    private(set) var userID: UUID?
    private(set) var clock: WorkoutRestClock?
    private(set) var selectedDuration = 90

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ suffix: String, owner: UUID) -> String { "fyrup.rest.\(owner.uuidString).\(suffix)" }

    func activate(userID: UUID?) {
        guard self.userID != userID else { return }
        self.userID = userID; clock = nil; selectedDuration = 90
        guard let userID else { return }
        let saved = defaults.integer(forKey: key("duration", owner: userID))
        if (15...600).contains(saved) { selectedDuration = saved }
        if let data = defaults.data(forKey: key("clock", owner: userID)),
           let restored = try? JSONDecoder().decode(WorkoutRestClock.self, from: data), restored.isValid { clock = restored }
    }
    func selectDuration(_ seconds: Int) {
        guard let userID, (15...600).contains(seconds) else { return }
        selectedDuration = seconds; defaults.set(seconds, forKey: key("duration", owner: userID))
    }
    func start(activityID: UUID, now: Date = .now) {
        guard let userID, now.timeIntervalSince1970.isFinite else { return }
        let value = WorkoutRestClock(activityID: activityID, startedAt: now, duration: selectedDuration)
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key("clock", owner: userID)); clock = value
    }
    func stop(activityID: UUID) {
        guard clock?.activityID == activityID, let userID else { return }
        clock = nil; defaults.removeObject(forKey: key("clock", owner: userID))
    }
    func clearDeletedAccount() {
        if let userID { for suffix in ["duration", "clock"] { defaults.removeObject(forKey: key(suffix, owner: userID)) } }
        activate(userID: nil)
    }
}
