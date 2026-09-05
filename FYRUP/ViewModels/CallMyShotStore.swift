import Foundation
import Observation

/// Mutation coordination only: commitments and reactions live exclusively in
/// WeeklyFlameStore's authenticated snapshots, never in a second optimistic cache.
@MainActor @Observable
final class CallMyShotStore {
    private let repository: any CallMyShotRepository
    private let weekly: WeeklyFlameStore
    private var generation = UUID()
    private var friendRevisions: [UUID: Int] = [:]
    private var errorRevision = 0

    private(set) var userID: UUID?
    private(set) var isCalling = false
    private(set) var reactingIDs: Set<UUID> = []
    var errorMessage: String?

    init(repository: any CallMyShotRepository, weekly: WeeklyFlameStore) {
        self.repository = repository; self.weekly = weekly
    }

    func activate(userID: UUID?) {
        if self.userID != userID { reset(); self.userID = userID }
    }

    func reset() {
        generation = UUID(); friendRevisions = [:]; errorRevision = 0
        userID = nil; isCalling = false; reactingIDs = []; errorMessage = nil
    }

    var canCall: Bool {
        guard let owner = userID, weekly.userID == owner, !isCalling,
              !weekly.isLoading, !weekly.isSavingGoal, weekly.isStateConfirmed,
              weekly.state?.goalConfirmed == true, let week = weekly.currentWeek else { return false }
        return week.userID == owner && week.isValid && !week.finalized && !week.flameEarned && week.commitment == nil
    }

    func isReacting(commitmentID: UUID) -> Bool { reactingIDs.contains(commitmentID) }

    /// Call immediately when a friendship is removed or blocked. Retire in-flight
    /// reactions before they can request another detail using the former access.
    func removeFriend(userID friendID: UUID) {
        friendRevisions[friendID, default: 0] += 1
        weekly.removeFriend(userID: friendID)
    }

    /// Invoked only by the explicit confirmation button. Transport errors never
    /// trigger a second create; an authorized read resolves a possible saved call.
    @discardableResult
    func call(expectedWeekID: UUID) async -> Bool {
        guard let owner = userID, weekly.userID == owner, !isCalling, !Task.isCancelled,
              let before = weekly.currentWeek else { return false }
        guard before.id == expectedWeekID else {
            let message = beginOperation()
            present("Die Woche hat gewechselt. Bitte prüfe dein aktuelles Ziel.", revision: message)
            return false
        }
        guard canCall else { return false }
        let request = generation; let message = beginOperation()
        isCalling = true
        defer { if generation == request { isCalling = false } }

        var response: WeeklyCommitment?
        var malformedResponse = false
        do {
            let value = try await repository.callMyShot(expectedWeekID: before.id)
            guard isCurrent(request, owner: owner) else { return false }
            // Achievement/reaction fields may advance between write and refresh.
            // Freeze-check identity against the week the person actually confirmed.
            malformedResponse = !matches(value, week: before)
            response = value
        } catch {
            guard isCurrent(request, owner: owner) else { return false }
            // A duplicate conflict or lost HTTP response can both mean it exists.
            // Do not claim either successful creation or failed persistence here.
        }

        guard isCurrent(request, owner: owner) else { return false }
        await weekly.refresh(force: true)
        guard isCurrent(request, owner: owner) else { return false }
        // Weekly coalesces concurrent reads. A queued refresh is not yet a receipt.
        guard !weekly.isLoading, !weekly.isSavingGoal, weekly.isStateConfirmed,
              weekly.state?.goalConfirmed == true, let fresh = weekly.currentWeek,
              fresh.id == before.id, fresh.userID == owner, fresh.isValid,
              let committed = fresh.commitment, committed.isValid(for: fresh),
              matches(committed, week: before), !malformedResponse else {
            present("Dein Call wird geprüft. Aktualisiere die Woche, um den bestätigten Stand zu sehen.", revision: message)
            return false
        }
        if let response, response.id != committed.id || response.calledAt != committed.calledAt {
            present("Dein Call wird geprüft. Aktualisiere die Woche, um den bestätigten Stand zu sehen.", revision: message)
            return false
        }
        return true
    }

    /// Only a currently visible, authorized friend's commitment can be targeted.
    /// Both the preflight and the post-write read pass through Weekly's privacy guards.
    @discardableResult
    func react(commitmentID: UUID, reaction: ShotReaction?) async -> Bool {
        guard let owner = userID, weekly.userID == owner, !Task.isCancelled,
              !reactingIDs.contains(commitmentID),
              let target = weekly.friends.first(where: { commitment(in: $0, id: commitmentID) != nil }) else { return false }
        let request = generation; let friendID = target.userID
        let accessRevision = friendRevisions[friendID, default: 0]; let message = beginOperation()
        reactingIDs.insert(commitmentID)
        defer { if generation == request { reactingIDs.remove(commitmentID) } }

        func stillAuthorized() -> Bool {
            isCurrent(request, owner: owner) && friendRevisions[friendID, default: 0] == accessRevision
        }
        guard let preflight = await weekly.loadFriend(userID: friendID), stillAuthorized(),
              commitment(in: preflight, id: commitmentID) != nil,
              let visible = weekly.friend(userID: friendID), commitment(in: visible, id: commitmentID) != nil else {
            if stillAuthorized() { present("Diese Ankündigung ist gerade nicht verfügbar. Aktualisiere deine Crew.", revision: message) }
            return false
        }
        do {
            guard try await repository.setShotReaction(commitmentID: commitmentID, reaction: reaction) else { throw AppError.server }
            guard stillAuthorized() else { return false }
            let refreshed = await weekly.loadFriend(userID: friendID)
            guard stillAuthorized() else { return false }
            guard let refreshed, let confirmed = commitment(in: refreshed, id: commitmentID),
                  let current = weekly.friend(userID: friendID),
                  let visibleCommitment = commitment(in: current, id: commitmentID),
                  visibleCommitment.myReaction == reaction,
                  confirmed.myReaction == reaction else {
                present("Deine Reaktion wird geprüft. Aktualisiere die Crew, um den bestätigten Stand zu sehen.", revision: message)
                return false
            }
            return true
        } catch {
            guard stillAuthorized() else { return false }
            if (error as? AppError)?.isAccessDenied == true { removeFriend(userID: friendID) }
            present("Deine Reaktion wurde nicht bestätigt. Aktualisiere die Crew und versuche es erneut.", revision: message)
            return false
        }
    }

    private func isCurrent(_ request: UUID, owner: UUID) -> Bool {
        generation == request && userID == owner && weekly.userID == owner && !Task.isCancelled
    }

    private func matches(_ value: WeeklyCommitment, week: WeeklyProgress) -> Bool {
        value.isValid && value.userID == week.userID && value.weekID == week.id
            && value.weekStartDate == week.weekStartDate && value.weeklyGoal == week.weeklyGoal
            && week.startsAt <= value.calledAt && value.calledAt < week.endsAt
    }

    private func commitment(in state: WeeklyFlameState, id: UUID) -> WeeklyCommitment? {
        guard state.userID != userID, state.isValid else { return nil }
        return ([state.currentWeek].compactMap { $0 } + state.history).compactMap { week -> WeeklyCommitment? in
            guard let value = week.commitment, value.id == id, value.isValid(for: week) else { return nil }
            return value
        }.first
    }

    private func beginOperation() -> Int { errorRevision += 1; errorMessage = nil; return errorRevision }
    private func present(_ message: String, revision: Int) { if errorRevision == revision { errorMessage = message } }
}
