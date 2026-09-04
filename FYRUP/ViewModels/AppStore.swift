import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppStore {
    enum Route: Equatable { case loading, configuration, signedOut, profileSetup, sportsSetup, onboardingComplete, main }
    var route: Route = .loading
    var profile: Profile?
    var myActivity: Activity?
    var crew: [CrewMember] = []
    var friendRequests: [Profile] = []
    var notifications: [AppNotification] = []
    var notificationPreferences: NotificationPreferences = .standard
    var invitations: [SessionInvitation] = []
    var recentActivities: [Activity] = []
    var userSearchResults: [Profile] = []
    var goals: GoalSummary = .empty
    var isBusy = false
    var isRefreshing = false
    var errorMessage: String?
    var showsActivityComposer = false
    var selectedTab = 0
    var opensNotifications = false
    var suggestedDisplayName = ""
    private(set) var session: AuthSession?
    let repository: any AppRepository
    private let analytics: any AnalyticsTracking
    private var appleNonce: String?
    private var avatarCache: [String: UIImage] = [:]

    init(repository: any AppRepository, analytics: any AnalyticsTracking = DevelopmentAnalytics()) { self.repository = repository; self.analytics = analytics }

    static func make() -> AppStore {
        if ProcessInfo.processInfo.arguments.contains("--onboarding-demo") { return AppStore(repository: DemoRepository(startsWithoutProfile: true)) }
        if ProcessInfo.processInfo.arguments.contains("--demo") { return AppStore(repository: DemoRepository()) }
        guard let configuration = AppConfiguration.load() else { return AppStore(repository: DemoRepositoryPlaceholder()) }
        return AppStore(repository: LiveAppRepository(configuration: configuration))
    }

    func bootstrap() async {
        if repository is DemoRepositoryPlaceholder { route = .configuration; return }
        do {
            guard let restored = try await repository.restoreSession() else { route = .signedOut; return }
            session = restored
            try await loadProfileAndRoute()
        } catch { present(error); route = .signedOut }
    }

    func signIn(email: String, password: String) async {
        await perform { self.session = try await self.repository.signIn(email: email, password: password); try await self.loadProfileAndRoute() }
    }

    func signUp(email: String, password: String) async {
        await perform {
            if let session = try await self.repository.signUp(email: email, password: password) { self.session = session; self.route = .profileSetup }
            else { self.errorMessage = "Prüfe dein E-Mail-Postfach und bestätige deine Adresse." }
        }
    }

    func resetPassword(email: String) async { await perform { try await self.repository.resetPassword(email: email); self.errorMessage = "Wir haben dir einen Link zum Zurücksetzen gesendet." } }
    func logout() async { if let id = session?.userID { FeedCache.clear(userID: id) }; await repository.signOut(); session = nil; profile = nil; route = .signedOut }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce(); appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        await perform {
            guard case .success(let authorization) = result,
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8), let nonce = self.appleNonce else { throw AppError.authentication }
            let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !appleName.isEmpty { self.suggestedDisplayName = appleName }
            self.session = try await self.repository.signInWithApple(idToken: token, nonce: nonce)
            try await self.loadProfileAndRoute()
        }
    }

    func saveProfile(displayName: String, username: String, birthYear: Int? = nil, city: String? = nil, avatarJPEG: Data? = nil, sports: [SportKind]? = nil) async {
        guard let userID = session?.userID else { return }
        let normalized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else { errorMessage = "Der Username braucht 3–24 Buchstaben, Zahlen oder _."; return }
        var value = profile ?? Profile(id: userID, username: normalized, displayName: displayName, avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [], weeklyGoal: 4, activityVisibility: "friends")
        value.username = normalized
        value.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if birthYear != nil { value.birthYear = birthYear }
        if let city { value.city = city.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        if let sports { value.sports = sports }
        await perform {
            if let avatarJPEG {
                let path = try await self.repository.uploadAvatar(userID: userID, data: avatarJPEG)
                value.avatarPath = path
                if let image = UIImage(data: avatarJPEG) { self.avatarCache[path] = image }
            }
            try await self.repository.saveProfile(value)
            self.profile = value
            self.route = value.sports.isEmpty ? .sportsSetup : .onboardingComplete
        }
    }

    func avatarImage(path: String) async -> UIImage? {
        if let cached = avatarCache[path] { return cached }
        guard let data = try? await repository.avatarData(path: path), let image = UIImage(data: data) else { return nil }
        avatarCache[path] = image
        return image
    }

    func updateProfile(displayName: String, username: String, birthYear: Int?, city: String, bio: String, avatarJPEG: Data?) async {
        guard let userID = session?.userID, var value = profile else { return }
        let normalized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            errorMessage = "Der Username braucht 3–24 Buchstaben, Zahlen oder _."
            return
        }
        value.username = normalized
        value.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        value.birthYear = birthYear
        value.city = city.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        value.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        await perform {
            if let avatarJPEG {
                let path = try await self.repository.uploadAvatar(userID: userID, data: avatarJPEG)
                value.avatarPath = path
                if let image = UIImage(data: avatarJPEG) { self.avatarCache[path] = image }
            }
            try await self.repository.saveProfile(value)
            self.profile = value
        }
    }

    func finishOnboarding() async {
        route = .main
        await analytics.track(.onboardingCompleted)
        await refresh()
    }

    func refresh() async {
        guard let userID = session?.userID else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result = try await repository.today(userID: userID)
            myActivity = result.0; crew = result.1
            async let requests = repository.requests(); async let notes = repository.notifications(); async let invites = repository.invitations(); async let summary = repository.goalSummary(); async let recent = repository.recentActivities(userID: userID); async let preferences = repository.notificationPreferences()
            friendRequests = (try? await requests) ?? []; notifications = (try? await notes) ?? []; invitations = (try? await invites) ?? []; goals = (try? await summary) ?? .empty; recentActivities = (try? await recent) ?? []; notificationPreferences = (try? await preferences) ?? .standard
            FeedCache.save(userID: userID, activity: myActivity, crew: crew, goals: goals)
        } catch {
            if let cached = FeedCache.load(userID: userID) { myActivity = cached.0; crew = cached.1; goals = cached.2 }
            present(error)
        }
    }

    func start(sport: SportKind, subtype: String?, linked: UUID? = nil, plannedSessionID: UUID? = nil) async {
        guard let userID = session?.userID else { return }
        await perform { self.myActivity = try await self.repository.startActivity(userID: userID, sport: sport, subtype: subtype, linkedActivityID: linked, plannedSessionID: plannedSessionID); Haptics.impact(.heavy); await self.analytics.track(linked == nil ? .activityStarted : .joinLiveFriend); self.showsActivityComposer = false; await self.refresh() }
    }

    func finish(distanceMeters: Int?) async { guard let id = myActivity?.id else { return }; await perform { self.myActivity = try await self.repository.completeActivity(id: id, distanceMeters: distanceMeters); Haptics.success(); await self.analytics.track(.activityCompleted); await self.refresh() } }
    func cancelCurrent() async { guard let id = myActivity?.id else { return }; await perform { try await self.repository.cancelActivity(id: id); self.myActivity = nil; await self.refresh() } }
    func fyrup(_ member: CrewMember) async { await perform { try await self.repository.fyrup(member.id); Haptics.impact(.light); await self.analytics.track(.fyrupSent) } }
    func react(_ activity: Activity, reaction: ReactionKind?) async { await perform { try await self.repository.react(activityID: activity.id, reaction: reaction) } }

    func searchUsers(_ query: String) async {
        guard query.count >= 2 else { userSearchResults = []; return }
        do { userSearchResults = try await repository.searchUsers(query: query) } catch { present(error) }
    }

    func sendFriendRequest(to profile: Profile) async { await perform { try await self.repository.sendFriendRequest(to: profile.id); await self.analytics.track(.friendRequestSent); self.userSearchResults.removeAll { $0.id == profile.id } } }
    func answerRequest(from profile: Profile, accept: Bool) async { await perform { try await self.repository.answerFriendRequest(from: profile.id, accept: accept); if accept { await self.analytics.track(.friendRequestAccepted) }; await self.refresh() } }
    func removeFriend(_ profile: Profile) async { await perform { try await self.repository.removeFriend(profile.id); await self.refresh() } }
    func block(_ profile: Profile) async { await perform { try await self.repository.block(profile.id); await self.refresh() } }
    func deleteAccount() async { await perform { let userID = self.session?.userID; try await self.repository.deleteAccount(); if let userID { FeedCache.clear(userID: userID) }; self.route = .signedOut; self.session = nil; self.profile = nil } }

    func plan(sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, invitees: [UUID]) async {
        guard let userID = session?.userID else { return }
        await perform { try await self.repository.planSession(userID: userID, sport: sport, subtype: subtype, startsAt: startsAt, duration: duration, note: note, friendIDs: invitees); await self.analytics.track(.activityPlanned); self.showsActivityComposer = false; await self.refresh() }
    }
    func respond(to invitation: SessionInvitation, status: InvitationStatus) async { await perform { try await self.repository.respondToInvitation(sessionID: invitation.sessionID, status: status); if status == .accepted { await self.analytics.track(.inviteAccepted) }; await self.refresh() } }
    func cancelPlannedSession(_ id: UUID) async { await perform { try await self.repository.cancelPlannedSession(sessionID: id); await self.refresh() } }
    func joinPlannedSession(_ id: UUID) async { await perform { try await self.repository.joinPlannedSession(sessionID: id); Haptics.impact(.medium); await self.refresh() } }
    func markNotificationsRead() async { try? await repository.markNotificationsRead(); notifications = notifications.map { var item = $0; item.readAt = item.readAt ?? Date(); return item } }
    func saveNotificationPreferences(_ preferences: NotificationPreferences) async {
        await perform { self.notificationPreferences = try await self.repository.saveNotificationPreferences(preferences) }
    }

    func handleNotificationTap(type: String?) async {
        guard route == .main else { return }
        if type == "friend_request" || type == "friend_accepted" { selectedTab = 2 }
        else { selectedTab = 0; opensNotifications = true }
        await refresh()
    }

    private func loadProfileAndRoute() async throws {
        guard let userID = session?.userID else { route = .signedOut; return }
        profile = try await repository.profile(userID: userID)
        if profile == nil { route = .profileSetup }
        else if profile?.sports.isEmpty == true { route = .sportsSetup }
        else { route = .main; await refresh() }
    }

    private func perform(_ operation: () async throws -> Void) async {
        isBusy = true; defer { isBusy = false }
        do { try await operation() } catch { present(error) }
    }

    private func present(_ error: Error) { errorMessage = (error as? LocalizedError)?.errorDescription ?? AppError.server.errorDescription }
    private static func sha256(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).compactMap { String(format: "%02x", $0) }.joined() }
    private static func randomNonce() -> String { String((0..<32).compactMap { _ in "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._".randomElement() }) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private actor DemoRepositoryPlaceholder: AppRepository {
    func restoreSession() async throws -> AuthSession? { nil }
    func signUp(email: String, password: String) async throws -> AuthSession? { nil }
    func signIn(email: String, password: String) async throws -> AuthSession { throw AppError.configuration }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { throw AppError.configuration }
    func resetPassword(email: String) async throws {} ; func signOut() async {}
    func profile(userID: UUID) async throws -> Profile? { nil }; func saveProfile(_ profile: Profile) async throws {}
    func uploadAvatar(userID: UUID, data: Data) async throws -> String { throw AppError.configuration }
    func avatarData(path: String) async throws -> Data { throw AppError.configuration }
    func today(userID: UUID) async throws -> (Activity?, [CrewMember]) { (nil, []) }
    func recentActivities(userID: UUID) async throws -> [Activity] { [] }
    func startActivity(userID: UUID, sport: SportKind, subtype: String?, linkedActivityID: UUID?, plannedSessionID: UUID?) async throws -> Activity { throw AppError.configuration }
    func completeActivity(id: UUID, distanceMeters: Int?) async throws -> Activity { throw AppError.configuration }
    func cancelActivity(id: UUID) async throws {}
    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, friendIDs: [UUID]) async throws {}
    func invitations() async throws -> [SessionInvitation] { [] }; func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws {}; func cancelPlannedSession(sessionID: UUID) async throws {}; func joinPlannedSession(sessionID: UUID) async throws {}
    func searchUsers(query: String) async throws -> [Profile] { [] }; func requests() async throws -> [Profile] { [] }
    func sendFriendRequest(to userID: UUID) async throws {}; func answerFriendRequest(from userID: UUID, accept: Bool) async throws {}
    func removeFriend(_ userID: UUID) async throws {}; func block(_ userID: UUID) async throws {}; func fyrup(_ userID: UUID) async throws {}
    func react(activityID: UUID, reaction: ReactionKind?) async throws {}; func notifications() async throws -> [AppNotification] { [] }
    func notificationPreferences() async throws -> NotificationPreferences { .standard }; func saveNotificationPreferences(_ preferences: NotificationPreferences) async throws -> NotificationPreferences { preferences }
    func goalSummary() async throws -> GoalSummary { .empty }; func markNotificationsRead() async throws {}
    func registerDeviceToken(_ token: String) async throws {}; func deleteAccount() async throws {}
}
