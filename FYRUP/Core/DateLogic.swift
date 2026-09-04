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
            let reference: Date? = switch activity.status {
            case .completed: activity.endedAt ?? activity.startedAt
            case .planned, .ready: activity.plannedAt
            case .live: activity.startedAt
            case .cancelled: nil
            }
            return reference.map(today.contains) ?? false
        }.sorted {
            let left = TodayStatus(activity: $0)
            let right = TodayStatus(activity: $1)
            if left != right { return left < right }
            switch left {
            case .live: return ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
            case .planned: return ($0.plannedAt ?? .distantFuture) < ($1.plannedAt ?? .distantFuture)
            case .done: return ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast)
            case .notYet: return false
            }
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
