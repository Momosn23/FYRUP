import Foundation
import Observation

struct WorkoutSetDraftKey: Codable, Hashable, Sendable {
    let ownerID: UUID
    let activityID: UUID
    let blindWorkoutID: UUID?
    let exerciseID: UUID
    let setID: UUID
}

/// Constructed only from an authorized live activity/current Blind reveal. The
/// persisted draft has no exercise name, prescription, future reveal or creator data.
struct WorkoutSetDraftContext: Sendable {
    let key: WorkoutSetDraftKey
    let baseline: WorkoutSetLog
    private init(key: WorkoutSetDraftKey, baseline: WorkoutSetLog) { self.key = key; self.baseline = baseline }

    static func workout(ownerID: UUID, activity: Activity, log: WorkoutLog, exerciseID: UUID, setID: UUID) -> Self? {
        guard activity.userID == ownerID, activity.status == .live, activity.blindWorkoutID == nil,
              activity.workoutPlanID != nil, log.activityID == activity.id, log.validationMessage == nil,
              let exercise = log.exercises.first(where: { $0.id == exerciseID }),
              let set = exercise.sets.first(where: { $0.id == setID }) else { return nil }
        return Self(key: WorkoutSetDraftKey(ownerID: ownerID, activityID: activity.id, blindWorkoutID: nil, exerciseID: exerciseID, setID: setID), baseline: set)
    }

    static func blind(ownerID: UUID, state: BlindWorkoutState, exerciseID: UUID, setID: UUID) -> Self? {
        guard state.isValid, state.viewerRole == .recipient, state.summary.recipientID == ownerID,
              state.summary.status == .live, let activity = state.activity,
              let exercise = state.currentExercise, exercise.id == exerciseID,
              let set = exercise.sets.first(where: { $0.id == setID }) else { return nil }
        return Self(key: WorkoutSetDraftKey(ownerID: ownerID, activityID: activity.id, blindWorkoutID: state.summary.id, exerciseID: exerciseID, setID: setID), baseline: set)
    }
}

enum WorkoutInputDraftRecovery {
    case none
    case restored(WorkoutSetEntryInput)
    case conflict(WorkoutSetEntryInput)
}

enum WorkoutLogDraftRecovery {
    case none
    case restored(WorkoutLog)
    case alreadySaved
    case conflict
}

/// Private, account-scoped on-device recovery only. No repository/HTTP access.
/// Unknown/corrupt storage is preserved and cannot be overwritten silently.
@MainActor @Observable
final class WorkoutTrackingDraftStore {
    private struct InputDraft: Codable {
        let key: WorkoutSetDraftKey
        let baseline: WorkoutSetLog
        let input: WorkoutSetEntryInput
        let updatedAt: Date
    }
    private struct LogDraft: Codable {
        let ownerID: UUID
        let baseline: WorkoutLog
        let candidate: WorkoutLog
        let updatedAt: Date
    }
    private struct Envelope: Codable {
        let version: Int
        let ownerID: UUID
        var inputs: [InputDraft]
        var logs: [LogDraft]
    }

    private let defaults: UserDefaults
    private var inputs: [InputDraft] = []
    private var logs: [LogDraft] = []
    private var storageBlocked = false
    private(set) var userID: UUID?
    private(set) var errorMessage: String?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func activate(userID: UUID?) {
        guard self.userID != userID else { return }
        self.userID = userID; inputs = []; logs = []; errorMessage = nil; storageBlocked = false
        guard let userID, let stored = defaults.object(forKey: key(userID)) else { return }
        guard let data = stored as? Data else { markUnreadable(); return }
        do {
            let value = try JSONDecoder().decode(Envelope.self, from: data)
            guard value.version == 1, value.ownerID == userID, value.inputs.count <= 1200, value.logs.count <= 100,
                  Set(value.inputs.map(\.key)).count == value.inputs.count,
                  Set(value.logs.map { $0.candidate.activityID }).count == value.logs.count,
                  value.inputs.allSatisfy({ $0.key.ownerID == userID && Self.accepts($0.input) && $0.baseline.id == $0.key.setID && $0.baseline.validationMessage == nil && $0.updatedAt.timeIntervalSince1970.isFinite }),
                  value.logs.allSatisfy({ $0.ownerID == userID && Self.accepts(baseline: $0.baseline, candidate: $0.candidate) && $0.updatedAt.timeIntervalSince1970.isFinite }) else { throw AppError.validation("Ungültiger lokaler Entwurf") }
            inputs = value.inputs; logs = value.logs
        } catch {
            markUnreadable()
        }
    }

    func input(for context: WorkoutSetDraftContext) -> WorkoutInputDraftRecovery {
        guard context.key.ownerID == userID, let draft = inputs.first(where: { $0.key == context.key }) else { return .none }
        return draft.baseline == context.baseline ? .restored(draft.input) : .conflict(draft.input)
    }

    @discardableResult
    func saveInput(_ input: WorkoutSetEntryInput, context: WorkoutSetDraftContext, now: Date = Date()) -> Bool {
        guard context.key.ownerID == userID, Self.accepts(input), now.timeIntervalSince1970.isFinite else { return false }
        var candidate = inputs.filter { $0.key != context.key }
        candidate.append(InputDraft(key: context.key, baseline: context.baseline, input: input, updatedAt: now))
        guard candidate.count <= 1200 else { errorMessage = "Zu viele lokale Satzentwürfe. Speichere oder verwirf zuerst einen vorhandenen Entwurf."; return false }
        return persist(inputs: candidate, logs: logs)
    }

    func removeInput(context: WorkoutSetDraftContext) {
        guard context.key.ownerID == userID else { return }
        _ = persist(inputs: inputs.filter { $0.key != context.key }, logs: logs)
    }

    func hasInput(activityID: UUID) -> Bool { inputs.contains { $0.key.ownerID == userID && $0.key.activityID == activityID } }

    @discardableResult
    func savePending(_ candidate: WorkoutLog, baseline: WorkoutLog, activity: Activity, now: Date = Date()) -> Bool {
        guard let userID, activity.userID == userID, activity.status == .live, activity.blindWorkoutID == nil,
              activity.workoutPlanID != nil, activity.id == candidate.activityID,
              Self.accepts(baseline: baseline, candidate: candidate), now.timeIntervalSince1970.isFinite else { return false }
        var remaining = logs.filter { $0.candidate.activityID != activity.id }
        remaining.append(LogDraft(ownerID: userID, baseline: baseline, candidate: candidate, updatedAt: now))
        guard remaining.count <= 100 else { return false }
        return persist(inputs: inputs, logs: remaining)
    }

    func recoverPending(activity: Activity, confirmed: WorkoutLog) -> WorkoutLogDraftRecovery {
        guard activity.userID == userID, activity.blindWorkoutID == nil, activity.id == confirmed.activityID,
              let draft = logs.first(where: { $0.candidate.activityID == activity.id && $0.ownerID == userID }) else { return .none }
        guard activity.status == .live else { return .conflict }
        if Self.sameIntent(draft.candidate, confirmed) {
            // SQL creates IDs for newly added sets. Keep unsaved raw text attached
            // to that now-confirmed set number rather than stranding the draft.
            let remapped = remapInputs(candidate: draft.candidate, receipt: confirmed)
            _ = persist(inputs: remapped, logs: logs.filter { $0.candidate.activityID != activity.id })
            return .alreadySaved
        }
        guard Self.sameIntent(draft.baseline, confirmed) else { return .conflict }
        return .restored(draft.candidate)
    }

    func removePending(activityID: UUID) {
        guard userID != nil else { return }
        _ = persist(inputs: inputs, logs: logs.filter { $0.candidate.activityID != activityID })
    }

    func clearActivity(_ activityID: UUID) {
        guard userID != nil else { return }
        _ = persist(inputs: inputs.filter { $0.key.activityID != activityID }, logs: logs.filter { $0.candidate.activityID != activityID })
    }

    /// Explicit logout/delete, before activating the next/nil account.
    func clearCurrentAccount() {
        if let userID { defaults.removeObject(forKey: key(userID)) }
        userID = nil; inputs = []; logs = []; errorMessage = nil; storageBlocked = false
    }

    private func persist(inputs: [InputDraft], logs: [LogDraft]) -> Bool {
        guard let userID, !storageBlocked else { return false }
        do {
            let data = try JSONEncoder().encode(Envelope(version: 1, ownerID: userID, inputs: inputs, logs: logs))
            defaults.set(data, forKey: key(userID))
            self.inputs = inputs; self.logs = logs; errorMessage = nil
            return true
        } catch {
            errorMessage = "Deine Eingaben konnten nicht auf diesem Gerät gesichert werden. Lass die Maske geöffnet und versuche es erneut."
            return false
        }
    }

    private func key(_ userID: UUID) -> String { "app.fyrup.tracking-drafts.v1.\(userID.uuidString)" }
    private func markUnreadable() {
        storageBlocked = true
        errorMessage = "Lokale Workout-Eingaben konnten nicht gelesen werden. Die ursprünglichen Daten bleiben erhalten; neue Entwürfe können gerade nicht gesichert werden."
    }

    private func remapInputs(candidate: WorkoutLog, receipt: WorkoutLog) -> [InputDraft] {
        var result: [WorkoutSetDraftKey: InputDraft] = [:]
        for draft in inputs {
            var value = draft
            if draft.key.blindWorkoutID == nil, draft.key.activityID == candidate.activityID,
               let before = candidate.exercises.first(where: { $0.id == draft.key.exerciseID })?.sets.first(where: { $0.id == draft.key.setID }),
               let saved = receipt.exercises.first(where: { $0.id == draft.key.exerciseID })?.sets.first(where: { $0.setNumber == before.setNumber }) {
                let key = WorkoutSetDraftKey(ownerID: draft.key.ownerID, activityID: draft.key.activityID, blindWorkoutID: nil, exerciseID: draft.key.exerciseID, setID: saved.id)
                var baseline = draft.baseline; baseline.id = saved.id
                value = InputDraft(key: key, baseline: baseline, input: draft.input, updatedAt: draft.updatedAt)
            }
            if result[value.key].map({ $0.updatedAt > value.updatedAt }) != true { result[value.key] = value }
        }
        return result.values.sorted { $0.updatedAt > $1.updatedAt }
    }
    private static func accepts(_ input: WorkoutSetEntryInput) -> Bool { input.weight.count <= 256 && input.reps.count <= 256 }
    private static func accepts(baseline: WorkoutLog, candidate: WorkoutLog) -> Bool {
        guard baseline.activityID == candidate.activityID, baseline.planName == candidate.planName,
              baseline.validationMessage == nil, candidate.validationMessage == nil,
              baseline.exercises.count == candidate.exercises.count else { return false }
        return zip(baseline.exercises, candidate.exercises).allSatisfy { before, after in
            before.id == after.id && before.exercise == after.exercise && before.planExerciseID == after.planExerciseID
                && before.sortOrder == after.sortOrder && before.targetSets == after.targetSets
                && before.targetRepsMin == after.targetRepsMin && before.targetRepsMax == after.targetRepsMax
                && before.targetWeight == after.targetWeight && before.note == after.note
        }
    }

    /// Timestamp fields are server-authored receipts, not user intent. A response
    /// lost after commit can still be recognized without submitting another save.
    private static func sameIntent(_ lhs: WorkoutLog, _ rhs: WorkoutLog) -> Bool {
        guard accepts(baseline: lhs, candidate: rhs) else { return false }
        return zip(lhs.exercises, rhs.exercises).allSatisfy { first, second in
            guard first.completed == second.completed, first.sets.count == second.sets.count else { return false }
            return zip(first.sets.sorted { $0.setNumber < $1.setNumber }, second.sets.sorted { $0.setNumber < $1.setNumber }).allSatisfy { a, b in
                a.setNumber == b.setNumber && a.weight == b.weight && a.reps == b.reps && a.completed == b.completed
            }
        }
    }
}
