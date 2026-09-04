import Foundation

actor DemoRepository: AppRepository {
    private let meID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private var me: Profile
    private var activities: [Activity]
    private var crew: [Profile]
    private var sentFyrups = Set<UUID>()

    init() {
        me = Profile(id: meID, username: "momo", displayName: "Momo", avatarPath: nil, birthYear: nil, city: "Berlin", bio: "Move together.", sports: [.gym, .running], weeklyGoal: 4, activityVisibility: "friends")
        crew = [
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, username: "max", displayName: "Max", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.gym], weeklyGoal: 4, activityVisibility: "friends"),
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, username: "sarah", displayName: "Sarah", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.running], weeklyGoal: 3, activityVisibility: "friends"),
            Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, username: "leon", displayName: "Leon", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [.football], weeklyGoal: 3, activityVisibility: "friends")
        ]
        let now = Date()
        activities = [
            Activity(id: UUID(), userID: crew[0].id, sport: .gym, subtype: "Pull", status: .live, plannedAt: nil, startedAt: now.addingTimeInterval(-28 * 60), endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil),
            Activity(id: UUID(), userID: crew[1].id, sport: .running, subtype: "Easy Run", status: .completed, plannedAt: nil, startedAt: now.addingTimeInterval(-3_000), endedAt: now.addingTimeInterval(-780), distanceMeters: 6_400, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        ]
    }

    func restoreSession() async throws -> AuthSession? { AuthSession(accessToken: "demo", refreshToken: "demo", expiresAt: .distantFuture, userID: meID) }
    func signUp(email: String, password: String) async throws -> AuthSession? { try await restoreSession() }
    func signIn(email: String, password: String) async throws -> AuthSession { guard let value = try await restoreSession() else { throw AppError.authentication }; return value }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { try await signIn(email: "", password: "") }
    func resetPassword(email: String) async throws {}
    func signOut() async {}
    func profile(userID: UUID) async throws -> Profile? { me }
    func saveProfile(_ profile: Profile) async throws { me = profile }
    func today(userID: UUID) async throws -> (Activity?, [CrewMember]) {
        let mine = DateLogic.status(for: activities.filter { $0.userID == meID })
        let members = crew.map { profile in CrewMember(profile: profile, activity: DateLogic.status(for: activities.filter { $0.userID == profile.id }), weeklyCount: profile.id == crew[1].id ? 5 : 3) }.sorted { $0.todayStatus < $1.todayStatus }
        return (mine, members)
    }
    func startActivity(userID: UUID, sport: SportKind, subtype: String?, linkedActivityID: UUID?, plannedSessionID: UUID?) async throws -> Activity {
        guard !activities.contains(where: { $0.userID == meID && $0.status == .live }) else { throw AppError.conflict("Du hast bereits ein LIVE-Training.") }
        let activity = Activity(id: UUID(), userID: meID, sport: sport, subtype: subtype, status: .live, plannedAt: nil, startedAt: Date(), endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        activities.append(activity); return activity
    }
    func completeActivity(id: UUID, distanceMeters: Int?) async throws -> Activity {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { throw AppError.server }
        activities[index].status = .completed; activities[index].endedAt = Date(); activities[index].distanceMeters = distanceMeters
        return activities[index]
    }
    func cancelActivity(id: UUID) async throws { activities.removeAll { $0.id == id } }
    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, friendIDs: [UUID]) async throws {
        activities.append(Activity(id: UUID(), userID: meID, sport: sport, subtype: subtype, status: .planned, plannedAt: startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: duration, note: note, plannedSessionID: UUID()))
    }
    func invitations() async throws -> [SessionInvitation] { [] }
    func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws {}
    func cancelPlannedSession(sessionID: UUID) async throws { activities.removeAll { $0.plannedSessionID == sessionID } }
    func joinPlannedSession(sessionID: UUID) async throws {}
    func searchUsers(query: String) async throws -> [Profile] { crew.filter { $0.username.localizedCaseInsensitiveContains(query) || $0.displayName.localizedCaseInsensitiveContains(query) } }
    func requests() async throws -> [Profile] { [] }
    func sendFriendRequest(to userID: UUID) async throws {}
    func answerFriendRequest(from userID: UUID, accept: Bool) async throws {}
    func removeFriend(_ userID: UUID) async throws { crew.removeAll { $0.id == userID } }
    func block(_ userID: UUID) async throws { crew.removeAll { $0.id == userID } }
    func fyrup(_ userID: UUID) async throws { guard sentFyrups.insert(userID).inserted else { throw AppError.conflict("Heute hast du Leon schon motiviert.") } }
    func react(activityID: UUID, reaction: ReactionKind?) async throws {}
    func notifications() async throws -> [AppNotification] { [] }
    func goalSummary() async throws -> GoalSummary { GoalSummary(weeklyCount: 3, weeklyGoal: me.weeklyGoal, streak: 6, monthCount: 17, crewCount: 15, crewTarget: 16) }
    func markNotificationsRead() async throws {}
    func registerDeviceToken(_ token: String) async throws {}
    func deleteAccount() async throws {}
}
