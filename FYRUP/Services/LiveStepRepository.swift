import Foundation

extension LiveAppRepository {
    func stepSharingPreference(userID: UUID) async throws -> StepSharingPreference {
        try await client.rpc("get_step_sharing", body: ["p_user": userID.uuidString])
    }

    func setStepSharing(userID: UUID, enabled: Bool) async throws -> StepSharingPreference {
        struct Body: Encodable {
            let user: UUID; let enabled: Bool
            enum CodingKeys: String, CodingKey { case user = "p_user", enabled = "p_enabled" }
        }
        return try await client.rpc("set_step_sharing", body: Body(user: userID, enabled: enabled))
    }

    func syncSteps(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) async throws -> Bool {
        try await client.rpc("sync_daily_steps", body: StepSyncRequest(userID: userID, localDate: localDate,
                                                                     timezone: timezone, steps: steps,
                                                                     sharingRevision: sharingRevision, observedAt: observedAt))
    }

    func sharedSteps() async throws -> [DailyStepMetric] {
        try await client.rpc("friend_daily_steps", body: [:] as [String: String])
    }
}

/// The only Health payload is an owner-local-day total plus consent/order metadata.
/// Neither source samples nor HealthKit authorization state are transmitted.
struct StepSyncRequest: Encodable {
    let userID: UUID
    let localDate: String
    let timezone: String
    let steps: Int?
    let sharingRevision: Int
    let observedAt: Date
    enum CodingKeys: String, CodingKey {
        case userID = "p_user", localDate = "p_date", timezone = "p_timezone", steps = "p_steps"
        case sharingRevision = "p_sharing_revision", observedAt = "p_observed_at"
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(userID, forKey: .userID)
        try values.encode(localDate, forKey: .localDate)
        try values.encode(timezone, forKey: .timezone)
        // An unavailable aggregate explicitly withdraws the previous total; omission
        // must never be confused with a real zero or an unchanged payload.
        try values.encode(steps, forKey: .steps)
        try values.encode(sharingRevision, forKey: .sharingRevision)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try values.encode(formatter.string(from: observedAt), forKey: .observedAt)
    }
}
