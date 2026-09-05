import Foundation

extension DemoRepository {
    func callMyShot(expectedWeekID: UUID) async throws -> WeeklyCommitment {
        _ = try await weeklyState(userID: meID, timezone: nil)
        return try await weeklyStorage.callMyShot(userID: meID, expectedWeekID: expectedWeekID, friends: Set(crew.map(\.id)), displayName: me.displayName)
    }
    func setShotReaction(commitmentID: UUID, reaction: ShotReaction?) async throws -> Bool {
        try await weeklyStorage.reactToShot(commitmentID: commitmentID, viewer: meID, friends: Set(crew.map(\.id)), reaction: reaction, displayName: me.displayName)
    }
    func weeklyNotifications() async throws -> [AppNotification] {
        try await weeklyStorage.notifications(userID: meID, friends: Set(crew.map(\.id)))
    }
}
