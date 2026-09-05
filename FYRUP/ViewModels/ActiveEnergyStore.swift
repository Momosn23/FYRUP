import Foundation
import Observation

@MainActor @Observable
final class ActiveEnergyStore {
    private let setup: PersonalSetupStore
    private let reader: any ActiveEnergyReading
    private let now: @MainActor () -> Date
    private let calendar: @MainActor () -> Calendar
    private var generation = UUID()
    private var owner: UUID?
    private var dateKey = ""
    private var timezone = ""
    private var lastRefresh: Date?
    private var amount: Double?
    private(set) var isBusy = false
    private(set) var isRefreshing = false
    private(set) var updatedAt: Date?
    private(set) var errorMessage: String?

    init(setup: PersonalSetupStore, reader: any ActiveEnergyReading = HealthKitEnergyReader(),
         now: @escaping @MainActor () -> Date = { .now }, calendar: @escaping @MainActor () -> Calendar = { .current }) {
        self.setup = setup; self.reader = reader; self.now = now; self.calendar = calendar
    }
    var isAvailable: Bool { reader.isAvailable }
    var kilocalories: Double? {
        guard owner == setup.userID, setup.value?.energyRequested == true,
              dateKey == StepDay.key(for: now(), calendar: calendar()), timezone == calendar().timeZone.identifier else { return nil }
        return amount
    }
    func accountChanged(to userID: UUID?) {
        generation = UUID(); owner = userID; amount = nil; dateKey = ""; timezone = ""
        lastRefresh = nil; updatedAt = nil; isBusy = false; isRefreshing = false; errorMessage = nil
    }
    func connect() async {
        guard !isBusy, let owner, owner == setup.userID, reader.isAvailable else { return }
        let request = generation; isBusy = true; errorMessage = nil
        defer { if generation == request { isBusy = false } }
        do {
            try await reader.requestAccess()
            guard generation == request, self.owner == owner, setup.userID == owner else { return }
            guard setup.update({ $0.energyRequested = true }) else { errorMessage = setup.errorMessage; return }
            await refresh(force: true)
        } catch { if generation == request { errorMessage = "Apple Health konnte nicht geöffnet werden. Versuche es erneut." } }
    }
    func disconnect() {
        guard setup.update({ $0.energyRequested = false }) else { errorMessage = setup.errorMessage; return }
        accountChanged(to: setup.userID)
    }
    func refresh(force: Bool = false) async {
        guard let owner, owner == setup.userID, setup.value?.energyRequested == true, !isRefreshing else { return }
        let date = now(), local = calendar()
        let key = StepDay.key(for: date, calendar: local)
        if key != dateKey || timezone != local.timeZone.identifier { amount = nil; updatedAt = nil; lastRefresh = nil }
        if !force, let lastRefresh, (0..<120).contains(date.timeIntervalSince(lastRefresh)) { return }
        let request = generation; isRefreshing = true; lastRefresh = date; errorMessage = nil
        defer { if generation == request { isRefreshing = false } }
        do {
            let result = try await reader.todayKilocalories(now: date, calendar: local)
            guard generation == request, self.owner == owner, setup.userID == owner,
                  key == StepDay.key(for: now(), calendar: calendar()), local.timeZone == calendar().timeZone else { return }
            amount = result.flatMap { $0.isFinite && (0...50000).contains($0) ? $0 : nil }
            dateKey = key; timezone = local.timeZone.identifier; updatedAt = now()
        } catch {
            if generation == request { amount = nil; updatedAt = nil; errorMessage = "Bewegungsenergie ist gerade nicht verfügbar." }
        }
    }
}
