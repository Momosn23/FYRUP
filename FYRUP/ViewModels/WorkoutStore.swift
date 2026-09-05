import Foundation
import Observation

@MainActor
@Observable
final class WorkoutStore {
    var plans: [WorkoutPlan] = []
    var exercises: [GymExercise] = []
    var favorites = Set<UUID>()
    var logs: [UUID: WorkoutLog] = [:]
    var isLoadingPlans = false
    var isLoadingLibrary = false
    var isBusy = false
    var errorMessage: String?
    private(set) var userID: UUID?
    private var generation = UUID()
    private var plansRevision = 0
    private var libraryRevision = 0
    private var logRevisions: [UUID: Int] = [:]
    private var errorRevision = 0
    private var revokedFriends = Set<UUID>()
    private var accessRevision = 0
    private let repository: any WorkoutRepository
    private let copyRequests: WorkoutCopyRequestStore

    init(repository: any WorkoutRepository, copyRequests: WorkoutCopyRequestStore? = nil) {
        self.repository = repository; self.copyRequests = copyRequests ?? WorkoutCopyRequestStore()
    }

    func activate(userID: UUID?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        plansRevision = 0; libraryRevision = 0; logRevisions = [:]; errorRevision = 0
        plans = []; exercises = []; favorites = []; logs = [:]
        revokedFriends = []; accessRevision = 0
        isLoadingPlans = false; isLoadingLibrary = false; isBusy = false; errorMessage = nil
    }

    func removeFriend(userID: UUID) {
        revokedFriends.insert(userID); accessRevision += 1
        plans.removeAll { $0.ownerID == userID }
    }

    func restoreFriend(userID: UUID) {
        revokedFriends.remove(userID); accessRevision += 1
    }

    func loadPlans() async {
        guard userID != nil, !isLoadingPlans else { return }
        let request = generation
        let revision = plansRevision
        let messageRevision = errorRevision
        isLoadingPlans = true
        defer { if generation == request { isLoadingPlans = false } }
        do {
            let values = try await repository.workoutPlans(ownerID: nil)
            guard generation == request, plansRevision == revision else { return }
            plans = values
            if errorRevision == messageRevision { errorMessage = nil }
        } catch { if generation == request && plansRevision == revision && errorRevision == messageRevision { present(error) } }
    }

    func loadLibrary() async {
        guard userID != nil, !isLoadingLibrary else { return }
        let request = generation
        let revision = libraryRevision
        let messageRevision = errorRevision
        isLoadingLibrary = true
        defer { if generation == request { isLoadingLibrary = false } }
        do {
            async let items = repository.exercises()
            async let starred = repository.exerciseFavorites()
            let result = try await (items, starred)
            guard generation == request, libraryRevision == revision else { return }
            exercises = result.0; favorites = Set(result.1)
            if errorRevision == messageRevision { errorMessage = nil }
        } catch { if generation == request && libraryRevision == revision && errorRevision == messageRevision { present(error) } }
    }

    func plan(id: UUID) async -> WorkoutPlan? {
        guard userID != nil else { return nil }
        let request = generation
        let permission = accessRevision
        do {
            let value = try await repository.workoutPlan(id: id)
            guard userID != nil, generation == request, permission == accessRevision, !revokedFriends.contains(value.ownerID) else { return nil }
            return value
        } catch { if generation == request { present(error) }; return nil }
    }

    func sharedPlans(ownerID: UUID) async -> [WorkoutPlan]? {
        guard userID != nil, !revokedFriends.contains(ownerID) else { return nil }
        let request = generation
        let permission = accessRevision
        do {
            let values = try await repository.workoutPlans(ownerID: ownerID)
            guard userID != nil, generation == request, permission == accessRevision, !revokedFriends.contains(ownerID) else { return nil }
            return values.filter { $0.ownerID == ownerID }
        } catch { if generation == request { present(error) }; return nil }
    }

    func savePlan(_ draft: WorkoutPlan) async -> WorkoutPlan? {
        if let message = draft.validationMessage { errorRevision += 1; errorMessage = message; return nil }
        return await mutate {
            let saved = try await self.repository.saveWorkoutPlan(draft)
            return saved
        } update: { saved in
            self.plansRevision += 1
            self.plans.removeAll { $0.id == saved.id }
            self.plans.insert(saved, at: 0)
        }
    }

    func saveExercise(_ draft: GymExercise) async -> GymExercise? {
        await mutate { try await self.repository.saveExercise(draft) } update: { saved in
            self.libraryRevision += 1
            self.exercises.removeAll { $0.id == saved.id }
            self.exercises.append(saved)
        }
    }

    func archiveExercise(id: UUID) async -> Bool {
        await mutate { try await self.repository.archiveExercise(id: id); return true } update: { _ in
            self.libraryRevision += 1
            self.exercises.removeAll { $0.id == id }; self.favorites.remove(id)
        } ?? false
    }

    func archivePlan(id: UUID) async -> Bool {
        await mutate { try await self.repository.archiveWorkoutPlan(id: id); return true } update: { _ in
            self.plansRevision += 1
            self.plans.removeAll { $0.id == id }
        } ?? false
    }

    func toggleFavorite(id: UUID) async {
        let selected = !favorites.contains(id)
        _ = await mutate { try await self.repository.favoriteExercise(id: id, favorite: selected); return true } update: { _ in
            self.libraryRevision += 1
            if selected { self.favorites.insert(id) } else { self.favorites.remove(id) }
        }
    }

    func copyPlan(id: UUID) async -> WorkoutPlan? {
        guard let ownerID = userID, !isBusy else { return nil }
        let account = generation
        isBusy = true; errorMessage = nil; errorRevision += 1
        defer { if generation == account { isBusy = false } }
        do {
            let requestID = try copyRequests.requestID(sourceID: id, ownerID: ownerID)
            let saved = try await repository.copyWorkoutPlan(id: id, requestID: requestID)
            guard generation == account, userID == ownerID else { return nil }
            guard saved.copyRequestID == requestID, saved.ownerID == ownerID, saved.id != id,
                  saved.copiedFromPlanID == nil || saved.copiedFromPlanID == id,
                  saved.validationMessage == nil else {
                throw AppError.conflict("Die Plankopie konnte nicht eindeutig bestätigt werden. Bitte versuche es erneut; deine Kopieranfrage bleibt erhalten.")
            }
            try copyRequests.confirm(sourceID: id, ownerID: ownerID, requestID: requestID)
            plansRevision += 1
            plans.removeAll { $0.id == saved.id }; plans.insert(saved, at: 0)
            return saved
        } catch {
            if generation == account { present(error) }
            return nil
        }
    }

    func clearCopyRequests(userID: UUID) { copyRequests.clearAccount(ownerID: userID) }

    func sharePlan(id: UUID, friendIDs: [UUID]) async -> Bool {
        guard !friendIDs.isEmpty else { errorRevision += 1; errorMessage = "Wähle mindestens einen Freund."; return false }
        return await mutate { try await self.repository.shareWorkoutPlan(id: id, friendIDs: friendIDs); return true } update: { _ in } ?? false
    }

    @discardableResult
    func loadLog(activityID: UUID) async -> WorkoutLog? {
        guard userID != nil else { return nil }
        let request = generation
        let revision = logRevisions[activityID, default: 0]
        do {
            let log = try await repository.workoutLog(activityID: activityID)
            guard userID != nil, generation == request else { return nil }
            guard logRevisions[activityID, default: 0] == revision else { return logs[activityID] }
            logs[activityID] = log
            return log
        } catch { if generation == request && logRevisions[activityID, default: 0] == revision { present(error) }; return nil }
    }

    func saveLog(_ log: WorkoutLog) async -> WorkoutLog? {
        await mutate { try await self.repository.saveWorkoutLog(log) } update: { saved in
            self.logRevisions[saved.activityID, default: 0] += 1
            self.logs[saved.activityID] = saved
        }
    }

    private func mutate<T>(_ operation: @MainActor () async throws -> T, update: @MainActor (T) -> Void) async -> T? {
        guard userID != nil, !isBusy else { return nil }
        let request = generation
        isBusy = true; errorMessage = nil
        errorRevision += 1
        defer { if generation == request { isBusy = false } }
        do {
            let value = try await operation()
            guard generation == request else { return nil }
            update(value)
            return value
        } catch { if generation == request { present(error) }; return nil }
    }

    private func present(_ error: Error) {
        errorRevision += 1
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Das Speichern hat nicht geklappt. Deine Eingaben bleiben erhalten. Versuche es erneut."
    }
}
