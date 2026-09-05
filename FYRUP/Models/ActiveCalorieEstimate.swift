import Foundation

enum ActiveCalorieSource: Equatable, Sendable {
    case appleHealth
    case fyrupEstimate
}

struct ActiveCalorieEstimate: Equatable, Sendable {
    let kilocalories: Double
    let source: ActiveCalorieSource
    let includesSteps: Bool
    let includesExplicitGymEffort: Bool

    /// A transparent fallback, not a physiological measurement. Apple Health
    /// always wins. The fallback takes the larger of step- and gym-based active
    /// energy rather than adding them, because FYRUP has no step timestamps and
    /// therefore cannot prove that the two inputs do not overlap.
    static func make(healthKilocalories: Double?, steps: Int?, heightCM: Double?, weightKG: Double?, ownerID: UUID,
                     activities: [Activity], feedback: [UUID: PersonalWorkoutFeedback], now: Date = .now,
                     calendar: Calendar = .current) -> ActiveCalorieEstimate? {
        if let healthKilocalories, healthKilocalories.isFinite, (0...50_000).contains(healthKilocalories) {
            return .init(kilocalories: healthKilocalories, source: .appleHealth,
                         includesSteps: false, includesExplicitGymEffort: false)
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
        let gymEnergy = activities.compactMap { activity -> Double? in
            guard seen.insert(activity.id).inserted, activity.userID == ownerID, activity.sport == .gym,
                  activity.status == .completed, let endedAt = activity.endedAt,
                  calendar.isDate(endedAt, inSameDayAs: now), let duration = activity.duration(at: endedAt), duration > 0,
                  let efforts = feedback[activity.id]?.exercises.map(\.effort), !efforts.isEmpty else { return nil }
            let average = efforts.map { effort in effort == .easy ? 0.0 : effort == .medium ? 1.0 : 2.0 }.reduce(0, +) / Double(efforts.count)
            let met = average < 0.5 ? 3.5 : average < 1.5 ? 5.0 : 6.0
            return max(0, (met - 1) * 3.5 * weightKG / 200 * min(duration / 60, 24 * 60))
        }.reduce(0, +)

        guard stepEnergy != nil || gymEnergy > 0 else { return nil }
        let amount = max(stepEnergy ?? 0, gymEnergy)
        return .init(kilocalories: min(50_000, amount), source: .fyrupEstimate,
                     includesSteps: stepEnergy != nil, includesExplicitGymEffort: gymEnergy > 0)
    }
}
