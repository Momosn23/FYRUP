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

/// Same Monday-based local week as Today and the weekly schedule.
/// Historical records outside this interval must not inflate the strip count.
struct ProfileWeekSnapshot {
    let calendar: Calendar
    let days: [Date]
    let completedDays: Set<Date>
    let plannedDays: Set<Date>

    init(activities: [Activity], now: Date, timezone: TimeZone = .current) {
        let calendar = TrainingWeekLogic.calendar(timezone: timezone)
        self.calendar = calendar
        days = TrainingWeekLogic.days(containing: now, calendar: calendar)
        let visibleDays = Set(days)
        completedDays = Set(activities.compactMap { activity -> Date? in
            guard activity.status == .completed, let end = activity.endedAt else { return nil }
            let day = calendar.startOfDay(for: end)
            return visibleDays.contains(day) ? day : nil
        })
        plannedDays = Set(activities.compactMap { activity -> Date? in
            guard [.planned, .ready].contains(activity.status), let start = activity.plannedAt else { return nil }
            let day = calendar.startOfDay(for: start)
            return visibleDays.contains(day) ? day : nil
        })
    }
}
