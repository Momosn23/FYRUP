import Foundation

extension LiveAppRepository {
    func trainingRoutine() async throws -> TrainingRoutine {
        try await client.rpc("get_training_routine", body: [:] as [String: String])
    }
    func saveTrainingRoutine(_ routine: TrainingRoutine) async throws -> TrainingRoutine {
        if let message = routine.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable { let p_routine: TrainingRoutine }
        return try await client.rpc("save_training_routine", body: Body(p_routine: routine))
    }
    func trainingWeek(start: Date, end: Date) async throws -> TrainingWeekSnapshot {
        struct Body: Encodable { let p_start: Date; let p_end: Date }
        return try await client.rpc("get_personal_training_week", body: Body(p_start: start, p_end: end))
    }
    func workoutFeedback(activityID: UUID) async throws -> PersonalWorkoutFeedback {
        try await client.rpc("get_personal_workout_feedback", body: ["p_activity": activityID.uuidString])
    }
    func saveWorkoutFeedback(_ feedback: PersonalWorkoutFeedback) async throws -> PersonalWorkoutFeedback {
        if let message = feedback.validationMessage { throw AppError.validation(message) }
        struct Body: Encodable { let p_feedback: PersonalWorkoutFeedback }
        return try await client.rpc("save_personal_workout_feedback", body: Body(p_feedback: feedback))
    }
}
