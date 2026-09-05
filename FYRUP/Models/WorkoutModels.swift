import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, adductors, core, traps, forearms, fullBody = "full_body", other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chest: "Brust"; case .back: "Rücken"; case .shoulders: "Schulter"
        case .biceps: "Bizeps"; case .triceps: "Trizeps"; case .quads: "Quadrizeps"
        case .hamstrings: "Beinbeuger"; case .glutes: "Gesäß"; case .calves: "Waden"
        case .adductors: "Adduktoren"; case .core: "Bauch / Core"; case .traps: "Trapez"
        case .forearms: "Unterarme"; case .fullBody: "Ganzkörper"; case .other: "Sonstiges"
        }
    }
}

enum ExerciseEquipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell, dumbbell, cable, machine, smith, bodyweight, kettlebell, band, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .barbell: "Langhantel"; case .dumbbell: "Kurzhantel"; case .cable: "Kabelzug"
        case .machine: "Maschine"; case .smith: "Smith Machine"; case .bodyweight: "Körpergewicht"
        case .kettlebell: "Kettlebell"; case .band: "Widerstandsband"; case .other: "Sonstiges"
        }
    }
}

/// Product limits shared by forms and repository validation, not training recommendations.
enum WorkoutLimits {
    static let exerciseNameLength = 2...100
    static let planNameLength = 2...60
    static let exerciseCount = 1...40
    static let targetSets = 1...30
    static let targetReps = 1...999
    static let actualReps = 0...999
    static let weight = 0.0...2000.0
    static let noteLength = 500

    static func accepts(weight value: Double?) -> Bool {
        guard let value else { return true }
        return value.isFinite && weight.contains(value)
    }

    static func optionalText(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

struct GymExercise: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var primaryMuscle: MuscleGroup
    var secondaryMuscles: [MuscleGroup] = []
    var equipment: ExerciseEquipment = .other
    var exerciseType: String = "strength"
    var isCustom = true
    var createdBy: UUID?
    var isArchived = false
    var note: String?
    enum CodingKeys: String, CodingKey {
        case id, name, equipment, note
        case primaryMuscle = "primary_muscle_group", secondaryMuscles = "secondary_muscles"
        case exerciseType = "exercise_type", isCustom = "is_custom", createdBy = "created_by", isArchived = "is_archived"
    }
    var searchText: String {
        ([name, primaryMuscle.title, equipment.title] + secondaryMuscles.map(\.title) + ExerciseLibrary.aliases(for: name)).joined(separator: " ")
    }
    var normalizedName: String { Self.normalizedSearch(name).replacingOccurrences(of: " ", with: "") }
    var muscleGroups: Set<MuscleGroup> { Set([primaryMuscle] + secondaryMuscles) }
    var isTimed: Bool { exerciseType == "timed" }
    var repetitionUnit: String { isTimed ? "Sek." : "Wdh." }
    var subtitle: String { "\(equipment.title) · \(primaryMuscle.title)" }

    var validationMessage: String? {
        if !WorkoutLimits.exerciseNameLength.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) { return "Gib der Übung einen Namen mit 2–100 Zeichen." }
        if !["strength", "timed"].contains(exerciseType) { return "Wähle eine gültige Übungsart." }
        if secondaryMuscles.contains(primaryMuscle) || Set(secondaryMuscles).count != secondaryMuscles.count { return "Wähle jede zusätzliche Muskelgruppe nur einmal." }
        if (note?.count ?? 0) > WorkoutLimits.noteLength { return "Die Notiz darf höchstens 500 Zeichen haben." }
        return nil
    }

    func normalizedForSaving() -> GymExercise {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.note = WorkoutLimits.optionalText(note)
        var seen: Set<MuscleGroup> = [primaryMuscle]
        value.secondaryMuscles = secondaryMuscles.filter { seen.insert($0).inserted }
        return value
    }

    /// Each word may match a name, alias, muscle or equipment; accents and punctuation are irrelevant.
    func matches(query: String) -> Bool {
        let haystack = Self.normalizedSearch(searchText)
        return Self.normalizedSearch(query).split(separator: " ").allSatisfy { haystack.contains($0) }
    }

    /// A suggestion only: distinct variants remain allowed when the user chooses “Trotzdem erstellen”.
    func hasSimilarName(to proposedName: String) -> Bool {
        let candidate = Self.normalizedSearch(proposedName).replacingOccurrences(of: " ", with: "")
        guard !candidate.isEmpty else { return false }
        let existing = normalizedName
        if existing == candidate { return true }
        if ExerciseLibrary.aliases(for: name).contains(where: { Self.normalizedSearch($0).replacingOccurrences(of: " ", with: "") == candidate }) { return true }
        guard min(existing.count, candidate.count) >= 5 else { return false }
        // Small spelling mistakes are helpful suggestions, broad “contains” matching is too noisy.
        let threshold = min(existing.count, candidate.count) >= 12 ? 2 : 1
        guard abs(existing.count - candidate.count) <= threshold else { return false }
        let lhs = Array(existing), rhs = Array(candidate)
        var previous = Array(0...rhs.count)
        for (i, character) in lhs.enumerated() {
            var current = [i + 1]
            for (j, other) in rhs.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (character == other ? 0 : 1)))
            }
            previous = current
        }
        return (previous.last ?? Int.max) <= threshold
    }

    static func normalizedSearch(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum PlanVisibility: String, Codable, CaseIterable, Sendable { case `private`, friends }

struct WorkoutPlanExercise: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exercise: GymExercise
    var sortOrder = 0
    var targetSets = 3
    var targetRepsMin = 8
    var targetRepsMax = 12
    var targetWeight: Double?
    var note: String?
    enum CodingKeys: String, CodingKey {
        case id, exercise, note
        case sortOrder = "sort_order", targetSets = "target_sets", targetRepsMin = "target_reps_min", targetRepsMax = "target_reps_max", targetWeight = "target_weight"
    }
    var prescription: String {
        let amount = targetRepsMin == targetRepsMax ? "\(targetRepsMin)" : "\(targetRepsMin)–\(targetRepsMax)"
        return "\(targetSets) × \(amount)\(exercise.isTimed ? " Sek." : "")"
    }
    var validationMessage: String? {
        if let message = exercise.validationMessage { return message }
        if !WorkoutLimits.targetSets.contains(targetSets) || !WorkoutLimits.targetReps.contains(targetRepsMin) || !WorkoutLimits.targetReps.contains(targetRepsMax) || targetRepsMax < targetRepsMin || !WorkoutLimits.accepts(weight: targetWeight) { return "Prüfe Sätze, Wiederholungen und Gewicht." }
        if (note?.count ?? 0) > WorkoutLimits.noteLength { return "Die Übungsnotiz darf höchstens 500 Zeichen haben." }
        return nil
    }
}

struct WorkoutPlan: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var ownerID: UUID
    var name: String = ""
    var category: String?
    var description: String?
    var visibility: PlanVisibility = .private
    var copiedFromPlanID: UUID?
    var exercises: [WorkoutPlanExercise] = []
    enum CodingKeys: String, CodingKey {
        case id, name, category, description, visibility, exercises
        case ownerID = "owner_id", copiedFromPlanID = "copied_from_plan_id"
    }
    var validationMessage: String? {
        if !WorkoutLimits.planNameLength.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) { return "Gib deinem Plan einen Namen mit 2–60 Zeichen." }
        if (category?.count ?? 0) > 60 { return "Die Kategorie darf höchstens 60 Zeichen haben." }
        if (description?.count ?? 0) > 1000 { return "Die Beschreibung darf höchstens 1.000 Zeichen haben." }
        if !WorkoutLimits.exerciseCount.contains(exercises.count) { return "Wähle zwischen 1 und 40 Übungen." }
        if Set(exercises.map(\.id)).count != exercises.count { return "Eine Planposition ist doppelt vorhanden. Füge die Übung erneut hinzu." }
        if let invalid = exercises.first(where: { $0.validationMessage != nil }) { return invalid.validationMessage }
        return nil
    }

    /// Array order is authoritative after drag-and-drop; stale positions never leak into a save.
    func normalizedForSaving() -> WorkoutPlan {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.category = WorkoutLimits.optionalText(category)
        value.description = WorkoutLimits.optionalText(description)
        value.exercises = exercises.enumerated().map { index, item in
            var normalized = item
            normalized.sortOrder = index
            normalized.note = WorkoutLimits.optionalText(item.note)
            normalized.exercise = item.exercise.normalizedForSaving()
            return normalized
        }
        return value
    }

    /// Value snapshots and custom exercise IDs belong to the new owner; catalog IDs stay shared.
    func independentCopy(ownerID newOwnerID: UUID) -> WorkoutPlan {
        var value = normalizedForSaving()
        value.id = UUID()
        value.ownerID = newOwnerID
        value.copiedFromPlanID = id
        value.visibility = .private
        var customCopies: [UUID: GymExercise] = [:]
        value.exercises = value.exercises.map { item in
            var copy = item
            copy.id = UUID()
            if item.exercise.isCustom {
                if let existing = customCopies[item.exercise.id] { copy.exercise = existing }
                else {
                    copy.exercise.id = UUID()
                    copy.exercise.createdBy = newOwnerID
                    copy.exercise.isArchived = false
                    customCopies[item.exercise.id] = copy.exercise
                }
            }
            return copy
        }
        return value
    }
}

struct WorkoutSetLog: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var setNumber: Int
    var weight: Double?
    var reps: Int?
    var completed = false
    var completedAt: Date?
    enum CodingKeys: String, CodingKey { case id, weight, reps, completed; case setNumber = "set_number", completedAt = "completed_at" }
    var validationMessage: String? {
        if !WorkoutLimits.targetSets.contains(setNumber) || !WorkoutLimits.accepts(weight: weight) || reps.map({ !WorkoutLimits.actualReps.contains($0) }) == true { return "Prüfe Satznummer, Wiederholungen und Gewicht." }
        return nil
    }
}

struct WorkoutExerciseLog: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exercise: GymExercise
    var planExerciseID: UUID?
    var sortOrder: Int
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetWeight: Double? = nil
    var note: String?
    var completed = false
    var completedAt: Date?
    var sets: [WorkoutSetLog]
    enum CodingKeys: String, CodingKey {
        case id, exercise, note, completed, sets
        case planExerciseID = "workout_plan_exercise_id", sortOrder = "sort_order", targetSets = "target_sets"
        case targetRepsMin = "target_reps_min", targetRepsMax = "target_reps_max", completedAt = "completed_at"
        case targetWeight = "target_weight"
    }
}

struct WorkoutLog: Codable, Sendable {
    var activityID: UUID
    var planName: String
    var exercises: [WorkoutExerciseLog]
    enum CodingKeys: String, CodingKey { case activityID = "activity_id", planName = "plan_name", exercises }
    var completedExercises: Int { exercises.filter(\.completed).count }
    var completedSets: Int { exercises.flatMap(\.sets).filter(\.completed).count }
    var currentExercise: WorkoutExerciseLog? { exercises.sorted { $0.sortOrder < $1.sortOrder }.first { !$0.completed } }
    var progress: Double { exercises.isEmpty ? 0 : Double(completedExercises) / Double(exercises.count) }
    var validationMessage: String? {
        if !WorkoutLimits.exerciseCount.contains(exercises.count) || Set(exercises.map(\.id)).count != exercises.count { return "Die gespeicherten Übungen sind unvollständig." }
        for exercise in exercises {
            if exercise.sets.count > WorkoutLimits.targetSets.upperBound || Set(exercise.sets.map(\.setNumber)).count != exercise.sets.count || Set(exercise.sets.map(\.id)).count != exercise.sets.count { return "Ein Satz ist doppelt oder ungültig. Prüfe deine Einträge." }
            if let invalid = exercise.sets.first(where: { $0.validationMessage != nil }) { return invalid.validationMessage }
        }
        return nil
    }
}

protocol WorkoutRepository: Sendable {
    func exercises() async throws -> [GymExercise]
    func saveExercise(_ exercise: GymExercise) async throws -> GymExercise
    func archiveExercise(id: UUID) async throws
    func favoriteExercise(id: UUID, favorite: Bool) async throws
    func exerciseFavorites() async throws -> [UUID]
    func workoutPlans(ownerID: UUID?) async throws -> [WorkoutPlan]
    func workoutPlan(id: UUID) async throws -> WorkoutPlan
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws -> WorkoutPlan
    func archiveWorkoutPlan(id: UUID) async throws
    func copyWorkoutPlan(id: UUID) async throws -> WorkoutPlan
    func shareWorkoutPlan(id: UUID, friendIDs: [UUID]) async throws
    func startWorkout(planID: UUID, linkedActivityID: UUID?, sessionID: UUID?) async throws -> Activity
    func planWorkout(planID: UUID, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws
    func workoutLog(activityID: UUID) async throws -> WorkoutLog
    func saveWorkoutLog(_ log: WorkoutLog) async throws -> WorkoutLog
}
