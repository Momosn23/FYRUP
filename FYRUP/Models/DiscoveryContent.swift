import Foundation

enum DiscoverySection: String, CaseIterable, Identifiable {
    case all, workouts, exercises, sports
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Alle"
        case .workouts: "Workouts"
        case .exercises: "Übungen"
        case .sports: "Sportarten"
        }
    }
}

/// Search only the current user's authorized library. No remote recommendations,
/// invented popularity, or deferred food-provider endpoints.
enum DiscoveryContent {
    static func exercises(_ values: [GymExercise], owner: UUID?, query: String) -> [GymExercise] {
        guard let owner else { return [] }
        var seen = Set<UUID>()
        return values.filter {
            !$0.isArchived && (!$0.isCustom || $0.createdBy == owner)
                && $0.matches(query: query) && seen.insert($0.id).inserted
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func plans(_ values: [WorkoutPlan], owner: UUID?, query: String) -> [WorkoutPlan] {
        guard let owner else { return [] }
        var seen = Set<UUID>()
        return values.filter { plan in
            plan.ownerID == owner && matches(query, in: [plan.name, plan.category ?? ""]
                + plan.exercises.map { $0.exercise.searchText }) && seen.insert(plan.id).inserted
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func sports(query: String) -> [SportKind] {
        SportKind.allCases.filter { matches(query, in: [$0.title]) }
    }

    private static func matches(_ query: String, in values: [String]) -> Bool {
        let text = GymExercise.normalizedSearch(values.joined(separator: " "))
        return GymExercise.normalizedSearch(query).split(separator: " ").allSatisfy { text.contains($0) }
    }
}
