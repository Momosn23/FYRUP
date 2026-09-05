import Foundation
import Observation

@MainActor @Observable
final class StepStore {
    private let repository: any StepRepository
    private let reader: any StepReading
    private let defaults: UserDefaults
    private let now: @MainActor () -> Date
    private let calendar: @MainActor () -> Calendar
    private let refreshInterval: TimeInterval

    private(set) var userID: UUID?
    private(set) var steps: Int?
    private(set) var localDate = ""
    /// nil means unknown. A failed network request must never look like confirmed privacy OFF.
    private(set) var sharingEnabled: Bool?
    private(set) var isSharingPreferenceCurrent = false
    private(set) var healthRequested = false
    private(set) var showSteps = false
    private(set) var goal: Int? = nil
    private(set) var isAuthorizing = false
    private(set) var isChangingSharing = false
    private(set) var isRefreshing = false
    private(set) var lastSyncedAt: Date?
    var message: String?

    private var generation = UUID()
    private var privacyGeneration = UUID()
    private var preference: StepSharingPreference?
    private var activeTimezone = ""
    private var lastRefresh: Date?
    private var sharedValues: [DailyStepMetric] = []
    private var sharedFetchedAt: Date?
    private var queuedRefresh = false

    init(repository: any StepRepository, reader: any StepReading = HealthKitStepReader(),
         defaults: UserDefaults = .standard, now: @escaping @MainActor () -> Date = { .now },
         calendar: @escaping @MainActor () -> Calendar = { .current }, refreshInterval: TimeInterval = 120) {
        self.repository = repository; self.reader = reader; self.defaults = defaults
        self.now = now; self.calendar = calendar
        self.refreshInterval = max(1, refreshInterval)
    }

    var isAvailable: Bool { reader.isAvailable }
    var isBusy: Bool { isAuthorizing || isChangingSharing }
    var todaysSteps: Int? { isCurrentDay ? steps : nil }
    var progress: Double? {
        guard let count = todaysSteps, let goal, goal > 0 else { return nil }
        return min(1, Double(count) / Double(goal))
    }
    /// HealthKit never tells us whether read permission was denied.
    var healthStatusText: String {
        if !isAvailable { return "Apple Health ist auf diesem Gerät nicht verfügbar." }
        if !healthRequested { return "Noch nicht verbunden" }
        return todaysSteps == nil ? "Keine Schrittdaten verfügbar" : "Schrittdaten verfügbar"
    }
    var shared: [DailyStepMetric] {
        guard isCurrentDay, let sharedFetchedAt, now().timeIntervalSince(sharedFetchedAt) >= 0,
              now().timeIntervalSince(sharedFetchedAt) <= refreshInterval else { return [] }
        return sharedValues.filter { $0.validUntil > now() }
    }
    private var isCurrentDay: Bool {
        localDate == StepDay.key(for: now(), calendar: calendar()) && activeTimezone == calendar().timeZone.identifier
    }
    private func key(_ name: String, userID: UUID) -> String { "fyrup.steps.\(userID.uuidString).\(name)" }

    func activate(userID: UUID) async {
        if self.userID != userID {
            reset(); self.userID = userID
            healthRequested = defaults.bool(forKey: key("healthRequested", userID: userID))
            showSteps = defaults.bool(forKey: key("show", userID: userID))
            if let saved = defaults.object(forKey: key("goal", userID: userID)) as? Int, (1000...100000).contains(saved) { goal = saved }
        }
        await refresh()
    }

    func reset(clearLocalPreferences: Bool = false) {
        if clearLocalPreferences, let id = userID {
            for name in ["healthRequested", "show", "goal"] { defaults.removeObject(forKey: key(name, userID: id)) }
        }
        generation = UUID(); privacyGeneration = UUID()
        userID = nil; steps = nil; localDate = ""; activeTimezone = ""
        sharingEnabled = nil; isSharingPreferenceCurrent = false; preference = nil
        sharedValues = []; sharedFetchedAt = nil; lastRefresh = nil; lastSyncedAt = nil
        healthRequested = false; showSteps = false; goal = nil; message = nil
        isAuthorizing = false; isChangingSharing = false; isRefreshing = false; queuedRefresh = false
    }

    /// Call only after the user accepts the explanatory screen, never from activation/refresh.
    func connect() async {
        guard !isAuthorizing, let id = userID else { return }
        guard reader.isAvailable else { message = healthStatusText; return }
        let request = generation
        isAuthorizing = true; message = nil
        defer { if generation == request { isAuthorizing = false } }
        do {
            try await reader.requestAccess()
            guard generation == request, userID == id else { return }
            healthRequested = true; showSteps = true
            defaults.set(true, forKey: key("healthRequested", userID: id))
            defaults.set(true, forKey: key("show", userID: id))
            await refresh(force: true)
        } catch {
            if generation == request { message = "Apple Health konnte gerade nicht geöffnet werden. Versuche es erneut." }
        }
    }

    func setShowSteps(_ enabled: Bool) {
        guard let id = userID else { return }
        showSteps = enabled; defaults.set(enabled, forKey: key("show", userID: id))
    }

    /// nil removes the optional goal. This preference never leaves the device.
    func setGoal(_ value: Int?) {
        guard let id = userID else { return }
        if let value {
            guard (1000...100000).contains(value) else { message = "Wähle ein Schrittziel zwischen 1.000 und 100.000."; return }
            goal = value; defaults.set(value, forKey: key("goal", userID: id))
        } else { goal = nil; defaults.removeObject(forKey: key("goal", userID: id)) }
    }

    func setSharing(_ enabled: Bool) async {
        guard !isChangingSharing, let id = userID else { return }
        let request = generation
        privacyGeneration = UUID()
        let privacy = privacyGeneration
        isChangingSharing = true; isSharingPreferenceCurrent = false; lastSyncedAt = nil; message = nil
        do {
            let response = try await repository.setStepSharing(userID: id, enabled: enabled)
            guard generation == request, privacyGeneration == privacy else { return }
            guard response.userID == id, response.sharingEnabled == enabled, response.sharingRevision >= 0 else {
                throw AppError.server
            }
            accept(response)
        } catch {
            if generation == request, privacyGeneration == privacy {
                // An interrupted response might have reached the server. Its actual state is unknown.
                sharingEnabled = nil; preference = nil; isSharingPreferenceCurrent = false
                message = "Die Freigabe wurde nicht bestätigt. Prüfe die Verbindung und versuche es erneut."
            }
        }
        guard generation == request, privacyGeneration == privacy else { return }
        isChangingSharing = false
        if enabled, sharingEnabled == true { await refresh(force: true) }
    }

    /// Call on Today/open/foreground, or force:true for an explicit retry/significant clock change.
    /// One request at a time; a forced request during a query is coalesced into one following refresh.
    func refresh(force: Bool = false) async {
        guard let id = userID else { return }
        let queryNow = now()
        let queryCalendar = StepDay.localCalendar(calendar())
        let day = StepDay.key(for: queryNow, calendar: queryCalendar)
        let timezone = queryCalendar.timeZone.identifier
        let dayChanged = localDate != day || activeTimezone != timezone
        if dayChanged {
            steps = nil; localDate = day; activeTimezone = timezone; lastRefresh = nil; lastSyncedAt = nil
            sharedValues = []; sharedFetchedAt = nil
        }
        if isRefreshing {
            queuedRefresh = queuedRefresh || force || dayChanged
            return
        }
        if !force, let lastRefresh, queryNow.timeIntervalSince(lastRefresh) >= 0,
           queryNow.timeIntervalSince(lastRefresh) < refreshInterval { return }
        let request = generation
        let privacy = privacyGeneration
        lastRefresh = queryNow; isRefreshing = true; message = nil
        await performRefresh(userID: id, request: request, privacy: privacy, queryNow: queryNow, calendar: queryCalendar)
        guard generation == request else { return }
        if StepDay.key(for: now(), calendar: calendar()) != day || calendar().timeZone.identifier != timezone {
            steps = nil; sharedValues = []; sharedFetchedAt = nil
            if !Task.isCancelled { queuedRefresh = true }
        }
        isRefreshing = false
        if queuedRefresh {
            queuedRefresh = false
            await refresh(force: true)
        }
    }

    private func performRefresh(userID id: UUID, request: UUID, privacy: UUID, queryNow: Date, calendar queryCalendar: Calendar) async {
        let day = StepDay.key(for: queryNow, calendar: queryCalendar)
        let timezone = queryCalendar.timeZone.identifier
        func current() -> Bool {
            generation == request && userID == id && !Task.isCancelled &&
            StepDay.key(for: now(), calendar: calendar()) == day && calendar().timeZone.identifier == timezone
        }

        var uploadPreference: StepSharingPreference?
        if !isChangingSharing {
            do {
                let response = try await repository.stepSharingPreference(userID: id)
                guard current() else { return }
                if privacyGeneration == privacy, !isChangingSharing {
                    guard response.userID == id, response.sharingRevision >= 0 else { throw AppError.server }
                    accept(response); uploadPreference = response
                }
            } catch {
                guard current() else { return }
                if privacyGeneration == privacy, !isChangingSharing {
                    isSharingPreferenceCurrent = false
                    message = "Deine Schrittfreigabe konnte nicht geprüft werden. Es werden keine neuen Schritte hochgeladen."
                }
            }
        }
        guard current() else { return }

        if healthRequested {
            let rawCount = try? await reader.todaySteps(now: queryNow, calendar: queryCalendar)
            guard current() else {
                if generation == request {
                    steps = nil; sharedValues = []; sharedFetchedAt = nil
                    if !Task.isCancelled { queuedRefresh = true }
                }
                return
            }
            let count = rawCount.flatMap { (0...StepDay.maximumSteps).contains($0) ? $0 : nil }
            steps = count
            if let uploadPreference, uploadPreference.sharingEnabled, isSharingPreferenceCurrent,
               privacyGeneration == privacy, !isChangingSharing {
                do {
                    let published = try await repository.syncSteps(userID: id, localDate: day, timezone: timezone, steps: count,
                                                                   sharingRevision: uploadPreference.sharingRevision, observedAt: queryNow)
                    guard current(), privacyGeneration == privacy, !isChangingSharing else { return }
                    if published { lastSyncedAt = now() }
                    else {
                        isSharingPreferenceCurrent = false
                        lastSyncedAt = nil
                        message = "Deine Schritte wurden nicht veröffentlicht. Prüfe die aktuelle Freigabe und versuche es später erneut."
                        // One read only, no blind upload retry: a revoked/re-enabled switch has a new revision.
                        if let response = try? await repository.stepSharingPreference(userID: id), current(),
                           privacyGeneration == privacy, !isChangingSharing, response.userID == id, response.sharingRevision >= 0 {
                            accept(response)
                        }
                    }
                } catch {
                    guard current(), privacyGeneration == privacy else { return }
                    lastSyncedAt = nil
                    message = "Deine Schritte konnten gerade nicht synchronisiert werden. Versuche es später erneut."
                }
            }
        }

        do {
            let values = try await repository.sharedSteps()
            guard current() else { return }
            // Server checks owner-local dates and friendship/privacy. No timezone/device data is exposed.
            sharedValues = values.filter { $0.userID != id && (0...StepDay.maximumSteps).contains($0.steps) }
            sharedFetchedAt = now()
        } catch {
            if generation == request { sharedValues = []; sharedFetchedAt = nil }
        }
    }

    private func accept(_ response: StepSharingPreference) {
        preference = response
        sharingEnabled = response.sharingEnabled
        isSharingPreferenceCurrent = true
    }
}
