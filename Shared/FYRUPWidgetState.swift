import ActivityKit
import AppIntents
import Foundation
@preconcurrency import UserNotifications

enum FYRUPWidgetState {
    static let appGroup = "group.app.fyrup.shared"
    static let snapshotKey = "fyrup.widget.live.snapshot"

    nonisolated(unsafe) static let defaults: UserDefaults = UserDefaults(suiteName: appGroup) ?? .standard
    static func restKey(ownerID: UUID, suffix: String) -> String { "fyrup.rest.\(ownerID.uuidString).\(suffix)" }

    static func snapshot(from defaults: UserDefaults = defaults) -> FYRUPWidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(FYRUPWidgetSnapshot.self, from: data)
    }
    static func save(_ snapshot: FYRUPWidgetSnapshot?, to defaults: UserDefaults = defaults) {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            defaults.removeObject(forKey: snapshotKey); return
        }
        defaults.set(data, forKey: snapshotKey)
    }

    static func toggleRest(activityID: UUID, ownerID: UUID, now: Date = .now, defaults: UserDefaults = defaults) -> FYRUPWidgetSnapshot? {
        guard var snapshot = snapshot(from: defaults), snapshot.sessionID == activityID,
              snapshot.ownerID == ownerID, snapshot.state.isGym else { return nil }
        let clockKey = restKey(ownerID: ownerID, suffix: "clock")
        if let end = snapshot.state.restEndsAt, end > now {
            defaults.removeObject(forKey: clockKey)
            snapshot.state.restStartedAt = nil; snapshot.state.restEndsAt = nil
        } else {
            let saved = defaults.integer(forKey: restKey(ownerID: ownerID, suffix: "duration"))
            let duration = (15...600).contains(saved) ? saved : 90
            let clock = WidgetRestClock(activityID: activityID, startedAt: now, duration: duration)
            guard let data = try? JSONEncoder().encode(clock) else { return nil }
            defaults.set(data, forKey: clockKey)
            snapshot.state.restStartedAt = clock.startedAt; snapshot.state.restEndsAt = clock.endsAt
        }
        save(snapshot, to: defaults)
        return snapshot
    }
}

struct FYRUPWidgetSnapshot: Codable, Equatable, Sendable {
    let ownerID: UUID
    let sessionID: UUID
    var state: SessionLiveAttributes.ContentState

    var activeRest: WidgetRestClock? {
        guard let start = state.restStartedAt, let end = state.restEndsAt, end > Date() else { return nil }
        return WidgetRestClock(activityID: sessionID, startedAt: start, duration: Int(end.timeIntervalSince(start)))
    }
}

struct WidgetRestClock: Codable, Equatable, Sendable {
    let activityID: UUID
    let startedAt: Date
    let duration: Int
    var endsAt: Date { startedAt.addingTimeInterval(TimeInterval(duration)) }
}

struct ToggleFYRUPRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Satzpause starten oder beenden"
    static var description = IntentDescription("Steuert die Satzpause deiner aktuell laufenden FYRUP-Session.")
    static var isDiscoverable = false

    @Parameter(title: "Aktivität") var activityID: String
    @Parameter(title: "Konto") var ownerID: String

    init() { activityID = ""; ownerID = "" }
    init(activityID: UUID, ownerID: UUID) {
        self.activityID = activityID.uuidString
        self.ownerID = ownerID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let activity = UUID(uuidString: activityID), let owner = UUID(uuidString: ownerID),
              let before = FYRUPWidgetState.snapshot(), before.sessionID == activity,
              before.ownerID == owner, before.state.isGym,
              let snapshot = FYRUPWidgetState.toggleRest(activityID: activity, ownerID: owner) else { return .result() }

        let defaults = FYRUPWidgetState.defaults
        if before.activeRest != nil {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["fyrup.workout.rest"])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["fyrup.workout.rest"])
        } else if let clock = snapshot.activeRest {
            if defaults.bool(forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "reminder")) {
                let content = UNMutableNotificationContent()
                content.title = "Satzpause geschafft"
                content.body = "Bereit für den nächsten Satz? Öffne deine Session in FYRUP."
                content.userInfo = ["fyrup_local_type": "rest_finished", "owner_id": owner.uuidString,
                                    "activity_id": activity.uuidString, "rest_started": String(clock.startedAt.timeIntervalSince1970)]
                if defaults.bool(forKey: FYRUPWidgetState.restKey(ownerID: owner, suffix: "sound")) { content.sound = .default }
                let request = UNNotificationRequest(identifier: "fyrup.workout.rest", content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(clock.duration), repeats: false))
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
        if let live = ActivityKit.Activity<SessionLiveAttributes>.activities.first(where: { $0.attributes.sessionID == activity }) {
            await live.update(ActivityContent(state: snapshot.state, staleDate: nil))
        }
        return .result()
    }
}
