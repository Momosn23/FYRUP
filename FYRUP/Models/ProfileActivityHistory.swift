import Foundation

/// A view of already-loaded, account-scoped data; never a claim of complete history.
enum ProfileActivityHistory {
    static func own(_ records: [Activity], latest: Activity?, owner: UUID?) -> [Activity] {
        guard let owner else { return [] }
        var seen = Set<UUID>()
        return ([latest].compactMap { $0 } + records)
            .filter { $0.userID == owner && seen.insert($0.id).inserted }
            .sorted { ($0.endedAt ?? $0.startedAt ?? .distantPast) > ($1.endedAt ?? $1.startedAt ?? .distantPast) }
    }

    static func completed(_ records: [Activity], period: Calendar.Component, now: Date, calendar: Calendar) -> [Activity] {
        guard let interval = calendar.dateInterval(of: period, for: now) else { return [] }
        return records.filter { activity in
            guard activity.status == .completed, let ended = activity.endedAt else { return false }
            return interval.start <= ended && ended < interval.end
        }
    }
}
