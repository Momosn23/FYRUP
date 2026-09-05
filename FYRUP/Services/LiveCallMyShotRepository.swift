import Foundation

extension LiveAppRepository {
    func callMyShot(expectedWeekID: UUID) async throws -> WeeklyCommitment {
        try await client.rpc("call_my_shot", body: CallMyShotRequest(expectedWeekID: expectedWeekID))
    }
    func setShotReaction(commitmentID: UUID, reaction: ShotReaction?) async throws -> Bool {
        try await client.rpc("set_shot_reaction", body: ShotReactionRequest(commitmentID: commitmentID, reaction: reaction))
    }
}

struct CallMyShotRequest: Encodable {
    let expectedWeekID: UUID
    enum CodingKeys: String, CodingKey { case expectedWeekID = "p_expected_week" }
}

struct ShotReactionRequest: Encodable {
    let commitmentID: UUID
    let reaction: ShotReaction?
    enum CodingKeys: String, CodingKey { case commitmentID = "p_commitment", reaction = "p_reaction" }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(commitmentID, forKey: .commitmentID)
        try values.encode(reaction, forKey: .reaction)
    }
}
