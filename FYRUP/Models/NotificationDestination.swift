import Foundation

enum NotificationDestination: Hashable, Sendable {
    case inbox
    case friends
    case blindWorkout(UUID)
    case workoutPlan(UUID)
    case session(UUID)
    case activity(UUID)
    case supplement(UUID)
    case weekly(userID: UUID?, weekID: UUID?, commitmentID: UUID?)
}

/// Only typed identifiers cross from UserNotifications' non-Sendable userInfo
/// into the MainActor. Payload text never authorizes or supplies detail content.
struct NotificationTapPayload: Equatable, Sendable {
    let notificationID: UUID?
    let recipientID: UUID?
    let type: String
    let destination: NotificationDestination
    var marksSupplementTaken = false

    init?(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["fyrup_type"] as? String, !type.isEmpty, type.count <= 80 else { return nil }
        var ids: [String: UUID] = [:]
        for key in Self.identifierKeys {
            if let raw = userInfo[key] {
                guard let text = raw as? String, text.count == 36, let id = UUID(uuidString: text) else { return nil }
                ids[key] = id
            }
        }
        self.notificationID = ids["fyrup_notification_id"]
        self.recipientID = ids["fyrup_recipient_id"]
        self.type = type
        self.destination = Self.destination(type: type, ids: ids)
    }

    init?(notification: AppNotification, recipientID: UUID) {
        var values: [AnyHashable: Any] = notification.data ?? [:]
        values["fyrup_type"] = notification.type
        values["fyrup_notification_id"] = notification.id.uuidString
        values["fyrup_recipient_id"] = recipientID.uuidString
        self.init(userInfo: values)
    }

    private static let identifierKeys = ["fyrup_notification_id", "fyrup_recipient_id", "blind_workout_id", "plan_id", "session_id", "activity_id", "week_id", "commitment_id", "user_id", "dose_id"]
    private static func destination(type: String, ids: [String: UUID]) -> NotificationDestination {
        switch type {
        case "supplement_reminder": return ids["dose_id"].map(NotificationDestination.supplement) ?? .inbox
        case "friend_request", "friend_accepted", "fyrup": return .friends
        case "blind_workout_received", "blind_workout_completed", "blind_reaction":
            return ids["blind_workout_id"].map(NotificationDestination.blindWorkout) ?? .inbox
        case "workout_plan_shared": return ids["plan_id"].map(NotificationDestination.workoutPlan) ?? .inbox
        case "session_invite", "session_started", "session_updated", "session_cancelled", "session_joined", "session_reminder", "invite_response":
            return ids["session_id"].map(NotificationDestination.session) ?? .inbox
        case "reaction", "activity_started", "joined_live":
            return ids["activity_id"].map(NotificationDestination.activity) ?? .inbox
        case "weekly_goal", "flame_reaction": return .weekly(userID: nil, weekID: ids["week_id"], commitmentID: nil)
        case "shot_called", "shot_achieved", "shot_reaction":
            guard let owner = ids["user_id"], let week = ids["week_id"], let commitment = ids["commitment_id"] else { return .inbox }
            return .weekly(userID: owner, weekID: week, commitmentID: commitment)
        default: return .inbox
        }
    }
}

struct NotificationPresentation: Identifiable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let destination: NotificationDestination
    var marksSupplementTaken = false
    var notificationID: UUID? = nil
}

struct NotificationActivityDetail: Sendable {
    let activity: Activity
    let owner: Profile
}

protocol NotificationRoutingRepository: Sendable {
    func notifications() async throws -> [AppNotification]
    func notificationForRouting(id: UUID) async throws -> AppNotification?
    func activityForNotification(id: UUID, userID: UUID) async throws -> NotificationActivityDetail?
}
