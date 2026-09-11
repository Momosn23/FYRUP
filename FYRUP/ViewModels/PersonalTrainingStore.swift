import Foundation
import Observation

@MainActor @Observable
final class PersonalTrainingStore {
    private let repository: any PersonalTrainingRepository
    private(set) var userID: UUID?
    private var generation = UUID()
    private var routineRequest = UUID()
    private var weekRequest = UUID()
    private(set) var routine: TrainingRoutine?
    private(set) var week: TrainingWeekSnapshot?
    private(set) var weekInterval: DateInterval?
    private(set) var isLoadingRoutine = false
    private(set) var isSavingRoutine = false
    private(set) var isLoadingWeek = false
    var routineError: String?
    var weekError: String?
    private(set) var feedback: [UUID: PersonalWorkoutFeedback] = [:]
    private(set) var loadingFeedback = Set<UUID>()
    private(set) var savingFeedback = Set<UUID>()
    var feedbackErrors: [UUID: String] = [:]

    init(repository: any PersonalTrainingRepository) { self.repository = repository }
    func activate(userID: UUID?) {
        guard userID != self.userID else { return }
        generation = UUID(); routineRequest = UUID(); weekRequest = UUID(); self.userID = userID
        routine = nil; week = nil; weekInterval = nil; feedback = [:]
        routineError = nil; weekError = nil; feedbackErrors = [:]
        isLoadingRoutine = false; isSavingRoutine = false; isLoadingWeek = false; loadingFeedback = []; savingFeedback = []
    }
    func loadRoutine() async {
        guard userID != nil, !isSavingRoutine, !isLoadingRoutine else { return }
        let epoch = generation; let request = UUID(); routineRequest = request; isLoadingRoutine = true
        defer { if epoch == generation && request == routineRequest { isLoadingRoutine = false } }
        do {
            let value = try await repository.trainingRoutine()
            guard epoch == generation, request == routineRequest, !Task.isCancelled else { return }
            if let message = value.validationMessage { throw AppError.validation(message) }
            routine = value; routineError = nil
        } catch { if epoch == generation && request == routineRequest { routineError = "Dein Wochenplan konnte nicht geladen werden. Versuche es erneut." } }
    }
    func saveRoutine(_ value: TrainingRoutine) async -> Bool {
        guard userID != nil, !isSavingRoutine, let baseline = routine else { return false }
        guard baseline.revision == value.revision else { routineError = "Der Wochenplan wurde inzwischen geändert. Lade ihn erneut."; return false }
        if let message = value.validationMessage { routineError = message; return false }
        let epoch = generation; routineRequest = UUID(); isSavingRoutine = true; isLoadingRoutine = false
        defer { if epoch == generation { isSavingRoutine = false } }
        do {
            let saved = try await repository.saveTrainingRoutine(value)
            guard epoch == generation, !Task.isCancelled else { return false }
            guard saved.validationMessage == nil, saved.goals == value.goals, saved.revision > value.revision else { throw AppError.server }
            routine = saved; routineError = nil; return true
        } catch { if epoch == generation { routineError = "Nicht gespeichert. Deine Eingaben bleiben hier. Bei einem Konflikt lade den aktuellen Wochenplan erneut." }; return false }
    }
    func loadWeek(now: Date = .now, calendar: Calendar = TrainingWeekLogic.calendar()) async {
        guard userID != nil, let interval = TrainingWeekLogic.interval(containing: now, calendar: calendar) else { return }
        let epoch = generation; let request = UUID(); weekRequest = request; isLoadingWeek = true
        if weekInterval != interval { week = nil; weekInterval = interval }
        defer { if epoch == generation && request == weekRequest { isLoadingWeek = false } }
        do {
            let value = try await repository.trainingWeek(start: interval.start, end: interval.end)
            guard epoch == generation, request == weekRequest, !Task.isCancelled else { return }
            guard value.activities.allSatisfy({ $0.userID == userID }) else { throw AppError.authentication }
            week = value; weekError = nil
        } catch { if epoch == generation && request == weekRequest { weekError = "Die Wochenübersicht ist gerade nicht aktuell. Erneut laden." } }
    }
    func invalidateWeekAccess() {
        weekRequest = UUID(); week = nil; weekError = nil; isLoadingWeek = false
    }
    func loadFeedback(activityID: UUID, force: Bool = false) async {
        guard userID != nil, !savingFeedback.contains(activityID) else { return }
        if loadingFeedback.contains(activityID) {
            let epoch = generation
            while epoch == generation, loadingFeedback.contains(activityID), !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            return
        }
        guard force || feedback[activityID] == nil else { return }
        let epoch = generation; loadingFeedback.insert(activityID)
        defer { if epoch == generation { loadingFeedback.remove(activityID) } }
        do {
            let value = try await repository.workoutFeedback(activityID: activityID)
            guard epoch == generation, !Task.isCancelled else { return }
            guard value.activityID == activityID, value.validationMessage == nil else { throw AppError.server }
            feedback[activityID] = value; feedbackErrors[activityID] = nil
        } catch { if epoch == generation { feedbackErrors[activityID] = "Deine Bewertung konnte nicht geladen werden." } }
    }
    func saveFeedback(_ value: PersonalWorkoutFeedback) async -> Bool {
        let id = value.activityID
        guard userID != nil, !savingFeedback.contains(id), !loadingFeedback.contains(id), let baseline = feedback[id] else { return false }
        guard baseline.revision == value.revision else { feedbackErrors[id] = "Die Bewertung wurde inzwischen geändert. Lade sie erneut."; return false }
        if let message = value.validationMessage { feedbackErrors[id] = message; return false }
        let epoch = generation; savingFeedback.insert(id)
        defer { if epoch == generation { savingFeedback.remove(id) } }
        do {
            let saved = try await repository.saveWorkoutFeedback(value)
            guard epoch == generation, !Task.isCancelled else { return false }
            guard saved.activityID == id, saved.validationMessage == nil, saved.revision > value.revision,
                  saved.exercises == value.exercises, saved.feeling == value.feeling,
                  saved.note == WorkoutLimits.optionalText(value.note) else { throw AppError.server }
            feedback[id] = saved; feedbackErrors[id] = nil; return true
        } catch { if epoch == generation { feedbackErrors[id] = "Noch nicht gespeichert. Lade die Bewertung erneut und versuche es noch einmal." }; return false }
    }
}
