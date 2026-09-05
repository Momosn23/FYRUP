import Foundation

extension LiveAppRepository {
    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState {
        try await client.rpc("get_weekly_state", body: WeeklyStateRequest(userID: userID, timezone: timezone))
    }

    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState {
        guard WeeklyGoal.isValid(goal) else { throw AppError.validation("Wähle ein Wochenziel zwischen 3 und 7 Trainings.") }
        struct Body: Encodable {
            let goal: Int; let timezone: String
            enum CodingKeys: String, CodingKey { case goal = "p_goal", timezone = "p_timezone" }
        }
        return try await client.rpc("confirm_weekly_goal", body: Body(goal: goal, timezone: timezone))
    }

    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState {
        guard WeeklyGoal.isValid(goal) else { throw AppError.validation("Wähle ein Wochenziel zwischen 3 und 7 Trainings.") }
        return try await client.rpc("set_next_weekly_goal", body: ["p_goal": goal])
    }

    func friendsWeeklyState() async throws -> [WeeklyFlameState] {
        try await client.rpc("get_friends_weekly_state", body: [:] as [String: String])
    }

    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool {
        try await client.rpc("set_flame_reaction", body: FlameReactionRequest(weekID: weekID, reaction: reaction))
    }

    func claimFlameCelebration(weekID: UUID) async throws -> Bool {
        try await client.rpc("claim_flame_celebration", body: ["p_week": weekID.uuidString])
    }
}

struct WeeklyStateRequest: Encodable {
    let userID: UUID
    let timezone: String?
    enum CodingKeys: String, CodingKey { case userID = "p_user", timezone = "p_timezone" }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(userID, forKey: .userID)
        // Friend reads explicitly carry no timezone mutation.
        try values.encode(timezone, forKey: .timezone)
    }
}

struct FlameReactionRequest: Encodable {
    let weekID: UUID
    let reaction: ReactionKind?
    enum CodingKeys: String, CodingKey { case weekID = "p_week", reaction = "p_reaction" }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weekID, forKey: .weekID)
        // nil removes the caller's reaction; it is never an omitted argument.
        try values.encode(reaction, forKey: .reaction)
    }
}
