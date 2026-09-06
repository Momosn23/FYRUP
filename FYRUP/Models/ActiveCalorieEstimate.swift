import Foundation

enum ActiveCalorieSource: Equatable, Sendable {
    case appleHealth
    case fyrupEstimate
}

struct ActiveCalorieEstimate: Equatable, Sendable {
    let kilocalories: Double
    let source: ActiveCalorieSource
    let includesSteps: Bool
    let includesExplicitActivityEffort: Bool

    /// A transparent fallback, not a physiological measurement. Apple Health
    /// always wins. The fallback takes the larger of step- and gym-based active
    /// energy rather than adding them, because FYRUP has no step timestamps and
    /// therefore cannot prove that the two inputs do not overlap.
    static func make(healthKilocalories: Double?, steps: Int?, heightCM: Double?, weightKG: Double?, ownerID: UUID,
                     activities: [Activity], feedback: [UUID: PersonalWorkoutFeedback], now: Date = .now,
                     calendar: Calendar = .current) -> ActiveCalorieEstimate? {
        if let healthKilocalories, healthKilocalories.isFinite, (0...50_000).contains(healthKilocalories) {
            return .init(kilocalories: healthKilocalories, source: .appleHealth,
                         includesSteps: false, includesExplicitActivityEffort: false)
        }
        guard let heightCM, heightCM.isFinite, (50...260).contains(heightCM),
              let weightKG, weightKG.isFinite, (20...450).contains(weightKG) else { return nil }

        let stepEnergy: Double? = steps.flatMap { count in
            guard (0...StepDay.maximumSteps).contains(count) else { return nil }
            // Documented assumption: 0.414 × stature per step, moderate level
            // walking at 4.8 km/h and 3.8 MET. Remove the 1-MET resting share.
            let distanceKM = Double(count) * (heightCM / 100) * 0.414 / 1_000
            let minutes = distanceKM / 4.8 * 60
            return max(0, (3.8 - 1) * 3.5 * weightKG / 200 * minutes)
        }

        var seen = Set<UUID>()
        let activityEnergy = activities.compactMap { activity -> Double? in
            guard seen.insert(activity.id).inserted, activity.userID == ownerID,
                  activity.status == .completed, let endedAt = activity.endedAt,
                  calendar.isDate(endedAt, inSameDayAs: now), let duration = activity.duration(at: endedAt), duration > 0,
                  let review = feedback[activity.id], let effort = explicitEffort(review) else { return nil }
            let met = met(for: activity.sport, effort: effort)
            return max(0, (met - 1) * 3.5 * weightKG / 200 * min(duration / 60, 24 * 60))
        }.reduce(0, +)

        guard stepEnergy != nil || activityEnergy > 0 else { return nil }
        let amount = max(stepEnergy ?? 0, activityEnergy)
        return .init(kilocalories: min(50_000, amount), source: .fyrupEstimate,
                     includesSteps: stepEnergy != nil, includesExplicitActivityEffort: activityEnergy > 0)
    }

    /// Gym can use the finer per-exercise effort. Every sport can use the
    /// voluntary completion feeling, so an unreviewed activity never creates an
    /// invented calorie value.
    private static func explicitEffort(_ feedback: PersonalWorkoutFeedback) -> Double? {
        let efforts = feedback.exercises.map(\.effort)
        if !efforts.isEmpty {
            return efforts.map { $0 == .easy ? 0.0 : $0 == .medium ? 1.0 : 2.0 }
                .reduce(0, +) / Double(efforts.count)
        }
        return feedback.feeling.map { $0 == .great ? 1.0 : $0 == .okay ? 0.5 : 1.5 }
    }

    /// Broad MET references are deliberately conservative and are scaled only
    /// from the user's own three-level effort signal. This remains an estimate,
    /// not a health measurement.
    private static func met(for sport: SportKind, effort: Double) -> Double {
        let base: Double = switch sport {
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
        let factor = effort < 0.75 ? 0.75 : effort < 1.25 ? 1.0 : 1.2
        return max(1.5, min(12, base * factor))
    }
}
