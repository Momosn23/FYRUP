import XCTest
@testable import FYRUP

final class ProfileActivityHistoryTests: XCTestCase {
    private let owner = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let other = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func activity(at end: Date, user: UUID? = nil) -> Activity {
        Activity(id: UUID(), userID: user ?? owner, sport: .gym, subtype: nil, status: .completed,
                 plannedAt: nil, startedAt: end.addingTimeInterval(-600), endedAt: end,
                 distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
    }
    func testOnlyCurrentOwnerAndLatestDuplicateAreShown() {
        let latest = activity(at: date("2026-09-08T12:00:00Z"))
        var stale = latest; stale.status = .live; stale.endedAt = nil
        let foreign = activity(at: date("2026-09-08T12:00:00Z"), user: other)
        XCTAssertEqual(ProfileActivityHistory.own([stale, foreign, stale], latest: latest, owner: owner), [latest])
        XCTAssertTrue(ProfileActivityHistory.own([latest], latest: latest, owner: nil).isEmpty)
    }
    func testHistorySortsNewestFirstWithoutDuplicatingCounts() {
        let old = activity(at: date("2026-09-01T12:00:00Z"))
        let recent = activity(at: date("2026-09-08T12:00:00Z"))
        XCTAssertEqual(ProfileActivityHistory.own([old, recent, old], latest: nil, owner: owner), [recent, old])
    }
    func testPeriodUsesActualCompletionAndHalfOpenLocalBoundary() {
        let now = date("2026-09-08T12:00:00Z")
        let start = activity(at: date("2026-08-31T22:00:00Z"))
        let end = activity(at: date("2026-09-30T22:00:00Z"))
        let before = activity(at: date("2026-08-31T21:59:59Z"))
        var live = start; live.status = .live
        var unknownEnd = start; unknownEnd.endedAt = nil
        XCTAssertEqual(ProfileActivityHistory.completed([before, start, end, live, unknownEnd], period: .month, now: now, calendar: calendar), [start])
    }
    func testWeekUsesLocalCalendarAcrossDaylightSavingChange() {
        let now = date("2026-03-29T12:00:00Z")
        let start = activity(at: date("2026-03-22T23:00:00Z"))
        let last = activity(at: date("2026-03-29T21:59:59Z"))
        let next = activity(at: date("2026-03-29T22:00:00Z"))
        XCTAssertEqual(ProfileActivityHistory.completed([start, last, next], period: .weekOfYear, now: now, calendar: calendar), [start, last])
    }

    func testProfileWeekMatchesScheduleAndExcludesOtherWeeks() {
        let now = date("2026-09-08T12:00:00Z")
        let monday = activity(at: date("2026-09-07T12:00:00Z"))
        let previous = activity(at: date("2026-09-06T12:00:00Z"))
        let next = activity(at: date("2026-09-14T12:00:00Z"))
        var missingEnd = monday; missingEnd.endedAt = nil
        var planned = monday; planned.status = .planned; planned.plannedAt = date("2026-09-13T12:00:00Z")
        var laterPlan = planned; laterPlan.plannedAt = date("2026-09-14T12:00:00Z")
        let week = ProfileWeekSnapshot(activities: [monday, monday, previous, next, missingEnd, planned, laterPlan], now: now, timezone: calendar.timeZone)
        XCTAssertEqual(week.days, TrainingWeekLogic.days(containing: now, calendar: calendar))
        XCTAssertEqual(week.days.map { TrainingWeekLogic.weekday($0, calendar: week.calendar) }, Array(1...7))
        XCTAssertEqual(week.completedDays, [calendar.startOfDay(for: monday.endedAt!)])
        XCTAssertEqual(week.plannedDays, [calendar.startOfDay(for: planned.plannedAt!)])
    }

    func testProfileWeekUsesLocalMidnightAcrossDST() {
        let now = date("2026-03-29T12:00:00Z")
        let start = activity(at: date("2026-03-22T23:00:00Z"))
        let sunday = activity(at: date("2026-03-29T21:59:59Z"))
        let next = activity(at: date("2026-03-29T22:00:00Z"))
        let week = ProfileWeekSnapshot(activities: [start, sunday, next], now: now, timezone: calendar.timeZone)
        XCTAssertEqual(week.days.count, 7)
        XCTAssertEqual(week.days.first, calendar.startOfDay(for: start.endedAt!))
        XCTAssertEqual(week.days.last, calendar.startOfDay(for: sunday.endedAt!))
        XCTAssertEqual(week.completedDays.count, 2)
        XCTAssertFalse(week.completedDays.contains(calendar.startOfDay(for: next.endedAt!)))
    }
}
