import Foundation

extension AppRepository {
    /// Default keeps test/demo repositories compatible. Live uses an exact RLS
    /// lookup, so opening a push is not limited by the inbox's fifty-row page.
    func notificationForRouting(id: UUID) async throws -> AppNotification? {
        try await notifications().first { $0.id == id }
    }

    func activityForNotification(id: UUID, userID: UUID) async throws -> NotificationActivityDetail? {
        let feed = try await today(userID: userID)
        let visible = [feed.0].compactMap { $0 } + feed.1.compactMap(\.activity)
        if let activity = visible.first(where: { $0.id == id }), let owner = try await profile(userID: activity.userID) {
            return NotificationActivityDetail(activity: activity, owner: owner)
        }
        if let activity = try await recentActivities(userID: userID).first(where: { $0.id == id }), let owner = try await profile(userID: userID) {
            return NotificationActivityDetail(activity: activity, owner: owner)
        }
        return nil
    }
}

extension LiveAppRepository {
    func notificationForRouting(id: UUID) async throws -> AppNotification? {
        let values: [AppNotification] = try await client.select("notifications", query: [
            .init(name: "id", value: "eq.\(id.uuidString)"), .init(name: "select", value: "*"), .init(name: "limit", value: "1")
        ])
        return values.first
    }

    func activityForNotification(id: UUID, userID: UUID) async throws -> NotificationActivityDetail? {
        let values: [Activity] = try await client.select("activities", query: [
            .init(name: "id", value: "eq.\(id.uuidString)"), .init(name: "select", value: "*"), .init(name: "limit", value: "1")
        ])
        guard let activity = values.first, activity.id == id, let owner = try await profile(userID: activity.userID) else { return nil }
        return NotificationActivityDetail(activity: activity, owner: owner)
    }
}
