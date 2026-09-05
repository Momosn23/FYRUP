import Foundation

enum SportKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case gym, running, football, basketball, cycling, swimming, martialArts = "martial_arts", racket, yoga, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gym: "Gym"; case .running: "Laufen"; case .football: "Fußball"
        case .basketball: "Basketball"; case .cycling: "Fahrrad"; case .swimming: "Schwimmen"
        case .martialArts: "Kampfsport"; case .racket: "Tennis / Padel"; case .yoga: "Yoga"; case .other: "Andere"
        }
    }
    var symbol: String {
        switch self {
        case .gym: "dumbbell.fill"; case .running: "figure.run"; case .football: "soccerball"
        case .basketball: "basketball.fill"; case .cycling: "bicycle"; case .swimming: "figure.pool.swim"
        case .martialArts: "figure.martial.arts"; case .racket: "tennis.racket"; case .yoga: "figure.mind.and.body"; case .other: "figure.mixed.cardio"
        }
    }
    var supportsDistance: Bool { [.running, .cycling, .swimming].contains(self) }
}

enum ActivityStatus: String, Codable, Sendable { case planned, ready, live, completed, cancelled }
enum InvitationStatus: String, Codable, Sendable { case pending, accepted, maybe, declined }
enum FriendshipStatus: String, Codable, Sendable { case pending, accepted, declined }
enum ReactionKind: String, Codable, CaseIterable, Sendable { case fire = "🔥", strong = "💪", applause = "👏" }
enum TodayStatus: Int, Codable, Comparable, Sendable {
    case live = 0, planned = 1, done = 2, notYet = 3
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum GymBodyArea: String, CaseIterable, Identifiable, Sendable {
    case chest, back, shoulders, biceps, triceps, core, glutes, quads, hamstrings, calves
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chest: "Brust"
        case .back: "Rücken"
        case .shoulders: "Schultern"
        case .biceps: "Bizeps"
        case .triceps: "Trizeps"
        case .core: "Core"
        case .glutes: "Po"
        case .quads: "Quadrizeps"
        case .hamstrings: "Beinbeuger"
        case .calves: "Waden"
        }
    }
    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .shoulders: "figure.arms.open"
        case .biceps, .triceps: "dumbbell.fill"
        case .core: "figure.core.training"
        case .glutes: "figure.stairs"
        case .quads, .hamstrings: "figure.step.training"
        case .calves: "figure.walk.motion"
        }
    }
}

enum GymProgram: String, CaseIterable, Identifiable, Sendable {
    case push = "Push", pull = "Pull", legs = "Beine", fullBody = "Full Body"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .push: "Brust, Schultern, Trizeps"
        case .pull: "Rücken, Bizeps"
        case .legs: "Quadrizeps, Beinbeuger, Po, Waden"
        case .fullBody: "Alle großen Muskelgruppen"
        }
    }
    var symbol: String {
        switch self {
        case .push: "arrow.up.forward"
        case .pull: "arrow.down.backward"
        case .legs: "figure.step.training"
        case .fullBody: "figure.strengthtraining.traditional"
        }
    }
    var areas: [GymBodyArea] {
        switch self {
        case .push: [.chest, .shoulders, .triceps]
        case .pull: [.back, .biceps]
        case .legs: [.quads, .hamstrings, .glutes, .calves]
        case .fullBody: GymBodyArea.allCases
        }
    }
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var username: String
    var displayName: String
    var avatarPath: String?
    var birthYear: Int?
    var city: String?
    var bio: String?
    var sports: [SportKind]
    var weeklyGoal: Int
    var activityVisibility: String
    var gymFocus: [String]? = nil
    var onboardingStep: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, username, city, bio, sports
        case displayName = "display_name", avatarPath = "avatar_path", birthYear = "birth_year"
        case weeklyGoal = "weekly_goal", activityVisibility = "activity_visibility"
        case gymFocus = "gym_focus", onboardingStep = "onboarding_step"
    }
}

struct Activity: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    var sport: SportKind
    var subtype: String?
    var status: ActivityStatus
    var plannedAt: Date?
    var startedAt: Date?
    var endedAt: Date?
    var distanceMeters: Int?
    var plannedDurationMinutes: Int?
    var note: String?
    var plannedSessionID: UUID?
    var workoutPlanID: UUID? = nil
    var blindWorkoutID: UUID? = nil
    var exerciseCount: Int? = nil
    var pausedAt: Date? = nil
    var pausedSeconds: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id, sport, subtype, status, note
        case userID = "user_id", plannedAt = "planned_at", startedAt = "started_at", endedAt = "ended_at"
        case distanceMeters = "distance_meters", plannedDurationMinutes = "planned_duration_minutes", plannedSessionID = "planned_session_id"
        case workoutPlanID = "workout_plan_id", exerciseCount = "exercise_count"
        case blindWorkoutID = "blind_workout_id"
        case pausedAt = "paused_at", pausedSeconds = "paused_seconds"
    }

    var duration: TimeInterval? {
        duration(at: Date())
    }

    func duration(at date: Date) -> TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, (endedAt ?? pausedAt ?? date).timeIntervalSince(startedAt) - Double(pausedSeconds ?? 0))
    }
}

struct CrewMember: Codable, Identifiable, Hashable, Sendable {
    let profile: Profile
    let activity: Activity?
    let weeklyCount: Int
    var id: UUID { profile.id }
    var todayStatus: TodayStatus {
        switch activity?.status {
        case .live: .live
        case .planned, .ready: .planned
        case .completed: .done
        default: .notYet
        }
    }
}

struct PlannedSession: Codable, Identifiable, Sendable {
    let id: UUID
    let hostID: UUID
    var sport: SportKind
    var subtype: String?
    var startsAt: Date
    var durationMinutes: Int?
    var note: String?
    var placeName: String?
    var friendsCanJoin: Bool
    var status: String
    var workoutPlanID: UUID? = nil
    var exerciseCount: Int? = nil
    enum CodingKeys: String, CodingKey {
        case id, sport, subtype, note, status
        case hostID = "host_id", startsAt = "starts_at", durationMinutes = "duration_minutes"
        case placeName = "place_name", friendsCanJoin = "friends_can_join"
        case workoutPlanID = "workout_plan_id", exerciseCount = "exercise_count"
    }
}

struct SessionParticipant: Codable, Identifiable, Sendable {
    let profile: Profile
    let status: InvitationStatus
    var id: UUID { profile.id }
}

struct HostedSession: Codable, Identifiable, Sendable {
    var session: PlannedSession
    let participants: [SessionParticipant]
    var id: UUID { session.id }
}

struct TrainingGroup: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerID: UUID
    var name: String
    let members: [Profile]
    var memberCount: Int { members.count }
    enum CodingKeys: String, CodingKey {
        case id, name, members
        case ownerID = "owner_id"
    }
}

struct SessionInvitation: Codable, Identifiable, Sendable {
    let sessionID: UUID
    let status: InvitationStatus
    let session: PlannedSession
    let host: Profile
    var id: UUID { sessionID }
    enum CodingKeys: String, CodingKey { case status, session, host; case sessionID = "session_id" }
}

struct AppNotification: Codable, Identifiable, Sendable {
    let id: UUID
    let type: String
    let title: String
    let body: String
    let data: [String: String]?
    let createdAt: Date
    var readAt: Date?
    enum CodingKeys: String, CodingKey { case id, type, title, body, data; case createdAt = "created_at", readAt = "read_at" }
}

struct NotificationPreferences: Codable, Equatable, Sendable {
    var friendStarts: Bool
    var fyrup: Bool
    var invitations: Bool
    var reactions: Bool
    var friendRequests: Bool
    var reminders: Bool
    var weeklyGoal: Bool
    var crewGoal: Bool

    enum CodingKeys: String, CodingKey {
        case fyrup, invitations, reactions, reminders
        case friendStarts = "friend_starts", friendRequests = "friend_requests"
        case weeklyGoal = "weekly_goal", crewGoal = "crew_goal"
    }

    static let standard = NotificationPreferences(
        friendStarts: false, fyrup: true, invitations: true, reactions: true,
        friendRequests: true, reminders: true, weeklyGoal: true, crewGoal: true
    )
}

struct GoalSummary: Codable, Sendable {
    let weeklyCount: Int
    let weeklyGoal: Int
    let streak: Int
    let monthCount: Int
    let crewCount: Int
    let crewTarget: Int
    enum CodingKeys: String, CodingKey { case weeklyCount = "weekly_count", weeklyGoal = "weekly_goal", streak, monthCount = "month_count", crewCount = "crew_count", crewTarget = "crew_target" }
    static let empty = GoalSummary(weeklyCount: 0, weeklyGoal: 4, streak: 0, monthCount: 0, crewCount: 0, crewTarget: 4)
}

struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: UUID
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresAt = "expires_at", userID = "user_id" }
}

enum SportCatalog {
    static let subtypes: [SportKind: [String]] = [
        .gym: ["Push", "Pull", "Legs", "Upper Body", "Lower Body", "Full Body", "Chest", "Back", "Arms", "Shoulders", "Cardio", "Freies Training"],
        .running: ["Easy Run", "Recovery Run", "Tempo Run", "Intervalle", "Long Run", "Frei"],
        .football: ["Mannschaftstraining", "Spiel", "Freizeit / Bolzplatz", "Einzeltraining"],
        .basketball: ["Training", "Spiel", "Freizeit", "Shooting", "Einzeltraining"],
        .cycling: ["Road", "Gravel", "MTB", "Indoor", "Locker", "Intervalle"],
        .swimming: ["Locker", "Technik", "Ausdauer", "Intervalle", "Freies Schwimmen"],
        .martialArts: ["Boxen · Technik", "Boxen · Sparring", "Kickboxen", "Muay Thai", "MMA", "BJJ · Open Mat", "Wrestling", "Judo", "Karate", "Taekwondo"],
        .racket: ["Tennis · Training", "Tennis · Match", "Padel · Training", "Padel · Match", "Freies Spielen"],
        .yoga: ["Mobility", "Stretching", "Yoga", "Recovery"]
    ]
}
