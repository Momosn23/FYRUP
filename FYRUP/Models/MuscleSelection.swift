import Foundation

/// One mapping for the body diagram, labelled controls and exercise filtering.
/// `other` has no anatomical region; `fullBody` is an exercise category, not a muscle.
enum MuscleSelection {
    static let anatomical = Set(MuscleGroup.allCases.filter { $0 != .fullBody && $0 != .other })
    static let upper: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .traps, .forearms]
    static let lower: Set<MuscleGroup> = [.glutes, .quads, .hamstrings, .calves, .adductors]
    static let gymGroups = Set(GymBodyArea.allCases.compactMap { MuscleGroup(rawValue: $0.rawValue) })

    enum Preset: String, CaseIterable, Identifiable {
        case core, upper, lower, whole
        var id: String { rawValue }
        var title: String {
            switch self {
            case .core: "Körpermitte"
            case .upper: "Oberkörper"
            case .lower: "Unterkörper"
            case .whole: "Ganzer Körper"
            }
        }
        var groups: Set<MuscleGroup> {
            switch self {
            case .core: [.core]
            case .upper: MuscleSelection.upper
            case .lower: MuscleSelection.lower
            case .whole: MuscleSelection.anatomical.union([.fullBody])
            }
        }
    }

    static func groups(for areas: Set<GymBodyArea>) -> Set<MuscleGroup> {
        Set(areas.compactMap { MuscleGroup(rawValue: $0.rawValue) })
    }

    static func areas(for groups: Set<MuscleGroup>) -> Set<GymBodyArea> {
        Set(groups.compactMap { GymBodyArea(rawValue: $0.rawValue) })
    }

    static func matches(_ exercise: GymExercise, selected: Set<MuscleGroup>) -> Bool {
        selected.isEmpty || !exercise.muscleGroups.isDisjoint(with: selected)
    }

    static func ordered(_ groups: Set<MuscleGroup>) -> [MuscleGroup] {
        MuscleGroup.allCases.filter { groups.contains($0) }
    }
}
