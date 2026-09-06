import Foundation

extension LiveAppRepository {
    func exercises() async throws -> [GymExercise] {
        try await client.rpc("list_exercises", body: [:] as [String: String])
    }

    func saveExercise(_ exercise: GymExercise) async throws -> GymExercise {
        let normalized = exercise.normalizedForSaving()
        if let message = normalized.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable {
            let exercise: GymExercise
            enum CodingKeys: String, CodingKey { case exercise = "p_exercise" }
        }
        return try await client.rpc("save_exercise", body: Body(exercise: normalized))
    }

    func archiveExercise(id: UUID) async throws {
        let _: Bool = try await client.rpc("archive_exercise", body: ["p_id": id.uuidString])
    }

    func favoriteExercise(id: UUID, favorite: Bool) async throws {
        struct Body: Encodable {
            let id: UUID; let favorite: Bool
            enum CodingKeys: String, CodingKey { case id = "p_id", favorite = "p_favorite" }
        }
        let _: Bool = try await client.rpc("set_exercise_favorite", body: Body(id: id, favorite: favorite))
    }

    func exerciseFavorites() async throws -> [UUID] {
        try await client.rpc("list_exercise_favorites", body: [:] as [String: String])
    }

    func workoutPlans(ownerID: UUID?) async throws -> [WorkoutPlan] {
        struct Body: Encodable {
            let owner: UUID?
            enum CodingKeys: String, CodingKey { case owner = "p_owner" }
        }
        return try await client.rpc("list_workout_plans", body: Body(owner: ownerID))
    }

    func workoutPlan(id: UUID) async throws -> WorkoutPlan {
        try await client.rpc("get_workout_plan", body: ["p_id": id.uuidString])
    }

    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws -> WorkoutPlan {
        let normalized = plan.normalizedForSaving()
        if let message = normalized.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable {
            let plan: WorkoutPlan
            enum CodingKeys: String, CodingKey { case plan = "p_plan" }
        }
        return try await client.rpc("save_workout_plan", body: Body(plan: normalized))
    }

    func archiveWorkoutPlan(id: UUID) async throws {
        let _: Bool = try await client.rpc("archive_workout_plan", body: ["p_id": id.uuidString])
    }

    func copyWorkoutPlan(id: UUID, requestID: UUID) async throws -> WorkoutPlan {
        try await client.rpc("copy_workout_plan", body: CopyWorkoutPlanRequest(id: id, requestID: requestID))
    }

    func shareWorkoutPlan(id: UUID, friendIDs: [UUID]) async throws {
        struct Body: Encodable {
            let id: UUID; let friends: [UUID]
            enum CodingKeys: String, CodingKey { case id = "p_id", friends = "p_friends" }
        }
        let _: Bool = try await client.rpc("share_workout_plan", body: Body(id: id, friends: Array(Set(friendIDs))))
    }

    func startWorkout(planID: UUID, linkedActivityID: UUID?, sessionID: UUID?, placeName: String?) async throws -> Activity {
        struct Body: Encodable {
            let plan: UUID; let linked: UUID?; let session: UUID?; let place: String?
            enum CodingKeys: String, CodingKey { case plan = "p_plan", linked = "p_linked", session = "p_session", place = "p_place_name" }
        }
        return try await client.rpc("start_workout", body: Body(plan: planID, linked: linkedActivityID, session: sessionID, place: placeName))
    }

    func planWorkout(planID: UUID, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws -> PlannedSession {
        try await client.rpc("plan_workout", body: PlanWorkoutRequest(
            plan: planID, startsAt: startsAt, duration: duration, note: note, place: placeName,
            friendsCanJoin: friendsCanJoin, friends: Array(Set(friendIDs))
        ))
    }

    func workoutLog(activityID: UUID) async throws -> WorkoutLog {
        try await client.rpc("get_workout_log", body: ["p_activity": activityID.uuidString])
    }

    func exercisePerformance(exerciseIDs: [UUID]) async throws -> [ExercisePerformance] {
        struct Body: Encodable {
            let exercises: [UUID]
            enum CodingKeys: String, CodingKey { case exercises = "p_exercises" }
        }
        guard !exerciseIDs.isEmpty else { return [] }
        return try await client.rpc("get_exercise_performance", body: Body(exercises: Array(Set(exerciseIDs))))
    }

    func saveWorkoutLog(_ log: WorkoutLog) async throws -> WorkoutLog {
        if let message = log.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable {
            let log: WorkoutLog
            enum CodingKeys: String, CodingKey { case log = "p_log" }
        }
        return try await client.rpc("save_workout_log", body: Body(log: log))
    }
}

struct CopyWorkoutPlanRequest: Encodable {
    let id: UUID; let requestID: UUID
    enum CodingKeys: String, CodingKey { case id = "p_id", requestID = "p_request_id" }
}

struct PlanWorkoutRequest: Encodable {
    let plan: UUID; let startsAt: Date; let duration: Int; let note: String?; let place: String?
    let friendsCanJoin: Bool; let friends: [UUID]
    enum CodingKeys: String, CodingKey {
        case plan = "p_plan", startsAt = "p_starts_at", duration = "p_duration", note = "p_note"
        case place = "p_place", friendsCanJoin = "p_friends_can_join", friends = "p_friends"
    }
    // These SQL parameters are required even when their value is NULL. The
    // synthesized encoder would omit them and PostgREST could not resolve the RPC.
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(plan, forKey: .plan); try values.encode(startsAt, forKey: .startsAt)
        try values.encode(duration, forKey: .duration); try values.encode(note, forKey: .note)
        try values.encode(place, forKey: .place); try values.encode(friendsCanJoin, forKey: .friendsCanJoin)
        try values.encode(friends, forKey: .friends)
    }
}
