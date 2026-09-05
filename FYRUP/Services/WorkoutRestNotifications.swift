import Foundation
import UserNotifications

struct WorkoutRestReminder: Equatable, Sendable {
    static let requestIdentifier = "fyrup.workout.rest"
    let ownerID: UUID
    let clock: WorkoutRestClock
    let sound: Bool

    var userInfo: [String: String] {
        ["fyrup_local_type": "rest_finished", "owner_id": ownerID.uuidString,
         "activity_id": clock.activityID.uuidString, "rest_started": String(clock.startedAt.timeIntervalSince1970)]
    }
}

struct WorkoutRestReminderTap: Equatable, Sendable {
    let ownerID: UUID
    let activityID: UUID
    let startedAt: Date
    init?(requestIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard requestIdentifier == WorkoutRestReminder.requestIdentifier,
              userInfo["fyrup_local_type"] as? String == "rest_finished",
              let owner = userInfo["owner_id"] as? String, let ownerID = UUID(uuidString: owner),
              let activity = userInfo["activity_id"] as? String, let activityID = UUID(uuidString: activity),
              let started = userInfo["rest_started"] as? String, let seconds = Double(started), seconds.isFinite else { return nil }
        self.ownerID = ownerID; self.activityID = activityID; startedAt = Date(timeIntervalSince1970: seconds)
    }
    func matches(ownerID: UUID?, clock: WorkoutRestClock?) -> Bool {
        guard self.ownerID == ownerID, let clock, clock.isValid else { return false }
        return activityID == clock.activityID && abs(startedAt.timeIntervalSince(clock.startedAt)) < 0.001
    }
}

@MainActor
protocol WorkoutRestNotificationScheduling {
    func replace(with reminder: WorkoutRestReminder?) async throws
}

@MainActor
struct SilentWorkoutRestNotifications: WorkoutRestNotificationScheduling {
    func replace(with reminder: WorkoutRestReminder?) async throws {}
}

@MainActor
struct SystemWorkoutRestNotifications: WorkoutRestNotificationScheduling {
    func replace(with reminder: WorkoutRestReminder?) async throws { try await Self.schedule(reminder) }

    nonisolated private static func schedule(_ reminder: WorkoutRestReminder?) async throws {
        let id = WorkoutRestReminder.requestIdentifier
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        guard let reminder, reminder.clock.isValid else { return }
        let status = UNAuthorizationStatus(rawValue: await SystemNotificationAuthorization.rawStatus())
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            throw AppError.validation("Erlaube Mitteilungen auf diesem iPhone, wenn du beim Ablauf erinnert werden möchtest.")
        }
        let delay = reminder.clock.endsAt.timeIntervalSinceNow
        guard delay > 0, delay <= 600 else { return } // Never replay a missed alarm.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let content = UNMutableNotificationContent()
            content.title = "Satzpause geschafft"
            content.body = "Bereit für den nächsten Satz? Öffne deine Session in FYRUP."
            content.userInfo = reminder.userInfo
            if reminder.sound { content.sound = .default }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
