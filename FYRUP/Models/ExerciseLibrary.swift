import Foundation

enum ExerciseLibrary {
    static let all: [GymExercise] = {
        guard let url = Bundle.main.url(forResource: "exercise-library", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }()

    static func parse(_ text: String) -> [GymExercise] {
        var ids: Set<UUID> = []
        return text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }.compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count == 6, let id = UUID(uuidString: parts[0]), let muscle = MuscleGroup(rawValue: parts[2]),
                  let equipment = ExerciseEquipment(rawValue: parts[4]), !ids.contains(id) else { return nil }
            let secondaryNames = parts[3].split(separator: ",")
            let secondary = secondaryNames.compactMap { MuscleGroup(rawValue: String($0)) }
            guard secondaryNames.count == secondary.count else { return nil }
            let exercise = GymExercise(id: id, name: parts[1], primaryMuscle: muscle, secondaryMuscles: secondary, equipment: equipment, exerciseType: parts[5], isCustom: false)
            guard exercise.validationMessage == nil else { return nil }
            ids.insert(id)
            return exercise
        }
    }

    static func matching(query: String, in exercises: [GymExercise] = all) -> [GymExercise] {
        exercises.filter { !$0.isArchived && $0.matches(query: query) }
    }

    static func duplicateCandidates(named name: String, in exercises: [GymExercise]) -> [GymExercise] {
        exercises.filter { $0.isCustom && !$0.isArchived && $0.hasSimilarName(to: name) }
    }

    static func aliases(for name: String) -> [String] {
        switch name {
        case "Bulgarian Split Squats": ["Bulgarian Split Squat", "Bulgarische Kniebeuge"]
        case "Romanian Deadlift": ["RDL", "Rumänisches Kreuzheben"]
        case "Farmer's Walk": ["Farmers Walk", "Farmer Walk", "Farmer Carry"]
        case "Step-Ups": ["Step Up", "Step Ups"]
        case "Butterfly / Pec Deck": ["Pec Fly", "Butterfly"]
        case "Schrägbankdrücken Kurzhantel": ["Schrägbank Kurzhantel", "Incline Dumbbell Bench Press"]
        case "Schrägbankdrücken Langhantel": ["Schrägbank Langhantel", "Incline Barbell Bench Press"]
        case "Bankdrücken Langhantel": ["Barbell Bench Press"]
        case "Bankdrücken Kurzhantel": ["Dumbbell Bench Press"]
        case "Lying Leg Curl": ["Beinbeuger liegend"]
        case "Seated Leg Curl": ["Beinbeuger sitzend"]
        case "Standing Leg Curl": ["Beinbeuger stehend"]
        default: []
        }
    }
}
