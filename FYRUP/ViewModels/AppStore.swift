import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppStore {
    enum Route: Equatable { case loading, configuration, signedOut, profileSetup, sportsSetup, gymSetup, weeklyGoalSetup, routineSetup, friendsSetup, onboardingComplete, main }
    var route: Route = .loading {
        didSet { notificationRouting.setMainReady(route == .main && session?.userID != nil && profile?.id == session?.userID) }
    }
    var profile: Profile?
    var myActivity: Activity?
    var crew: [CrewMember] = []
    private(set) var revokedFriendIDs = Set<UUID>()
    private(set) var friendAccessRevision = 0
    private var feedRequestID: UUID?
    var friendRequests: [Profile] = []
    var notifications: [AppNotification] = []
    var notificationPreferences: NotificationPreferences? { notificationSettings.confirmedValue }
    var invitations: [SessionInvitation] = []
    var hostedSessions: [HostedSession] = []
    var trainingGroups: [TrainingGroup] = []
    var recentActivities: [Activity] = []
    var userSearchResults: [Profile] = []
    var goals: GoalSummary = .empty
    var isBusy = false
    var isRefreshing = false
    var errorMessage: String?
    var showsActivityComposer = false
    var activityComposerMode = 0
    var selectedTab = 0
    var opensNotifications = false
    var suggestedDisplayName = ""
    private(set) var session: AuthSession? {
        didSet {
            accountGeneration = UUID(); isRefreshing = false
            notificationSettings.activate(userID: session?.userID)
            trackingDrafts.activate(userID: session?.userID)
            personal.activate(userID: session?.userID)
            notificationRouting.accountChanged(to: session?.userID)
        }
    }
    private var accountGeneration = UUID()
    let repository: any AppRepository
    let workouts: WorkoutStore
    let workoutDrafts: WorkoutDraftStore
    let trackingDrafts: WorkoutTrackingDraftStore
    let personal: PersonalTrainingStore
    let steps: StepStore
    let weekly: WeeklyFlameStore
    let blind: BlindWorkoutStore
    let shot: CallMyShotStore
    let notificationSettings: NotificationPreferenceStore
    let notificationRouting: NotificationRoutingStore
    private let analytics: any AnalyticsTracking
    private var appleNonce: String?
    private var avatarCache: [String: UIImage] = [:]

    init(repository: any AppRepository, analytics: any AnalyticsTracking = DevelopmentAnalytics(), workoutDrafts: WorkoutDraftStore? = nil, steps: StepStore? = nil, weekly: WeeklyFlameStore? = nil, workoutCopies: WorkoutCopyRequestStore? = nil, trackingDrafts: WorkoutTrackingDraftStore? = nil) {
        self.repository = repository; self.analytics = analytics
        self.workouts = WorkoutStore(repository: repository, copyRequests: workoutCopies ?? WorkoutCopyRequestStore(defaults: .standard))
        self.workoutDrafts = workoutDrafts ?? WorkoutDraftStore()
        self.trackingDrafts = trackingDrafts ?? WorkoutTrackingDraftStore()
        self.personal = PersonalTrainingStore(repository: repository)
        self.steps = steps ?? StepStore(repository: repository)
        self.weekly = weekly ?? WeeklyFlameStore(repository: repository)
        self.blind = BlindWorkoutStore(repository: repository)
        self.shot = CallMyShotStore(repository: repository, weekly: self.weekly)
        self.notificationRouting = NotificationRoutingStore(repository: repository)
        self.notificationSettings = NotificationPreferenceStore(
            read: { try await repository.notificationPreferences() },
            write: { try await repository.saveNotificationPreferences($0, expected: $1) }
        )
    }

    static func make() -> AppStore {
        if ProcessInfo.processInfo.arguments.contains("--onboarding-demo") { return AppStore(repository: DemoRepository(startsWithoutProfile: true)) }
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            let arguments = ProcessInfo.processInfo.arguments
            let testPrefix = "--workout-persistence="
            let testID = arguments.first(where: { $0.hasPrefix(testPrefix) }).map { String($0.dropFirst(testPrefix.count)) }
            let suite = testID.flatMap(UUID.init(uuidString:)).map { "app.fyrup.uitest.workouts.\($0.uuidString)" }
                ?? (arguments.contains("--persistent-demo") ? "app.fyrup.demo.workouts" : nil)
            let localDefaults = UserDefaults(suiteName: suite ?? "app.fyrup.demo.drafts.\(UUID().uuidString)") ?? .standard
            let drafts = WorkoutDraftStore(defaults: localDefaults)
            let demoUser = arguments.first(where: { $0.hasPrefix("--demo-user=") }).flatMap { UUID(uuidString: String($0.dropFirst("--demo-user=".count))) } ?? DemoRepository.defaultUserID
            let repository = DemoRepository(includesSocialFixtures: arguments.contains("--social-fixtures"), userID: demoUser, workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite), weeklyStorage: DemoWeeklyFlameStorage(persistenceSuiteName: suite), blindStorage: DemoBlindWorkoutStorage(persistenceSuiteName: suite))
            let steps = arguments.contains("--steps-demo")
                ? StepStore(repository: repository, reader: StepPreviewReader(), defaults: localDefaults)
                : StepStore(repository: repository, defaults: localDefaults)
            return AppStore(repository: repository, workoutDrafts: drafts, steps: steps, weekly: WeeklyFlameStore(repository: repository, defaults: localDefaults), workoutCopies: WorkoutCopyRequestStore(defaults: localDefaults), trackingDrafts: WorkoutTrackingDraftStore(defaults: localDefaults))
        }
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
    func logout() async {
        guard !isBusy else { return }
        isBusy = true
        if let id = session?.userID { FeedCache.clear(userID: id) }
        workouts.activate(userID: nil)
        workoutDrafts.clearCurrentAccount()
        trackingDrafts.clearCurrentAccount()
        steps.reset()
        weekly.reset()
        blind.reset()
        shot.reset()
        session = nil; profile = nil; myActivity = nil; crew = []; recentActivities = []
        invitations = []; hostedSessions = []; notifications = []; trainingGroups = []; avatarCache = [:]
        goals = .empty; friendRequests = []; userSearchResults = []; errorMessage = nil
        revokedFriendIDs = []; friendAccessRevision += 1; feedRequestID = nil
        route = .loading
        await repository.signOut()
        isBusy = false
        route = .signedOut
    }

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
        var value = profile ?? Profile(id: userID, username: normalized, displayName: displayName, avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [], weeklyGoal: 4, activityVisibility: "friends", onboardingStep: "sports")
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

    func saveOnboardingSports(_ sports: [SportKind]) async {
        await saveProfile(
            displayName: profile?.displayName ?? suggestedDisplayName,
            username: profile?.username ?? "",
            birthYear: profile?.birthYear,
            city: profile?.city,
            sports: sports
        )
        guard errorMessage == nil else { return }
        await saveOnboardingStep(sports.contains(.gym) ? "gym" : "weekly_goal")
    }

    func saveOnboardingStep(_ step: String, gymFocus: [String]? = nil) async {
        await perform {
            self.profile = try await self.repository.saveOnboardingState(step: step, gymFocus: gymFocus)
            self.route = self.onboardingRoute(step)
        }
    }

    func confirmOnboardingGoal(_ goal: Int) async {
        guard let userID = session?.userID else { return }
        await weekly.activate(userID: userID)
        guard await weekly.confirmGoal(goal), session?.userID == userID else { return }
        route = .routineSetup
    }

    private func onboardingRoute(_ step: String?) -> Route {
        switch step {
        case "sports": .sportsSetup
        case "gym": .gymSetup
        case "weekly_goal": weekly.state?.goalConfirmed == true ? .routineSetup : .weeklyGoalSetup
        case "friends": .friendsSetup
        case "complete": .onboardingComplete
        default: .main
        }
    }

    func avatarImage(path: String) async -> UIImage? {
        if let cached = avatarCache[path] { return cached }
        guard let data = try? await repository.avatarData(path: path), let image = UIImage(data: data) else { return nil }
        avatarCache[path] = image
        return image
    }

    func updateProfile(displayName: String, username: String, birthYear: Int?, city: String, bio: String, sports: [SportKind], avatarJPEG: Data?) async {
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
        value.sports = sports
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
        guard let userID = session?.userID else { return }
        await weekly.activate(userID: userID)
        guard weekly.needsGoalConfirmation == false else { route = .weeklyGoalSetup; return }
        await saveOnboardingStep("done")
        guard errorMessage == nil, session?.userID == userID else { return }
        workouts.activate(userID: session?.userID)
        blind.activate(userID: session?.userID)
        shot.activate(userID: session?.userID)
        workoutDrafts.activate(userID: session?.userID)
        route = .main
        await analytics.track(.onboardingCompleted)
        await refresh()
    }

    func refresh() async {
        guard let userID = session?.userID, !isRefreshing else { return }
        let generation = accountGeneration
        let accessRevision = friendAccessRevision
        let requestID = UUID()
        feedRequestID = requestID
        isRefreshing = true
        defer { if generation == accountGeneration, feedRequestID == requestID { isRefreshing = false; feedRequestID = nil } }
        do {
            let result = try await repository.today(userID: userID)
            guard generation == accountGeneration, session?.userID == userID, accessRevision == friendAccessRevision else { return }
            async let requests = repository.requests(); async let notes = repository.notifications(); async let invites = repository.invitations(); async let hosted = repository.hostedSessions(); async let groups = repository.trainingGroups(); async let summary = repository.goalSummary(); async let recent = repository.recentActivities(userID: userID)
            async let preferenceRefresh: Void = notificationSettings.refresh()
            let loadedRequests = (try? await requests) ?? []
            let loadedNotifications = (try? await notes) ?? []
            let loadedInvitations = (try? await invites) ?? []
            let loadedHosted = (try? await hosted) ?? []
            let loadedGroups = (try? await groups) ?? []
            let loadedSummary = (try? await summary) ?? .empty
            let loadedRecent = (try? await recent) ?? []
            await preferenceRefresh
            guard generation == accountGeneration, session?.userID == userID, accessRevision == friendAccessRevision else { return }
            let currentFriends = Set(result.1.map(\.id))
            for removed in Set(crew.map(\.id)).subtracting(currentFriends) { revokeFriendAccess(userID: removed) }
            // Only a new, fully confirmed server read may restore access after re-acceptance.
            for restored in revokedFriendIDs.intersection(currentFriends) {
                revokedFriendIDs.remove(restored)
                steps.restoreFriend(userID: restored)
                workouts.restoreFriend(userID: restored)
                friendAccessRevision += 1
            }
            myActivity = result.0; crew = result.1
            friendRequests = loadedRequests.filter { !revokedFriendIDs.contains($0.id) }
            notifications = loadedNotifications
            invitations = loadedInvitations.filter { !revokedFriendIDs.contains($0.host.id) }
            hostedSessions = loadedHosted.map { HostedSession(session: $0.session, participants: $0.participants.filter { !revokedFriendIDs.contains($0.id) }) }
            trainingGroups = loadedGroups.filter { !revokedFriendIDs.contains($0.ownerID) }.map { group in
                TrainingGroup(id: group.id, ownerID: group.ownerID, name: group.name, members: group.members.filter { !revokedFriendIDs.contains($0.id) })
            }
            goals = loadedSummary
            recentActivities = loadedRecent
            FeedCache.save(userID: userID, activity: myActivity, crew: crew, goals: goals)
        } catch {
            guard generation == accountGeneration, session?.userID == userID, accessRevision == friendAccessRevision else { return }
            if let cached = FeedCache.load(userID: userID) { myActivity = cached.0; crew = cached.1.filter { !revokedFriendIDs.contains($0.id) }; goals = cached.2 }
            present(error)
        }
    }

    func start(sport: SportKind, subtype: String?, linked: UUID? = nil, plannedSessionID: UUID? = nil, workoutPlanID: UUID? = nil) async {
        guard let userID = session?.userID else { return }
        let linkedPlan = crew.first(where: { $0.activity?.id == linked && linked != nil })?.activity?.workoutPlanID
        let sessionPlan = hostedSessions.first(where: { $0.id == plannedSessionID })?.session.workoutPlanID
            ?? invitations.first(where: { $0.id == plannedSessionID })?.session.workoutPlanID
        let planID = workoutPlanID ?? linkedPlan ?? sessionPlan
        await perform {
            let started: Activity
            if let planID {
                started = try await self.repository.startWorkout(planID: planID, linkedActivityID: linked, sessionID: plannedSessionID)
            } else {
                started = try await self.repository.startActivity(userID: userID, sport: sport, subtype: subtype, linkedActivityID: linked, plannedSessionID: plannedSessionID)
            }
            guard self.session?.userID == userID else { return }
            self.myActivity = started
            Haptics.impact(.heavy)
            await self.analytics.track(linked == nil ? .activityStarted : .joinLiveFriend)
            self.showsActivityComposer = false
            await self.refresh()
        }
    }

    @discardableResult
    func finish(distanceMeters: Int?) async -> Activity? {
        guard let id = myActivity?.id, let userID = session?.userID else { return nil }
        var completed: Activity?
        let wasBelowWeeklyGoal = goals.weeklyCount < goals.weeklyGoal
        await perform {
            let result = try await self.repository.completeActivity(id: id, distanceMeters: distanceMeters)
            guard self.session?.userID == userID, result.id == id, result.status == .completed else { return }
            completed = result
            self.myActivity = result
            Haptics.success()
            await self.analytics.track(.activityCompleted)
            await self.refresh()
            await self.weekly.refresh(force: true)
            if wasBelowWeeklyGoal && self.goals.weeklyCount >= self.goals.weeklyGoal { await self.analytics.track(.weeklyGoalCompleted) }
        }
        return completed
    }
    func setPaused(_ paused: Bool) async {
        guard let activity = myActivity, activity.status == .live, let userID = session?.userID else { return }
        await perform {
            let updated = try await self.repository.setActivityPaused(id: activity.id, paused: paused)
            guard self.session?.userID == userID && self.myActivity?.id == activity.id else { return }
            self.myActivity = updated
            Haptics.impact(.light)
        }
    }
    func cancelCurrent() async { guard let id = myActivity?.id else { return }; await perform { try await self.repository.cancelActivity(id: id); self.myActivity = nil; await self.refresh() } }
    func fyrup(_ member: CrewMember) async { await perform { try await self.repository.fyrup(member.id); Haptics.impact(.light); await self.analytics.track(.fyrupSent) } }
    func react(_ activity: Activity, reaction: ReactionKind?) async { await perform { try await self.repository.react(activityID: activity.id, reaction: reaction) } }

    func searchUsers(_ query: String) async {
        guard query.count >= 2 else { userSearchResults = []; return }
        do { userSearchResults = try await repository.searchUsers(query: query) } catch { present(error) }
    }

    func sendFriendRequest(to profile: Profile) async { await perform { try await self.repository.sendFriendRequest(to: profile.id); await self.analytics.track(.friendRequestSent); self.userSearchResults.removeAll { $0.id == profile.id } } }
    func answerRequest(from profile: Profile, accept: Bool) async { await perform { try await self.repository.answerFriendRequest(from: profile.id, accept: accept); if accept { await self.analytics.track(.friendRequestAccepted) }; await self.refresh() } }
    func removeFriend(_ profile: Profile) async { await endFriendAccess(profile, block: false) }
    func block(_ profile: Profile) async { await endFriendAccess(profile, block: true) }

    private func endFriendAccess(_ profile: Profile, block: Bool) async {
        guard let ownerID = session?.userID else { return }
        let generation = accountGeneration
        await perform {
            if block { try await self.repository.block(profile.id) }
            else { try await self.repository.removeFriend(profile.id) }
            guard self.accountGeneration == generation, self.session?.userID == ownerID else { return }
            self.revokeFriendAccess(userID: profile.id)
            // Retire any feed request which began before the confirmed revocation.
            self.feedRequestID = nil; self.isRefreshing = false
            await self.refresh()
        }
    }

    private func revokeFriendAccess(userID: UUID) {
        revokedFriendIDs.insert(userID); friendAccessRevision += 1
        personal.invalidateWeekAccess()
        notificationRouting.revokeSocialDestinations()
        crew.removeAll { $0.id == userID }
        friendRequests.removeAll { $0.id == userID }
        userSearchResults.removeAll { $0.id == userID }
        invitations.removeAll { $0.host.id == userID }
        trainingGroups = trainingGroups.filter { $0.ownerID != userID }.map { group in
            TrainingGroup(id: group.id, ownerID: group.ownerID, name: group.name, members: group.members.filter { $0.id != userID })
        }
        hostedSessions = hostedSessions.map { HostedSession(session: $0.session, participants: $0.participants.filter { $0.id != userID }) }
        shot.removeFriend(userID: userID); blind.removeFriend(userID: userID)
        steps.removeFriend(userID: userID); workouts.removeFriend(userID: userID)
        avatarCache = [:]
        if let ownerID = session?.userID { FeedCache.clear(userID: ownerID) }
    }
    func deleteAccount() async {
        await perform {
            let userID = self.session?.userID
            try await self.repository.deleteAccount()
            if let userID { FeedCache.clear(userID: userID) }
            if let userID { self.workouts.clearCopyRequests(userID: userID) }
            self.workouts.activate(userID: nil)
            self.workoutDrafts.clearCurrentAccount()
            self.trackingDrafts.clearCurrentAccount()
            self.steps.reset(clearLocalPreferences: true)
            self.weekly.reset(clearLocalPreferences: true)
            self.blind.reset()
            self.shot.reset()
            self.route = .signedOut; self.session = nil; self.profile = nil; self.myActivity = nil
            self.crew = []; self.recentActivities = []; self.invitations = []; self.hostedSessions = []
            self.notifications = []; self.trainingGroups = []; self.avatarCache = [:]
            self.goals = .empty; self.friendRequests = []; self.userSearchResults = []
            self.revokedFriendIDs = []; self.friendAccessRevision += 1; self.feedRequestID = nil
        }
    }

    func plan(sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, placeName: String?, friendsCanJoin: Bool, invitees: [UUID], workoutPlanID: UUID? = nil) async {
        guard let userID = session?.userID else { return }
        await perform {
            if let workoutPlanID {
                try await self.repository.planWorkout(planID: workoutPlanID, startsAt: startsAt, duration: duration ?? 60, note: note, placeName: placeName, friendsCanJoin: friendsCanJoin, friendIDs: invitees)
            } else {
                try await self.repository.planSession(userID: userID, sport: sport, subtype: subtype, startsAt: startsAt, duration: duration, note: note, placeName: placeName, friendsCanJoin: friendsCanJoin, friendIDs: invitees)
            }
            guard self.session?.userID == userID else { return }
            await self.analytics.track(.activityPlanned)
            if !invitees.isEmpty { await self.analytics.track(.inviteSent) }
            self.showsActivityComposer = false
            await self.refresh()
        }
    }
    func createTrainingGroup(name: String, memberIDs: [UUID]) async {
        await perform { try await self.repository.createTrainingGroup(name: name, memberIDs: memberIDs); await self.refresh() }
    }
    func deleteTrainingGroup(_ group: TrainingGroup) async {
        await perform { try await self.repository.deleteTrainingGroup(id: group.id); await self.refresh() }
    }
    func updateHostedSession(_ session: PlannedSession) async {
        await perform { _ = try await self.repository.updateHostedSession(session); await self.refresh() }
    }
    func respond(to invitation: SessionInvitation, status: InvitationStatus) async { await perform { try await self.repository.respondToInvitation(sessionID: invitation.sessionID, status: status); if status == .accepted { await self.analytics.track(.inviteAccepted) }; await self.refresh() } }
    func cancelPlannedSession(_ id: UUID) async { await perform { try await self.repository.cancelPlannedSession(sessionID: id); await self.refresh() } }
    func joinPlannedSession(_ id: UUID) async { await perform { try await self.repository.joinPlannedSession(sessionID: id); Haptics.impact(.medium); await self.refresh() } }
    func markNotificationsRead() async {
        guard session != nil else { return }
        let generation = accountGeneration
        do {
            try await repository.markNotificationsRead()
            guard generation == accountGeneration else { return }
            notifications = notifications.map { var item = $0; item.readAt = item.readAt ?? Date(); return item }
        } catch { if generation == accountGeneration { present(error) } }
    }
    @discardableResult
    func saveNotificationPreferences(_ preferences: NotificationPreferences, expected: NotificationPreferences) async -> Bool {
        await notificationSettings.save(preferences, expected: expected)
    }

    func handleNotificationTap(_ payload: NotificationTapPayload) async {
        notificationRouting.setMainReady(route == .main && session?.userID != nil && profile?.id == session?.userID)
        let generation = accountGeneration
        if route == .main, payload.recipientID == nil || payload.recipientID == session?.userID {
            showsActivityComposer = false; weekly.dismissCelebration()
        }
        await notificationRouting.receive(payload)
        guard generation == accountGeneration else { return }
        if notificationRouting.presentation != nil { selectedTab = 0 }
        if let message = notificationRouting.errorMessage { errorMessage = message }
    }

    func handleNotificationTap(notification: AppNotification) async {
        guard let owner = session?.userID, let payload = NotificationTapPayload(notification: notification, recipientID: owner) else { return }
        await handleNotificationTap(payload)
    }

    func deliverPendingNotification() async {
        notificationRouting.setMainReady(route == .main && session?.userID != nil && profile?.id == session?.userID)
        let generation = accountGeneration
        await notificationRouting.deliverPending()
        guard generation == accountGeneration else { return }
        if notificationRouting.presentation != nil { selectedTab = 0 }
        if let message = notificationRouting.errorMessage { errorMessage = message }
    }

    private func loadProfileAndRoute() async throws {
        guard let userID = session?.userID else { route = .signedOut; return }
        workouts.activate(userID: userID)
        blind.activate(userID: userID)
        shot.activate(userID: userID)
        workoutDrafts.activate(userID: userID)
        profile = try await repository.profile(userID: userID)
        guard session?.userID == userID else { return }
        if profile == nil { route = .profileSetup }
        else if profile?.sports.isEmpty == true { route = .sportsSetup }
        else {
            await weekly.activate(userID: userID)
            guard session?.userID == userID else { return }
            route = onboardingRoute(profile?.onboardingStep)
            if route == .main { await refresh() }
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        errorMessage = nil
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
    func blindWorkouts() async throws -> [BlindWorkoutSummary] { throw AppError.configuration }
    func callMyShot(expectedWeekID: UUID) async throws -> WeeklyCommitment { throw AppError.configuration }
    func setShotReaction(commitmentID: UUID, reaction: ShotReaction?) async throws -> Bool { throw AppError.configuration }
    func blindWorkout(id: UUID) async throws -> BlindWorkoutState { throw AppError.configuration }
    func sendBlindWorkout(_ draft: BlindWorkoutDraft) async throws -> BlindWorkoutState { throw AppError.configuration }
    func respondToBlindWorkout(id: UUID, accept: Bool, equipmentConfirmed: Bool) async throws -> BlindWorkoutState { throw AppError.configuration }
    func planBlindWorkout(id: UUID, startsAt: Date) async throws -> BlindWorkoutState { throw AppError.configuration }
    func startBlindWorkout(id: UUID) async throws -> BlindWorkoutState { throw AppError.configuration }
    func saveBlindWorkoutExercise(id: UUID, exerciseID: UUID, sets: [WorkoutSetLog], complete: Bool) async throws -> BlindWorkoutState { throw AppError.configuration }
    func finishBlindWorkout(id: UUID) async throws -> BlindWorkoutState { throw AppError.configuration }
    func cancelBlindWorkout(id: UUID) async throws -> BlindWorkoutState { throw AppError.configuration }
    func copyBlindWorkout(id: UUID) async throws -> WorkoutPlan { throw AppError.configuration }
    func reactToBlindWorkout(id: UUID, reaction: ReactionKind?) async throws -> BlindWorkoutState { throw AppError.configuration }
    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState { throw AppError.configuration }
    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState { throw AppError.configuration }
    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState { throw AppError.configuration }
    func friendsWeeklyState() async throws -> [WeeklyFlameState] { throw AppError.configuration }
    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool { throw AppError.configuration }
    func claimFlameCelebration(weekID: UUID) async throws -> Bool { throw AppError.configuration }
    func saveOnboardingState(step: String, gymFocus: [String]?) async throws -> Profile { throw AppError.configuration }
    func stepSharingPreference(userID: UUID) async throws -> StepSharingPreference { throw AppError.configuration }
    func setStepSharing(userID: UUID, enabled: Bool) async throws -> StepSharingPreference { throw AppError.configuration }
    func syncSteps(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) async throws -> Bool { throw AppError.configuration }
    func sharedSteps() async throws -> [DailyStepMetric] { throw AppError.configuration }
    func setActivityPaused(id: UUID, paused: Bool) async throws -> Activity { throw AppError.configuration }
    func exercises() async throws -> [GymExercise] { throw AppError.configuration }
    func saveExercise(_ exercise: GymExercise) async throws -> GymExercise { throw AppError.configuration }
    func archiveExercise(id: UUID) async throws { throw AppError.configuration }
    func favoriteExercise(id: UUID, favorite: Bool) async throws { throw AppError.configuration }
    func exerciseFavorites() async throws -> [UUID] { throw AppError.configuration }
    func workoutPlans(ownerID: UUID?) async throws -> [WorkoutPlan] { throw AppError.configuration }
    func workoutPlan(id: UUID) async throws -> WorkoutPlan { throw AppError.configuration }
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws -> WorkoutPlan { throw AppError.configuration }
    func archiveWorkoutPlan(id: UUID) async throws { throw AppError.configuration }
    func copyWorkoutPlan(id: UUID, requestID: UUID) async throws -> WorkoutPlan { throw AppError.configuration }
    func shareWorkoutPlan(id: UUID, friendIDs: [UUID]) async throws { throw AppError.configuration }
    func startWorkout(planID: UUID, linkedActivityID: UUID?, sessionID: UUID?) async throws -> Activity { throw AppError.configuration }
    func planWorkout(planID: UUID, startsAt: Date, duration: Int, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws { throw AppError.configuration }
    func workoutLog(activityID: UUID) async throws -> WorkoutLog { throw AppError.configuration }
    func saveWorkoutLog(_ log: WorkoutLog) async throws -> WorkoutLog { throw AppError.configuration }
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
    func planSession(userID: UUID, sport: SportKind, subtype: String?, startsAt: Date, duration: Int?, note: String?, placeName: String?, friendsCanJoin: Bool, friendIDs: [UUID]) async throws {}
    func invitations() async throws -> [SessionInvitation] { [] }; func hostedSessions() async throws -> [HostedSession] { [] }
    func trainingGroups() async throws -> [TrainingGroup] { [] }; func createTrainingGroup(name: String, memberIDs: [UUID]) async throws {}; func deleteTrainingGroup(id: UUID) async throws {}
    func updateHostedSession(_ session: PlannedSession) async throws -> PlannedSession { session }; func respondToInvitation(sessionID: UUID, status: InvitationStatus) async throws {}; func cancelPlannedSession(sessionID: UUID) async throws {}; func joinPlannedSession(sessionID: UUID) async throws {}
    func searchUsers(query: String) async throws -> [Profile] { [] }; func requests() async throws -> [Profile] { [] }
    func sendFriendRequest(to userID: UUID) async throws {}; func answerFriendRequest(from userID: UUID, accept: Bool) async throws {}
    func removeFriend(_ userID: UUID) async throws {}; func block(_ userID: UUID) async throws {}; func fyrup(_ userID: UUID) async throws {}
    func react(activityID: UUID, reaction: ReactionKind?) async throws {}; func notifications() async throws -> [AppNotification] { [] }
    func notificationPreferences() async throws -> NotificationPreferences { .standard }; func saveNotificationPreferences(_ preferences: NotificationPreferences, expected: NotificationPreferences) async throws -> NotificationPreferences { throw AppError.configuration }
    func goalSummary() async throws -> GoalSummary { .empty }; func markNotificationsRead() async throws {}
    func registerDeviceToken(_ token: String) async throws {}; func deleteAccount() async throws {}
}
