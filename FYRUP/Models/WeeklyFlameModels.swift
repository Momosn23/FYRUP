import Foundation

enum WeeklyGoal {
    static let allowed = 3...7
    static let options = Array(allowed)
    static func isValid(_ value: Int) -> Bool { allowed.contains(value) }
}

struct WeeklyFlameReactionCount: Codable, Equatable, Sendable {
    let reaction: ReactionKind
    let count: Int
}

/// A server-authored snapshot. Local steps, timers and completed-screen taps cannot award credits.
struct WeeklyProgress: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let weekStartDate: String
    let timezone: String
    let startsAt: Date
    let endsAt: Date
    let weeklyGoal: Int
    let completedWorkouts: Int
    let flameEarned: Bool
    let flameEarnedAt: Date?
    let finalized: Bool
    let finalizedAt: Date?
    let reactionCounts: [WeeklyFlameReactionCount]
    let myReaction: ReactionKind?
    var commitment: WeeklyCommitment? = nil

    enum CodingKeys: String, CodingKey {
        case id, timezone, finalized
        case userID = "user_id", weekStartDate = "week_start_date", startsAt = "starts_at", endsAt = "ends_at"
        case weeklyGoal = "weekly_goal", completedWorkouts = "completed_workouts", flameEarned = "flame_earned"
        case flameEarnedAt = "flame_earned_at", finalizedAt = "finalized_at"
        case reactionCounts = "reaction_counts", myReaction = "my_reaction"
        case commitment
    }

    var fraction: Double {
        guard WeeklyGoal.isValid(weeklyGoal), completedWorkouts >= 0 else { return 0 }
        return min(1, Double(completedWorkouts) / Double(weeklyGoal))
    }
    var remaining: Int {
        guard WeeklyGoal.isValid(weeklyGoal), completedWorkouts >= 0 else { return 0 }
        return max(0, weeklyGoal - completedWorkouts)
    }
    var aboveGoal: Int {
        guard WeeklyGoal.isValid(weeklyGoal), completedWorkouts >= 0 else { return 0 }
        return max(0, completedWorkouts - weeklyGoal)
    }
    var progressText: String { "\(completedWorkouts) / \(weeklyGoal)" }
    var motivationText: String {
        if flameEarned { return aboveGoal > 0 ? "+\(aboveGoal) über deinem Ziel" : "Wochenziel geschafft" }
        return remaining == 1 ? "Noch 1 Training bis zu deiner Flamme" : "Noch \(remaining) Trainings bis zu deiner Flamme"
    }
    /// The natural owner/week key also prevents duplicate presentation if a row is restored with a different UUID.
    var celebrationID: String { "\(userID.uuidString.lowercased()):\(weekStartDate)" }

    var isValid: Bool {
        guard WeeklyGoal.isValid(weeklyGoal), completedWorkouts >= 0,
              startsAt.timeIntervalSince1970.isFinite, endsAt.timeIntervalSince1970.isFinite, startsAt < endsAt,
              TimeZone(identifier: timezone) != nil, Self.isDateLabel(weekStartDate),
              flameEarned == (completedWorkouts >= weeklyGoal),
              flameEarned == (flameEarnedAt != nil), finalized == (finalizedAt != nil) else { return false }
        if let earned = flameEarnedAt, !(startsAt <= earned && earned < endsAt) { return false }
        if let finalizedAt, !finalizedAt.timeIntervalSince1970.isFinite || finalizedAt < endsAt { return false }
        guard reactionCounts.allSatisfy({ $0.count >= 0 }),
              Set(reactionCounts.map(\.reaction)).count == reactionCounts.count else { return false }
        guard commitment.map({ $0.isValid(for: self) }) ?? true else { return false }
        return flameEarned || (reactionCounts.isEmpty && myReaction == nil)
    }

    private static func isDateLabel(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              value.allSatisfy({ $0 == "-" || ($0.isASCII && $0.isNumber) }),
              let year = Int(parts[0]), (1...9999).contains(year), let month = Int(parts[1]), let day = Int(parts[2]) else { return false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        let decoded = calendar.dateComponents([.year, .month, .day], from: date)
        return decoded.year == year && decoded.month == month && decoded.day == day
    }
}

struct WeeklyFlameState: Codable, Equatable, Sendable {
    let userID: UUID
    let serverNow: Date
    let currentWeek: WeeklyProgress?
    let suggestedWeeklyGoal: Int
    let nextWeeklyGoal: Int?
    let nextTimezone: String?
    let goalConfirmed: Bool
    /// Only finalized, consecutive successful weeks count. Never derived from the truncated client history.
    let currentStreak: Int
    let bestStreak: Int
    let history: [WeeklyProgress]

    enum CodingKeys: String, CodingKey {
        case history
        case userID = "user_id", serverNow = "server_now", currentWeek = "current_week"
        case suggestedWeeklyGoal = "suggested_weekly_goal", nextWeeklyGoal = "next_weekly_goal", nextTimezone = "next_timezone"
        case goalConfirmed = "goal_confirmed", currentStreak = "current_streak", bestStreak = "best_streak"
    }

    var isValid: Bool {
        guard serverNow.timeIntervalSince1970.isFinite, WeeklyGoal.isValid(suggestedWeeklyGoal),
              nextWeeklyGoal.map(WeeklyGoal.isValid) ?? true, currentStreak >= 0, bestStreak >= currentStreak,
              goalConfirmed == (currentWeek != nil),
              nextTimezone.map({ TimeZone(identifier: $0) != nil }) ?? true else { return false }
        if let week = currentWeek {
            guard week.userID == userID, week.isValid, !week.finalized,
                  week.startsAt <= serverNow, serverNow < week.endsAt else { return false }
        } else if nextWeeklyGoal != nil { return false }
        guard history.allSatisfy({ $0.userID == userID && $0.isValid && $0.finalized && $0.endsAt <= serverNow }),
              Set(history.map(\.id)).count == history.count,
              Set(history.map(\.weekStartDate)).count == history.count else { return false }
        if let week = currentWeek, history.contains(where: { $0.id == week.id || $0.weekStartDate == week.weekStartDate }) { return false }
        return true
    }
}

struct WeeklyFlameCelebration: Identifiable, Equatable, Sendable {
    let week: WeeklyProgress
    var id: String { week.celebrationID }
}

protocol WeeklyFlameRepository: Sendable {
    /// nil timezone when reading a friend's state: readers never change someone else's weekly boundaries.
    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState
    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState
    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState
    func friendsWeeklyState() async throws -> [WeeklyFlameState]
    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool
    /// Atomically claims an earned own week once on the server, including across devices.
    func claimFlameCelebration(weekID: UUID) async throws -> Bool
}
