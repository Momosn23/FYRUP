import Foundation

enum BlindWorkoutFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case push, pull, legs, upperBody = "upper_body", lowerBody = "lower_body", fullBody = "full_body"
    case chest, back, arms, shoulders, cardio, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .push: "Push"; case .pull: "Pull"; case .legs: "Beine"; case .upperBody: "Oberkörper"
        case .lowerBody: "Unterkörper"; case .fullBody: "Ganzkörper"; case .chest: "Brust"
        case .back: "Rücken"; case .arms: "Arme"; case .shoulders: "Schultern"; case .cardio: "Cardio"; case .custom: "Eigener Fokus"
        }
    }
}

enum BlindWorkoutStatus: String, Codable, CaseIterable, Sendable {
    case sent, accepted, planned, live, completed, declined, cancelled
    var title: String {
        switch self {
        case .sent: "Einladung"; case .accepted: "Angenommen"; case .planned: "Geplant"; case .live: "LIVE"
        case .completed: "Geschafft"; case .declined: "Abgelehnt"; case .cancelled: "Nicht abgeschlossen"
        }
    }
}

enum BlindWorkoutRole: String, Codable, Sendable { case creator, recipient }

struct BlindWorkoutReactionCount: Codable, Equatable, Sendable {
    let reaction: ReactionKind
    let count: Int
}

/// Product limits, not recommendations or a promise that a particular workout is safe.
/// A recipient can decline or stop at any point regardless of these bounds.
enum BlindWorkoutLimits {
    static let exercises = 1...12
    static let targetSets = 1...6
    static let strengthReps = 1...30
    static let timedSeconds = 1...300
    static let durationMinutes = 5...180
    static let targetWeight = 0.0...500.0
}

struct BlindWorkoutDraft: Codable, Equatable, Sendable {
    /// Preserved on send retries; a successful send cannot create duplicate invitations.
    var id: UUID = UUID()
    var recipientID: UUID
    var title: String?
    var focus: BlindWorkoutFocus = .fullBody
    var estimatedDurationMinutes: Int = 45
    var exercises: [WorkoutPlanExercise] = []
    enum CodingKeys: String, CodingKey {
        case id, title, focus, exercises
        case recipientID = "recipient_id", estimatedDurationMinutes = "estimated_duration_minutes"
    }

    var validationMessage: String? {
        if let title, title.trimmingCharacters(in: .whitespacesAndNewlines).count > 60 {
            return "Gib dem Workout einen kurzen Namen mit höchstens 60 Zeichen oder lass den Namen frei."
        }
        if !BlindWorkoutLimits.durationMinutes.contains(estimatedDurationMinutes) { return "Wähle eine geschätzte Dauer zwischen 5 und 180 Minuten." }
        if !BlindWorkoutLimits.exercises.contains(exercises.count) { return "Wähle zwischen 1 und 12 Übungen aus der Übungsbibliothek." }
        if Set(exercises.map(\.id)).count != exercises.count { return "Eine Übungsposition ist doppelt vorhanden." }
        for row in exercises {
            if let message = row.validationMessage { return message }
            let allowedReps = row.exercise.isTimed ? BlindWorkoutLimits.timedSeconds : BlindWorkoutLimits.strengthReps
            if !BlindWorkoutLimits.targetSets.contains(row.targetSets) || !allowedReps.contains(row.targetRepsMin) || !allowedReps.contains(row.targetRepsMax) {
                return row.exercise.isTimed ? "Nutze 1–6 Sätze und 1–300 Sekunden pro Vorgabe." : "Nutze 1–6 Sätze und 1–30 Wiederholungen pro Vorgabe."
            }
            if let weight = row.targetWeight, !weight.isFinite || !BlindWorkoutLimits.targetWeight.contains(weight) {
                return "Prüfe die optionale Gewichtsvorgabe. Sie ist kein tatsächlich verwendetes Gewicht."
            }
        }
        return nil
    }

    func normalizedForSending() -> BlindWorkoutDraft {
        var value = self
        value.title = WorkoutLimits.optionalText(title)
        value.exercises = exercises.enumerated().map { index, input in
            var row = input
            row.sortOrder = index; row.note = WorkoutLimits.optionalText(row.note)
            row.exercise = row.exercise.normalizedForSaving()
            return row
        }
        return value
    }
}

/// A safe invitation/overview DTO. It deliberately has no exercise names, IDs,
/// ordering, prescriptions or actual training measurements.
struct BlindWorkoutSummary: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let creatorID: UUID
    let recipientID: UUID
    let creatorName: String
    let recipientName: String
    let title: String?
    let focus: BlindWorkoutFocus
    let estimatedDurationMinutes: Int
    let exerciseCount: Int
    let requiredEquipment: [ExerciseEquipment]
    let muscleGroups: [MuscleGroup]
    let status: BlindWorkoutStatus
    let createdAt: Date
    let scheduledAt: Date?
    let acceptedAt: Date?
    let startedAt: Date?
    let completedAt: Date?
    let activityID: UUID?
    let completedExercises: Int

    enum CodingKeys: String, CodingKey {
        case id, title, focus, status
        case creatorID = "creator_id", recipientID = "recipient_id", creatorName = "creator_name", recipientName = "recipient_name"
        case estimatedDurationMinutes = "estimated_duration_minutes", exerciseCount = "exercise_count"
        case requiredEquipment = "required_equipment", muscleGroups = "muscle_groups"
        case createdAt = "created_at", scheduledAt = "scheduled_at", acceptedAt = "accepted_at"
        case startedAt = "started_at", completedAt = "completed_at", activityID = "activity_id", completedExercises = "completed_exercises"
    }

    var displayTitle: String { title ?? "\(focus.title) · Blind Workout" }
    var progress: Double { exerciseCount > 0 ? min(1, Double(completedExercises) / Double(exerciseCount)) : 0 }
    var isValid: Bool {
        guard creatorID != recipientID, BlindWorkoutLimits.exercises.contains(exerciseCount),
              BlindWorkoutLimits.durationMinutes.contains(estimatedDurationMinutes), (0...exerciseCount).contains(completedExercises),
              Set(requiredEquipment).count == requiredEquipment.count, Set(muscleGroups).count == muscleGroups.count,
              createdAt.timeIntervalSince1970.isFinite else { return false }
        if let title, title.count > 60 { return false }
        if status == .planned && (scheduledAt == nil || activityID == nil) { return false }
        if [.accepted, .planned, .live, .completed].contains(status) && acceptedAt == nil { return false }
        if [.live, .completed].contains(status) && (startedAt == nil || activityID == nil) { return false }
        if status == .completed && (completedAt == nil || completedExercises != exerciseCount) { return false }
        if status != .completed && completedAt != nil { return false }
        return true
    }
}

struct BlindWorkoutState: Codable, Equatable, Sendable {
    let summary: BlindWorkoutSummary
    let viewerRole: BlindWorkoutRole
    /// The server returns only this authorized prefix. Hidden future rows are not downloaded.
    let visibleExercises: [WorkoutExerciseLog]
    let activity: Activity?
    var reactionCounts: [BlindWorkoutReactionCount]? = nil
    var myReaction: ReactionKind? = nil
    enum CodingKeys: String, CodingKey {
        case summary, activity
        case viewerRole = "viewer_role", visibleExercises = "visible_exercises"
        case reactionCounts = "reaction_counts", myReaction = "my_reaction"
    }

    var currentExercise: WorkoutExerciseLog? {
        guard viewerRole == .recipient, summary.status == .live else { return nil }
        return visibleExercises.first { !$0.completed }
    }
    var canFinish: Bool { viewerRole == .recipient && summary.status == .live && summary.completedExercises == summary.exerciseCount }
    var canCopy: Bool { viewerRole == .creator || summary.status == .completed }
    var canReact: Bool { summary.status == .completed }

    var isValid: Bool {
        guard summary.isValid, Set(visibleExercises.map(\.id)).count == visibleExercises.count,
              visibleExercises.enumerated().allSatisfy({ $0.offset == $0.element.sortOrder }),
              visibleExercises.count <= summary.exerciseCount else { return false }
        for row in visibleExercises {
            let targetReps = row.exercise.isTimed ? BlindWorkoutLimits.timedSeconds : BlindWorkoutLimits.strengthReps
            guard row.exercise.validationMessage == nil, row.planExerciseID == nil,
                  BlindWorkoutLimits.targetSets.contains(row.targetSets), targetReps.contains(row.targetRepsMin),
                  targetReps.contains(row.targetRepsMax), row.targetRepsMin <= row.targetRepsMax,
                  (row.targetWeight.map { $0.isFinite && BlindWorkoutLimits.targetWeight.contains($0) } ?? true),
                  (row.note?.count ?? 0) <= WorkoutLimits.noteLength,
                  row.completed == (row.completedAt != nil), row.sets.count <= 6,
                  Set(row.sets.map(\.id)).count == row.sets.count, Set(row.sets.map(\.setNumber)).count == row.sets.count else { return false }
            if let completedAt = row.completedAt, !completedAt.timeIntervalSince1970.isFinite { return false }
            for set in row.sets {
                guard BlindWorkoutLimits.targetSets.contains(set.setNumber),
                      (set.reps.map { (0...targetReps.upperBound).contains($0) } ?? true),
                      (set.weight.map { $0.isFinite && BlindWorkoutLimits.targetWeight.contains($0) } ?? true),
                      set.completed == (set.completedAt != nil) else { return false }
                if let completedAt = set.completedAt, !completedAt.timeIntervalSince1970.isFinite { return false }
            }
        }
        if let reactionCounts {
            guard reactionCounts.allSatisfy({ $0.count > 0 && $0.count <= 2 }),
                  Set(reactionCounts.map(\.reaction)).count == reactionCounts.count,
                  reactionCounts.reduce(0, { $0 + $1.count }) <= 2 else { return false }
        }
        if summary.status != .completed && (!(reactionCounts?.isEmpty ?? true) || myReaction != nil) { return false }
        if let activity {
            guard activity.id == summary.activityID, activity.userID == summary.recipientID,
                  activity.blindWorkoutID == summary.id, activity.workoutPlanID == nil else { return false }
            switch summary.status {
            case .sent, .accepted, .declined: return false
            case .planned: if activity.status != .planned { return false }
            case .live: if activity.status != .live { return false }
            case .completed: if activity.status != .completed { return false }
            case .cancelled: if activity.status != .cancelled { return false }
            }
        } else if viewerRole == .recipient && summary.activityID != nil { return false }
        if viewerRole == .creator {
            if summary.status == .cancelled && visibleExercises.isEmpty && activity == nil { return true }
            return activity == nil && visibleExercises.count == summary.exerciseCount
                && visibleExercises.allSatisfy { $0.sets.isEmpty && !$0.completed && $0.completedAt == nil }
        }
        // Completion/reveal is a monotonic prefix, never arbitrary later rows.
        if !visibleExercises.isEmpty && !visibleExercises.enumerated().allSatisfy({ $0.element.completed == ($0.offset < summary.completedExercises) }) { return false }
        switch summary.status {
        case .sent, .accepted, .planned, .declined:
            return visibleExercises.isEmpty && summary.completedExercises == 0
        case .live:
            return visibleExercises.count == min(summary.completedExercises + 1, summary.exerciseCount)
                && visibleExercises.filter(\.completed).count == summary.completedExercises
        case .completed:
            return visibleExercises.count == summary.exerciseCount && visibleExercises.allSatisfy(\.completed)
        case .cancelled:
            // After access revocation, cancelling may return only the owner's
            // status, without disclosing any additional exercise content.
            return visibleExercises.isEmpty || (visibleExercises.count <= min(summary.completedExercises + 1, summary.exerciseCount)
                && visibleExercises.filter(\.completed).count == summary.completedExercises)
        }
    }
}

protocol BlindWorkoutRepository: Sendable {
    func blindWorkouts() async throws -> [BlindWorkoutSummary]
    func blindWorkout(id: UUID) async throws -> BlindWorkoutState
    func sendBlindWorkout(_ draft: BlindWorkoutDraft) async throws -> BlindWorkoutState
    func respondToBlindWorkout(id: UUID, accept: Bool, equipmentConfirmed: Bool) async throws -> BlindWorkoutState
    func planBlindWorkout(id: UUID, startsAt: Date) async throws -> BlindWorkoutState
    func startBlindWorkout(id: UUID) async throws -> BlindWorkoutState
    func saveBlindWorkoutExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async throws -> BlindWorkoutState
    func finishBlindWorkout(id: UUID) async throws -> BlindWorkoutState
    func cancelBlindWorkout(id: UUID) async throws -> BlindWorkoutState
    func copyBlindWorkout(id: UUID) async throws -> WorkoutPlan
    func reactToBlindWorkout(id: UUID, reaction: ReactionKind?) async throws -> BlindWorkoutState
}
