import Foundation

extension DemoRepository {
    func trainingRoutine() async throws -> TrainingRoutine { try await workoutStorage.routine(userID: meID) }
    func saveTrainingRoutine(_ routine: TrainingRoutine) async throws -> TrainingRoutine { try await workoutStorage.saveRoutine(routine, userID: meID) }
    func trainingWeek(start: Date, end: Date) async throws -> TrainingWeekSnapshot {
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, end > start, end.timeIntervalSince(start) <= 8 * 86400 else { throw AppError.validation("Ungültige Woche.") }
        try await restoreWorkoutActivities()
        let own = activities.filter { activity in
            guard activity.userID == meID, activity.status != .cancelled,
                  let date = activity.endedAt ?? activity.startedAt ?? activity.plannedAt else { return false }
            return start <= date && date < end
        }
        let hosted = try await hostedSessions().map(\.session)
        let invited = try await invitations().filter { invite in invite.status == .accepted && crew.contains(where: { $0.id == invite.host.id }) }.map(\.session)
        var seen = Set<UUID>()
        let scheduled = (hosted + invited).filter { session in
            ["planned", "ready"].contains(session.status) && start <= session.startsAt && session.startsAt < end
                && !activities.contains { $0.userID == meID && $0.plannedSessionID == session.id && [.live, .completed].contains($0.status) }
                && seen.insert(session.id).inserted
        }
        return TrainingWeekSnapshot(activities: own, sessions: scheduled)
    }
    func workoutFeedback(activityID: UUID) async throws -> PersonalWorkoutFeedback {
        try await restoreWorkoutActivities()
        guard activities.contains(where: { $0.id == activityID && $0.userID == meID }) else { throw AppError.authentication }
        return try await workoutStorage.feedback(activityID: activityID, userID: meID)
    }
    func saveWorkoutFeedback(_ feedback: PersonalWorkoutFeedback) async throws -> PersonalWorkoutFeedback {
        try await restoreWorkoutActivities()
        guard let activity = activities.first(where: { $0.id == feedback.activityID && $0.userID == meID }), [.live, .completed].contains(activity.status) else { throw AppError.authentication }
        guard activity.status == .completed || (feedback.feeling == nil && WorkoutLimits.optionalText(feedback.note) == nil) else { throw AppError.validation("Beende das Training vor der Abschlussbewertung.") }
        if !feedback.exercises.isEmpty {
            let visible = try await workoutLog(activityID: activity.id)
            guard Set(feedback.exercises.map(\.exerciseID)).isSubset(of: Set(visible.exercises.map(\.id))) else { throw AppError.authentication }
        }
        return try await workoutStorage.saveFeedback(feedback, userID: meID)
    }
}
