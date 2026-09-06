import Foundation
import Observation

/// Server-authored exercise prefixes only. This store never keeps a hidden full
/// plan for a recipient, invents completion, or turns target weights into actuals.
@MainActor @Observable
final class BlindWorkoutStore {
    private let repository: any BlindWorkoutRepository
    private var generation = UUID()
    private var mutationRevision = 0
    private var sequence = 0
    private var readVersions: [UUID: Int] = [:]
    private var selectionID: UUID?
    private var loadingID: UUID?
    private var loadingTicket: UUID?

    private(set) var userID: UUID?
    private(set) var summaries: [BlindWorkoutSummary] = []
    private(set) var selectedState: BlindWorkoutState?
    private(set) var isLoadingSummaries = false
    private(set) var isBusy = false
    var errorMessage: String?
    var isLoading: Bool { loadingID != nil }
    var incoming: [BlindWorkoutSummary] { summaries.filter { $0.recipientID == userID } }
    var outgoing: [BlindWorkoutSummary] { summaries.filter { $0.creatorID == userID } }

    init(repository: any BlindWorkoutRepository) { self.repository = repository }

    func activate(userID: UUID?) {
        if self.userID != userID { reset(); self.userID = userID }
    }

    func reset() {
        generation = UUID(); mutationRevision = 0; sequence = 0; readVersions = [:]
        userID = nil; summaries = []; selectedState = nil; selectionID = nil; loadingID = nil; loadingTicket = nil
        isLoadingSummaries = false; isBusy = false; errorMessage = nil
    }

    func state(id: UUID) -> BlindWorkoutState? { selectedState?.summary.id == id ? selectedState : nil }

    /// A failed authorized refresh hides cached private content. It also retires
    /// older detail requests, including ones that have not produced a cache yet.
    func refreshSummaries() async {
        guard let owner = userID, !isLoadingSummaries, !isBusy, !Task.isCancelled else { return }
        let request = generation; let revision = mutationRevision
        sequence += 1; let version = sequence
        isLoadingSummaries = true
        var reloadID: UUID?
        do {
            // End the batch lock before awaiting the follow-up detail request.
            // A newer revocation/empty batch must still be able to retire it.
            defer { if generation == request { isLoadingSummaries = false } }
            let values = try await repository.blindWorkouts()
            guard isCurrent(request, revision: revision), !Task.isCancelled else { return }
            guard values.allSatisfy({ valid($0, owner: owner) }), Set(values.map(\.id)).count == values.count else { throw AppError.server }
            let returned = Set(values.map(\.id))
            let known = Set(summaries.map(\.id)).union(readVersions.keys)
            for id in known where !returned.contains(id) && readVersions[id, default: 0] <= version {
                forget(id: id); readVersions[id] = version
            }
            for value in values where readVersions[value.id, default: 0] <= version {
                // Metadata alone cannot authorize/reconstruct a different prefix.
                if selectionID == value.id, selectedState?.summary != value {
                    selectedState = nil; reloadID = value.id
                }
                upsert(value); readVersions[value.id] = version
            }
            errorMessage = nil
        } catch {
            guard isCurrent(request, revision: revision), !Task.isCancelled else { return }
            let known = Set(summaries.map(\.id)).union(readVersions.keys)
            for id in known where readVersions[id, default: 0] <= version {
                forget(id: id); readVersions[id] = version
            }
            errorMessage = "Deine Blind Workouts konnten nicht geladen werden. Versuche es erneut."
        }
        if let reloadID, isCurrent(request, revision: revision), selectionID == reloadID,
           readVersions[reloadID] == version, !Task.isCancelled {
            // A summary is not a disclosure grant. Ask the server for a newly
            // authorized prefix and validate it with the ordinary load guards.
            _ = await load(id: reloadID)
        }
    }

    @discardableResult
    func load(id: UUID) async -> BlindWorkoutState? {
        guard let owner = userID, !isBusy, !Task.isCancelled else { return nil }
        let request = generation; let revision = mutationRevision
        sequence += 1; let version = sequence; readVersions[id] = version
        let ticket = UUID(); loadingTicket = ticket
        selectionID = id; loadingID = id
        // Even a previously visible detail must be re-authorized before reuse.
        selectedState = nil; errorMessage = nil
        defer { if generation == request, loadingTicket == ticket { loadingID = nil; loadingTicket = nil } }
        do {
            let value = try await repository.blindWorkout(id: id)
            guard isCurrent(request, revision: revision), readVersions[id] == version,
                  selectionID == id, !Task.isCancelled else { return nil }
            guard valid(value, id: id, owner: owner) else { throw AppError.server }
            selectedState = value; upsert(value.summary)
            return value
        } catch {
            guard isCurrent(request, revision: revision), readVersions[id] == version,
                  selectionID == id, !Task.isCancelled else { return nil }
            forget(id: id)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? AppError.server.errorDescription
            return nil
        }
    }

    /// Call immediately when a friendship is removed/blocked, before any refresh.
    func removeFriend(userID friendID: UUID) {
        mutationRevision += 1
        for summary in summaries where summary.creatorID == friendID || summary.recipientID == friendID { forget(id: summary.id) }
        if let value = selectedState, value.summary.creatorID == friendID || value.summary.recipientID == friendID { selectedState = nil }
        // Any outstanding detail may concern this friend, even without a summary.
        loadingID = nil
    }

    @discardableResult
    func send(_ draft: BlindWorkoutDraft) async -> Bool {
        guard let owner = userID, !isBusy, !Task.isCancelled else { return false }
        let value = draft.normalizedForSending()
        if let message = value.validationMessage { errorMessage = message; return false }
        guard value.recipientID != owner else { errorMessage = "Wähle einen Freund als Empfänger."; return false }
        return await mutate(id: value.id, expected: { $0.viewerRole == .creator && $0.summary.recipientID == value.recipientID }) {
            try await self.repository.sendBlindWorkout(value)
        }
    }

    @discardableResult
    func respond(id: UUID, accept: Bool, equipmentConfirmed: Bool) async -> Bool {
        guard let value = recipientState(id: id), !isBusy else { return false }
        if accept && !equipmentConfirmed { errorMessage = "Bestätige zuerst, dass das benötigte Equipment verfügbar ist."; return false }
        let allowed: [BlindWorkoutStatus] = accept ? [.sent, .accepted, .planned, .live, .completed] : [.sent, .declined]
        guard allowed.contains(value.summary.status) else { return false }
        return await mutate(id: id, expected: { accept ? [.accepted, .planned, .live, .completed].contains($0.summary.status) : $0.summary.status == .declined }) {
            try await self.repository.respondToBlindWorkout(id: id, accept: accept, equipmentConfirmed: equipmentConfirmed)
        }
    }

    @discardableResult
    func plan(id: UUID, startsAt: Date) async -> Bool {
        guard let value = recipientState(id: id), [.accepted, .planned].contains(value.summary.status), !isBusy else { return false }
        guard startsAt.timeIntervalSince1970.isFinite else { errorMessage = "Wähle einen gültigen Zeitpunkt."; return false }
        // The server, not a possibly skewed device clock, decides if it is future.
        return await mutate(id: id, expected: { $0.summary.status == .planned }) {
            try await self.repository.planBlindWorkout(id: id, startsAt: startsAt)
        }
    }

    @discardableResult
    func start(id: UUID) async -> Bool {
        guard let value = recipientState(id: id), [.accepted, .planned, .live].contains(value.summary.status), !isBusy else { return false }
        return await mutate(id: id, expected: { $0.summary.status == .live }) {
            try await self.repository.startBlindWorkout(id: id)
        }
    }

    @discardableResult
    func saveExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async -> Bool {
        guard let value = recipientState(id: id), value.summary.status == .live, !isBusy,
              let exercise = value.visibleExercises.first(where: { $0.id == exerciseID }) else { return false }
        guard validSets(sets, exercise: exercise.exercise) else {
            errorMessage = "Prüfe deine tatsächlichen Sätze, Wiederholungen und Gewichte. Deine Eingaben bleiben erhalten."; return false
        }
        return await mutate(id: id, expected: { state in
            state.summary.status == .live && state.visibleExercises.contains { $0.id == exerciseID && (!complete || $0.completed) }
        }) {
            try await self.repository.saveBlindWorkoutExercise(id: id, exerciseID: exerciseID, sets: sets, complete: complete)
        }
    }

    @discardableResult
    func finish(id: UUID) async -> Bool {
        guard let value = recipientState(id: id), value.canFinish || value.summary.status == .completed, !isBusy else { return false }
        return await mutate(id: id, expected: { $0.summary.status == .completed }) { try await self.repository.finishBlindWorkout(id: id) }
    }

    @discardableResult
    func cancel(id: UUID) async -> Bool {
        // Cancellation must remain possible after friendship access is revoked.
        // The server checks ownership and returns a minimal, role-safe response.
        await mutate(id: id, expected: { $0.summary.status == .cancelled }) { try await self.repository.cancelBlindWorkout(id: id) }
    }

    @discardableResult
    func react(id: UUID, reaction: ReactionKind?) async -> Bool {
        guard state(id: id)?.canReact == true, !isBusy else { return false }
        return await mutate(id: id, expected: { $0.canReact && $0.myReaction == reaction }) {
            try await self.repository.reactToBlindWorkout(id: id, reaction: reaction)
        }
    }

    func copy(id: UUID) async -> WorkoutPlan? {
        guard let owner = userID, state(id: id)?.canCopy == true, !isBusy, !Task.isCancelled else { return nil }
        let request = generation; mutationRevision += 1; let revision = mutationRevision
        isBusy = true; loadingID = nil; errorMessage = nil
        defer { if generation == request { isBusy = false } }
        do {
            let value = try await repository.copyBlindWorkout(id: id)
            guard isCurrent(request, revision: revision), !Task.isCancelled else { return nil }
            guard value.ownerID == owner, value.visibility == .private, value.validationMessage == nil else { throw AppError.server }
            return value
        } catch {
            if isCurrent(request, revision: revision), !Task.isCancelled {
                if (error as? AppError)?.isAccessDenied == true { forget(id: id) }
                errorMessage = "Der Plan wurde nicht bestätigt. Versuche es erneut."
            }
            return nil
        }
    }

    private func mutate(id: UUID, expected: @MainActor (BlindWorkoutState) -> Bool,
                        operation: @MainActor () async throws -> BlindWorkoutState) async -> Bool {
        guard let owner = userID, !isBusy, !Task.isCancelled else { return false }
        let request = generation; mutationRevision += 1; let revision = mutationRevision
        isBusy = true; loadingID = nil; errorMessage = nil
        defer { if generation == request { isBusy = false } }
        do {
            let value = try await operation()
            guard isCurrent(request, revision: revision), !Task.isCancelled else { return false }
            guard valid(value, id: id, owner: owner), expected(value) else { throw AppError.server }
            sequence += 1; readVersions[id] = sequence
            selectionID = id; selectedState = value; upsert(value.summary)
            return true
        } catch {
            if isCurrent(request, revision: revision), !Task.isCancelled {
                if (error as? AppError)?.isAccessDenied == true { forget(id: id) }
                if case .validation(let message) = error as? AppError { errorMessage = message }
                else if case .conflict(let message) = error as? AppError { errorMessage = message }
                else { errorMessage = "Die Aktion wurde nicht bestätigt. Deine Eingaben bleiben erhalten. Versuche es erneut." }
            }
            return false
        }
    }

    private func recipientState(id: UUID) -> BlindWorkoutState? {
        guard let value = state(id: id), value.viewerRole == .recipient, value.summary.recipientID == userID else { return nil }
        return value
    }
    private func isCurrent(_ request: UUID, revision: Int) -> Bool { generation == request && mutationRevision == revision }
    private func valid(_ value: BlindWorkoutSummary, owner: UUID) -> Bool {
        value.isValid && (value.creatorID == owner || value.recipientID == owner)
    }
    private func valid(_ value: BlindWorkoutState, id: UUID, owner: UUID) -> Bool {
        guard value.summary.id == id, valid(value.summary, owner: owner), value.isValid else { return false }
        return value.viewerRole == .creator ? value.summary.creatorID == owner : value.summary.recipientID == owner
    }
    private func validSets(_ sets: [WorkoutSetLog], exercise: GymExercise) -> Bool {
        let limit = exercise.isTimed ? BlindWorkoutLimits.timedSeconds.upperBound : BlindWorkoutLimits.strengthReps.upperBound
        return sets.count <= BlindWorkoutLimits.targetSets.upperBound && Set(sets.map(\.id)).count == sets.count
            && Set(sets.map(\.setNumber)).count == sets.count && sets.allSatisfy { row in
                BlindWorkoutLimits.targetSets.contains(row.setNumber)
                    && (row.reps.map { (0...limit).contains($0) } ?? true)
                    && (row.weight.map { $0.isFinite && BlindWorkoutLimits.targetWeight.contains($0) } ?? true)
            }
    }
    private func upsert(_ value: BlindWorkoutSummary) {
        summaries.removeAll { $0.id == value.id }; summaries.append(value)
        summaries.sort { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt }
    }
    private func forget(id: UUID) {
        summaries.removeAll { $0.id == id }
        if selectedState?.summary.id == id { selectedState = nil }
        if loadingID == id { loadingID = nil }
    }
}
