import Foundation

struct StepSharingPreference: Codable, Equatable, Sendable {
    var userID: UUID
    var sharingEnabled: Bool
    var sharingRevision: Int
    enum CodingKeys: String, CodingKey { case userID = "user_id", sharingEnabled = "sharing_enabled", sharingRevision = "sharing_revision" }
}

struct DailyStepMetric: Codable, Identifiable, Equatable, Sendable {
    var userID: UUID
    var localDate: String
    var steps: Int
    var updatedAt: Date
    var validUntil: Date
    var id: String { "\(userID.uuidString):\(localDate)" }
    enum CodingKeys: String, CodingKey { case steps; case userID = "user_id", localDate = "local_date", updatedAt = "updated_at", validUntil = "valid_until" }
}

enum StepDay {
    static let maximumSteps = 300_000

    static func localCalendar(_ calendar: Calendar) -> Calendar {
        // PostgreSQL local_date is Gregorian even when iOS uses a different display calendar.
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        local.locale = Locale(identifier: "en_US_POSIX")
        return local
    }

    static func key(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = localCalendar(calendar).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func bounds(for date: Date, calendar: Calendar) -> DateInterval {
        let local = localCalendar(calendar)
        let start = local.startOfDay(for: date)
        let end = local.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func count(from value: Double?) -> Int? {
        guard let value, value.isFinite, value >= 0, value <= Double(maximumSteps) else { return nil }
        return Int(value.rounded())
    }
}

protocol StepRepository: Sendable {
    func stepSharingPreference(userID: UUID) async throws -> StepSharingPreference
    func setStepSharing(userID: UUID, enabled: Bool) async throws -> StepSharingPreference
    func syncSteps(userID: UUID, localDate: String, timezone: String, steps: Int?, sharingRevision: Int, observedAt: Date) async throws -> Bool
    func sharedSteps() async throws -> [DailyStepMetric]
}
