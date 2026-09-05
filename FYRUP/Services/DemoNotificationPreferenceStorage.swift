import Foundation

/// One demo-only authority for every notification producer. All reads, joins and
/// compare-and-save operations use the same lock; no suspension splits a save.
/// Explicit suites are re-read inside that lock, so another repository cannot
/// confirm stale defaults or overwrite an opt-out after a relaunch.
final class DemoNotificationPreferenceStorage: @unchecked Sendable {
    private final class Coordinator: @unchecked Sendable {
        let lock = NSRecursiveLock()
        var suites: [String: DemoNotificationPreferenceStorage] = [:]
    }
    private struct Legacy: Decodable { let preferences: [UUID: NotificationPreferences]? }
    private static let coordinator = Coordinator()
    static let persistenceKey = "fyrup.demo.notification-preferences.v1"
    private let suite: String?
    private let defaults: UserDefaults?
    private var memory: [UUID: NotificationPreferences] = [:]
    private var parent: DemoNotificationPreferenceStorage?
    private var invalid = false

    private init(suite: String?) {
        self.suite = suite
        defaults = suite.flatMap { UserDefaults(suiteName: $0) }
        invalid = suite != nil && defaults == nil
    }

    static func shared(persistenceSuiteName: String? = nil) -> DemoNotificationPreferenceStorage {
        coordinator.lock.lock(); defer { coordinator.lock.unlock() }
        guard let persistenceSuiteName else { return .init(suite: nil) }
        if let value = coordinator.suites[persistenceSuiteName] { return value }
        let value = DemoNotificationPreferenceStorage(suite: persistenceSuiteName)
        coordinator.suites[persistenceSuiteName] = value
        return value
    }

    private var root: DemoNotificationPreferenceStorage { parent?.root ?? self }
    private static var unreadable: AppError {
        .conflict("Die gespeicherten Mitteilungseinstellungen konnten nicht geladen werden. Deine Auswahl wurde nicht überschrieben.")
    }

    /// Default ephemeral feature stores are joined when a DemoRepository is made.
    /// Existing holders follow the root too, including a second demo account that
    /// shares only one feature store. Different persistent suites never get mixed.
    func joined(with other: DemoNotificationPreferenceStorage) -> DemoNotificationPreferenceStorage {
        Self.coordinator.lock.lock(); defer { Self.coordinator.lock.unlock() }
        let first = root, second = other.root
        guard first !== second else { return first }
        guard first.suite == nil || second.suite == nil || first.suite == second.suite else {
            first.invalid = true; second.invalid = true
            return first
        }
        let destination = first.suite != nil ? first : second
        let source = destination === first ? second : first
        do {
            let current = try destination.load()
            let joined = Self.merge(current, try source.load())
            if joined != current { try destination.write(joined) }
        } catch { destination.invalid = true }
        source.parent = destination
        return destination
    }

    func value(userID: UUID) throws -> NotificationPreferences {
        Self.coordinator.lock.lock(); defer { Self.coordinator.lock.unlock() }
        return try root.load()[userID] ?? .standard
    }

    func compareAndSave(_ desired: NotificationPreferences, expected: NotificationPreferences,
                        userID: UUID) throws -> NotificationPreferences {
        Self.coordinator.lock.lock(); defer { Self.coordinator.lock.unlock() }
        let source = root
        var values = try source.load()
        let current = values[userID] ?? .standard
        if current == desired { return current }
        guard current == expected else {
            throw AppError.conflict("Die Einstellungen wurden inzwischen geändert. Bitte prüfe den aktuellen Stand, bevor du speicherst.")
        }
        values[userID] = desired
        try source.write(values)
        return desired
    }

    /// Internal fixture setup, not the client save API. Producers still read the
    /// same authority; DemoRepository always uses compareAndSave with a baseline.
    func setFixture(_ preferences: NotificationPreferences, userID: UUID) throws {
        Self.coordinator.lock.lock(); defer { Self.coordinator.lock.unlock() }
        var values = try root.load(); values[userID] = preferences
        try root.write(values)
    }

    func remove(userID: UUID) throws {
        Self.coordinator.lock.lock(); defer { Self.coordinator.lock.unlock() }
        var values = try root.load(); values.removeValue(forKey: userID)
        try root.write(values)
    }

    private func load() throws -> [UUID: NotificationPreferences] {
        guard !invalid else { throw Self.unreadable }
        guard let defaults else { return memory }
        do {
            if let stored = defaults.object(forKey: Self.persistenceKey) {
                guard let data = stored as? Data else { throw Self.unreadable }
                return try JSONDecoder().decode([UUID: NotificationPreferences].self, from: data)
            }
            // Read both old stores only until the first canonical record exists.
            // If old copies disagree, an opt-out wins; never infer consent from
            // a missing or unreadable legacy record.
            var migrated: [UUID: NotificationPreferences] = [:]
            for key in ["fyrup.demo.weekly-flames.v1", "fyrup.demo.blind-workouts.v1"] {
                if let stored = defaults.object(forKey: key) {
                    guard let data = stored as? Data else { throw Self.unreadable }
                    let values = try JSONDecoder().decode(Legacy.self, from: data).preferences ?? [:]
                    migrated = Self.merge(migrated, values)
                }
            }
            return migrated
        } catch { throw Self.unreadable }
    }

    private func write(_ values: [UUID: NotificationPreferences]) throws {
        guard !invalid else { throw Self.unreadable }
        let encoded = try JSONEncoder().encode(values)
        if let defaults { defaults.set(encoded, forKey: Self.persistenceKey) }
        else { memory = values }
    }

    private static func merge(_ first: [UUID: NotificationPreferences], _ second: [UUID: NotificationPreferences]) -> [UUID: NotificationPreferences] {
        first.merging(second) { a, b in
            NotificationPreferences(friendStarts: a.friendStarts && b.friendStarts, fyrup: a.fyrup && b.fyrup,
                invitations: a.invitations && b.invitations, reactions: a.reactions && b.reactions,
                friendRequests: a.friendRequests && b.friendRequests, reminders: a.reminders && b.reminders,
                weeklyGoal: a.weeklyGoal && b.weeklyGoal, crewGoal: a.crewGoal && b.crewGoal)
        }
    }
}
