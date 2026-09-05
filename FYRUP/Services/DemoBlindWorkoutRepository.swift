import Foundation

/// Separate storage keeps unrevealed exercise rows out of generic workout-plan/log APIs.
actor DemoBlindWorkoutStorage {
    private struct Entry: Codable {
        var draft: BlindWorkoutDraft
        var creator: Profile
        var recipient: Profile
        var createdAt: Date
        var logs: [WorkoutExerciseLog]
        var status: BlindWorkoutStatus = .sent
        var scheduledAt: Date?
        var acceptedAt: Date?
        var revealedCount = 0
        var activity: Activity?
        var completionNotified = false
        var copies: [UUID: WorkoutPlan] = [:]
        var reactions: [UUID: ReactionKind] = [:]
        var reactionNotificationAuthors: Set<UUID> = []
    }
    private struct State: Codable {
        var entries: [UUID: Entry] = [:]
        var notifications: [UUID: [AppNotification]] = [:]
        var revokedFriendships: Set<String> = []
        var preferences: [UUID: NotificationPreferences] = [:]
        var orphanedActivities: [UUID: Activity] = [:]
    }
    private var saved: State
    private let defaults: UserDefaults?
    private let now: @Sendable () -> Date
    private var failedToLoad = false
    private let key = "fyrup.demo.blind-workouts.v1"
    nonisolated let notificationPreferenceStorage: DemoNotificationPreferenceStorage

    init(persistenceSuiteName: String? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
        notificationPreferenceStorage = .shared(persistenceSuiteName: persistenceSuiteName)
        let defaults = persistenceSuiteName.flatMap { UserDefaults(suiteName: $0) }
        self.defaults = defaults
        if let data = defaults?.data(forKey: "fyrup.demo.blind-workouts.v1") {
            do { saved = try JSONDecoder().decode(State.self, from: data) }
            catch { saved = State(); failedToLoad = true }
        } else { saved = State() }
    }

    private func checkLoaded() throws {
        if failedToLoad { throw AppError.conflict("Die gespeicherten Blind Workouts konnten nicht geladen werden. Deine Daten wurden nicht überschrieben.") }
    }
    private func persist() throws {
        try checkLoaded()
        if let defaults { defaults.set(try JSONEncoder().encode(saved), forKey: key) }
    }
    private func friendshipKey(_ first: UUID, _ second: UUID) -> String { [first.uuidString, second.uuidString].sorted().joined(separator: ":") }
    private func hasAccess(_ entry: Entry, userID: UUID, friends: Set<UUID>) -> Bool {
        let other: UUID
        if entry.creator.id == userID { other = entry.recipient.id }
        else if entry.recipient.id == userID { other = entry.creator.id }
        else { return false }
        return friends.contains(other) && !saved.revokedFriendships.contains(friendshipKey(other, userID))
    }
    private func authorized(_ id: UUID, userID: UUID, friends: Set<UUID>) throws -> Entry {
        try checkLoaded()
        guard let entry = saved.entries[id], hasAccess(entry, userID: userID, friends: friends) else { throw AppError.authentication }
        return entry
    }

    private func summary(_ entry: Entry) -> BlindWorkoutSummary {
        let equipment = Set(entry.draft.exercises.map { $0.exercise.equipment })
        let muscles = entry.draft.exercises.reduce(into: Set<MuscleGroup>()) { $0.formUnion($1.exercise.muscleGroups) }
        return BlindWorkoutSummary(id: entry.draft.id, creatorID: entry.creator.id, recipientID: entry.recipient.id,
                                   creatorName: entry.creator.displayName, recipientName: entry.recipient.displayName,
                                   title: entry.draft.title, focus: entry.draft.focus, estimatedDurationMinutes: entry.draft.estimatedDurationMinutes,
                                   exerciseCount: entry.logs.count, requiredEquipment: ExerciseEquipment.allCases.filter { equipment.contains($0) },
                                   muscleGroups: MuscleGroup.allCases.filter { muscles.contains($0) }, status: entry.status,
                                   createdAt: entry.createdAt, scheduledAt: entry.scheduledAt, acceptedAt: entry.acceptedAt,
                                   startedAt: entry.activity?.startedAt, completedAt: entry.status == .completed ? entry.activity?.endedAt : nil,
                                   activityID: entry.activity?.id, completedExercises: entry.logs.filter(\.completed).count)
    }
    private func document(_ entry: Entry, userID: UUID, disclose: Bool = true) -> BlindWorkoutState {
        let role: BlindWorkoutRole = entry.creator.id == userID ? .creator : .recipient
        let visible: [WorkoutExerciseLog]
        if !disclose { visible = [] }
        else if role == .creator {
            // The creator owns the prescription, not the recipient's measurements.
            visible = entry.logs.map { row in
                var target = row; target.sets = []; target.completed = false; target.completedAt = nil
                return target
            }
        } else {
            visible = Array(entry.logs.prefix(entry.revealedCount))
        }
        let counts = ReactionKind.allCases.compactMap { reaction -> BlindWorkoutReactionCount? in
            let count = entry.reactions.values.filter { $0 == reaction }.count
            return count == 0 ? nil : BlindWorkoutReactionCount(reaction: reaction, count: count)
        }
        return BlindWorkoutState(summary: summary(entry), viewerRole: role, visibleExercises: visible, activity: role == .recipient ? entry.activity : nil,
                                 reactionCounts: entry.status == .completed && disclose ? counts : nil,
                                 myReaction: disclose ? entry.reactions[userID] : nil)
    }

    func list(userID: UUID, friends: Set<UUID>) throws -> [BlindWorkoutSummary] {
        try checkLoaded()
        return saved.entries.values.filter { hasAccess($0, userID: userID, friends: friends) }
            .sorted { $0.createdAt > $1.createdAt }.map(summary)
    }
    func detail(id: UUID, userID: UUID, friends: Set<UUID>) throws -> BlindWorkoutState {
        document(try authorized(id, userID: userID, friends: friends), userID: userID)
    }
    func visibleLog(activityID: UUID, userID: UUID, friends: Set<UUID>) throws -> WorkoutLog? {
        try checkLoaded()
        guard let entry = saved.entries.values.first(where: { $0.activity?.id == activityID }) else { return nil }
        guard entry.recipient.id == userID else { throw AppError.authentication }
        let visible = try detail(id: entry.draft.id, userID: userID, friends: friends)
        return WorkoutLog(activityID: activityID, planName: "Blind Workout", exercises: visible.visibleExercises)
    }

    func send(_ input: BlindWorkoutDraft, creator: Profile, recipient: Profile, friends: Set<UUID>, availableExercises: [GymExercise]) throws -> BlindWorkoutState {
        try checkLoaded()
        guard creator.id != recipient.id, input.recipientID == recipient.id, friends.contains(recipient.id),
              !saved.revokedFriendships.contains(friendshipKey(creator.id, recipient.id)) else { throw AppError.authentication }
        var draft = input.normalizedForSending()
        if let previous = saved.entries[draft.id] {
            guard previous.creator.id == creator.id, sameSendRequest(previous.draft, draft) else { throw AppError.conflict("Diese Einladung wurde bereits mit anderen Angaben gesendet.") }
            return document(previous, userID: creator.id)
        }
        let catalog = Dictionary(availableExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in draft.exercises.indices {
            guard let canonical = catalog[draft.exercises[index].exercise.id], !canonical.isArchived,
                  !canonical.isCustom || canonical.createdBy == creator.id else { throw AppError.validation("Wähle eine verfügbare Standardübung oder eine deiner eigenen Übungen.") }
            draft.exercises[index].exercise = canonical
        }
        if let message = draft.validationMessage { throw AppError.validation(message) }
        let logs = draft.exercises.map { row in
            WorkoutExerciseLog(exercise: row.exercise, planExerciseID: nil, sortOrder: row.sortOrder, targetSets: row.targetSets,
                               targetRepsMin: row.targetRepsMin, targetRepsMax: row.targetRepsMax, targetWeight: row.targetWeight,
                               note: row.note, sets: [])
        }
        let entry = Entry(draft: draft, creator: creator, recipient: recipient, createdAt: now(), logs: logs)
        saved.entries[draft.id] = entry
        if (try? notificationPreferenceStorage.value(userID: recipient.id))?.invitations == true {
            saved.notifications[recipient.id, default: []].insert(AppNotification(
                id: UUID(), type: "blind_workout_received", title: "\(creator.displayName) hat dir ein Blind Workout gebaut 👀",
                body: "\(draft.focus.title) · \(logs.count) Übungen · ca. \(draft.estimatedDurationMinutes) Min.",
                data: ["blind_workout_id": draft.id.uuidString], createdAt: now(), readAt: nil), at: 0)
        }
        try persist()
        return document(entry, userID: creator.id)
    }

    private func sameSendRequest(_ first: BlindWorkoutDraft, _ second: BlindWorkoutDraft) -> Bool {
        guard first.id == second.id, first.recipientID == second.recipientID, first.title == second.title, first.focus == second.focus,
              first.estimatedDurationMinutes == second.estimatedDurationMinutes, first.exercises.count == second.exercises.count else { return false }
        return zip(first.exercises, second.exercises).allSatisfy { pair in
            let a = pair.0, b = pair.1
            return a.id == b.id && a.exercise.id == b.exercise.id && a.sortOrder == b.sortOrder && a.targetSets == b.targetSets
                && a.targetRepsMin == b.targetRepsMin && a.targetRepsMax == b.targetRepsMax && a.targetWeight == b.targetWeight && a.note == b.note
        }
    }

    func respond(id: UUID, userID: UUID, friends: Set<UUID>, accept: Bool, equipmentConfirmed: Bool) throws -> BlindWorkoutState {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID else { throw AppError.authentication }
        if accept {
            guard equipmentConfirmed else { throw AppError.validation("Bestätige zuerst, dass das benötigte Equipment verfügbar ist.") }
            if [.accepted, .planned, .live, .completed].contains(entry.status) { return document(entry, userID: userID) }
            guard entry.status == .sent else { throw AppError.conflict("Diese Einladung kann nicht mehr angenommen werden.") }
            entry.status = .accepted; entry.acceptedAt = now()
        } else {
            if entry.status == .declined { return document(entry, userID: userID) }
            guard entry.status == .sent else { throw AppError.conflict("Diese Einladung wurde bereits beantwortet. Du kannst das Workout weiterhin abbrechen.") }
            entry.status = .declined
        }
        saved.entries[id] = entry; try persist()
        return document(entry, userID: userID)
    }

    func plan(id: UUID, userID: UUID, friends: Set<UUID>, startsAt: Date) throws -> BlindWorkoutState {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID, [.accepted, .planned].contains(entry.status) else { throw AppError.authentication }
        guard startsAt > now() else { throw AppError.validation("Wähle einen Zeitpunkt in der Zukunft.") }
        entry.status = .planned; entry.scheduledAt = startsAt
        var activity = entry.activity ?? Activity(id: UUID(), userID: userID, sport: .gym, subtype: "Blind Workout · \(entry.draft.focus.title)",
                                                 status: .planned, plannedAt: startsAt, startedAt: nil, endedAt: nil,
                                                 distanceMeters: nil, plannedDurationMinutes: entry.draft.estimatedDurationMinutes,
                                                 note: nil, plannedSessionID: nil)
        activity.plannedAt = startsAt; activity.exerciseCount = entry.logs.count; activity.blindWorkoutID = id
        entry.activity = activity
        saved.entries[id] = entry; try persist()
        return document(entry, userID: userID)
    }

    func mayStart(id: UUID, userID: UUID, friends: Set<UUID>) throws -> BlindWorkoutState {
        let entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID, [.accepted, .planned, .live].contains(entry.status) else { throw AppError.authentication }
        return document(entry, userID: userID)
    }
    func attachStartedActivity(id: UUID, userID: UUID, friends: Set<UUID>, activity: Activity) throws -> BlindWorkoutState {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID, activity.userID == userID, activity.status == .live,
              [.accepted, .planned].contains(entry.status) else { throw AppError.authentication }
        // Generic start reserves the single-live slot. A planned Blind Workout
        // keeps its original lifecycle ID when that reservation becomes LIVE.
        var canonical = Activity(id: entry.activity?.id ?? activity.id, userID: userID, sport: .gym,
                                 subtype: activity.subtype, status: .live, plannedAt: entry.scheduledAt,
                                 startedAt: activity.startedAt, endedAt: nil, distanceMeters: nil,
                                 plannedDurationMinutes: entry.draft.estimatedDurationMinutes, note: nil, plannedSessionID: nil)
        canonical.blindWorkoutID = id; canonical.exerciseCount = entry.logs.count
        entry.activity = canonical; entry.status = .live; entry.revealedCount = 1
        entry.logs[0].sets = (1...entry.logs[0].targetSets).map { WorkoutSetLog(setNumber: $0, weight: nil, reps: nil) }
        saved.entries[id] = entry; try persist()
        return document(entry, userID: userID)
    }

    private func validSets(_ sets: [WorkoutSetLog], exercise: GymExercise) -> Bool {
        let maxReps = exercise.isTimed ? BlindWorkoutLimits.timedSeconds.upperBound : BlindWorkoutLimits.strengthReps.upperBound
        return sets.count <= 6 && Set(sets.map(\.setNumber)).count == sets.count && sets.allSatisfy { row in
            BlindWorkoutLimits.targetSets.contains(row.setNumber) && (row.reps.map { (0...maxReps).contains($0) } ?? true)
                && (row.weight.map { $0.isFinite && BlindWorkoutLimits.targetWeight.contains($0) } ?? true)
        }
    }
    private func sameMeasurements(_ first: [WorkoutSetLog], _ second: [WorkoutSetLog]) -> Bool {
        let left = first.sorted { $0.setNumber < $1.setNumber }, right = second.sorted { $0.setNumber < $1.setNumber }
        guard left.count == right.count else { return false }
        return zip(left, right).allSatisfy { pair in
            pair.0.setNumber == pair.1.setNumber && pair.0.weight == pair.1.weight && pair.0.reps == pair.1.reps && pair.0.completed == pair.1.completed
        }
    }
    func saveExercise(id: UUID, exerciseID: UUID, userID: UUID, friends: Set<UUID>, sets: [WorkoutSetLog], complete: Bool) throws -> BlindWorkoutState {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID, [.live, .completed].contains(entry.status),
              let index = entry.logs.firstIndex(where: { $0.id == exerciseID }), index < entry.revealedCount else { throw AppError.authentication }
        let previous = entry.logs[index]
        guard validSets(sets, exercise: previous.exercise) else { throw AppError.validation("Prüfe die tatsächlichen Sätze, Wiederholungen und Gewichte.") }
        if previous.completed {
            guard complete && sameMeasurements(previous.sets, sets) else { throw AppError.conflict("Diese Übung ist bereits abgeschlossen und kann nicht nachträglich verändert werden.") }
            return document(entry, userID: userID)
        }
        guard entry.status == .live, index == entry.logs.firstIndex(where: { !$0.completed }) else { throw AppError.authentication }
        let timestamp = now()
        entry.logs[index].sets = sets.sorted { $0.setNumber < $1.setNumber }.map { input in
            let old = previous.sets.first { $0.setNumber == input.setNumber }
            return WorkoutSetLog(id: old?.id ?? UUID(), setNumber: input.setNumber, weight: input.weight, reps: input.reps,
                                 completed: input.completed, completedAt: input.completed ? (old?.completedAt ?? timestamp) : nil)
        }
        if complete {
            entry.logs[index].completed = true; entry.logs[index].completedAt = timestamp
            entry.revealedCount = min(entry.logs.count, index + 2)
            if index + 1 < entry.logs.count {
                entry.logs[index + 1].sets = (1...entry.logs[index + 1].targetSets).map { WorkoutSetLog(setNumber: $0, weight: nil, reps: nil) }
            }
        }
        saved.entries[id] = entry; try persist()
        return document(entry, userID: userID)
    }

    func mayFinish(id: UUID, userID: UUID, friends: Set<UUID>) throws -> BlindWorkoutState {
        let entry = try authorized(id, userID: userID, friends: friends)
        guard entry.recipient.id == userID, [.live, .completed].contains(entry.status), entry.logs.allSatisfy(\.completed) else {
            throw AppError.conflict("Schließe zuerst die aufgedeckten Übungen ab. Du kannst das Workout jederzeit abbrechen.")
        }
        return document(entry, userID: userID)
    }

    /// Root wires this into generic completion before any Activity is marked DONE.
    func requireCompletionAllowed(activityID: UUID, userID: UUID, friends: Set<UUID>, markedBlind: Bool) throws {
        try checkLoaded()
        if markedBlind || saved.entries.values.contains(where: { $0.activity?.id == activityID }) {
            throw AppError.conflict("Schließe dieses Blind Workout dort ab oder brich es ab.")
        }
    }

    /// Activity persistence uses the same ID as normal activity completion/weekly credit.
    /// It does not create a second completion, credit, plan or generic workout log.
    func synchronizeActivity(_ activity: Activity, userID: UUID) throws {
        try checkLoaded()
        guard let id = saved.entries.first(where: { $0.value.activity?.id == activity.id })?.key, var entry = saved.entries[id] else {
            if let orphan = saved.orphanedActivities[activity.id] {
                guard orphan.userID == userID, activity.userID == userID, activity.status == .cancelled else { throw AppError.authentication }
                saved.orphanedActivities[activity.id] = activity; try persist()
            }
            return
        }
        guard activity.userID == userID, entry.recipient.id == userID else { throw AppError.authentication }
        if activity.status == .completed {
            guard [.live, .completed].contains(entry.status), entry.logs.allSatisfy(\.completed), activity.endedAt != nil,
                  !saved.revokedFriendships.contains(friendshipKey(entry.creator.id, entry.recipient.id)) else {
                throw AppError.conflict("Das Blind Workout kann nicht als abgeschlossen bestätigt werden. Du kannst es weiterhin abbrechen.")
            }
            entry.status = .completed; entry.revealedCount = entry.logs.count
            if !entry.completionNotified {
                entry.completionNotified = true
                if (try? notificationPreferenceStorage.value(userID: entry.creator.id))?.reactions == true {
                    saved.notifications[entry.creator.id, default: []].insert(AppNotification(
                        id: UUID(), type: "blind_workout_completed", title: "\(entry.recipient.displayName) hat dein Blind Workout abgeschlossen 🔥",
                        body: "\(entry.logs.count) Übungen · stark gemacht.", data: ["blind_workout_id": id.uuidString], createdAt: now(), readAt: nil), at: 0)
                }
            }
        } else if activity.status == .cancelled {
            guard ![.completed, .declined].contains(entry.status) else { throw AppError.conflict("Dieses Blind Workout wurde bereits beendet.") }
            entry.status = .cancelled
        } else if activity.status == .live {
            guard entry.status == .live else { throw AppError.conflict("Dieses Blind Workout läuft nicht mehr.") }
        } else {
            guard entry.status == .planned && [.planned, .ready].contains(activity.status) else { throw AppError.authentication }
        }
        var canonical = activity; canonical.workoutPlanID = nil; canonical.blindWorkoutID = id; canonical.exerciseCount = entry.logs.count
        entry.activity = canonical
        saved.entries[id] = entry; try persist()
    }

    /// Revocation never prevents the recipient from stopping their own activity.
    func cancel(id: UUID, userID: UUID, friends: Set<UUID>) throws -> BlindWorkoutState {
        try checkLoaded()
        guard var entry = saved.entries[id], entry.recipient.id == userID || entry.creator.id == userID else { throw AppError.authentication }
        if entry.creator.id == userID && ![.sent, .accepted, .planned, .cancelled].contains(entry.status) { throw AppError.authentication }
        let disclose = hasAccess(entry, userID: userID, friends: friends)
        if entry.status == .cancelled { return document(entry, userID: userID, disclose: disclose) }
        guard ![.completed, .declined].contains(entry.status) else { throw AppError.conflict("Dieses Workout wurde bereits beendet.") }
        entry.status = .cancelled
        if var activity = entry.activity {
            let timestamp = now()
            if let pausedAt = activity.pausedAt {
                activity.pausedSeconds = (activity.pausedSeconds ?? 0) + max(0, Int(timestamp.timeIntervalSince(pausedAt)))
                activity.pausedAt = nil
            }
            activity.status = .cancelled; activity.endedAt = timestamp; entry.activity = activity
        }
        saved.entries[id] = entry; try persist()
        // No cancellation notification, negative score, or pressure message.
        return document(entry, userID: userID, disclose: disclose)
    }

    func existingCopyID(id: UUID, userID: UUID, friends: Set<UUID>) throws -> UUID? {
        let entry = try authorized(id, userID: userID, friends: friends)
        guard userID == entry.creator.id || (userID == entry.recipient.id && entry.status == .completed) else { throw AppError.authentication }
        return entry.copies[userID]?.id
    }
    func discardArchivedCopy(id: UUID, userID: UUID, friends: Set<UUID>, planID: UUID) throws {
        var entry = try authorized(id, userID: userID, friends: friends)
        if entry.copies[userID]?.id == planID { entry.copies.removeValue(forKey: userID); saved.entries[id] = entry; try persist() }
    }
    func copySource(id: UUID, userID: UUID, friends: Set<UUID>) throws -> WorkoutPlan {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard userID == entry.creator.id || (userID == entry.recipient.id && entry.status == .completed) else { throw AppError.authentication }
        if let copy = entry.copies[userID] { return copy }
        let name = entry.draft.title.flatMap { $0.count >= 2 ? $0 : nil } ?? "\(entry.draft.focus.title) · Blind Workout"
        let source = WorkoutPlan(id: id, ownerID: entry.creator.id, name: name, category: entry.draft.focus.title,
                                 visibility: .private, exercises: entry.draft.exercises)
        var copy = source.independentCopy(ownerID: userID)
        copy.copiedFromPlanID = nil // Blind IDs are not generic workout-plan IDs.
        entry.copies[userID] = copy
        saved.entries[id] = entry; try persist()
        return copy
    }

    func react(id: UUID, userID: UUID, friends: Set<UUID>, reaction: ReactionKind?) throws -> BlindWorkoutState {
        var entry = try authorized(id, userID: userID, friends: friends)
        guard entry.status == .completed else { throw AppError.conflict("Reaktionen sind nach dem abgeschlossenen Blind Workout möglich.") }
        let previous = entry.reactions[userID]
        entry.reactions[userID] = reaction
        let recipient = entry.creator.id == userID ? entry.recipient : entry.creator
        let author = entry.creator.id == userID ? entry.creator : entry.recipient
        if let reaction, previous != reaction, (try? notificationPreferenceStorage.value(userID: recipient.id))?.reactions == true,
           entry.reactionNotificationAuthors.insert(userID).inserted {
            saved.notifications[recipient.id, default: []].insert(AppNotification(
                id: UUID(), type: "blind_reaction", title: "\(author.displayName) feiert euer Blind Workout",
                body: reaction.rawValue, data: ["blind_workout_id": id.uuidString], createdAt: now(), readAt: nil), at: 0)
        }
        saved.entries[id] = entry; try persist()
        return document(entry, userID: userID)
    }

    func activities(userID: UUID) throws -> [Activity] {
        try checkLoaded()
        // The owner retains enough lifecycle state to stop a workout after access revocation.
        return saved.entries.values.filter { $0.recipient.id == userID }.compactMap(\.activity)
            + saved.orphanedActivities.values.filter { $0.userID == userID }
    }
    func notifications(userID: UUID, friends: Set<UUID>) throws -> [AppNotification] {
        try checkLoaded()
        return saved.notifications[userID, default: []].filter { note in
            guard let text = note.data?["blind_workout_id"], let id = UUID(uuidString: text), let entry = saved.entries[id] else { return false }
            return hasAccess(entry, userID: userID, friends: friends)
        }
    }
    func revokeFriendship(_ first: UUID, _ second: UUID) throws {
        try checkLoaded(); saved.revokedFriendships.insert(friendshipKey(first, second)); try persist()
    }
    func setNotificationPreferences(_ preferences: NotificationPreferences, userID: UUID) throws {
        try checkLoaded(); try notificationPreferenceStorage.setFixture(preferences, userID: userID)
    }
    func deleteAccount(userID: UUID) throws {
        try checkLoaded()
        // A surviving recipient keeps their activity/history and a safe generic
        // cancellation path, but never receives the deleted creator's hidden rows.
        for entry in saved.entries.values where entry.creator.id == userID && entry.recipient.id != userID {
            if let activity = entry.activity { saved.orphanedActivities[activity.id] = activity }
        }
        saved.entries = saved.entries.filter { $0.value.creator.id != userID && $0.value.recipient.id != userID }
        saved.orphanedActivities = saved.orphanedActivities.filter { $0.value.userID != userID }
        saved.notifications.removeValue(forKey: userID)
        saved.preferences.removeValue(forKey: userID)
        try notificationPreferenceStorage.remove(userID: userID)
        try persist()
    }
}

extension DemoRepository {
    func blindWorkouts() async throws -> [BlindWorkoutSummary] { try await blindStorage.list(userID: meID, friends: Set(crew.map(\.id))) }
    func blindWorkout(id: UUID) async throws -> BlindWorkoutState { try await blindStorage.detail(id: id, userID: meID, friends: Set(crew.map(\.id))) }
    func sendBlindWorkout(_ draft: BlindWorkoutDraft) async throws -> BlindWorkoutState {
        guard let recipient = crew.first(where: { $0.id == draft.recipientID }) else { throw AppError.authentication }
        let available = try await exercises()
        return try await blindStorage.send(draft, creator: me, recipient: recipient, friends: Set(crew.map(\.id)), availableExercises: available)
    }
    func respondToBlindWorkout(id: UUID, accept: Bool, equipmentConfirmed: Bool) async throws -> BlindWorkoutState {
        try await blindStorage.respond(id: id, userID: meID, friends: Set(crew.map(\.id)), accept: accept, equipmentConfirmed: equipmentConfirmed)
    }
    func planBlindWorkout(id: UUID, startsAt: Date) async throws -> BlindWorkoutState {
        let result = try await blindStorage.plan(id: id, userID: meID, friends: Set(crew.map(\.id)), startsAt: startsAt)
        if let activity = result.activity { activities.removeAll { $0.id == activity.id }; activities.append(activity) }
        return result
    }
    func startBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        let previous = try await blindStorage.mayStart(id: id, userID: meID, friends: Set(crew.map(\.id)))
        if previous.summary.status == .live {
            if let activity = previous.activity { activities.removeAll { $0.id == activity.id }; activities.append(activity) }
            return previous
        }
        let started = try await startActivity(userID: meID, sport: .gym, subtype: "Blind Workout · \(previous.summary.focus.title)",
                                              linkedActivityID: nil, plannedSessionID: nil)
        do {
            let result = try await blindStorage.attachStartedActivity(id: id, userID: meID, friends: Set(crew.map(\.id)), activity: started)
            activities.removeAll { $0.id == started.id || $0.id == previous.summary.activityID }
            if let activity = result.activity { activities.append(activity) }
            return result
        } catch { try? await cancelActivity(id: started.id); throw error }
    }
    func saveBlindWorkoutExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async throws -> BlindWorkoutState {
        try await blindStorage.saveExercise(id: id, exerciseID: exerciseID, userID: meID, friends: Set(crew.map(\.id)), sets: sets, complete: complete)
    }
    func finishBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        let previous = try await blindStorage.mayFinish(id: id, userID: meID, friends: Set(crew.map(\.id)))
        if previous.summary.status == .completed { return previous }
        guard let activityID = previous.summary.activityID else { throw AppError.server }
        try await restoreBlindActivities()
        let completed = try await completeValidatedActivity(id: activityID, distanceMeters: nil)
        try await blindStorage.synchronizeActivity(completed, userID: meID)
        return try await blindWorkout(id: id)
    }
    func cancelBlindWorkout(id: UUID) async throws -> BlindWorkoutState {
        let result = try await blindStorage.cancel(id: id, userID: meID, friends: Set(crew.map(\.id)))
        if let activityID = result.summary.activityID { activities.removeAll { $0.id == activityID } }
        return result
    }
    func copyBlindWorkout(id: UUID) async throws -> WorkoutPlan {
        if let previousID = try await blindStorage.existingCopyID(id: id, userID: meID, friends: Set(crew.map(\.id))) {
            let available = try await workoutPlans(ownerID: nil)
            if let previous = available.first(where: { $0.id == previousID }) { return previous }
            // A pending save may not exist yet: reuse its reserved IDs on retry.
            // Only a real archived own plan gets a new independent copy.
            if (try? await workoutPlan(id: previousID)) != nil {
                try await blindStorage.discardArchivedCopy(id: id, userID: meID, friends: Set(crew.map(\.id)), planID: previousID)
            }
        }
        var plan = try await blindStorage.copySource(id: id, userID: meID, friends: Set(crew.map(\.id)))
        var customCopies: [UUID: GymExercise] = [:]
        for index in plan.exercises.indices where plan.exercises[index].exercise.isCustom {
            let exercise = plan.exercises[index].exercise
            if let existing = customCopies[exercise.id] { plan.exercises[index].exercise = existing }
            else {
                let saved = try await saveExercise(exercise)
                customCopies[exercise.id] = saved; plan.exercises[index].exercise = saved
            }
        }
        return try await saveWorkoutPlan(plan)
    }
    func reactToBlindWorkout(id: UUID, reaction: ReactionKind?) async throws -> BlindWorkoutState {
        try await blindStorage.react(id: id, userID: meID, friends: Set(crew.map(\.id)), reaction: reaction)
    }

    // Integration hooks for existing DemoRepository lifecycle methods. Root owns
    // the call sites; keeping them here does not mutate existing repository files.
    func restoreBlindActivities() async throws {
        let restored = try await blindStorage.activities(userID: meID)
        activities.removeAll { $0.blindWorkoutID != nil }
        activities.append(contentsOf: restored.filter { $0.status != .cancelled })
    }
    func requireBlindCompletionAllowed(activityID: UUID) async throws {
        let markedBlind = activities.contains { $0.id == activityID && $0.blindWorkoutID != nil }
        try await blindStorage.requireCompletionAllowed(activityID: activityID, userID: meID, friends: Set(crew.map(\.id)), markedBlind: markedBlind)
    }
    func synchronizeBlindActivity(_ activity: Activity) async throws { try await blindStorage.synchronizeActivity(activity, userID: meID) }
    func blindNotifications() async throws -> [AppNotification] { try await blindStorage.notifications(userID: meID, friends: Set(crew.map(\.id))) }
    func blindWorkoutLog(activityID: UUID) async throws -> WorkoutLog? { try await blindStorage.visibleLog(activityID: activityID, userID: meID, friends: Set(crew.map(\.id))) }
}
