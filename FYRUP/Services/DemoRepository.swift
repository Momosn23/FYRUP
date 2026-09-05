import Foundation

actor DemoRepository: AppRepository {
    static let defaultUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let meID: UUID
    var me: Profile
    var activities: [Activity]
    let workoutStorage: DemoWorkoutStorage
    let stepStorage: DemoStepStorage
    let weeklyStorage: DemoWeeklyFlameStorage
    let hasConfirmedDemoWeeklyGoal: Bool
    private let now: @Sendable () -> Date
    private var avatarObjects: [String: Data] = [:]
    var crew: [Profile]
    private var sentFyrups = Set<UUID>()
    private var profileExists: Bool
    private var pushPreferences: NotificationPreferences = .standard
    private var hosted: [HostedSession] = []
    private var groups: [TrainingGroup] = []
    private var demoInvitations: [SessionInvitation] = []
    private var demoNotifications: [AppNotification] = []

    init(startsWithoutProfile: Bool = false, includesSocialFixtures: Bool = false, userID: UUID = DemoRepository.defaultUserID, workoutStorage: DemoWorkoutStorage = DemoWorkoutStorage(), stepStorage: DemoStepStorage = DemoStepStorage(), weeklyStorage: DemoWeeklyFlameStorage = DemoWeeklyFlameStorage(), now: @escaping @Sendable () -> Date = { Date() }) {
        meID = userID
        self.workoutStorage = workoutStorage
        self.stepStorage = stepStorage
        self.weeklyStorage = weeklyStorage
        self.hasConfirmedDemoWeeklyGoal = !startsWithoutProfile
        self.now = now
        profileExists = !startsWithoutProfile
        me = Profile(id: meID, username: "momo", displayName: "Momo", avatarPath: nil, birthYear: nil, city: "Berlin", bio: "Move together.", sports: [.gym, .running], weeklyGoal: 4, activityVisibility: "friends")
        crew = [
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, username: "max", displayName: "Max", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.gym], weeklyGoal: 4, activityVisibility: "friends"),
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, username: "sarah", displayName: "Sarah", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.running], weeklyGoal: 3, activityVisibility: "friends"),
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, username: "leon", displayName: "Leon", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.football], weeklyGoal: 3, activityVisibility: "friends")
        ]
        groups = [TrainingGroup(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, ownerID: meID, name: "Gym Crew", members: [crew[0], crew[2]])]
        let now = now()
        activities = [
            Activity(id: UUID(), userID: crew[0].id, sport: .gym, subtype: "Pull", status: .live, plannedAt: nil, startedAt: now.addingTimeInterval(-28 * 60), endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil),
            Activity(id: UUID(), userID: crew[1].id, sport: .running, subtype: "Easy Run", status: .completed, plannedAt: nil, startedAt: now.addingTimeInterval(-3_000), endedAt: now.addingTimeInterval(-780), distanceMeters: 6_400, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil),
            Activity(id: UUID(), userID: meID, sport: .gym, subtype: "Push", status: .completed, plannedAt: nil, startedAt: Calendar.current.date(byAdding: .day, value: -1, to: now)?.addingTimeInterval(-3_900), endedAt: Calendar.current.date(byAdding: .day, value: -1, to: now), distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil),
            Activity(id: UUID(), userID: meID, sport: .running, subtype: "Easy Run", status: .completed, plannedAt: nil, startedAt: Calendar.current.date(byAdding: .day, value: -3, to: now)?.addingTimeInterval(-2_760), endedAt: Calendar.current.date(byAdding: .day, value: -3, to: now), distanceMeters: 5_200, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil),
            Activity(id: UUID(), userID: meID, sport: .yoga, subtype: "Mobility", status: .completed, plannedAt: nil, startedAt: Calendar.current.date(byAdding: .day, value: -5, to: now)?.addingTimeInterval(-1_800), endedAt: Calendar.current.date(byAdding: .day, value: -5, to: now), distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        ]
        if includesSocialFixtures {
            let session = PlannedSession(id: UUID(), hostID: crew[0].id, sport: .gym, subtype: "Push", startsAt: now.addingTimeInterval(3600), durationMinutes: 60, note: "Brust / Schulter / Trizeps 💪", placeName: "Fitness First", friendsCanJoin: true, status: "planned")
            demoInvitations = [SessionInvitation(sessionID: session.id, status: .pending, session: session, host: crew[0])]
            demoNotifications = [
                AppNotification(id: UUID(), type: "reaction", title: "Sarah hat dein Training geliked.", body: "Stark gemacht! 🔥", data: nil, createdAt: now.addingTimeInterval(-600), readAt: nil),
                AppNotification(id: UUID(), type: "fyrup", title: "Leon hat dich gepusht!", body: "Deine Crew motiviert dich. 🔥", data: nil, createdAt: now.addingTimeInterval(-1800), readAt: nil),
                AppNotification(id: UUID(), type: "session_invite", title: "Max lädt dich zum Training ein.", body: "Gym · Push · Heute", data: nil, createdAt: now.addingTimeInterval(-2400), readAt: nil)
            ]
        }
        let belongsToCrewFixture = crew.contains { $0.id == userID }
        let isKnownFixture = userID == Self.defaultUserID || belongsToCrewFixture
        if let ownFixture = crew.first(where: { $0.id == userID }) {
            me = ownFixture
        }
        if userID != Self.defaultUserID {
            crew.append(Profile(id: Self.defaultUserID, username: "momo", displayName: "Momo", avatarPath: nil, birthYear: nil, city: "Berlin", bio: nil, sports: [.gym], weeklyGoal: 4, activityVisibility: "friends"))
        }
        crew.removeAll { $0.id == userID }
        if !isKnownFixture { crew = [] }
        // Alternate-account tests must not inherit Max's sample LIVE activity.
        if userID != Self.defaultUserID { activities.removeAll { $0.userID == userID } }
    }

    func restoreSession() async throws -> AuthSession? { AuthSession(accessToken: "demo", refreshToken: "demo", expiresAt: .distantFuture, userID: meID) }
    func signUp(email: String, password: String) async throws -> AuthSession? { try await restoreSession() }
    func signIn(email: String, password: String) async throws -> AuthSession { guard let value = try await restoreSession() else { throw AppError.authentication }; return value }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { try await signIn(email: "", password: "") }
    func resetPassword(email: String) async throws {}
    func signOut() async {}
    func profile(userID: UUID) async throws -> Profile? { userID == meID ? (profileExists ? me : nil) : crew.first { $0.id == userID } }
    func saveProfile(_ profile: Profile) async throws {
        guard profile.id == meID else { throw AppError.authentication }
        me = profile; profileExists = true
    }
    func uploadAvatar(userID: UUID, data: Data) async throws -> String { let path = "\(userID.uuidString.lowercased())/avatar.jpg"; avatarObjects[path] = data; return path }
    func saveOnboardingState(step: String, gymFocus: [String]?) async throws -> Profile {
        guard ["sports", "gym", "weekly_goal", "friends", "complete", "done"].contains(step) else { throw AppError.server }
        if ["friends", "complete", "done"].contains(step) {
            let state = try await weeklyState(userID: meID, timezone: nil)
            guard state.goalConfirmed else { throw AppError.server }
        }
        me.onboardingStep = step
        if let gymFocus { me.gymFocus = gymFocus }
        return me
    }
    func avatarData(path: String) async throws -> Data { guard let data = avatarObjects[path] else { throw AppError.server }; return data }
    func today(userID: UUID) async throws -> (Activity?, [CrewMember]) {
        try await restoreWorkoutActivities()
        let mine = DateLogic.status(for: activities.filter { $0.userID == meID })
        var members: [CrewMember] = []
        for var profile in crew {
            let weekly = try await weeklyState(userID: profile.id, timezone: nil)
            profile.weeklyGoal = weekly.suggestedWeeklyGoal
            members.append(CrewMember(profile: profile, activity: DateLogic.status(for: activities.filter { $0.userID == profile.id }),
                                      weeklyCount: weekly.currentWeek?.completedWorkouts ?? 0))
        }
        return (mine, members.sorted { $0.todayStatus < $1.todayStatus })
    }
    func recentActivities(userID: UUID) async throws -> [Activity] {
        try await restoreWorkoutActivities()
        return activities
            .filter { $0.userID == userID && $0.status == .completed }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }
    func startActivity(userID: UUID, sport: SportKind, subtype: String?, linkedActivityID: UUID?, plannedSessionID: UUID?) async throws -> Activity {
        guard userID == meID else { throw AppError.authentication }
        try await restoreWorkoutActivities()
        if let plannedSessionID, let planID = try await workoutStorage.planID(sessionID: plannedSessionID, userID: meID, friends: Set(crew.map(\.id))) {
            return try await startWorkout(planID: planID, linkedActivityID: linkedActivityID, sessionID: plannedSessionID)
        }
        if let linkedActivityID, let planID = try await workoutStorage.planID(activityID: linkedActivityID, userID: meID, friends: Set(crew.map(\.id))) {
            return try await startWorkout(planID: planID, linkedActivityID: linkedActivityID, sessionID: plannedSessionID)
        }
        guard !activities.contains(where: { $0.userID == meID && $0.status == .live }) else { throw AppError.conflict("Du hast bereits ein LIVE-Training.") }
        let activity = Activity(id: UUID(), userID: meID, sport: sport, subtype: subtype, status: .live, plannedAt: nil, startedAt: now(), endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        activities.append(activity); return activity
    }
    func completeActivity(id: UUID, distanceMeters: Int?) async throws -> Activity {
        try await restoreWorkoutActivities()
        guard let index = activities.firstIndex(where: { $0.id == id && $0.userID == meID }), [.live, .completed].contains(activities[index].status) else { throw AppError.server }
        if activities[index].status == .completed {
            let completed = activities[index]
            try await weeklyStorage.recordCompletion(completed)
            return completed
        }
        // Seed only the explicit existing-demo goal, never historical sample credits.
        _ = try await weeklyState(userID: meID, timezone: nil)
        guard let currentIndex = activities.firstIndex(where: { $0.id == id && $0.userID == meID }),
              [.live, .completed].contains(activities[currentIndex].status) else { throw AppError.server }
        if activities[currentIndex].status == .completed {
            let completed = activities[currentIndex]
            try await weeklyStorage.recordCompletion(completed)
            return completed
        }
        let now = now()
        if let pausedAt = activities[currentIndex].pausedAt {
            activities[currentIndex].pausedSeconds = (activities[currentIndex].pausedSeconds ?? 0) + max(0, Int(now.timeIntervalSince(pausedAt)))
            activities[currentIndex].pausedAt = nil
        }
        activities[currentIndex].status = .completed; activities[currentIndex].endedAt = now; activities[currentIndex].distanceMeters = distanceMeters
        let completed = activities[currentIndex]
        try await workoutStorage.updateActivity(completed, userID: meID)
        try await weeklyStorage.recordCompletion(completed)
        return completed
    }
    func cancelActivity(id: UUID) async throws {
        try await restoreWorkoutActivities()
        guard let activity = activities.first(where: { $0.id == id && $0.userID == meID && [.planned, .ready, .live].contains($0.status) }) else { throw AppError.authentication }
        var cancelled = activity; cancelled.status = .cancelled; cancelled.endedAt = now()
        if let pausedAt = cancelled.pausedAt {
            cancelled.pausedSeconds = (cancelled.pausedSeconds ?? 0) + max(0, Int((cancelled.endedAt ?? now()).timeIntervalSince(pausedAt)))
            cancelled.pausedAt = nil
        }
        try await workoutStorage.updateActivity(cancelled, userID: meID)
        activities.removeAll { $0.id == id }
    }

    func setActivityPaused(id: UUID, paused: Bool) async throws -> Activity {
        try await restoreWorkoutActivities()
        guard let index = activities.firstIndex(where: { $0.id == id && $0.userID == meID && $0.status == .live }) else {
            throw AppError.conflict("Nur dein laufendes Training kann pausiert werden.")
        }
        let now = now()
        if paused && activities[index].pausedAt == nil { activities[index].pausedAt = now }
        else if !paused, let pausedAt = activities[index].pausedAt {
            activities[index].pausedSeconds = (activities[index].pausedSeconds ?? 0) + max(0, Int(now.timeIntervalSince(pausedAt)))
            activities[index].pausedAt = nil
        }
        let updated = activities[index]
        try await workoutStorage.updateActivity(updated, userID: meID)
        return updated
    }
    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws {
        let sessionID = UUID()
        let session = PlannedSession(id: sessionID, hostID: meID, sport: sport, subtype: subtype, startsAt: startsAt, durationMinutes: duration, note: note, placeName: placeName, friendsCanJoin: friendsCanJoin, status: "planned")
        let participants = crew.filter { friendIDs.contains($0.id) }.map { SessionParticipant(profile: $0, status: .pending) }
        hosted.append(HostedSession(session: session, participants: participants))
        activities.append(Activity(id: UUID(), userID: meID, sport: sport, subtype: subtype, status: .planned, plannedAt: startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: duration, note: note, plannedSessionID: sessionID))
    }
    func invitations() async throws -> [SessionInvitation] { try await workoutStorage.invitations(userID: meID, friends: Set(crew.map(\.id))) + demoInvitations }
    func hostedSessions() async throws -> [HostedSession] { try await workoutStorage.hostedSessions(userID: meID) + hosted }
    func trainingGroups() async throws -> [TrainingGroup] { groups }
    func createTrainingGroup(name: String, memberIDs: [UUID]) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw AppError.conflict("Der Gruppenname ist zu kurz.") }
        let members = crew.filter { memberIDs.contains($0.id) }
        groups.append(TrainingGroup(id: UUID(), ownerID: meID, name: trimmed, members: members))
    }
    func deleteTrainingGroup(id: UUID) async throws { groups.removeAll { $0.id == id } }
    func updateHostedSession(_ session: PlannedSession) async throws -> PlannedSession {
        if session.workoutPlanID != nil { return try await workoutStorage.updateSession(session, userID: meID) }
        guard let index = hosted.firstIndex(where: { $0.id == session.id }) else { throw AppError.server }
        hosted[index].session = session
        if let activityIndex = activities.firstIndex(where: { $0.plannedSessionID == session.id && $0.userID == meID }) {
            activities[activityIndex].plannedAt = session.startsAt
            activities[activityIndex].plannedDurationMinutes = session.durationMinutes
            activities[activityIndex].note = session.note
        }
        return session
    }
    func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws {
        if try await workoutStorage.respond(sessionID: sessionID, status: status, userID: meID, friends: Set(crew.map(\.id))) { return }
        guard let index = demoInvitations.firstIndex(where: { $0.sessionID == sessionID }) else { throw AppError.server }
        let invitation = demoInvitations[index]
        demoInvitations[index] = SessionInvitation(sessionID: invitation.sessionID, status: status, session: invitation.session, host: invitation.host)
    }
    func cancelPlannedSession(sessionID: UUID) async throws {
        try await workoutStorage.cancelSession(sessionID: sessionID, userID: meID)
        activities.removeAll { $0.plannedSessionID == sessionID }; hosted.removeAll { $0.id == sessionID }
    }
    func joinPlannedSession(sessionID: UUID) async throws { _ = try await workoutStorage.respond(sessionID: sessionID, status: .accepted, userID: meID, friends: Set(crew.map(\.id))) }
    func searchUsers(query: String) async throws -> [Profile] { crew.filter { $0.username.localizedCaseInsensitiveContains(query) || $0.displayName.localizedCaseInsensitiveContains(query) } }
    func requests() async throws -> [Profile] { [] }
    func sendFriendRequest(to userID: UUID) async throws {}
    func answerFriendRequest(from userID: UUID, accept: Bool) async throws {}
    func removeFriend(_ userID: UUID) async throws { try await workoutStorage.revokeFriendship(meID, userID); await stepStorage.revokeFriendship(meID, userID); try await weeklyStorage.revokeFriendship(meID, userID); crew.removeAll { $0.id == userID } }
    func block(_ userID: UUID) async throws { try await workoutStorage.revokeFriendship(meID, userID); await stepStorage.revokeFriendship(meID, userID); try await weeklyStorage.revokeFriendship(meID, userID); crew.removeAll { $0.id == userID } }
    func fyrup(_ userID: UUID) async throws { guard sentFyrups.insert(userID).inserted else { throw AppError.conflict("Heute hast du Leon schon motiviert.") } }
    func react(activityID: UUID, reaction: ReactionKind?) async throws {}
    func notifications() async throws -> [AppNotification] { try await workoutStorage.notifications(userID: meID) + demoNotifications }
    func notificationPreferences() async throws -> NotificationPreferences { pushPreferences }
    func saveNotificationPreferences(_ preferences: NotificationPreferences) async throws -> NotificationPreferences { pushPreferences = preferences; return preferences }
    func goalSummary() async throws -> GoalSummary {
        let own = try await weeklyState(userID: meID, timezone: nil)
        let friends = try await friendsWeeklyState()
        let count = own.currentWeek?.completedWorkouts ?? 0
        let monthStart = Calendar.current.dateInterval(of: .month, for: now())?.start ?? .distantPast
        let monthCount = activities.filter { $0.userID == meID && $0.status == .completed && ($0.endedAt ?? .distantPast) >= monthStart }.count
        return GoalSummary(weeklyCount: count, weeklyGoal: own.suggestedWeeklyGoal, streak: own.currentStreak, monthCount: monthCount,
                           crewCount: count + friends.reduce(0) { $0 + ($1.currentWeek?.completedWorkouts ?? 0) },
                           crewTarget: own.suggestedWeeklyGoal + friends.reduce(0) { $0 + $1.suggestedWeeklyGoal })
    }
    func markNotificationsRead() async throws {}
    func registerDeviceToken(_ token: String) async throws {}
    func deleteAccount() async throws { try await workoutStorage.deleteAccount(userID: meID); await stepStorage.deleteAccount(userID: meID); try await weeklyStorage.deleteAccount(userID: meID) }
}
