import Foundation

actor DemoSupplementStorage {
    private struct Receipt: Codable { let change: SupplementDoseMutation }
    private struct State: Codable {
        let owner: UUID
        var settings: SupplementSettings
        var plans: [SupplementPlan] = []
        var doses: [SupplementDose] = []
        var receipts: [Receipt] = []
    }
    private let suiteName: String?
    private var memory: [UUID: State] = [:]
    init(persistenceSuiteName: String? = nil) { suiteName = persistenceSuiteName }
    private func key(_ owner: UUID) -> String { "supplements.v1.\(owner.uuidString)" }
    private func state(owner: UUID, timezone: String) throws -> State {
        if let suiteName, let data = UserDefaults(suiteName: suiteName)?.object(forKey: key(owner)) {
            guard let data = data as? Data else { throw AppError.server }
            let value = try JSONDecoder().decode(State.self, from: data)
            guard value.owner == owner, value.settings.isValid, value.plans.allSatisfy({ $0.ownerID == owner && $0.validationMessage == nil }),
                  value.doses.allSatisfy({ $0.ownerID == owner }) else { throw AppError.server }
            return value
        }
        if let value = memory[owner] { return value }
        guard TimeZone(identifier: timezone) != nil else { throw AppError.validation("Unbekannte Zeitzone") }
        var settings = SupplementSettings(timezone: timezone); settings.revision = 1
        return State(owner: owner, settings: settings)
    }
    private func persist(_ value: State) throws {
        let data = try JSONEncoder().encode(value)
        if let suiteName {
            guard let defaults = UserDefaults(suiteName: suiteName) else { throw AppError.server }
            defaults.set(data, forKey: key(value.owner))
        }
        memory[value.owner] = value
    }
    private func materialize(_ value: inout State, now: Date) throws {
        guard let calendar = SupplementDay.calendar(timezone: value.settings.timezone),
              let day = SupplementDay.key(now, timezone: value.settings.timezone),
              let weekday = SupplementDay.weekday(now, timezone: value.settings.timezone) else { throw AppError.server }
        for plan in value.plans where !plan.isPaused && !plan.isArchived && plan.weekdays.contains(weekday) {
            for slot in plan.slots {
                // nextDate preserves the minute inside a missing spring hour; date(bySettingHour:)
                // was observed to round 02:30 to 03:00 in the native iOS test.
                guard let due = calendar.nextDate(after: calendar.startOfDay(for: now).addingTimeInterval(-1),
                                              matching: DateComponents(hour: slot.hour, minute: slot.minuteOfHour, second: 0),
                                              matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .last),
                      SupplementDay.key(due, timezone: value.settings.timezone) == day else { throw AppError.server }
                if let index = value.doses.firstIndex(where: { $0.planID == plan.id && $0.slotID == slot.id && $0.day == day }) {
                    value.doses[index].dueAt = due
                } else {
                    value.doses.append(SupplementDose(id: UUID(), ownerID: value.owner, planID: plan.id, slotID: slot.id,
                                                     day: day, dueAt: due, status: .open, revision: 1, changedAt: nil))
                }
            }
        }
    }
    func snapshot(owner: UUID, timezone: String, now: Date) throws -> SupplementSnapshot {
        var value = try state(owner: owner, timezone: timezone)
        try materialize(&value, now: now); try persist(value)
        let day = SupplementDay.key(now, timezone: value.settings.timezone)!
        let weekday = SupplementDay.weekday(now, timezone: value.settings.timezone)!
        let plans = value.plans.filter { !$0.isArchived }.sorted { $0.name < $1.name }
        let doses = value.doses.filter { dose in
            dose.day == day && plans.contains { plan in
                plan.id == dose.planID && !plan.isPaused && plan.weekdays.contains(weekday) && plan.slots.contains { $0.id == dose.slotID }
            }
        }.sorted { $0.dueAt < $1.dueAt }
        let result = SupplementSnapshot(ownerID: owner, serverNow: now, day: day, settings: value.settings, plans: plans, doses: doses)
        guard result.isValid(for: owner) else { throw AppError.server }
        return result
    }
    func save(_ plan: SupplementPlan, owner: UUID, now: Date) throws -> SupplementPlan {
        guard plan.ownerID == owner, plan.validationMessage == nil else { throw AppError.authentication }
        var value = try state(owner: owner, timezone: TimeZone.current.identifier)
        let previous = value.plans.first { $0.id == plan.id }
        guard (previous?.revision ?? 0) == plan.revision else { throw AppError.conflict("Eintrag inzwischen geändert") }
        guard plan.isArchived || value.plans.filter({ !$0.isArchived && $0.id != plan.id }).count < SupplementLimits.planCount else { throw AppError.validation("Höchstens 20 Einträge") }
        var saved = plan; saved.revision += 1; saved.name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines); saved.weekdays.sort()
        value.plans.removeAll { $0.id == plan.id }; value.plans.append(saved)
        try materialize(&value, now: now); try persist(value); return saved
    }
    func saveSettings(_ settings: SupplementSettings, owner: UUID) throws -> SupplementSettings {
        var value = try state(owner: owner, timezone: settings.timezone)
        guard settings.isValid, settings.timezone == value.settings.timezone, settings.revision == value.settings.revision else { throw AppError.conflict("Ruhezeiten inzwischen geändert") }
        var saved = settings; saved.revision += 1; value.settings = saved
        try persist(value); return saved
    }
    func mark(_ change: SupplementDoseMutation, owner: UUID, now: Date) throws -> SupplementDose {
        var value = try state(owner: owner, timezone: TimeZone.current.identifier)
        guard let index = value.doses.firstIndex(where: { $0.id == change.doseID && $0.ownerID == owner }) else { throw AppError.authentication }
        if let receipt = value.receipts.first(where: { $0.change.id == change.id }) {
            guard receipt.change == change else { throw AppError.conflict("Vormerkung wurde verändert") }
            return value.doses[index]
        }
        if value.doses[index].status != change.status {
            guard value.doses[index].revision == change.expectedRevision else { throw AppError.conflict("Eintrag inzwischen geändert") }
            value.doses[index].status = change.status; value.doses[index].revision += 1
            value.doses[index].changedAt = change.status == .open ? nil : now
        }
        value.receipts.append(Receipt(change: change)); try persist(value); return value.doses[index]
    }
    func delete(owner: UUID) {
        if let suiteName { UserDefaults(suiteName: suiteName)?.removeObject(forKey: key(owner)) }
        memory[owner] = nil
    }
}

extension DemoRepository {
    func supplements(timezone: String) async throws -> SupplementSnapshot {
        try await supplementStorage.snapshot(owner: meID, timezone: timezone, now: currentDemoTime())
    }
    func saveSupplement(_ plan: SupplementPlan) async throws -> SupplementPlan {
        try await supplementStorage.save(plan, owner: meID, now: currentDemoTime())
    }
    func saveSupplementSettings(_ settings: SupplementSettings) async throws -> SupplementSettings {
        try await supplementStorage.saveSettings(settings, owner: meID)
    }
    func setSupplementDose(_ mutation: SupplementDoseMutation) async throws -> SupplementDose {
        try await supplementStorage.mark(mutation, owner: meID, now: currentDemoTime())
    }
}
