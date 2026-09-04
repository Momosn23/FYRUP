import Foundation

@MainActor
enum FeedCache {
    private struct Snapshot: Codable { let savedAt: Date; let activity: Activity?; let crew: [CrewMember]; let goals: GoalSummary }
    static func save(userID: UUID, activity: Activity?, crew: [CrewMember], goals: GoalSummary) {
        let value = Snapshot(savedAt: Date(), activity: activity, crew: crew, goals: goals)
        if let data = try? JSONEncoder.supabase.encode(value) { UserDefaults.standard.set(data, forKey: "feed.\(userID.uuidString)") }
    }
    static func load(userID: UUID) -> (Activity?, [CrewMember], GoalSummary)? {
        guard let data = UserDefaults.standard.data(forKey: "feed.\(userID.uuidString)"), let value = try? JSONDecoder.supabase.decode(Snapshot.self, from: data), Date().timeIntervalSince(value.savedAt) < 7 * 86_400 else { return nil }
        return (value.activity, value.crew, value.goals)
    }
    static func clear(userID: UUID) { UserDefaults.standard.removeObject(forKey: "feed.\(userID.uuidString)") }
}
