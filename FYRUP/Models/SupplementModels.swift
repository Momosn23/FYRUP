import Foundation

/// Product bounds for a user-authored checklist, never dosage recommendations.
enum SupplementLimits {
    static let planCount = 20
    static let slotCount = 4
    static let intervals = [15, 30, 60, 120, 180]
    static let maxRepeats = 3
}

struct SupplementSlot: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var minute: Int
    var hour: Int { minute / 60 }
    var minuteOfHour: Int { minute % 60 }
    var clockLabel: String { String(format: "%02d:%02d", hour, minuteOfHour) }
}

struct SupplementPlan: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var ownerID: UUID
    var revision = 0
    var name: String
    var weekdays = Array(1...7)
    var slots: [SupplementSlot] = [.init(minute: 9 * 60)]
    var isPaused = false
    var isArchived = false
    var remindersEnabled = false
    var repeatMinutes = 60
    /// Extra reminders after the first, not additional intended intakes.
    var repeatCount = 0

    enum CodingKeys: String, CodingKey {
        case id, revision, name, weekdays, slots
        case ownerID = "owner_id", isPaused = "is_paused", isArchived = "is_archived"
        case remindersEnabled = "reminders_enabled", repeatMinutes = "repeat_minutes", repeatCount = "repeat_count"
    }

    var validationMessage: String? {
        guard (0..<1_000_000_000).contains(revision),
              (1...60).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count) else { return "Gib einen Namen mit 1–60 Zeichen ein." }
        guard !weekdays.isEmpty, weekdays.count <= 7, Set(weekdays).count == weekdays.count,
              weekdays.allSatisfy({ (1...7).contains($0) }) else { return "Wähle mindestens einen Wochentag." }
        guard (1...SupplementLimits.slotCount).contains(slots.count), Set(slots.map(\.id)).count == slots.count,
              Set(slots.map(\.minute)).count == slots.count, slots.allSatisfy({ (0..<1440).contains($0.minute) }) else { return "Wähle 1–4 unterschiedliche Uhrzeiten." }
        guard SupplementLimits.intervals.contains(repeatMinutes), (0...SupplementLimits.maxRepeats).contains(repeatCount) else { return "Wähle einen Abstand und höchstens drei zusätzliche Erinnerungen." }
        return nil
    }
}

struct SupplementSettings: Codable, Equatable, Sendable {
    var revision = 0
    var timezone: String
    var quietEnabled = true
    var quietStart = 22 * 60
    var quietEnd = 8 * 60
    enum CodingKeys: String, CodingKey {
        case revision, timezone
        case quietEnabled = "quiet_enabled", quietStart = "quiet_start", quietEnd = "quiet_end"
    }
    var isValid: Bool {
        (0..<1_000_000_000).contains(revision) && TimeZone(identifier: timezone) != nil
            && (0..<1440).contains(quietStart) && (0..<1440).contains(quietEnd)
            && (!quietEnabled || quietStart != quietEnd)
    }
    func isQuiet(minute: Int) -> Bool {
        guard quietEnabled else { return false }
        if quietStart < quietEnd { return quietStart <= minute && minute < quietEnd }
        return minute >= quietStart || minute < quietEnd
    }
}

enum SupplementDoseStatus: String, Codable, CaseIterable, Sendable {
    case open, taken, skipped
    var title: String {
        switch self { case .open: "Offen"; case .taken: "Genommen"; case .skipped: "Übersprungen" }
    }
}

struct SupplementDose: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var ownerID: UUID
    var planID: UUID
    var slotID: UUID
    var day: String
    var dueAt: Date
    var status: SupplementDoseStatus
    var revision: Int
    var changedAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, day, status, revision
        case ownerID = "owner_id", planID = "plan_id", slotID = "slot_id", dueAt = "due_at", changedAt = "changed_at"
    }
}

struct SupplementSnapshot: Codable, Equatable, Sendable {
    var ownerID: UUID
    var serverNow: Date
    var day: String
    var settings: SupplementSettings
    var plans: [SupplementPlan]
    var doses: [SupplementDose]
    enum CodingKeys: String, CodingKey {
        case day, settings, plans, doses
        case ownerID = "owner_id", serverNow = "server_now"
    }

    func isValid(for owner: UUID) -> Bool {
        guard ownerID == owner, settings.isValid, plans.count <= SupplementLimits.planCount,
              Set(plans.map(\.id)).count == plans.count, Set(doses.map(\.id)).count == doses.count,
              plans.allSatisfy({ $0.ownerID == owner && $0.validationMessage == nil }),
              day == SupplementDay.key(serverNow, timezone: settings.timezone) else { return false }
        var identities = Set<String>()
        return doses.allSatisfy { dose in
            guard dose.ownerID == owner, dose.day == day, (0..<1_000_000_000).contains(dose.revision),
                  dose.dueAt.timeIntervalSince1970.isFinite,
                  dose.day == SupplementDay.key(dose.dueAt, timezone: settings.timezone),
                  let plan = plans.first(where: { $0.id == dose.planID }),
                  !plan.isArchived, !plan.isPaused, plan.slots.contains(where: { $0.id == dose.slotID }),
                  SupplementDay.weekday(dose.dueAt, timezone: settings.timezone).map(plan.weekdays.contains) == true,
                  (dose.status == .open) == (dose.changedAt == nil),
                  dose.changedAt.map({ $0.timeIntervalSince1970.isFinite && $0 <= serverNow }) ?? true else { return false }
            return identities.insert("\(dose.planID):\(dose.slotID):\(dose.day)").inserted
        }
    }
}

struct SupplementDoseMutation: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    let doseID: UUID
    let status: SupplementDoseStatus
    let expectedRevision: Int
    enum CodingKeys: String, CodingKey {
        case status
        case id = "request_id", doseID = "dose_id", expectedRevision = "expected_revision"
    }
}

enum SupplementDay {
    static func calendar(timezone: String) -> Calendar? {
        guard let zone = TimeZone(identifier: timezone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone; calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
    static func key(_ date: Date, timezone: String) -> String? {
        guard date.timeIntervalSince1970.isFinite, let calendar = calendar(timezone: timezone) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    static func weekday(_ date: Date, timezone: String) -> Int? {
        guard date.timeIntervalSince1970.isFinite, let calendar = calendar(timezone: timezone) else { return nil }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}

protocol SupplementRepository: Sendable {
    func supplements(timezone: String) async throws -> SupplementSnapshot
    func saveSupplement(_ plan: SupplementPlan) async throws -> SupplementPlan
    func saveSupplementSettings(_ settings: SupplementSettings) async throws -> SupplementSettings
    func setSupplementDose(_ mutation: SupplementDoseMutation) async throws -> SupplementDose
}

extension SupplementRepository {
    func supplements(timezone: String) async throws -> SupplementSnapshot { throw AppError.server }
    func saveSupplement(_ plan: SupplementPlan) async throws -> SupplementPlan { throw AppError.server }
    func saveSupplementSettings(_ settings: SupplementSettings) async throws -> SupplementSettings { throw AppError.server }
    func setSupplementDose(_ mutation: SupplementDoseMutation) async throws -> SupplementDose { throw AppError.server }
}
