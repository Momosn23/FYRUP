import XCTest
@testable import FYRUP

final class DateLogicTests: XCTestCase {
    private var calendar: Calendar { var value = Calendar(identifier: .iso8601); value.timeZone = TimeZone(identifier: "Europe/Berlin")!; return value }

    func testYesterdayIsNotToday() {
        let now = Date(timeIntervalSince1970: 1_788_540_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let activity = Activity(id: UUID(), userID: UUID(), sport: .gym, subtype: nil, status: .completed, plannedAt: nil, startedAt: yesterday, endedAt: yesterday, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        XCTAssertNil(DateLogic.status(for: [activity], now: now, calendar: calendar))
    }

    func testLiveWinsOverPlannedAndDone() {
        let now = Date()
        let user = UUID()
        let done = Activity(id: UUID(), userID: user, sport: .running, subtype: nil, status: .completed, plannedAt: nil, startedAt: now.addingTimeInterval(-2000), endedAt: now.addingTimeInterval(-1000), distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        let live = Activity(id: UUID(), userID: user, sport: .gym, subtype: nil, status: .live, plannedAt: nil, startedAt: now, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        XCTAssertEqual(DateLogic.status(for: [done, live], now: now, calendar: calendar)?.id, live.id)
    }

    func testWorkoutFinishingAfterMidnightCountsForToday() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 0, minute: 20))!
        let started = calendar.date(byAdding: .minute, value: -40, to: now)!
        let ended = calendar.date(byAdding: .minute, value: -5, to: now)!
        let activity = Activity(id: UUID(), userID: UUID(), sport: .running, subtype: nil, status: .completed, plannedAt: nil, startedAt: started, endedAt: ended, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
        XCTAssertEqual(DateLogic.status(for: [activity], now: now, calendar: calendar)?.id, activity.id)
    }

    func testNearestPlannedWorkoutWins() {
        // Keep both candidates inside the same local day. Using the wall clock made
        // this test fail shortly before midnight when the planned times crossed
        // into tomorrow, even though the production rule correctly shows only
        // today's status.
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12))!
        let later = Activity(id: UUID(), userID: UUID(), sport: .gym, subtype: "Pull", status: .planned, plannedAt: now.addingTimeInterval(4_000), startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: UUID())
        let next = Activity(id: UUID(), userID: later.userID, sport: .running, subtype: nil, status: .planned, plannedAt: now.addingTimeInterval(2_000), startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: UUID())
        XCTAssertEqual(DateLogic.status(for: [later, next], now: now, calendar: calendar)?.id, next.id)
    }

    func testWeeklyGoalStreakSkipsIncompleteCurrentWeek() {
        let now = Date()
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)!
        let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start)!
        let dates = (0..<4).map { calendar.date(byAdding: .day, value: $0, to: previous)! }
        XCTAssertEqual(DateLogic.weeklyStreak(completedDates: dates, goal: 4, now: now, calendar: calendar), 1)
    }

    func testTimerFormatting() {
        XCTAssertEqual(LiveTimer.format(1938), "00:32:18")
        XCTAssertEqual(LiveTimer.format(-5), "00:00:00")
        XCTAssertEqual(LiveTimer.format(59), "00:00:59")
        XCTAssertEqual(LiveTimer.format(3600), "01:00:00")
    }
}
