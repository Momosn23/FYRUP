import Foundation

/// An empty, in-memory demo backend. Only explicit sync calls supply aggregate
/// values; fixtures and real device readings are never fabricated here.
actor DemoStepStorage {
    private struct Record {
        let userID: UUID
        let localDate: String
        let timezone: String
        let steps: Int
        let updatedAt: Date
    }
    private var preferences: [UUID: StepSharingPreference] = [:]
    private var records: [UUID: Record] = [:]
    private var observations: [UUID: Date] = [:]
    private var clampedObservations: Set<UUID> = []
    private var revokedFriendships = Set<String>()
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) { self.now = now }

    func preference(userID: UUID) -> StepSharingPreference {
        preferences[userID] ?? StepSharingPreference(userID: userID, sharingEnabled: false, sharingRevision: 0)
    }

    func setSharing(userID: UUID, enabled: Bool) -> StepSharingPreference {
        var value = preference(userID: userID)
        if value.sharingEnabled != enabled {
            value.sharingRevision += 1
            observations.removeValue(forKey: userID)
            clampedObservations.remove(userID)
        }
        value.sharingEnabled = enabled
        preferences[userID] = value
        if !enabled { records.removeValue(forKey: userID) }
        return value
    }

    func sync(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) throws -> Bool {
        let receipt = now()
        guard let zone = TimeZone(identifier: timezone) else { throw AppError.validation("Die Zeitzone konnte nicht erkannt werden.") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        guard localDate == StepDay.key(for: receipt, calendar: calendar) else {
            throw AppError.validation("Dieser Schrittwert gehört nicht zum aktuellen lokalen Tag.")
        }
        if let steps, !(0...StepDay.maximumSteps).contains(steps) {
            throw AppError.validation("Der Schrittwert ist ungültig.")
        }
        let preference = preference(userID: userID)
        guard preference.sharingEnabled, preference.sharingRevision == sharingRevision else { return false }
        guard observedAt >= receipt.addingTimeInterval(-86_400), observedAt <= receipt.addingTimeInterval(300) else {
            throw AppError.validation("Die Schrittabfrage ist nicht mehr aktuell. Lade deine Schritte erneut.")
        }
        guard localDate == StepDay.key(for: observedAt, calendar: calendar) else {
            throw AppError.validation("Dieser Schrittwert gehört nicht zum aktuellen lokalen Tag.")
        }
        // Tolerate a small device-clock skew without allowing it to move the cursor
        // ahead of every correctly timed future read.
        let observed = min(observedAt, receipt)
        if let previous = observations[userID] {
            if observed < previous { return false }
            // A correctly timed observation can replace a skewed one at the same
            // receipt tick. Ordinary equal-time conflicts remain rejected.
            let replacesClamped = clampedObservations.contains(userID) && observedAt <= receipt
            if observed == previous && !replacesClamped {
                guard let steps else { return records[userID] == nil }
                guard let record = records[userID] else { return false }
                return record.localDate == localDate && record.timezone == timezone && record.steps == steps
            }
        }
        observations[userID] = observed
        if observedAt > receipt { clampedObservations.insert(userID) }
        else { clampedObservations.remove(userID) }
        if let steps {
            records[userID] = Record(userID: userID, localDate: localDate, timezone: timezone, steps: steps, updatedAt: receipt)
        } else { records.removeValue(forKey: userID) }
        return true
    }

    func sharedSteps(userID: UUID, friends: Set<UUID>) -> [DailyStepMetric] {
        let receipt = now()
        return records.values.compactMap { record in
            guard record.userID != userID, friends.contains(record.userID), preference(userID: record.userID).sharingEnabled,
                  !revokedFriendships.contains(friendshipKey(userID, record.userID)), let zone = TimeZone(identifier: record.timezone) else { return nil }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
            guard record.localDate == StepDay.key(for: receipt, calendar: calendar) else { return nil }
            return DailyStepMetric(userID: record.userID, localDate: record.localDate, steps: record.steps, updatedAt: record.updatedAt,
                                   validUntil: min(StepDay.bounds(for: receipt, calendar: calendar).end, receipt.addingTimeInterval(120)))
        }.sorted { $0.userID.uuidString < $1.userID.uuidString }
    }

    func revokeFriendship(_ first: UUID, _ second: UUID) { revokedFriendships.insert(friendshipKey(first, second)) }

    func deleteAccount(userID: UUID) {
        preferences.removeValue(forKey: userID)
        records.removeValue(forKey: userID)
        observations.removeValue(forKey: userID)
        clampedObservations.remove(userID)
    }

    private func friendshipKey(_ first: UUID, _ second: UUID) -> String {
        [first.uuidString, second.uuidString].sorted().joined(separator: ":")
    }
}

extension DemoRepository {
    private func requireStepOwner(_ userID: UUID) throws {
        guard userID == meID else { throw AppError.conflict("Schritt-Freigaben können nur für das eigene Konto geändert werden.") }
    }

    func stepSharingPreference(userID: UUID) async throws -> StepSharingPreference {
        try requireStepOwner(userID)
        return await stepStorage.preference(userID: userID)
    }

    func setStepSharing(userID: UUID, enabled: Bool) async throws -> StepSharingPreference {
        try requireStepOwner(userID)
        return await stepStorage.setSharing(userID: userID, enabled: enabled)
    }

    func syncSteps(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) async throws -> Bool {
        try requireStepOwner(userID)
        return try await stepStorage.sync(userID: userID, localDate: localDate, timezone: timezone, steps: steps,
                                          sharingRevision: sharingRevision, observedAt: observedAt)
    }

    func sharedSteps() async throws -> [DailyStepMetric] {
        await stepStorage.sharedSteps(userID: meID, friends: Set(crew.map(\.id)))
    }
}
