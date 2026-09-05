import Foundation

/// Isolated demo backend, not a source of credits in a signed-in production session.
/// An explicit suite persists confirmed goals, immutable weekly periods and receipts.
actor DemoWeeklyFlameStorage {
    private struct Commitment: Codable {
        var id = UUID()
        var calledAt: Date
        var ownerName: String
        var audience: Set<UUID>
        var reactions: [UUID: ShotReaction] = [:]
        var reactionNotificationAuthors: Set<UUID> = []
    }

    private struct Week: Codable {
        var id = UUID()
        var label: String
        var timezone: String
        var startsAt: Date
        var endsAt: Date
        var goal: Int
        var goalConfirmed = false
        var credits: Set<UUID> = []
        var earnedAt: Date?
        var finalizedAt: Date?
        var celebrationClaimed = false
        var reactions: [UUID: ReactionKind] = [:]
        // Optional so already-persisted weekly state remains readable after this extension.
        var commitment: Commitment?
    }

    private struct Account: Codable {
        var suggestedGoal: Int
        var confirmedAt: Date?
        var timezone = "UTC"
        var nextTimezone: String?
        var nextGoal: Int?
        var weeks: [Week] = []
        var processedActivities: Set<UUID> = []
    }

    private struct State: Codable {
        var accounts: [UUID: Account] = [:]
        var revokedFriendships: Set<String> = []
        var notifications: [UUID: [AppNotification]]?
        var preferences: [UUID: NotificationPreferences]?
    }

    private var state: State
    private let defaults: UserDefaults?
    private let now: @Sendable () -> Date
    private var failedToLoad = false
    private let key = "fyrup.demo.weekly-flames.v1"

    init(persistenceSuiteName: String? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
        let defaults = persistenceSuiteName.flatMap { UserDefaults(suiteName: $0) }
        self.defaults = defaults
        if let data = defaults?.data(forKey: "fyrup.demo.weekly-flames.v1") {
            do { state = try JSONDecoder().decode(State.self, from: data) }
            catch { state = State(); failedToLoad = true }
        } else { state = State() }
    }

    private func checkLoaded() throws {
        if failedToLoad { throw AppError.conflict("Die gespeicherten Demo-Wochenziele konnten nicht geladen werden. Deine Daten wurden nicht überschrieben.") }
    }

    private func persist() throws {
        try checkLoaded()
        if let defaults { defaults.set(try JSONEncoder().encode(state), forKey: key) }
    }

    private func calendar(_ timezone: String) throws -> Calendar {
        guard let zone = TimeZone(identifier: timezone) else { throw AppError.validation("Diese Zeitzone ist nicht verfügbar.") }
        var value = Calendar(identifier: .gregorian)
        value.timeZone = zone; value.firstWeekday = 2; value.minimumDaysInFirstWeek = 4
        return value
    }

    private func firstWeek(goal: Int, timezone: String, receipt: Date) throws -> Week {
        let calendar = try calendar(timezone)
        guard let bounds = calendar.dateInterval(of: .weekOfYear, for: receipt) else { throw AppError.server }
        return Week(label: StepDay.key(for: bounds.start, calendar: calendar), timezone: timezone,
                    startsAt: bounds.start, endsAt: bounds.end, goal: goal)
    }

    private func nextWeek(after previous: Week, goal: Int, timezone: String) throws -> Week {
        let utc = try calendar("UTC")
        let components = previous.label.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3,
              let labelDate = utc.date(from: DateComponents(year: components[0], month: components[1], day: components[2])),
              let nextLabelDate = utc.date(byAdding: .day, value: 7, to: labelDate),
              let endLabelDate = utc.date(byAdding: .day, value: 14, to: labelDate) else { throw AppError.server }
        let targetCalendar = try calendar(timezone)
        let endComponents = utc.dateComponents([.year, .month, .day], from: endLabelDate)
        guard let end = targetCalendar.date(from: endComponents), end > previous.endsAt else { throw AppError.server }
        // Travel cannot reopen a credited week or create overlapping absolute periods.
        // The next local label advances exactly seven days, while its start stays contiguous.
        return Week(label: StepDay.key(for: nextLabelDate, calendar: utc), timezone: timezone,
                    startsAt: previous.endsAt, endsAt: end, goal: goal)
    }

    private func bootstrap(userID: UUID, suggestedGoal: Int, confirmedFixture: Bool, timezone: String?, receipt: Date) throws {
        guard state.accounts[userID] == nil else { return }
        var account = Account(suggestedGoal: WeeklyGoal.isValid(suggestedGoal) ? suggestedGoal : 4)
        let zone = timezone ?? "UTC"
        account.timezone = zone
        var week = try firstWeek(goal: account.suggestedGoal, timezone: zone, receipt: receipt)
        week.goalConfirmed = confirmedFixture
        if confirmedFixture { account.confirmedAt = receipt }
        account.weeks = [week]
        state.accounts[userID] = account
    }

    private func advance(userID: UUID, receipt: Date) throws {
        guard var account = state.accounts[userID] else { return }
        while let latest = account.weeks.last, receipt >= latest.endsAt {
            account.weeks[account.weeks.count - 1].finalizedAt = receipt
            let goal = account.nextGoal ?? latest.goal
            let zone = account.nextTimezone ?? account.timezone
            var next = try nextWeek(after: latest, goal: goal, timezone: zone)
            next.goalConfirmed = account.confirmedAt != nil
            account.weeks.append(next)
            account.suggestedGoal = goal; account.timezone = zone
            account.nextGoal = nil; account.nextTimezone = nil
        }
        state.accounts[userID] = account
    }

    private func friendshipKey(_ first: UUID, _ second: UUID) -> String {
        [first.uuidString, second.uuidString].sorted().joined(separator: ":")
    }

    private func canRead(owner: UUID, viewer: UUID, friends: Set<UUID>) -> Bool {
        owner == viewer || (friends.contains(owner) && !state.revokedFriendships.contains(friendshipKey(owner, viewer)))
    }

    private func progress(_ week: Week, owner: UUID, viewer: UUID) -> WeeklyProgress {
        let visibleReactions = week.reactions.filter { !state.revokedFriendships.contains(friendshipKey(owner, $0.key)) }
        let counts = ReactionKind.allCases.compactMap { reaction -> WeeklyFlameReactionCount? in
            let count = visibleReactions.values.filter { $0 == reaction }.count
            return count == 0 ? nil : WeeklyFlameReactionCount(reaction: reaction, count: count)
        }
        return WeeklyProgress(id: week.id, userID: owner, weekStartDate: week.label, timezone: week.timezone,
                              startsAt: week.startsAt, endsAt: week.endsAt, weeklyGoal: week.goal,
                              completedWorkouts: week.credits.count, flameEarned: week.earnedAt != nil,
                              flameEarnedAt: week.earnedAt, finalized: week.finalizedAt != nil, finalizedAt: week.finalizedAt,
                              reactionCounts: counts, myReaction: visibleReactions[viewer],
                              commitment: commitmentDocument(week, owner: owner, viewer: viewer))
    }

    private func commitmentDocument(_ week: Week, owner: UUID, viewer: UUID) -> WeeklyCommitment? {
        guard let commitment = week.commitment else { return nil }
        let visible = commitment.reactions.filter { !state.revokedFriendships.contains(friendshipKey(owner, $0.key)) }
        let counts = ShotReaction.allCases.compactMap { reaction -> ShotReactionCount? in
            let count = visible.values.filter { $0 == reaction }.count
            return count == 0 ? nil : ShotReactionCount(reaction: reaction, count: count)
        }
        // Success and finalization are projections of the same authoritative week;
        // they cannot diverge or be set by a separate client mutation.
        return WeeklyCommitment(id: commitment.id, userID: owner, weekID: week.id, weekStartDate: week.label,
                                weeklyGoal: week.goal, calledAt: commitment.calledAt, achieved: week.earnedAt != nil,
                                achievedAt: week.earnedAt, finalized: week.finalizedAt != nil,
                                reactionCounts: counts, myReaction: visible[viewer])
    }

    private func appendNotification(owner: UUID, recipient: UUID, actor: UUID, commitmentID: UUID,
                                    type: String, title: String, body: String, receipt: Date) {
        guard recipient != actor, !state.revokedFriendships.contains(friendshipKey(recipient, actor)) else { return }
        let preference = state.preferences?[recipient] ?? .standard
        guard (type == "shot_reaction" ? preference.reactions : preference.weeklyGoal),
              let weekID = state.accounts[owner]?.weeks.first(where: { $0.commitment?.id == commitmentID })?.id else { return }
        var notifications = state.notifications ?? [:]
        let exists = notifications[recipient, default: []].contains {
            $0.type == type && $0.data?["commitment_id"] == commitmentID.uuidString
                && (type != "shot_reaction" || $0.data?["actor_id"] == actor.uuidString)
        }
        guard !exists else { return }
        notifications[recipient, default: []].insert(AppNotification(
            id: UUID(), type: type, title: title, body: body,
            data: ["commitment_id": commitmentID.uuidString, "week_id": weekID.uuidString,
                   "user_id": owner.uuidString, "actor_id": actor.uuidString],
            createdAt: receipt, readAt: nil), at: 0)
        state.notifications = notifications
    }

    private func announceAchievement(_ week: Week, owner: UUID, receipt: Date) {
        guard let commitment = week.commitment else { return }
        for friend in commitment.audience {
            appendNotification(owner: owner, recipient: friend, actor: owner, commitmentID: commitment.id,
                               type: "shot_achieved", title: "CALLED IT ✓",
                               body: "\(commitment.ownerName) hat das angekündigte Wochenziel geschafft.", receipt: receipt)
        }
    }

    private func snapshot(owner: UUID, viewer: UUID, receipt: Date, includeHistory: Bool = true) throws -> WeeklyFlameState {
        guard let account = state.accounts[owner] else { throw AppError.server }
        let closed = account.weeks.filter { $0.finalizedAt != nil }.sorted { $0.startsAt < $1.startsAt }
        var current = 0; var best = 0
        for week in closed {
            current = week.earnedAt == nil ? 0 : current + 1
            best = max(best, current)
        }
        return WeeklyFlameState(userID: owner, serverNow: receipt,
                                currentWeek: account.weeks.last.flatMap { $0.finalizedAt == nil && $0.goalConfirmed ? progress($0, owner: owner, viewer: viewer) : nil },
                                suggestedWeeklyGoal: account.suggestedGoal, nextWeeklyGoal: owner == viewer ? account.nextGoal : nil,
                                nextTimezone: owner == viewer ? account.nextTimezone : nil, goalConfirmed: account.confirmedAt != nil,
                                currentStreak: current, bestStreak: best,
                                history: includeHistory ? closed.filter(\.goalConfirmed).reversed().prefix(52).map { progress($0, owner: owner, viewer: viewer) } : [])
    }

    func weeklyState(owner: UUID, viewer: UUID, friends: Set<UUID>, timezone: String?, suggestedGoal: Int, confirmedFixture: Bool, includeHistory: Bool = true) throws -> WeeklyFlameState {
        try checkLoaded()
        guard canRead(owner: owner, viewer: viewer, friends: friends) else { throw AppError.authentication }
        guard owner == viewer || timezone == nil else { throw AppError.authentication }
        if let timezone { _ = try calendar(timezone) }
        let receipt = now()
        try bootstrap(userID: owner, suggestedGoal: suggestedGoal, confirmedFixture: confirmedFixture, timezone: timezone, receipt: receipt)
        try advance(userID: owner, receipt: receipt)
        if owner == viewer, let timezone, var account = state.accounts[owner] {
            account.nextTimezone = timezone == account.timezone ? nil : timezone
            state.accounts[owner] = account
        }
        try persist()
        return try snapshot(owner: owner, viewer: viewer, receipt: receipt, includeHistory: includeHistory)
    }

    func confirmGoal(userID: UUID, goal: Int, timezone: String) throws -> WeeklyFlameState {
        try checkLoaded()
        guard WeeklyGoal.isValid(goal) else { throw AppError.validation("Wähle ein Wochenziel zwischen 3 und 7 Trainings.") }
        _ = try calendar(timezone)
        let receipt = now()
        try bootstrap(userID: userID, suggestedGoal: goal, confirmedFixture: false, timezone: timezone, receipt: receipt)
        try advance(userID: userID, receipt: receipt)
        if let account = state.accounts[userID], account.confirmedAt != nil {
            guard account.suggestedGoal == goal else { throw AppError.conflict("Dein Wochenziel wurde bereits bestätigt. Änderungen gelten ab nächster Woche.") }
            return try weeklyState(owner: userID, viewer: userID, friends: [], timezone: timezone,
                                   suggestedGoal: account.suggestedGoal, confirmedFixture: false)
        }
        guard var account = state.accounts[userID] else { throw AppError.server }
        if account.confirmedAt == nil {
            account.suggestedGoal = goal; account.confirmedAt = receipt
            let index = account.weeks.count - 1
            account.nextTimezone = timezone == account.weeks[index].timezone ? nil : timezone
            account.weeks[index].goal = goal; account.weeks[index].goalConfirmed = true
            if account.weeks[index].credits.count >= goal { account.weeks[index].earnedAt = receipt }
            state.accounts[userID] = account
        }
        try persist()
        return try snapshot(owner: userID, viewer: userID, receipt: receipt)
    }

    func setNextGoal(userID: UUID, goal: Int) throws -> WeeklyFlameState {
        try checkLoaded()
        guard WeeklyGoal.isValid(goal) else { throw AppError.validation("Wähle ein Wochenziel zwischen 3 und 7 Trainings.") }
        let receipt = now()
        try advance(userID: userID, receipt: receipt)
        guard var account = state.accounts[userID], let current = account.weeks.last, account.confirmedAt != nil else {
            throw AppError.conflict("Bestätige zuerst dein persönliches Wochenziel.")
        }
        account.nextGoal = goal == current.goal ? nil : goal
        state.accounts[userID] = account
        try persist()
        return try snapshot(owner: userID, viewer: userID, receipt: receipt)
    }

    /// Called only by a confirmed demo completion, not by steps, timers or presentation views.
    func recordCompletion(_ activity: Activity) throws {
        try checkLoaded()
        let receipt = now()
        guard activity.status == .completed, let start = activity.startedAt, let end = activity.endedAt,
              end <= receipt, start <= end, activity.pausedAt == nil, (activity.pausedSeconds ?? 0) >= 0 else { return }
        try advance(userID: activity.userID, receipt: end)
        guard var account = state.accounts[activity.userID], account.processedActivities.insert(activity.id).inserted else { return }
        guard end.timeIntervalSince(start) - Double(activity.pausedSeconds ?? 0) >= 60,
              let index = account.weeks.firstIndex(where: { $0.startsAt <= end && end < $0.endsAt && $0.finalizedAt == nil }) else {
            state.accounts[activity.userID] = account
            try persist()
            return
        }
        account.weeks[index].credits.insert(activity.id)
        if account.weeks[index].goalConfirmed && account.weeks[index].earnedAt == nil && account.weeks[index].credits.count >= account.weeks[index].goal {
            account.weeks[index].earnedAt = end
            announceAchievement(account.weeks[index], owner: activity.userID, receipt: receipt)
        }
        state.accounts[activity.userID] = account
        try persist()
    }

    func react(weekID: UUID, viewer: UUID, friends: Set<UUID>, reaction: ReactionKind?) throws -> Bool {
        try checkLoaded()
        guard let owner = state.accounts.first(where: { $0.value.weeks.contains { $0.id == weekID } })?.key,
              owner != viewer, canRead(owner: owner, viewer: viewer, friends: friends),
              var account = state.accounts[owner], let index = account.weeks.firstIndex(where: { $0.id == weekID }),
              account.weeks[index].earnedAt != nil else { throw AppError.authentication }
        account.weeks[index].reactions[viewer] = reaction
        state.accounts[owner] = account
        try persist()
        return true
    }

    func claim(weekID: UUID, userID: UUID) throws -> Bool {
        try checkLoaded()
        guard var account = state.accounts[userID], let index = account.weeks.firstIndex(where: { $0.id == weekID }),
              account.weeks[index].earnedAt != nil else { throw AppError.authentication }
        guard !account.weeks[index].celebrationClaimed else { return false }
        account.weeks[index].celebrationClaimed = true
        state.accounts[userID] = account
        try persist()
        return true
    }

    func callMyShot(userID: UUID, expectedWeekID: UUID, friends: Set<UUID>, displayName: String) throws -> WeeklyCommitment {
        try checkLoaded()
        let receipt = now()
        try advance(userID: userID, receipt: receipt)
        guard var account = state.accounts[userID], account.confirmedAt != nil, let current = account.weeks.last,
              current.goalConfirmed else { throw AppError.conflict("Bestätige zuerst dein persönliches Wochenziel.") }
        // This check runs against the authoritative current week after rollover,
        // before any commitment, audience, or notification is created.
        guard current.id == expectedWeekID else {
            throw AppError.conflict("Deine Woche hat gewechselt. Prüfe das aktuelle Ziel und bestätige deinen Call erneut.")
        }
        guard current.commitment == nil else { throw AppError.conflict("Du hast dein Wochenziel diese Woche bereits angekündigt.") }
        guard current.earnedAt == nil else { throw AppError.conflict("Du hast dein Wochenziel bereits erreicht. Kündige es nächste Woche an.") }
        let audience = friends.filter { $0 != userID && !state.revokedFriendships.contains(friendshipKey(userID, $0)) }
        let commitment = Commitment(calledAt: receipt, ownerName: displayName, audience: Set(audience))
        let index = account.weeks.count - 1
        account.weeks[index].commitment = commitment
        state.accounts[userID] = account
        for friend in audience {
            appendNotification(owner: userID, recipient: friend, actor: userID, commitmentID: commitment.id,
                               type: "shot_called", title: "CALL MY SHOT",
                               body: "\(displayName) kündigt \(current.goal) Trainings für diese Woche an.", receipt: receipt)
        }
        try persist()
        guard let result = commitmentDocument(account.weeks[index], owner: userID, viewer: userID) else { throw AppError.server }
        return result
    }

    func reactToShot(commitmentID: UUID, viewer: UUID, friends: Set<UUID>, reaction: ShotReaction?, displayName: String) throws -> Bool {
        try checkLoaded()
        guard let owner = state.accounts.first(where: { $0.value.weeks.contains { $0.commitment?.id == commitmentID } })?.key,
              owner != viewer, canRead(owner: owner, viewer: viewer, friends: friends) else { throw AppError.accessDenied }
        try advance(userID: owner, receipt: now())
        guard var account = state.accounts[owner], let index = account.weeks.firstIndex(where: { $0.commitment?.id == commitmentID }),
              var commitment = account.weeks[index].commitment else { throw AppError.accessDenied }
        let previous = commitment.reactions[viewer]
        commitment.reactions[viewer] = reaction
        if let reaction, previous != reaction, (state.preferences?[owner] ?? .standard).reactions,
           commitment.reactionNotificationAuthors.insert(viewer).inserted {
            appendNotification(owner: owner, recipient: owner, actor: viewer, commitmentID: commitmentID,
                               type: "shot_reaction", title: "\(displayName) unterstützt dein Wochenziel",
                               body: reaction.rawValue, receipt: now())
        }
        account.weeks[index].commitment = commitment
        state.accounts[owner] = account
        try persist()
        return true
    }

    func notifications(userID: UUID, friends: Set<UUID>) throws -> [AppNotification] {
        try checkLoaded()
        return (state.notifications?[userID] ?? []).filter { notification in
            guard let ownerText = notification.data?["user_id"], let owner = UUID(uuidString: ownerText),
                  let actorText = notification.data?["actor_id"], let actor = UUID(uuidString: actorText),
                  let idText = notification.data?["commitment_id"], let id = UUID(uuidString: idText),
                  state.accounts[owner]?.weeks.contains(where: { $0.commitment?.id == id }) == true else { return false }
            return canRead(owner: owner, viewer: userID, friends: friends)
                && actor != userID && friends.contains(actor)
                && !state.revokedFriendships.contains(friendshipKey(userID, actor))
        }
    }

    func setNotificationPreferences(_ preferences: NotificationPreferences, userID: UUID) throws {
        try checkLoaded()
        var values = state.preferences ?? [:]
        values[userID] = preferences; state.preferences = values
        try persist()
    }

    func revokeFriendship(_ first: UUID, _ second: UUID) throws {
        try checkLoaded()
        state.revokedFriendships.insert(friendshipKey(first, second))
        for owner in [first, second] {
            guard var account = state.accounts[owner] else { continue }
            let other = owner == first ? second : first
            for index in account.weeks.indices {
                account.weeks[index].reactions.removeValue(forKey: other)
                account.weeks[index].commitment?.reactions.removeValue(forKey: other)
                account.weeks[index].commitment?.audience.remove(other)
            }
            state.accounts[owner] = account
        }
        try persist()
    }

    func deleteAccount(userID: UUID) throws {
        try checkLoaded()
        state.accounts.removeValue(forKey: userID)
        state.notifications?.removeValue(forKey: userID)
        state.preferences?.removeValue(forKey: userID)
        for owner in Array(state.accounts.keys) {
            guard var account = state.accounts[owner] else { continue }
            for index in account.weeks.indices {
                account.weeks[index].reactions.removeValue(forKey: userID)
                account.weeks[index].commitment?.reactions.removeValue(forKey: userID)
                account.weeks[index].commitment?.audience.remove(userID)
            }
            state.accounts[owner] = account
        }
        try persist()
    }
}

extension DemoRepository {
    func weeklyState(userID: UUID, timezone: String?) async throws -> WeeklyFlameState {
        let owner = userID == meID ? me : crew.first { $0.id == userID }
        guard let owner else { throw AppError.authentication }
        return try await weeklyStorage.weeklyState(owner: userID, viewer: meID, friends: Set(crew.map(\.id)),
                                                  timezone: timezone, suggestedGoal: owner.weeklyGoal,
                                                  confirmedFixture: userID == meID && hasConfirmedDemoWeeklyGoal)
    }

    func confirmWeeklyGoal(_ goal: Int, timezone: String) async throws -> WeeklyFlameState {
        try await weeklyStorage.confirmGoal(userID: meID, goal: goal, timezone: timezone)
    }

    func setNextWeeklyGoal(_ goal: Int) async throws -> WeeklyFlameState {
        _ = try await weeklyState(userID: meID, timezone: nil)
        return try await weeklyStorage.setNextGoal(userID: meID, goal: goal)
    }

    func friendsWeeklyState() async throws -> [WeeklyFlameState] {
        var values: [WeeklyFlameState] = []
        for friend in crew {
            if let value = try? await weeklyStorage.weeklyState(owner: friend.id, viewer: meID, friends: Set(crew.map(\.id)),
                                                                timezone: nil, suggestedGoal: friend.weeklyGoal,
                                                                confirmedFixture: false, includeHistory: false) { values.append(value) }
        }
        return values
    }

    func setFlameReaction(weekID: UUID, reaction: ReactionKind?) async throws -> Bool {
        try await weeklyStorage.react(weekID: weekID, viewer: meID, friends: Set(crew.map(\.id)), reaction: reaction)
    }

    func claimFlameCelebration(weekID: UUID) async throws -> Bool {
        try await weeklyStorage.claim(weekID: weekID, userID: meID)
    }
}
