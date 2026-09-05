import Foundation

/// A small, account-scoped demo backend. Each ordinary demo/test gets a fresh in-memory
/// instance; an explicit suite name opts a manual demo into restart persistence.
actor DemoWorkoutStorage {
    private struct SavedSession: Codable {
        var hosted: HostedSession
        var host: Profile
    }
    private struct CopyRequest: Codable {
        let sourceID: UUID
        let copyID: UUID
    }
    private struct State: Codable {
        var exercises: [UUID: GymExercise] = [:]
        var plans: [UUID: WorkoutPlan] = [:]
        var archivedPlans: Set<UUID> = []
        var favorites: [UUID: Set<UUID>] = [:]
        var shares: [UUID: Set<UUID>] = [:]
        var logs: [UUID: WorkoutLog] = [:]
        var activities: [UUID: Activity] = [:]
        var sessions: [UUID: SavedSession] = [:]
        var notifications: [UUID: [AppNotification]] = [:]
        var revokedFriendships: Set<String> = []
        // Optional for persisted demos created before request-idempotent copying.
        var copyRequests: [UUID: [UUID: CopyRequest]]?
    }

    private var state: State
    private let defaults: UserDefaults?
    private let key = "fyrup.demo.workouts.v1"
    private var failedToLoad = false
    private let library: [UUID: GymExercise]

    init(persistenceSuiteName: String? = nil, library: [GymExercise] = ExerciseLibrary.all) {
        self.library = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let defaults = persistenceSuiteName.flatMap { UserDefaults(suiteName: $0) }
        self.defaults = defaults
        if let data = defaults?.data(forKey: "fyrup.demo.workouts.v1") {
            do { state = try JSONDecoder().decode(State.self, from: data) }
            catch { state = State(); failedToLoad = true }
        } else { state = State() }
    }

    private func checkLoaded() throws {
        if failedToLoad { throw AppError.conflict("Die gespeicherten Demo-Trainings konnten nicht geladen werden. Deine Daten wurden nicht überschrieben.") }
    }

    private func persist() throws {
        try checkLoaded()
        if let defaults { defaults.set(try JSONEncoder().encode(state), forKey: key) }
    }

    private func friendshipKey(_ first: UUID, _ second: UUID) -> String {
        [first.uuidString, second.uuidString].sorted().joined(separator: ":")
    }

    private func areFriends(_ owner: UUID, _ user: UUID, friends: Set<UUID>) -> Bool {
        owner != user && friends.contains(owner) && !state.revokedFriendships.contains(friendshipKey(owner, user))
    }

    /// The fixture crew must respect the same persistent revocations as plan/RPC reads.
    func permittedFriendIDs(userID: UUID, candidates: Set<UUID>) throws -> Set<UUID> {
        try checkLoaded()
        return Set(candidates.filter { areFriends($0, userID, friends: candidates) })
    }

    private func availableExercise(_ id: UUID, userID: UUID) -> GymExercise? {
        if let standard = library[id] { return standard }
        guard let exercise = state.exercises[id], exercise.createdBy == userID else { return nil }
        return exercise
    }

    private func readablePlan(_ id: UUID, userID: UUID, friends: Set<UUID>, includeArchived: Bool = true) throws -> WorkoutPlan {
        try checkLoaded()
        guard var plan = state.plans[id], includeArchived || !state.archivedPlans.contains(id) else {
            throw AppError.conflict("Dieser Trainingsplan ist nicht mehr verfügbar.")
        }
        if plan.ownerID != userID {
            let invited = state.sessions.values.contains { entry in
                entry.hosted.session.workoutPlanID == id && entry.hosted.session.status != "cancelled" &&
                entry.hosted.participants.contains { $0.id == userID && [.pending, .accepted, .maybe].contains($0.status) }
            }
            guard !state.archivedPlans.contains(id), areFriends(plan.ownerID, userID, friends: friends),
                  plan.visibility == .friends || state.shares[id, default: []].contains(userID) || invited else {
                throw AppError.conflict("Dieser Plan wurde nicht mit dir geteilt.")
            }
        }
        // Current templates follow edits; workout logs below retain their own frozen copy.
        for index in plan.exercises.indices {
            if let current = library[plan.exercises[index].exercise.id] ?? state.exercises[plan.exercises[index].exercise.id] {
                plan.exercises[index].exercise = current
            }
        }
        return plan
    }

    func exercises(userID: UUID) throws -> [GymExercise] {
        try checkLoaded()
        return (Array(library.values) + state.exercises.values.filter { $0.createdBy == userID })
            .filter { !$0.isArchived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func saveExercise(_ input: GymExercise, userID: UUID) throws -> GymExercise {
        try checkLoaded()
        var exercise = input.normalizedForSaving()
        if let message = exercise.validationMessage { throw AppError.validation(message) }
        guard library[exercise.id] == nil, input.createdBy == nil || input.createdBy == userID,
              state.exercises[exercise.id] == nil || state.exercises[exercise.id]?.createdBy == userID else {
            throw AppError.conflict("Du kannst nur deine eigenen Übungen bearbeiten.")
        }
        exercise.isCustom = true
        exercise.createdBy = userID
        exercise.isArchived = state.exercises[exercise.id]?.isArchived ?? false
        state.exercises[exercise.id] = exercise
        try persist()
        return exercise
    }

    func archiveExercise(id: UUID, userID: UUID) throws {
        try checkLoaded()
        guard var exercise = state.exercises[id], exercise.createdBy == userID else {
            throw AppError.conflict("Du kannst nur deine eigenen Übungen archivieren.")
        }
        exercise.isArchived = true
        state.exercises[id] = exercise
        state.favorites[userID]?.remove(id)
        try persist()
    }

    func favoriteExercise(id: UUID, favorite: Bool, userID: UUID) throws {
        try checkLoaded()
        guard let exercise = availableExercise(id, userID: userID), !favorite || !exercise.isArchived else {
            throw AppError.conflict("Diese Übung ist nicht verfügbar.")
        }
        if favorite { state.favorites[userID, default: []].insert(id) }
        else { state.favorites[userID]?.remove(id) }
        try persist()
    }

    func favorites(userID: UUID) throws -> [UUID] {
        try checkLoaded()
        return state.favorites[userID, default: []].filter { availableExercise($0, userID: userID)?.isArchived == false }
            .sorted { $0.uuidString < $1.uuidString }
    }

    func plans(ownerID: UUID?, userID: UUID, friends: Set<UUID>) throws -> [WorkoutPlan] {
        try checkLoaded()
        let owner = ownerID ?? userID
        if owner != userID && !areFriends(owner, userID, friends: friends) { return [] }
        return try state.plans.values.filter {
            $0.ownerID == owner && !state.archivedPlans.contains($0.id) && (owner == userID || $0.visibility == .friends)
        }.map { try readablePlan($0.id, userID: userID, friends: friends) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func plan(id: UUID, userID: UUID, friends: Set<UUID>) throws -> WorkoutPlan {
        try readablePlan(id, userID: userID, friends: friends)
    }

    func savePlan(_ input: WorkoutPlan, userID: UUID) throws -> WorkoutPlan {
        try checkLoaded()
        var plan = input.normalizedForSaving()
        if let message = plan.validationMessage { throw AppError.validation(message) }
        guard plan.ownerID == userID, state.plans[plan.id] == nil || state.plans[plan.id]?.ownerID == userID else {
            throw AppError.conflict("Du kannst nur deine eigenen Pläne bearbeiten.")
        }
        guard !state.archivedPlans.contains(plan.id) else { throw AppError.conflict("Dieser Plan wurde archiviert.") }
        let previous = state.plans[plan.id]
        guard Set(plan.exercises.map(\.id)).count == plan.exercises.count else { throw AppError.validation("Jede Planzeile braucht eine eindeutige Zuordnung.") }
        let otherRowIDs = Set(state.plans.values.filter { $0.id != plan.id }.flatMap(\.exercises).map(\.id))
        for index in plan.exercises.indices {
            let item = plan.exercises[index]
            guard !otherRowIDs.contains(item.id), let exercise = availableExercise(item.exercise.id, userID: userID),
                  !exercise.isArchived || previous?.exercises.contains(where: { $0.id == item.id && $0.exercise.id == exercise.id }) == true else {
                throw AppError.conflict("Eine Übung ist nicht verfügbar. Wähle eine eigene oder eine Übung aus der Bibliothek.")
            }
            plan.exercises[index].exercise = exercise
            plan.exercises[index].sortOrder = index
        }
        plan.copiedFromPlanID = previous?.copiedFromPlanID
        plan.copyRequestID = nil
        state.plans[plan.id] = plan
        try persist()
        return plan
    }

    func archivePlan(id: UUID, userID: UUID) throws {
        try checkLoaded()
        guard state.plans[id]?.ownerID == userID else { throw AppError.conflict("Du kannst nur deine eigenen Pläne archivieren.") }
        state.archivedPlans.insert(id)
        try persist()
    }

    func copyPlan(id: UUID, requestID: UUID, userID: UUID, friends: Set<UUID>) throws -> WorkoutPlan {
        try checkLoaded()
        if let request = state.copyRequests?[userID]?[requestID] {
            guard request.sourceID == id else { throw AppError.conflict("Diese Kopieranfrage gehört zu einem anderen Plan.") }
            guard state.plans[request.copyID]?.ownerID == userID, !state.archivedPlans.contains(request.copyID) else {
                throw AppError.conflict("Deine zuvor erstellte Kopie wurde archiviert oder gelöscht. Es wurde keine weitere Kopie angelegt.")
            }
            var existing = try readablePlan(request.copyID, userID: userID, friends: [])
            existing.copyRequestID = requestID
            return existing
        }
        let source = try readablePlan(id, userID: userID, friends: friends, includeArchived: false)
        let copy = source.independentCopy(ownerID: userID)
        let previous = state
        for item in copy.exercises where item.exercise.isCustom { state.exercises[item.exercise.id] = item.exercise }
        state.plans[copy.id] = copy
        var requests = state.copyRequests ?? [:]
        requests[userID, default: [:]][requestID] = CopyRequest(sourceID: id, copyID: copy.id)
        state.copyRequests = requests
        do { try persist() } catch { state = previous; throw error }
        var receipt = copy; receipt.copyRequestID = requestID
        return receipt
    }

    func sharePlan(id: UUID, recipients: [UUID], sender: Profile, friends: Set<UUID>) throws {
        let plan = try readablePlan(id, userID: sender.id, friends: friends, includeArchived: false)
        guard plan.ownerID == sender.id, recipients.allSatisfy({ areFriends($0, sender.id, friends: friends) }) else {
            throw AppError.conflict("Du kannst deinen Plan nur mit bestätigten Freunden teilen.")
        }
        for recipient in Set(recipients) {
            guard state.shares[id, default: []].insert(recipient).inserted else { continue }
            state.notifications[recipient, default: []].insert(AppNotification(
                id: UUID(), type: "workout_plan_shared", title: "\(sender.displayName) teilt einen Trainingsplan.", body: plan.name,
                data: ["plan_id": id.uuidString], createdAt: Date(), readAt: nil
            ), at: 0)
        }
        try persist()
    }

    func startWorkout(planID: UUID, userID: UUID, friends: Set<UUID>, linkedActivityID: UUID?, sessionID: UUID?, alreadyLive: Bool) throws -> Activity {
        let plan = try readablePlan(planID, userID: userID, friends: friends, includeArchived: false)
        guard !alreadyLive && !state.activities.values.contains(where: { $0.userID == userID && $0.status == .live }) else {
            throw AppError.conflict("Du hast bereits ein LIVE-Training.")
        }
        if let linkedActivityID {
            guard let linked = state.activities[linkedActivityID], linked.workoutPlanID == planID,
                  linked.status == .live, areFriends(linked.userID, userID, friends: friends) else {
                throw AppError.conflict("Dieses gemeinsame Training ist nicht mehr verfügbar.")
            }
        }
        if let sessionID {
            guard let session = state.sessions[sessionID]?.hosted, session.session.workoutPlanID == planID,
                  session.session.status != "cancelled", session.session.hostID == userID ||
                    session.participants.contains(where: { $0.id == userID && $0.status == .accepted }) else {
                throw AppError.conflict("Nimm zuerst die Einladung für dieses Training an.")
            }
        }
        let planned = state.activities.values.first { $0.userID == userID && sessionID != nil && $0.plannedSessionID == sessionID && [.planned, .ready].contains($0.status) }
        var activity = Activity(id: planned?.id ?? UUID(), userID: userID, sport: .gym, subtype: plan.name, status: .live,
                                plannedAt: planned?.plannedAt, startedAt: Date(), endedAt: nil, distanceMeters: nil,
                                plannedDurationMinutes: planned?.plannedDurationMinutes, note: planned?.note, plannedSessionID: sessionID)
        activity.workoutPlanID = planID; activity.exerciseCount = plan.exercises.count
        let log = WorkoutLog(activityID: activity.id, planName: plan.name, exercises: plan.exercises.map { item in
            WorkoutExerciseLog(exercise: item.exercise, planExerciseID: item.id, sortOrder: item.sortOrder,
                               targetSets: item.targetSets, targetRepsMin: item.targetRepsMin, targetRepsMax: item.targetRepsMax,
                               targetWeight: item.targetWeight, note: item.note, sets: (1...item.targetSets).map { WorkoutSetLog(setNumber: $0) })
        })
        state.activities[activity.id] = activity
        state.logs[activity.id] = log
        if let sessionID, var session = state.sessions[sessionID], session.host.id == userID {
            session.hosted.session.status = "live"
            state.sessions[sessionID] = session
        }
        try persist()
        return activity
    }

    func planWorkout(planID: UUID, host: Profile, friends: Set<UUID>, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, invitees: [Profile]) throws {
        let plan = try readablePlan(planID, userID: host.id, friends: friends, includeArchived: false)
        guard plan.ownerID == host.id, invitees.allSatisfy({ areFriends($0.id, host.id, friends: friends) }) else { throw AppError.conflict("Nur eigene Pläne können mit bestätigten Freunden geplant werden.") }
        guard startsAt > Date() else { throw AppError.validation("Wähle bitte einen Zeitpunkt in der Zukunft.") }
        guard (5...600).contains(duration), (note?.count ?? 0) <= 500, (placeName?.count ?? 0) <= 120 else { throw AppError.validation("Prüfe Dauer, Nachricht und Ort.") }
        var session = PlannedSession(id: UUID(), hostID: host.id, sport: .gym, subtype: plan.name, startsAt: startsAt,
                                     durationMinutes: duration, note: note, placeName: placeName, friendsCanJoin: friendsCanJoin, status: "planned")
        session.workoutPlanID = plan.id; session.exerciseCount = plan.exercises.count
        let participants = invitees.map { SessionParticipant(profile: $0, status: .pending) }
        state.sessions[session.id] = SavedSession(hosted: HostedSession(session: session, participants: participants), host: host)
        var activity = Activity(id: UUID(), userID: host.id, sport: .gym, subtype: plan.name, status: .planned,
                                plannedAt: startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil,
                                plannedDurationMinutes: duration, note: note, plannedSessionID: session.id)
        activity.workoutPlanID = plan.id; activity.exerciseCount = plan.exercises.count
        state.activities[activity.id] = activity
        for invitee in invitees {
            state.notifications[invitee.id, default: []].insert(AppNotification(
                id: UUID(), type: "session_invite", title: "\(host.displayName) lädt dich zum Training ein.", body: "Gym · \(plan.name)",
                data: ["session_id": session.id.uuidString, "plan_id": plan.id.uuidString], createdAt: Date(), readAt: nil
            ), at: 0)
        }
        try persist()
    }

    func workoutLog(activityID: UUID, userID: UUID) throws -> WorkoutLog {
        try checkLoaded()
        guard state.activities[activityID]?.userID == userID, let log = state.logs[activityID] else {
            throw AppError.conflict("Trainingsprotokolle sind nur für das eigene Konto sichtbar.")
        }
        return log
    }

    func saveLog(_ input: WorkoutLog, userID: UUID) throws -> WorkoutLog {
        var saved = try workoutLog(activityID: input.activityID, userID: userID)
        guard let activity = state.activities[input.activityID], [.live, .completed].contains(activity.status) else {
            throw AppError.conflict("Dieses Training kann nicht mehr bearbeitet werden.")
        }
        if let message = input.validationMessage { throw AppError.validation(message) }
        guard input.exercises.count == saved.exercises.count,
              Set(input.exercises.map(\.id)) == Set(saved.exercises.map(\.id)),
              Set(input.exercises.map(\.id)).count == input.exercises.count else { throw AppError.validation("Die Übungen passen nicht zu diesem Training.") }
        let now = Date()
        for index in saved.exercises.indices {
            guard let incoming = input.exercises.first(where: { $0.id == saved.exercises[index].id }) else { throw AppError.server }
            saved.exercises[index].completed = incoming.completed
            saved.exercises[index].completedAt = incoming.completed ? (saved.exercises[index].completedAt ?? now) : nil
            let existing = saved.exercises[index].sets
            saved.exercises[index].sets = incoming.sets.sorted { $0.setNumber < $1.setNumber }.map { item in
                let previous = existing.first { $0.setNumber == item.setNumber }
                return WorkoutSetLog(id: previous?.id ?? UUID(), setNumber: item.setNumber, weight: item.weight, reps: item.reps,
                                     completed: item.completed, completedAt: item.completed ? (previous?.completedAt ?? now) : nil)
            }
        }
        state.logs[saved.activityID] = saved
        try persist()
        return saved
    }

    func activities(userID: UUID, friends: Set<UUID>) throws -> [Activity] {
        try checkLoaded()
        return state.activities.values.filter { $0.userID == userID || areFriends($0.userID, userID, friends: friends) }
    }

    func updateActivity(_ activity: Activity, userID: UUID) throws {
        try checkLoaded()
        guard let stored = state.activities[activity.id] else { return }
        guard stored.userID == userID, activity.userID == userID else { throw AppError.authentication }
        var authoritative = stored
        authoritative.status = activity.status; authoritative.endedAt = activity.endedAt; authoritative.distanceMeters = activity.distanceMeters
        authoritative.pausedAt = activity.pausedAt; authoritative.pausedSeconds = activity.pausedSeconds
        state.activities[activity.id] = authoritative
        try persist()
    }

    func planID(activityID: UUID, userID: UUID, friends: Set<UUID>) throws -> UUID? {
        try checkLoaded()
        guard let activity = state.activities[activityID], let id = activity.workoutPlanID else { return nil }
        _ = try readablePlan(id, userID: userID, friends: friends, includeArchived: false)
        return id
    }

    func planID(sessionID: UUID, userID: UUID, friends: Set<UUID>) throws -> UUID? {
        try checkLoaded()
        guard let id = state.sessions[sessionID]?.hosted.session.workoutPlanID else { return nil }
        _ = try readablePlan(id, userID: userID, friends: friends, includeArchived: false)
        return id
    }

    func invitations(userID: UUID, friends: Set<UUID>) throws -> [SessionInvitation] {
        try checkLoaded()
        return state.sessions.values.compactMap { entry in
            guard entry.hosted.session.status != "cancelled", areFriends(entry.host.id, userID, friends: friends),
                  let participant = entry.hosted.participants.first(where: { $0.id == userID }) else { return nil }
            return SessionInvitation(sessionID: entry.hosted.id, status: participant.status, session: entry.hosted.session, host: entry.host)
        }.sorted { $0.session.startsAt < $1.session.startsAt }
    }

    func hostedSessions(userID: UUID) throws -> [HostedSession] {
        try checkLoaded()
        return state.sessions.values.filter { $0.host.id == userID && $0.hosted.session.status != "cancelled" }
            .map(\.hosted).sorted { $0.session.startsAt < $1.session.startsAt }
    }

    func respond(sessionID: UUID, status: InvitationStatus, userID: UUID, friends: Set<UUID>) throws -> Bool {
        try checkLoaded()
        guard var saved = state.sessions[sessionID] else { return false }
        guard saved.hosted.session.status != "cancelled", areFriends(saved.host.id, userID, friends: friends),
              let index = saved.hosted.participants.firstIndex(where: { $0.id == userID }) else { throw AppError.conflict("Diese Einladung ist nicht verfügbar.") }
        var participants = saved.hosted.participants
        let participant = participants[index].profile
        participants[index] = SessionParticipant(profile: participant, status: status)
        saved.hosted = HostedSession(session: saved.hosted.session, participants: participants)
        state.sessions[sessionID] = saved
        let associated = state.activities.values.first { $0.userID == userID && $0.plannedSessionID == sessionID && $0.status != .cancelled }
        let oldActivity = associated.flatMap { [.planned, .ready].contains($0.status) ? $0 : nil }
        if status == .accepted && (associated == nil || oldActivity != nil) {
            let session = saved.hosted.session
            var activity = Activity(id: oldActivity?.id ?? UUID(), userID: userID, sport: .gym, subtype: session.subtype, status: .planned,
                                    plannedAt: session.startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil,
                                    plannedDurationMinutes: session.durationMinutes, note: session.note, plannedSessionID: sessionID)
            activity.workoutPlanID = session.workoutPlanID; activity.exerciseCount = session.exerciseCount
            state.activities[activity.id] = activity
        } else if status != .accepted, let oldActivity { state.activities.removeValue(forKey: oldActivity.id) }
        try persist()
        return true
    }

    func updateSession(_ input: PlannedSession, userID: UUID) throws -> PlannedSession {
        try checkLoaded()
        guard var saved = state.sessions[input.id], saved.host.id == userID, saved.hosted.session.status == "planned" else { throw AppError.conflict("Dieses Training kann nicht mehr geändert werden.") }
        guard input.startsAt > Date(), (5...600).contains(input.durationMinutes ?? 60), (input.note?.count ?? 0) <= 500, (input.placeName?.count ?? 0) <= 120 else { throw AppError.validation("Prüfe Zeitpunkt, Dauer, Nachricht und Ort.") }
        saved.hosted.session.startsAt = input.startsAt; saved.hosted.session.durationMinutes = input.durationMinutes
        saved.hosted.session.note = input.note; saved.hosted.session.placeName = input.placeName; saved.hosted.session.friendsCanJoin = input.friendsCanJoin
        state.sessions[input.id] = saved
        for (id, activity) in state.activities where activity.plannedSessionID == input.id && [.planned, .ready].contains(activity.status) {
            var updated = activity
            updated.plannedAt = input.startsAt; updated.plannedDurationMinutes = input.durationMinutes; updated.note = input.note
            state.activities[id] = updated
        }
        try persist()
        return saved.hosted.session
    }

    func cancelSession(sessionID: UUID, userID: UUID) throws {
        try checkLoaded()
        guard var saved = state.sessions[sessionID] else { return }
        guard saved.host.id == userID else { throw AppError.authentication }
        saved.hosted.session.status = "cancelled"; state.sessions[sessionID] = saved
        for (id, activity) in state.activities where activity.plannedSessionID == sessionID && [.planned, .ready].contains(activity.status) {
            var cancelled = activity
            cancelled.status = .cancelled; state.activities[id] = cancelled
        }
        try persist()
    }

    func notifications(userID: UUID) throws -> [AppNotification] { try checkLoaded(); return state.notifications[userID, default: []] }

    func revokeFriendship(_ first: UUID, _ second: UUID) throws {
        try checkLoaded()
        state.revokedFriendships.insert(friendshipKey(first, second))
        try persist()
    }

    func deleteAccount(userID: UUID) throws {
        try checkLoaded()
        let planIDs = Set(state.plans.values.filter { $0.ownerID == userID }.map(\.id))
        let activityIDs = Set(state.activities.values.filter { $0.userID == userID }.map(\.id))
        state.exercises = state.exercises.filter { $0.value.createdBy != userID }
        state.plans = state.plans.filter { !planIDs.contains($0.key) }
        for (id, plan) in state.plans where plan.copiedFromPlanID.map({ planIDs.contains($0) }) == true {
            var independent = plan; independent.copiedFromPlanID = nil; state.plans[id] = independent
        }
        state.archivedPlans.subtract(planIDs)
        state.favorites.removeValue(forKey: userID)
        state.logs = state.logs.filter { !activityIDs.contains($0.key) }
        state.activities = state.activities.filter { !activityIDs.contains($0.key) }
        state.sessions = state.sessions.filter { $0.value.host.id != userID }
        state.notifications.removeValue(forKey: userID)
        state.copyRequests?.removeValue(forKey: userID)
        state.shares = state.shares.filter { !planIDs.contains($0.key) }.mapValues { $0.subtracting([userID]) }
        try persist()
    }
}

extension DemoRepository {
    func restoreWorkoutActivities() async throws {
        try await restoreBlindActivities()
        let persisted = try await workoutStorage.activities(userID: meID, friends: Set(crew.map(\.id)))
        // Replace, rather than merge, persisted summaries so a declined/cancelled invitation
        // or revoked friendship cannot leave an old workout visible in this process.
        activities.removeAll { $0.workoutPlanID != nil }
        activities.append(contentsOf: persisted)
    }

    func exercises() async throws -> [GymExercise] { try await workoutStorage.exercises(userID: meID) }
    func saveExercise(_ exercise: GymExercise) async throws -> GymExercise { try await workoutStorage.saveExercise(exercise, userID: meID) }
    func archiveExercise(id: UUID) async throws { try await workoutStorage.archiveExercise(id: id, userID: meID) }
    func favoriteExercise(id: UUID, favorite: Bool) async throws { try await workoutStorage.favoriteExercise(id: id, favorite: favorite, userID: meID) }
    func exerciseFavorites() async throws -> [UUID] { try await workoutStorage.favorites(userID: meID) }
    func workoutPlans(ownerID: UUID?) async throws -> [WorkoutPlan] { try await workoutStorage.plans(ownerID: ownerID, userID: meID, friends: Set(crew.map(\.id))) }
    func workoutPlan(id: UUID) async throws -> WorkoutPlan { try await workoutStorage.plan(id: id, userID: meID, friends: Set(crew.map(\.id))) }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws -> WorkoutPlan { try await workoutStorage.savePlan(plan, userID: meID) }
    func archiveWorkoutPlan(id: UUID) async throws { try await workoutStorage.archivePlan(id: id, userID: meID) }
    func copyWorkoutPlan(id: UUID, requestID: UUID) async throws -> WorkoutPlan { try await workoutStorage.copyPlan(id: id, requestID: requestID, userID: meID, friends: Set(crew.map(\.id))) }
    func shareWorkoutPlan(id: UUID, friendIDs: [UUID]) async throws { try await workoutStorage.sharePlan(id: id, recipients: friendIDs, sender: me, friends: Set(crew.map(\.id))) }

    func startWorkout(planID: UUID, linkedActivityID: UUID?, sessionID: UUID?) async throws -> Activity {
        try await restoreWorkoutActivities()
        let activity = try await workoutStorage.startWorkout(planID: planID, userID: meID, friends: Set(crew.map(\.id)),
                                                            linkedActivityID: linkedActivityID, sessionID: sessionID,
                                                            alreadyLive: activities.contains { $0.userID == meID && $0.status == .live })
        activities.removeAll { $0.id == activity.id }
        activities.append(activity)
        return activity
    }

    func planWorkout(planID: UUID, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws {
        let uniqueIDs = Set(friendIDs)
        guard uniqueIDs.isSubset(of: Set(crew.map(\.id))) else { throw AppError.conflict("Du kannst nur bestätigte Freunde einladen.") }
        try await workoutStorage.planWorkout(planID: planID, host: me, friends: Set(crew.map(\.id)), startsAt: startsAt,
                                             duration: duration, note: note, placeName: placeName, friendsCanJoin: friendsCanJoin,
                                             invitees: crew.filter { uniqueIDs.contains($0.id) })
        try await restoreWorkoutActivities()
    }

    func workoutLog(activityID: UUID) async throws -> WorkoutLog {
        if let blind = try await blindWorkoutLog(activityID: activityID) { return blind }
        return try await workoutStorage.workoutLog(activityID: activityID, userID: meID)
    }
    func saveWorkoutLog(_ log: WorkoutLog) async throws -> WorkoutLog { try await workoutStorage.saveLog(log, userID: meID) }
}
