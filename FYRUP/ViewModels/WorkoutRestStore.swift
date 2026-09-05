import Foundation
import Observation

/// One device-local rest clock per account. A set pause does not pause the whole
/// session or change any recorded set. Dates keep it correct across backgrounding.
@MainActor @Observable
final class WorkoutRestStore {
    private let defaults: UserDefaults
    private let notifications: any WorkoutRestNotificationScheduling
    private let now: @MainActor () -> Date
    private var hasActivated = false
    private var confirmedActivityID: UUID?
    private var notificationRevision = 0
    private var notificationWorker: Task<Void, Never>?
    private var desiredReminder: WorkoutRestReminder?
    private var appliedReminder: WorkoutRestReminder?
    private(set) var userID: UUID?
    private(set) var clock: WorkoutRestClock?
    private(set) var selectedDuration = 90
    private(set) var reminderEnabled = false
    private(set) var soundEnabled = false
    private(set) var reminderMessage: String?

    init(defaults: UserDefaults = FYRUPWidgetState.defaults, notifications: any WorkoutRestNotificationScheduling = SilentWorkoutRestNotifications(), now: @escaping @MainActor () -> Date = { .now }) {
        self.defaults = defaults; self.notifications = notifications; self.now = now
    }
    func reloadExternalClock() {
        guard let userID else { return }
        if let data = defaults.data(forKey: key("clock", owner: userID)),
           let restored = try? JSONDecoder().decode(WorkoutRestClock.self, from: data), restored.isValid,
           restored.activityID == confirmedActivityID {
            clock = restored
        } else if clock != nil {
            clock = nil
        }
        synchronizeReminder(force: true)
    }
    private func key(_ suffix: String, owner: UUID) -> String { "fyrup.rest.\(owner.uuidString).\(suffix)" }

    func activate(userID: UUID?) {
        guard !hasActivated || self.userID != userID else { return }
        hasActivated = true
        self.userID = userID; clock = nil; selectedDuration = 90
        confirmedActivityID = nil; reminderEnabled = false; soundEnabled = false
        synchronizeReminder(force: true)
        guard let userID else { return }
        migrateLegacyPreferencesIfNeeded(owner: userID)
        reminderEnabled = defaults.bool(forKey: key("reminder", owner: userID))
        soundEnabled = defaults.bool(forKey: key("sound", owner: userID))
        let saved = defaults.integer(forKey: key("duration", owner: userID))
        if (15...600).contains(saved) { selectedDuration = saved }
        if let data = defaults.data(forKey: key("clock", owner: userID)),
           let restored = try? JSONDecoder().decode(WorkoutRestClock.self, from: data), restored.isValid { clock = restored }
    }
    private func migrateLegacyPreferencesIfNeeded(owner: UUID) {
        guard defaults === FYRUPWidgetState.defaults, defaults !== UserDefaults.standard else { return }
        let legacy = UserDefaults.standard
        for suffix in ["duration", "clock", "reminder", "sound"] {
            let storageKey = key(suffix, owner: owner)
            guard defaults.object(forKey: storageKey) == nil, let value = legacy.object(forKey: storageKey) else { continue }
            defaults.set(value, forKey: storageKey)
        }
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
        confirmedActivityID = activityID; synchronizeReminder(force: true)
    }
    func stop(activityID: UUID) {
        guard clock?.activityID == activityID, let userID else { return }
        clock = nil; defaults.removeObject(forKey: key("clock", owner: userID))
        synchronizeReminder(force: true)
    }
    func confirmActivity(_ activity: Activity?) {
        confirmedActivityID = activity?.userID == userID && activity?.status == .live ? activity?.id : nil
        synchronizeReminder()
    }
    func setReminderEnabled(_ enabled: Bool) {
        guard let userID else { return }
        reminderEnabled = enabled; defaults.set(enabled, forKey: key("reminder", owner: userID)); synchronizeReminder(force: true)
    }
    func setSoundEnabled(_ enabled: Bool) {
        guard let userID else { return }
        soundEnabled = enabled; defaults.set(enabled, forKey: key("sound", owner: userID)); synchronizeReminder(force: true)
    }
    func retryReminder() { synchronizeReminder(force: true) }
    func waitForReminderSynchronization() async { await notificationWorker?.value }

    private func synchronizeReminder(force: Bool = false) {
        let next: WorkoutRestReminder?
        if reminderEnabled, let userID, let clock, confirmedActivityID == clock.activityID, clock.remaining(at: now()) > 0 {
            next = WorkoutRestReminder(ownerID: userID, clock: clock, sound: soundEnabled)
        } else { next = nil }
        if !force, next == desiredReminder, next == appliedReminder { return }
        desiredReminder = next; notificationRevision += 1; reminderMessage = nil
        guard notificationWorker == nil else { return }
        notificationWorker = Task { await reconcileReminder() }
    }
    private func reconcileReminder() async {
        while !Task.isCancelled {
            let revision = notificationRevision, reminder = desiredReminder
            do {
                try await notifications.replace(with: reminder)
                if revision == notificationRevision { appliedReminder = reminder; reminderMessage = nil }
            } catch {
                if revision == notificationRevision {
                    appliedReminder = nil
                    reminderMessage = "Die Erinnerung ist nicht bestätigt. Prüfe die Mitteilungsfreigabe; der Timer läuft in FYRUP weiter."
                }
            }
            if revision == notificationRevision { break }
        }
        notificationWorker = nil
    }
    func clearDeletedAccount() {
        if let userID { for suffix in ["duration", "clock", "reminder", "sound"] { defaults.removeObject(forKey: key(suffix, owner: userID)) } }
        activate(userID: nil)
    }
}
