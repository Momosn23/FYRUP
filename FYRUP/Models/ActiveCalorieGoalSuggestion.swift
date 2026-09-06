import Foundation

enum MovementGoalLevel: String, CaseIterable, Identifiable, Sendable {
    case gentle, balanced, ambitious

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gentle: "Sanft"
        case .balanced: "Ausgeglichen"
        case .ambitious: "Ambitioniert"
        }
    }
    var detail: String {
        switch self {
        case .gentle: "Ein gut erreichbarer Einstieg"
        case .balanced: "Regelmäßige Bewegung im Alltag"
        case .ambitious: "Ein bewusst anspruchsvolleres Ziel"
        }
    }
    fileprivate var reference: (minutes: Double, met: Double) {
        switch self {
        case .gentle: (20, 3.8)
        case .balanced: (35, 5.0)
        case .ambitious: (50, 6.0)
        }
    }
}

struct ActiveCalorieGoalSuggestion: Equatable, Sendable {
    let kilocalories: Int
    let usedStepGoal: Bool
    let usedWeeklyRoutine: Bool

    /// A transparent on-device guide, not a medical target or physiological
    /// measurement. The largest of the selected movement level, step goal and
    /// average planned weekly activity is used to avoid adding overlapping inputs.
    static func make(level: MovementGoalLevel, heightCM: Double?, weightKG: Double?,
                     stepGoal: Int?, routine: TrainingRoutine?) -> ActiveCalorieGoalSuggestion? {
        guard let weightKG, weightKG.isFinite, (20...450).contains(weightKG) else { return nil }

        let levelEnergy = activeEnergy(met: level.reference.met, weightKG: weightKG,
                                       minutes: level.reference.minutes)
        let stepEnergy: Double? = {
            guard let heightCM, heightCM.isFinite, (50...260).contains(heightCM),
                  let stepGoal, (1_000...StepDay.maximumSteps).contains(stepGoal) else { return nil }
            let distanceKM = Double(stepGoal) * (heightCM / 100) * 0.414 / 1_000
            let minutes = distanceKM / 4.8 * 60
            return activeEnergy(met: 3.8, weightKG: weightKG, minutes: minutes)
        }()

        let weeklyEnergy = routine?.goals.reduce(0.0) { partial, goal in
            guard goal.validationMessage == nil, let minutes = goal.minutes else { return partial }
            return partial + activeEnergy(met: met(for: goal.sport), weightKG: weightKG,
                                          minutes: Double(minutes * goal.sessions))
        } ?? 0
        let routineDaily: Double? = weeklyEnergy > 0 ? weeklyEnergy / 7 : nil
        let raw = max(levelEnergy, max(stepEnergy ?? 0, routineDaily ?? 0))
        let rounded = Int((raw / 25).rounded() * 25)
        return .init(kilocalories: min(2_000, max(50, rounded)),
                     usedStepGoal: stepEnergy != nil, usedWeeklyRoutine: routineDaily != nil)
    }

    private static func activeEnergy(met: Double, weightKG: Double, minutes: Double) -> Double {
        max(0, (met - 1) * 3.5 * weightKG / 200 * min(minutes, 7 * 24 * 60))
    }

    private static func met(for sport: SportKind) -> Double {
        switch sport {
        case .gym: 5.0
        case .running: 7.0
        case .football: 7.0
        case .basketball: 6.5
        case .cycling: 6.0
        case .swimming: 6.0
        case .martialArts: 7.0
        case .racket: 6.0
        case .yoga: 2.8
        case .other: 4.5
        }
    }
}
