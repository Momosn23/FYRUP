import Foundation
import Observation

/// Local presentation receipts only, never workout credits or authoritative achievement state.
/// Persist before publishing the event to avoid showing the reward again after a relaunch.
@MainActor
final class SuccessAnimationEventStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func hasConsumed(_ week: WeeklyProgress) -> Bool { defaults.bool(forKey: key(week)) }
    @discardableResult
    func consume(_ week: WeeklyProgress) -> Bool {
        guard week.isValid, week.flameEarned, !hasConsumed(week) else { return false }
        defaults.set(true, forKey: key(week))
        return true
    }
    func clear(userID: UUID) {
        let prefix = "fyrup.weeklyFlame.presented.\(userID.uuidString.lowercased()):"
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) { defaults.removeObject(forKey: key) }
    }
    private func key(_ week: WeeklyProgress) -> String { "fyrup.weeklyFlame.presented.\(week.celebrationID)" }
}

@MainActor @Observable
final class WeeklyFlameStore {
    private struct Snapshot {
        let state: WeeklyFlameState
        let receivedAt: TimeInterval
        func serverTime(at uptime: TimeInterval) -> Date { state.serverNow.addingTimeInterval(max(0, uptime - receivedAt)) }
    }

    private let repository: any WeeklyFlameRepository
    private let events: SuccessAnimationEventStore
    /// Monotonic time keeps a device clock/timezone change from moving the server-authored week boundary.
    private let uptime: @MainActor () -> TimeInterval
    private let timezone: @MainActor () -> String
    private let refreshInterval: TimeInterval
    private var generation = UUID()
    private var revision = 0
    private var friendRevision = 0
    private var friendReadSequence = 0
    private var friendReadVersions: [UUID: Int] = [:]
    private var errorRevision = 0
    private var ownSnapshot: Snapshot?
    private var friendSnapshots: [UUID: Snapshot] = [:]
    private var lastTimezone: String?
    private var queuedRefresh = false
    private var reactingWeeks: Set<UUID> = []

    private(set) var userID: UUID?
    private(set) var state: WeeklyFlameState?
    private(set) var isLoading = false
    private(set) var isLoadingFriends = false
    private(set) var isSavingGoal = false
    private(set) var isPreparingCelebration = false
    private(set) var isStateConfirmed = false
    private(set) var celebration: WeeklyFlameCelebration?
    var errorMessage: String?

    init(repository: any WeeklyFlameRepository, defaults: UserDefaults = .standard,
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         timezone: @escaping @MainActor () -> String = { TimeZone.current.identifier }, refreshInterval: TimeInterval = 60) {
        self.repository = repository; self.events = SuccessAnimationEventStore(defaults: defaults)
        self.uptime = uptime; self.timezone = timezone; self.refreshInterval = max(1, refreshInterval)
    }

    var needsGoalConfirmation: Bool? { isStateConfirmed ? state.map { !$0.goalConfirmed } : nil }
    var currentWeek: WeeklyProgress? {
        guard let snapshot = ownSnapshot, let week = snapshot.state.currentWeek,
              snapshot.serverTime(at: uptime()) < week.endsAt else { return nil }
        return week
    }
    var history: [WeeklyProgress] { state?.history.sorted { $0.startsAt > $1.startsAt } ?? [] }
    var friends: [WeeklyFlameState] {
        friendSnapshots.values.filter(isFreshFriend).map(\.state).sorted { $0.userID.uuidString < $1.userID.uuidString }
    }
    func friend(userID: UUID) -> WeeklyFlameState? {
        guard let snapshot = friendSnapshots[userID], isFreshFriend(snapshot) else { return nil }
        return snapshot.state
    }
    func isReacting(weekID: UUID) -> Bool { reactingWeeks.contains(weekID) }

    func activate(userID: UUID) async {
        if self.userID != userID { reset(); self.userID = userID }
        await refresh()
    }

    func reset(clearLocalPreferences: Bool = false) {
        if clearLocalPreferences, let userID { events.clear(userID: userID) }
        generation = UUID(); revision = 0; friendRevision = 0; errorRevision = 0
        friendReadSequence = 0; friendReadVersions = [:]
        userID = nil; state = nil; ownSnapshot = nil; friendSnapshots = [:]; lastTimezone = nil
        isLoading = false; isLoadingFriends = false; isSavingGoal = false; isPreparingCelebration = false
        isStateConfirmed = false; celebration = nil; errorMessage = nil; queuedRefresh = false; reactingWeeks = []
    }

    /// Call on foreground, Today/profile open and force:true after a confirmed FYRUP completion.
    /// No completed count is ever incremented locally; the server finalizes missing weeks and credits each activity once.
    func refresh(force: Bool = false) async {
        guard let owner = userID else { return }
        let zone = timezone()
        if isLoading { queuedRefresh = queuedRefresh || force || zone != lastTimezone; return }
        if !force, isStateConfirmed, zone == lastTimezone, let snapshot = ownSnapshot,
           uptime() - snapshot.receivedAt >= 0, uptime() - snapshot.receivedAt < refreshInterval,
           snapshot.state.currentWeek == nil || currentWeek != nil { return }
        let request = generation; let readRevision = revision; let messageRevision = errorRevision; let startedAt = uptime()
        isLoading = true
        do {
            let value = try await repository.weeklyState(userID: owner, timezone: zone)
            guard generation == request, !Task.isCancelled else { finishRead(request: request); return }
            if revision == readRevision {
                try accept(value, owner: owner, startedAt: startedAt); lastTimezone = zone
                if errorRevision == messageRevision { errorMessage = nil }
            }
        } catch {
            if generation == request, revision == readRevision {
                isStateConfirmed = false
                if errorRevision == messageRevision { present("Dein Wochenziel konnte nicht geladen werden. Versuche es erneut.") }
            }
        }
        guard generation == request else { return }
        isLoading = false
        if queuedRefresh, !Task.isCancelled { queuedRefresh = false; await refresh(force: true) }
    }

    /// Only the explicit onboarding button calls this. A suggested/default selection never confirms itself.
    @discardableResult
    func confirmGoal(_ goal: Int) async -> Bool {
        await saveGoal(goal, firstConfirmation: true)
    }

    /// Both increases and decreases take effect next week, never by editing the current week's target.
    @discardableResult
    func scheduleGoal(_ goal: Int) async -> Bool {
        await saveGoal(goal, firstConfirmation: false)
    }

    private func saveGoal(_ goal: Int, firstConfirmation: Bool) async -> Bool {
        guard WeeklyGoal.isValid(goal) else { present("Wähle ein Wochenziel zwischen 3 und 7 Trainings."); return false }
        guard let owner = userID, !isSavingGoal else { return false }
        guard firstConfirmation || state?.goalConfirmed == true else {
            present("Bestätige zuerst dein persönliches Wochenziel."); return false
        }
        let request = generation; let startedAt = uptime()
        revision += 1; errorRevision += 1; isSavingGoal = true; isStateConfirmed = false; errorMessage = nil
        defer { if generation == request { isSavingGoal = false } }
        do {
            let value: WeeklyFlameState
            if firstConfirmation { value = try await repository.confirmWeeklyGoal(goal, timezone: timezone()) }
            else { value = try await repository.setNextWeeklyGoal(goal) }
            guard generation == request, !Task.isCancelled else { return false }
            guard value.goalConfirmed else { throw AppError.server }
            try accept(value, owner: owner, startedAt: startedAt)
            revision += 1
            return true
        } catch {
            if generation == request {
                isStateConfirmed = false
                present("Dein Wochenziel wurde nicht bestätigt. Deine Auswahl bleibt erhalten. Prüfe die Verbindung und versuche es erneut.")
            }
            return false
        }
    }

    func refreshFriends() async {
        guard let owner = userID, !isLoadingFriends else { return }
        let request = generation; let readRevision = friendRevision; let startedAt = uptime()
        friendReadSequence += 1
        let batchVersion = friendReadSequence
        isLoadingFriends = true
        defer { if generation == request { isLoadingFriends = false } }
        do {
            let values = try await repository.friendsWeeklyState()
            guard generation == request, friendRevision == readRevision, !Task.isCancelled else { return }
            guard values.allSatisfy({ $0.userID != owner && $0.isValid }), Set(values.map(\.userID)).count == values.count else { throw AppError.server }
            let returnedIDs = Set(values.map(\.userID))
            // Include requested-but-not-yet-cached profiles. A newer authorized batch
            // must invalidate their old detail response even when no snapshot exists yet.
            let knownIDs = Set(friendSnapshots.keys).union(friendReadVersions.keys)
            for id in knownIDs where !returnedIDs.contains(id) && friendReadVersions[id, default: 0] <= batchVersion {
                friendSnapshots.removeValue(forKey: id); friendReadVersions[id] = batchVersion
            }
            for value in values where friendReadVersions[value.userID, default: 0] <= batchVersion {
                friendSnapshots[value.userID] = Snapshot(state: value, receivedAt: startedAt)
                friendReadVersions[value.userID] = batchVersion
            }
        } catch {
            // Do not retain potentially revoked friend access after a failed authorized refresh.
            if generation == request, friendRevision == readRevision {
                let knownIDs = Set(friendSnapshots.keys).union(friendReadVersions.keys)
                for id in knownIDs where friendReadVersions[id, default: 0] <= batchVersion {
                    friendSnapshots.removeValue(forKey: id); friendReadVersions[id] = batchVersion
                }
            }
        }
    }

    @discardableResult
    func loadFriend(userID friendID: UUID) async -> WeeklyFlameState? {
        guard let owner = userID, friendID != owner else { return nil }
        let request = generation; let readRevision = friendRevision; let startedAt = uptime()
        friendReadSequence += 1
        let detailVersion = friendReadSequence
        friendReadVersions[friendID] = detailVersion
        do {
            let value = try await repository.weeklyState(userID: friendID, timezone: nil)
            guard generation == request, friendRevision == readRevision,
                  friendReadVersions[friendID] == detailVersion, !Task.isCancelled else { return nil }
            guard value.userID == friendID, value.isValid else { throw AppError.server }
            friendSnapshots[friendID] = Snapshot(state: value, receivedAt: startedAt)
            return value
        } catch {
            if generation == request, friendRevision == readRevision, friendReadVersions[friendID] == detailVersion {
                friendSnapshots.removeValue(forKey: friendID)
            }
            return nil
        }
    }

    /// Call immediately after blocking/removing a friendship as well as refreshing the authorized server list.
    func removeFriend(userID: UUID) { friendRevision += 1; friendSnapshots.removeValue(forKey: userID) }

    @discardableResult
    func react(weekID: UUID, reaction: ReactionKind?) async -> Bool {
        guard userID != nil, !reactingWeeks.contains(weekID),
              let target = friends.first(where: { value in
                  ([value.currentWeek].compactMap { $0 } + value.history).contains { $0.id == weekID && $0.flameEarned }
              }) else { return false }
        let request = generation; let accessRevision = friendRevision
        reactingWeeks.insert(weekID)
        defer { if generation == request { reactingWeeks.remove(weekID) } }
        do {
            guard try await repository.setFlameReaction(weekID: weekID, reaction: reaction) else { throw AppError.server }
            guard generation == request, friendRevision == accessRevision, !Task.isCancelled else { return false }
            friendRevision += 1
            // No optimistic count or forged confirmation; reload the authenticated reaction summary.
            _ = await loadFriend(userID: target.userID)
            return generation == request && friendSnapshots[target.userID] != nil
        } catch {
            if generation == request { present("Deine Reaktion wurde nicht bestätigt. Versuche es erneut.") }
            return false
        }
    }

    /// Invoke only when the success surface can actually be presented. Read refreshes never consume this event.
    func prepareCelebration() async {
        guard let owner = userID, isStateConfirmed, celebration == nil, !isPreparingCelebration,
              let week = currentWeek, week.flameEarned, !events.hasConsumed(week) else { return }
        let request = generation
        isPreparingCelebration = true
        defer { if generation == request { isPreparingCelebration = false } }
        do {
            let claimed = try await repository.claimFlameCelebration(weekID: week.id)
            guard generation == request, userID == owner, !Task.isCancelled,
                  currentWeek?.id == week.id, currentWeek?.flameEarned == true else { return }
            // False means already claimed (possibly on another device); remember that locally too.
            let firstLocalReceipt = events.consume(week)
            if claimed, firstLocalReceipt { celebration = WeeklyFlameCelebration(week: currentWeek ?? week) }
        } catch {
            // No local receipt on transport failure: retry asks the same atomic server claim, never awards another flame.
            if generation == request { present("Deine Flamme bleibt gespeichert. Die Erfolgsanzeige konnte gerade nicht geladen werden.") }
        }
    }

    func dismissCelebration() { celebration = nil }

    private func accept(_ value: WeeklyFlameState, owner: UUID, startedAt: TimeInterval) throws {
        guard value.userID == owner, value.isValid else { throw AppError.server }
        // Anchoring to request start conservatively includes network latency: a slow response
        // may expire slightly early, but can never keep last week's progress visible past its boundary.
        state = value; ownSnapshot = Snapshot(state: value, receivedAt: startedAt); isStateConfirmed = true
        if celebration?.week.id != value.currentWeek?.id { celebration = nil }
    }
    private func isFreshFriend(_ snapshot: Snapshot) -> Bool {
        let age = uptime() - snapshot.receivedAt
        guard age >= 0, age < 120 else { return false }
        return snapshot.state.currentWeek.map { snapshot.serverTime(at: uptime()) < $0.endsAt } ?? true
    }
    private func finishRead(request: UUID) { if generation == request { isLoading = false } }
    private func present(_ message: String) { errorRevision += 1; errorMessage = message }
}
