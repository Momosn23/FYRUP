import Foundation

enum DateLogic {
    static func todayInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: now)!
    }

    static func weekInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: now)!
    }

    static func status(for activities: [Activity], now: Date = Date(), calendar: Calendar = .current) -> Activity? {
        let today = todayInterval(now: now, calendar: calendar)
        return activities.filter { activity in
            if activity.status == .live { return true }
            let reference = activity.startedAt ?? activity.plannedAt ?? activity.endedAt
            return reference.map(today.contains) ?? false
        }.sorted {
            TodayStatus(activity: $0) < TodayStatus(activity: $1)
        }.first
    }

    static func weeklyStreak(completedDates: [Date], goal: Int, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard goal > 0 else { return 0 }
        var streak = 0
        var cursor = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let currentCount = completedDates.filter { calendar.isDate($0, equalTo: now, toGranularity: .weekOfYear) }.count
        if currentCount < goal { cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)! }
        while true {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let count = completedDates.filter(interval.contains).count
            guard count >= goal else { break }
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)!
        }
        return streak
    }
}

private extension TodayStatus {
    init(activity: Activity) {
        switch activity.status {
        case .live: self = .live
        case .planned, .ready: self = .planned
        case .completed: self = .done
        case .cancelled: self = .notYet
        }
    }
}
