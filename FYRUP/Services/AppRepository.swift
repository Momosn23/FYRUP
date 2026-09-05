import Foundation

protocol AppRepository: WorkoutRepository, StepRepository, WeeklyFlameRepository, BlindWorkoutRepository, CallMyShotRepository, NotificationRoutingRepository, PersonalTrainingRepository {
    func restoreSession() async throws -> AuthSession?
    func signUp(email: String, password: String) async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func resetPassword(email: String) async throws
    func signOut() async
    func profile(userID: UUID) async throws -> Profile?
    func saveProfile(_ profile: Profile) async throws
    func saveOnboardingState(step: String, gymFocus: [String]?) async throws -> Profile
    func uploadAvatar(userID: UUID, data: Data) async throws -> String
    func avatarData(path: String) async throws -> Data
    func today(userID: UUID) async throws -> (Activity?, [CrewMember])
    func recentActivities(userID: UUID) async throws -> [Activity]
    func startActivity(userID: UUID, sport: SportKind, subtype: String?, linkedActivityID: UUID?, plannedSessionID: UUID?) async throws -> Activity
    func completeActivity(id: UUID, distanceMeters: Int?) async throws -> Activity
    func setActivityPaused(id: UUID, paused: Bool) async throws -> Activity
    func cancelActivity(id: UUID) async throws
    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws
    func invitations() async throws -> [SessionInvitation]
    func hostedSessions() async throws -> [HostedSession]
    func trainingGroups() async throws -> [TrainingGroup]
    func createTrainingGroup(name: String, memberIDs: [UUID]) async throws
    func deleteTrainingGroup(id: UUID) async throws
    func updateHostedSession(_ session: PlannedSession) async throws -> PlannedSession
    func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws
    func cancelPlannedSession(sessionID: UUID) async throws
    func joinPlannedSession(sessionID: UUID) async throws
    func searchUsers(query: String) async throws -> [Profile]
    func requests() async throws -> [Profile]
    func sendFriendRequest(to userID: UUID) async throws
    func answerFriendRequest(from userID: UUID, accept: Bool) async throws
    func removeFriend(_ userID: UUID) async throws
    func block(_ userID: UUID) async throws
    func fyrup(_ userID: UUID) async throws
    func react(activityID: UUID, reaction: ReactionKind?) async throws
    func notifications() async throws -> [AppNotification]
    func notificationPreferences() async throws -> NotificationPreferences
    func saveNotificationPreferences(_ preferences: NotificationPreferences, expected: NotificationPreferences) async throws -> NotificationPreferences
    func goalSummary() async throws -> GoalSummary
    func markNotificationsRead() async throws
    func registerDeviceToken(_ token: String) async throws
    func deleteAccount() async throws
}

actor LiveAppRepository: AppRepository {
    let client: SupabaseRESTClient
    init(configuration: AppConfiguration) { client = SupabaseRESTClient(configuration: configuration) }

    func restoreSession() async throws -> AuthSession? { try await client.restore() }
    func signUp(email: String, password: String) async throws -> AuthSession? { try await client.signUp(email: email, password: password) }
    func signIn(email: String, password: String) async throws -> AuthSession { try await client.signIn(email: email, password: password) }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { try await client.signInWithApple(idToken: idToken, nonce: nonce) }
    func resetPassword(email: String) async throws { try await client.resetPassword(email: email) }
    func signOut() async { await client.signOut() }

    func profile(userID: UUID) async throws -> Profile? {
        let values: [Profile] = try await client.select("profiles", query: [.init(name: "id", value: "eq.\(userID)"), .init(name: "select", value: "*")])
        return values.first
    }

    func saveProfile(_ profile: Profile) async throws {
        struct Body: Encodable {
            let pUsername: String; let pDisplayName: String; let pAvatarPath: String?; let pBirthYear: Int?; let pCity: String?; let pBio: String?; let pSports: [SportKind]; let pWeeklyGoal: Int; let pActivityVisibility: String
            enum CodingKeys: String, CodingKey { case pUsername = "p_username", pDisplayName = "p_display_name", pAvatarPath = "p_avatar_path", pBirthYear = "p_birth_year", pCity = "p_city", pBio = "p_bio", pSports = "p_sports", pWeeklyGoal = "p_weekly_goal", pActivityVisibility = "p_activity_visibility" }
        }
        let _: Profile = try await client.rpc("upsert_profile", body: Body(pUsername: profile.username, pDisplayName: profile.displayName, pAvatarPath: profile.avatarPath, pBirthYear: profile.birthYear, pCity: profile.city, pBio: profile.bio, pSports: profile.sports, pWeeklyGoal: profile.weeklyGoal, pActivityVisibility: profile.activityVisibility))
    }

    func saveOnboardingState(step: String, gymFocus: [String]?) async throws -> Profile {
        struct Body: Encodable {
            let pStep: String; let pGymFocus: [String]?
            enum CodingKeys: String, CodingKey { case pStep = "p_step", pGymFocus = "p_gym_focus" }
        }
        return try await client.rpc("save_onboarding_state", body: Body(pStep: step, pGymFocus: gymFocus))
    }

    func uploadAvatar(userID: UUID, data: Data) async throws -> String {
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        try await client.uploadObject(bucket: "avatars", path: path, data: data, contentType: "image/jpeg")
        return path
    }

    func avatarData(path: String) async throws -> Data {
        try await client.downloadObject(bucket: "avatars", path: path)
    }

    func today(userID: UUID) async throws -> (Activity?, [CrewMember]) {
        struct Feed: Decodable { let me: Activity?; let crew: [FeedMember] }
        struct FeedMember: Decodable {
            let profile: Profile; let activity: Activity?; let weeklyCount: Int
            enum CodingKeys: String, CodingKey { case profile, activity; case weeklyCount = "weekly_count" }
        }
        let feed: Feed = try await client.rpc("today_feed", body: ["p_timezone": TimeZone.current.identifier])
        return (feed.me, feed.crew.map { CrewMember(profile: $0.profile, activity: $0.activity, weeklyCount: $0.weeklyCount) })
    }

    func recentActivities(userID: UUID) async throws -> [Activity] {
        try await client.select("activities", query: [
            .init(name: "user_id", value: "eq.\(userID)"),
            .init(name: "status", value: "eq.completed"),
            .init(name: "select", value: "*"),
            .init(name: "order", value: "created_at.desc"),
            .init(name: "limit", value: "20")
        ])
    }

    func startActivity(userID: UUID, sport: SportKind, subtype: String?, linkedActivityID: UUID?, plannedSessionID: UUID?) async throws -> Activity {
        struct Body: Encodable { let pSport: String; let pSubtype: String?; let pLinkedActivityID: UUID?; let pPlannedSessionID: UUID?; enum CodingKeys: String, CodingKey { case pSport = "p_sport", pSubtype = "p_subtype", pLinkedActivityID = "p_linked_activity_id", pPlannedSessionID = "p_planned_session_id" } }
        return try await client.rpc("start_activity", body: Body(pSport: sport.rawValue, pSubtype: subtype, pLinkedActivityID: linkedActivityID, pPlannedSessionID: plannedSessionID))
    }

    func completeActivity(id: UUID, distanceMeters: Int?) async throws -> Activity {
        struct Body: Encodable { let pActivityID: UUID; let pDistanceMeters: Int?; enum CodingKeys: String, CodingKey { case pActivityID = "p_activity_id", pDistanceMeters = "p_distance_meters" } }
        return try await client.rpc("complete_activity", body: Body(pActivityID: id, pDistanceMeters: distanceMeters))
    }

    func setActivityPaused(id: UUID, paused: Bool) async throws -> Activity {
        struct Body: Encodable {
            let activity: UUID; let paused: Bool
            enum CodingKeys: String, CodingKey { case activity = "p_activity", paused = "p_paused" }
        }
        return try await client.rpc("set_activity_paused", body: Body(activity: id, paused: paused))
    }

    func cancelActivity(id: UUID) async throws {
        let _: Bool = try await client.rpc("cancel_activity", body: ["p_activity_id": id.uuidString])
    }

    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws {
        struct Body: Encodable {
            let pSport: String; let pSubtype: String?; let pStartsAt: Date; let pDurationMinutes: Int?
            let pNote: String?; let pPlaceName: String?; let pFriendsCanJoin: Bool; let pInvitees: [UUID]
            enum CodingKeys: String, CodingKey {
                case pSport = "p_sport", pSubtype = "p_subtype", pStartsAt = "p_starts_at", pDurationMinutes = "p_duration_minutes"
                case pNote = "p_note", pPlaceName = "p_place_name", pFriendsCanJoin = "p_friends_can_join", pInvitees = "p_invitees"
            }
            func encode(to encoder: Encoder) throws {
                var values = encoder.container(keyedBy: CodingKeys.self)
                try values.encode(pSport, forKey: .pSport); try values.encode(pSubtype, forKey: .pSubtype)
                try values.encode(pStartsAt, forKey: .pStartsAt); try values.encode(pDurationMinutes, forKey: .pDurationMinutes)
                try values.encode(pNote, forKey: .pNote); try values.encode(pPlaceName, forKey: .pPlaceName)
                try values.encode(pFriendsCanJoin, forKey: .pFriendsCanJoin); try values.encode(pInvitees, forKey: .pInvitees)
            }
        }
        struct Result: Decodable { let id: UUID }
        let _: Result = try await client.rpc("plan_session", body: Body(pSport: sport.rawValue, pSubtype: subtype, pStartsAt: startsAt, pDurationMinutes: duration, pNote: note, pPlaceName: placeName, pFriendsCanJoin: friendsCanJoin, pInvitees: friendIDs))
    }
    func invitations() async throws -> [SessionInvitation] { try await client.rpc("my_session_invites", body: [:] as [String: String]) }
    func hostedSessions() async throws -> [HostedSession] { try await client.rpc("my_hosted_sessions", body: [:] as [String: String]) }
    func trainingGroups() async throws -> [TrainingGroup] { try await client.rpc("my_training_groups", body: [:] as [String: String]) }
    func createTrainingGroup(name: String, memberIDs: [UUID]) async throws {
        struct Body: Encodable {
            let pName: String; let pMemberIDs: [UUID]
            enum CodingKeys: String, CodingKey { case pName = "p_name", pMemberIDs = "p_member_ids" }
        }
        let _: Bool = try await client.rpc("create_training_group", body: Body(pName: name, pMemberIDs: memberIDs))
    }
    func deleteTrainingGroup(id: UUID) async throws {
        let _: Bool = try await client.rpc("delete_training_group", body: ["p_group": id.uuidString])
    }
    func updateHostedSession(_ session: PlannedSession) async throws -> PlannedSession {
        struct Body: Encodable {
            let pSession: UUID; let pStartsAt: Date; let pDurationMinutes: Int?; let pNote: String?; let pPlaceName: String?; let pFriendsCanJoin: Bool
            enum CodingKeys: String, CodingKey {
                case pSession = "p_session", pStartsAt = "p_starts_at", pDurationMinutes = "p_duration_minutes"
                case pNote = "p_note", pPlaceName = "p_place_name", pFriendsCanJoin = "p_friends_can_join"
            }
            func encode(to encoder: Encoder) throws {
                var values = encoder.container(keyedBy: CodingKeys.self)
                try values.encode(pSession, forKey: .pSession); try values.encode(pStartsAt, forKey: .pStartsAt)
                try values.encode(pDurationMinutes, forKey: .pDurationMinutes); try values.encode(pNote, forKey: .pNote)
                try values.encode(pPlaceName, forKey: .pPlaceName); try values.encode(pFriendsCanJoin, forKey: .pFriendsCanJoin)
            }
        }
        return try await client.rpc("update_planned_session", body: Body(pSession: session.id, pStartsAt: session.startsAt, pDurationMinutes: session.durationMinutes, pNote: session.note, pPlaceName: session.placeName, pFriendsCanJoin: session.friendsCanJoin))
    }
    func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws { let _: Bool = try await client.rpc("respond_to_invite", body: ["p_session": sessionID.uuidString, "p_status": status.rawValue]) }
    func cancelPlannedSession(sessionID: UUID) async throws { let _: Bool = try await client.rpc("cancel_session", body: ["p_session": sessionID.uuidString]) }
    func joinPlannedSession(sessionID: UUID) async throws { let _: Bool = try await client.rpc("join_session", body: ["p_session": sessionID.uuidString]) }

    func searchUsers(query: String) async throws -> [Profile] { try await client.rpc("search_profiles", body: ["p_query": query]) }
    func requests() async throws -> [Profile] { try await client.rpc("pending_friend_requests", body: [:] as [String: String]) }
    func sendFriendRequest(to userID: UUID) async throws { let _: Bool = try await client.rpc("send_friend_request", body: ["p_addressee": userID.uuidString]) }
    func answerFriendRequest(from userID: UUID, accept: Bool) async throws {
        struct Body: Encodable { let pRequester: UUID; let pAccept: Bool; enum CodingKeys: String, CodingKey { case pRequester = "p_requester", pAccept = "p_accept" } }
        let _: Bool = try await client.rpc("answer_friend_request", body: Body(pRequester: userID, pAccept: accept))
    }
    func removeFriend(_ userID: UUID) async throws { let _: Bool = try await client.rpc("remove_friend", body: ["p_friend": userID.uuidString]) }
    func block(_ userID: UUID) async throws { let _: Bool = try await client.rpc("block_user", body: ["p_blocked": userID.uuidString]) }
    func fyrup(_ userID: UUID) async throws { let _: Bool = try await client.rpc("send_fyrup", body: ["p_recipient": userID.uuidString, "p_timezone": TimeZone.current.identifier]) }
    func react(activityID: UUID, reaction: ReactionKind?) async throws { let _: Bool = try await client.rpc("set_reaction", body: ["p_activity": activityID.uuidString, "p_reaction": reaction?.rawValue ?? ""]) }
    func notifications() async throws -> [AppNotification] { try await client.select("notifications", query: [.init(name: "select", value: "*"), .init(name: "order", value: "created_at.desc"), .init(name: "limit", value: "50")]) }
    func notificationPreferences() async throws -> NotificationPreferences { try await client.rpc("get_notification_preferences", body: [:] as [String: String]) }
    func saveNotificationPreferences(_ preferences: NotificationPreferences, expected: NotificationPreferences) async throws -> NotificationPreferences {
        try await client.rpc("save_notification_preferences_cas", body: NotificationPreferenceSaveRequest(expected: expected, desired: preferences))
    }
    func goalSummary() async throws -> GoalSummary { try await client.rpc("goal_summary", body: ["p_timezone": TimeZone.current.identifier]) }
    func markNotificationsRead() async throws { let _: Bool = try await client.rpc("mark_notifications_read", body: [:] as [String: String]) }
    func registerDeviceToken(_ token: String) async throws {
        #if DEBUG
        let environment = "ios-sandbox"
        #else
        let environment = "ios"
        #endif
        let _: Bool = try await client.rpc("register_device_token", body: ["p_token": token, "p_environment": environment])
    }
    func deleteAccount() async throws {
        struct Result: Decodable { let deleted: Bool }
        let result: Result = try await client.invokeFunction("delete-account")
        guard result.deleted else { throw AppError.server }
        await client.signOut()
    }
}
