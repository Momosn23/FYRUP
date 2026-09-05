import Foundation

extension LiveAppRepository {
    func blindWorkouts() async throws -> [BlindWorkoutSummary] {
        try await client.rpc("list_blind_workouts", body: [:] as [String: String])
    }

    func blindWorkout(id: UUID) async throws -> BlindWorkoutState {
        try await client.rpc("get_blind_workout", body: ["p_id": id.uuidString])
    }

    func sendBlindWorkout(_ draft: BlindWorkoutDraft) async throws -> BlindWorkoutState {
        let normalized = draft.normalizedForSending()
        if let message = normalized.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable { let p_draft: BlindWorkoutDraft }
        return try await client.rpc("send_blind_workout", body: Body(p_draft: normalized))
    }

    func respondToBlindWorkout(id: UUID, accept: Bool, equipmentConfirmed: Bool) async throws -> BlindWorkoutState {
        struct Body: Encodable {
            let id: UUID; let accept: Bool; let equipment: Bool
            enum CodingKeys: String, CodingKey { case id = "p_id", accept = "p_accept", equipment = "p_equipment_confirmed" }
        }
        return try await client.rpc("respond_blind_workout", body: Body(id: id, accept: accept, equipment: equipmentConfirmed))
    }

    func planBlindWorkout(id: UUID, startsAt: Date) async throws -> BlindWorkoutState {
        struct Body: Encodable {
            let id: UUID; let startsAt: Date
            enum CodingKeys: String, CodingKey { case id = "p_id", startsAt = "p_starts_at" }
        }
        return try await client.rpc("plan_blind_workout", body: Body(id: id, startsAt: startsAt))
    }

    func startBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        try await client.rpc("start_blind_workout", body: ["p_id": id.uuidString])
    }

    func saveBlindWorkoutExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async throws -> BlindWorkoutState {
        try await client.rpc("save_blind_workout_exercise", body: BlindExerciseUpdateRequest(id: id, exerciseID: exerciseID, sets: sets, complete: complete))
    }

    func finishBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        try await client.rpc("finish_blind_workout", body: ["p_id": id.uuidString])
    }

    func cancelBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        try await client.rpc("cancel_blind_workout", body: ["p_id": id.uuidString])
    }

    func copyBlindWorkout(id: UUID) async throws -> WorkoutPlan {
        try await client.rpc("copy_blind_workout", body: ["p_id": id.uuidString])
    }
    func reactToBlindWorkout(id: UUID, reaction: ReactionKind?) async throws -> BlindWorkoutState {
        try await client.rpc("react_to_blind_workout", body: BlindReactionRequest(id: id, reaction: reaction))
    }
}

struct BlindReactionRequest: Encodable {
    let id: UUID
    let reaction: ReactionKind?
    enum CodingKeys: String, CodingKey { case id = "p_id", reaction = "p_reaction" }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(reaction, forKey: .reaction)
    }
}

struct BlindExerciseUpdateRequest: Encodable {
    let id: UUID
    let exerciseID: UUID
    let sets: [WorkoutSetLog]
    let complete: Bool
    enum CodingKeys: String, CodingKey {
        case id = "p_id", exerciseID = "p_exercise_id", sets = "p_sets", complete = "p_complete"
    }
}
