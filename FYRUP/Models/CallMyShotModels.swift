import Foundation

enum ShotReaction: String, Codable, CaseIterable, Identifiable, Sendable {
    case fire = "🔥", target = "🎯", strong = "💪"
    var id: String { rawValue }
}

struct ShotReactionCount: Codable, Equatable, Sendable {
    let reaction: ShotReaction
    let count: Int
}

struct WeeklyCommitment: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let weekID: UUID
    let weekStartDate: String
    let weeklyGoal: Int
    let calledAt: Date
    let achieved: Bool
    let achievedAt: Date?
    let finalized: Bool
    let reactionCounts: [ShotReactionCount]
    let myReaction: ShotReaction?
    enum CodingKeys: String, CodingKey {
        case id, achieved, finalized
        case userID = "user_id", weekID = "week_id", weekStartDate = "week_start_date", weeklyGoal = "weekly_goal"
        case calledAt = "called_at", achievedAt = "achieved_at", reactionCounts = "reaction_counts", myReaction = "my_reaction"
    }
    var title: String { achieved ? "CALLED IT ✓" : "CALL MY SHOT" }
    var statusText: String {
        if achieved { return "Du hast dein angekündigtes Wochenziel geschafft." }
        return finalized ? "Neue Woche, neue Chance." : "Dein Wochenziel ist angekündigt."
    }
    var isValid: Bool {
        guard WeeklyGoal.isValid(weeklyGoal), calledAt.timeIntervalSince1970.isFinite,
              achieved == (achievedAt != nil), reactionCounts.allSatisfy({ $0.count > 0 }),
              Set(reactionCounts.map(\.reaction)).count == reactionCounts.count else { return false }
        if let achievedAt, !achievedAt.timeIntervalSince1970.isFinite || achievedAt < calledAt { return false }
        return true
    }
    func isValid(for week: WeeklyProgress) -> Bool {
        isValid && userID == week.userID && weekID == week.id && weekStartDate == week.weekStartDate && weeklyGoal == week.weeklyGoal
            && week.startsAt <= calledAt && calledAt < week.endsAt && achieved == week.flameEarned
            && achievedAt == week.flameEarnedAt && finalized == week.finalized
    }
}

protocol CallMyShotRepository: Sendable {
    /// The displayed week's ID is a consent precondition, never a week/goal
    /// override. The server rejects it after rollover rather than calling a new goal.
    func callMyShot(expectedWeekID: UUID) async throws -> WeeklyCommitment
    func setShotReaction(commitmentID: UUID, reaction: ShotReaction?) async throws -> Bool
}
