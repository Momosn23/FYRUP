import Foundation

struct TrainingRoutineGoal: Codable, Equatable, Identifiable, Sendable {
    var sport: SportKind
    var sessions = 2
    var minutes: Int? = nil
    /// ISO weekdays: Monday = 1 ... Sunday = 7. Empty means flexible.
    var weekdays: [Int] = []
    var id: SportKind { sport }
    var validationMessage: String? {
        guard (1...7).contains(sessions), minutes.map({ (5...360).contains($0) }) ?? true,
              Set(weekdays).count == weekdays.count, weekdays.allSatisfy({ (1...7).contains($0) }),
              weekdays.count <= sessions else { return "Prüfe Häufigkeit, Dauer und Wochentage." }
        return nil
    }
    var summary: String { "\(sessions)× pro Woche" + (minutes.map { " · je \($0) Min." } ?? "") }
}

struct TrainingRoutine: Codable, Equatable, Sendable {
    var revision = 0
    var goals: [TrainingRoutineGoal] = []
    var validationMessage: String? {
        if !(0..<1_000_000_000).contains(revision) || goals.count > SportKind.allCases.count || Set(goals.map(\.sport)).count != goals.count { return "Prüfe den Wochenplan und wähle jede Sportart nur einmal." }
        return goals.compactMap(\.validationMessage).first
    }
}

struct TrainingWeekSnapshot: Codable, Sendable {
    var activities: [Activity] = []
    var sessions: [PlannedSession] = []
}

/// A compact row previews a day; its detail view retains every entry.
/// Missing data must not be presented as an empty calendar.
struct WeeklyDaySummary {
    let completed: [Activity]
    let planned: [PlannedSession]
    let isLoaded: Bool

    init(snapshot: TrainingWeekSnapshot?, ownerID: UUID?, day: Date, calendar: Calendar = TrainingWeekLogic.calendar()) {
        guard let snapshot, let ownerID else { completed = []; planned = []; isLoaded = false; return }
        isLoaded = true
        completed = TrainingWeekLogic.completed(snapshot.activities, owner: ownerID, day: day, calendar: calendar)
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
        var seen = Set<UUID>()
        planned = snapshot.sessions.filter {
            ["planned", "ready"].contains($0.status) && calendar.isDate($0.startsAt, inSameDayAs: day) && seen.insert($0.id).inserted
        }.sorted { $0.startsAt < $1.startsAt }
    }
    var title: String {
        if let next = planned.first { return next.displaySubtype ?? next.sport.title }
        if let latest = completed.first { return latest.displaySubtype ?? latest.sport.title }
        return isLoaded ? "Keine Session geplant" : "Noch nicht geladen"
    }
    var detail: String? {
        if !completed.isEmpty && !planned.isEmpty { return "\(completed.count) abgeschlossen · \(planned.count) geplant" }
        if let next = planned.first {
            let time = next.startsAt.formatted(date: .omitted, time: .shortened)
            return planned.count > 1 ? "Ab \(time) · \(planned.count) Sessions" : "\(next.sport.title) · \(time)"
        }
        if let latest = completed.first {
            return completed.count > 1 ? "\(completed.count) Einheiten · DONE" : "\(latest.sport.title) · DONE"
        }
        return nil
    }
}

enum ExerciseEffort: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy, medium, hardcore
    var id: String { rawValue }
    var title: String { switch self { case .easy: "Easy"; case .medium: "Mittel"; case .hardcore: "Hardcore" } }
    var symbol: String { switch self { case .easy: "leaf"; case .medium: "bolt"; case .hardcore: "flame" } }
}

enum TrainingFeeling: String, Codable, CaseIterable, Identifiable, Sendable {
    case great, okay, tough
    var id: String { rawValue }
    var title: String { switch self { case .great: "Richtig gut"; case .okay: "War okay"; case .tough: "War zäh" } }
    var emoji: String { switch self { case .great: "😊"; case .okay: "🙂"; case .tough: "😮‍💨" } }
}

struct ExerciseEffortEntry: Codable, Equatable, Sendable {
    let exerciseID: UUID
    var effort: ExerciseEffort
    enum CodingKeys: String, CodingKey { case exerciseID = "exercise_id", effort }
}

struct PersonalWorkoutFeedback: Codable, Equatable, Sendable {
    let activityID: UUID
    var revision = 0
    var exercises: [ExerciseEffortEntry] = []
    var feeling: TrainingFeeling? = nil
    var note: String? = nil
    enum CodingKeys: String, CodingKey { case activityID = "activity_id", revision, exercises, feeling, note }
    var validationMessage: String? {
        guard (0..<1_000_000_000).contains(revision), exercises.count <= 40, Set(exercises.map(\.exerciseID)).count == exercises.count,
              (note?.unicodeScalars.count ?? 0) <= 500 else { return "Prüfe die Bewertung und kürze deine Notiz auf höchstens 500 Zeichen." }
        return nil
    }
    func effort(for id: UUID) -> ExerciseEffort? { exercises.first { $0.exerciseID == id }?.effort }
    mutating func setEffort(_ effort: ExerciseEffort?, for id: UUID) {
        exercises.removeAll { $0.exerciseID == id }
        if let effort { exercises.append(.init(exerciseID: id, effort: effort)) }
    }
}

enum TrainingWeekLogic {
    static func calendar(timezone: TimeZone = .current) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timezone; value.firstWeekday = 2; value.minimumDaysInFirstWeek = 4
        return value
    }
    static func interval(containing date: Date, calendar: Calendar = TrainingWeekLogic.calendar()) -> DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: date)
    }
    static func days(containing date: Date, calendar: Calendar = TrainingWeekLogic.calendar()) -> [Date] {
        guard let week = interval(containing: date, calendar: calendar) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }
    static func weekday(_ date: Date, calendar: Calendar = TrainingWeekLogic.calendar()) -> Int { (calendar.component(.weekday, from: date) + 5) % 7 + 1 }
    static func completed(_ activities: [Activity], owner: UUID, day: Date, calendar: Calendar = TrainingWeekLogic.calendar()) -> [Activity] {
        var seen = Set<UUID>()
        return activities.filter { item in
            guard item.userID == owner, item.status == .completed, let end = item.endedAt,
                  calendar.isDate(end, inSameDayAs: day) else { return false }
            return seen.insert(item.id).inserted
        }
    }
    static func completedCount(sport: SportKind, activities: [Activity], owner: UUID, now: Date, calendar: Calendar = TrainingWeekLogic.calendar()) -> Int {
        days(containing: now, calendar: calendar).flatMap { completed(activities, owner: owner, day: $0, calendar: calendar) }.filter { $0.sport == sport }.count
    }
}

protocol PersonalTrainingRepository: Sendable {
    func trainingRoutine() async throws -> TrainingRoutine
    func saveTrainingRoutine(_ routine: TrainingRoutine) async throws -> TrainingRoutine
    func trainingWeek(start: Date, end: Date) async throws -> TrainingWeekSnapshot
    func workoutFeedback(activityID: UUID) async throws -> PersonalWorkoutFeedback
    func saveWorkoutFeedback(_ feedback: PersonalWorkoutFeedback) async throws -> PersonalWorkoutFeedback
}

// Existing test doubles and the configuration placeholder fail closed until implemented.
extension PersonalTrainingRepository {
    func trainingRoutine() async throws -> TrainingRoutine { throw AppError.configuration }
    func saveTrainingRoutine(_ routine: TrainingRoutine) async throws -> TrainingRoutine { throw AppError.configuration }
    func trainingWeek(start: Date, end: Date) async throws -> TrainingWeekSnapshot { throw AppError.configuration }
    func workoutFeedback(activityID: UUID) async throws -> PersonalWorkoutFeedback { throw AppError.configuration }
    func saveWorkoutFeedback(_ feedback: PersonalWorkoutFeedback) async throws -> PersonalWorkoutFeedback { throw AppError.configuration }
}
