import XCTest
@testable import FYRUP

final class HomeAndRestTests: XCTestCase {
    private func local(_ hour: Int, _ minute: Int = 0, zone: String = "Europe/Berlin") -> (Date, Calendar) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: zone)!
        return (calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: hour, minute: minute))!, calendar)
    }
    func testGreetingAt1745IsNotMorning() {
        let (date, calendar) = local(17, 45)
        XCTAssertEqual(HomePresentation.greeting(at: date, calendar: calendar), "Hallo")
    }
    func testGreetingUsesLocalClockAndBoundaries() {
        for (hour, expected) in [(0, "Schön, dass du da bist"), (4, "Schön, dass du da bist"), (5, "Guten Morgen"), (10, "Guten Morgen"), (11, "Hallo"), (17, "Hallo"), (18, "Guten Abend"), (22, "Guten Abend"), (23, "Schön, dass du da bist")] {
            for zone in ["Europe/Berlin", "America/New_York", "Asia/Tokyo"] {
                let (date, calendar) = local(hour, zone: zone)
                XCTAssertEqual(HomePresentation.greeting(at: date, calendar: calendar), expected)
            }
        }
    }
    func testRestClockSurvivesBackgroundAndNeverBecomesNegative() {
        let start = Date(timeIntervalSince1970: 1000)
        let clock = WorkoutRestClock(activityID: UUID(), startedAt: start, duration: 90)
        XCTAssertEqual(clock.remaining(at: start), 90)
        XCTAssertEqual(clock.remaining(at: start.addingTimeInterval(45.2)), 45)
        XCTAssertEqual(clock.progress(at: start.addingTimeInterval(45)), 0.5)
        XCTAssertEqual(clock.remaining(at: start.addingTimeInterval(90)), 0)
        XCTAssertEqual(clock.remaining(at: start.addingTimeInterval(90000)), 0)
        XCTAssertEqual(clock.remaining(at: start.addingTimeInterval(-90000)), 90)
        XCTAssertEqual(clock.remaining(at: Date(timeIntervalSince1970: -Double.greatestFiniteMagnitude)), 90)
    }
    func testInvalidRestClockCannotCreateNonsense() {
        for duration in [-1, 0, 14, 601, Int.max] {
            let clock = WorkoutRestClock(activityID: UUID(), startedAt: .now, duration: duration)
            XCTAssertFalse(clock.isValid); XCTAssertEqual(clock.remaining(at: .now), 0)
        }
    }
    func testLiveLinksOnlyRecognizeTheSpecificRoute() {
        let id = UUID()
        for action in [SessionLiveAction.open, .rest, .setEntry] {
            let link = SessionLiveLink(url: SessionLiveLink.url(sessionID: id, action: action))
            XCTAssertEqual(link?.sessionID, id); XCTAssertEqual(link?.action, action)
            XCTAssertEqual(link?.opensRest, action == .rest)
        }
        XCTAssertEqual(SessionLiveLink(url: SessionLiveLink.url(sessionID: id, opensRest: true))?.action, .rest)
        for text in ["https://live/\(id)", "fyrup://other/\(id)", "fyrup://live/not-a-uuid", "fyrup://live/\(id)/extra", "fyrup://live/\(id)?action=finish", "fyrup://live/\(id)?action=rest&action=rest", "fyrup://live/\(id)?action=set&action=set", "fyrup://live/\(id)?action=open", "fyrup://secret@live/\(id)", "fyrup://live:123/\(id)", "fyrup://live/\(id)#finish"] {
            XCTAssertNil(SessionLiveLink(url: URL(string: text)!))
        }
    }
}

@MainActor
final class WorkoutRestStoreTests: XCTestCase {
    func testRestPersistsAcrossStoreRecreationButIsIsolatedByAccount() {
        let suite = "app.fyrup.tests.rest.\(UUID())", owner = UUID(), other = UUID(), session = UUID()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutRestStore(defaults: defaults)
        store.activate(userID: owner); store.selectDuration(120); store.start(activityID: session, now: Date(timeIntervalSince1970: 1000))
        let restored = WorkoutRestStore(defaults: defaults); restored.activate(userID: owner)
        XCTAssertEqual(restored.selectedDuration, 120); XCTAssertEqual(restored.clock?.remaining(at: Date(timeIntervalSince1970: 1075)), 45)
        restored.activate(userID: other); XCTAssertNil(restored.clock); XCTAssertEqual(restored.selectedDuration, 90)
        restored.activate(userID: owner); XCTAssertEqual(restored.clock?.activityID, session)
        restored.stop(activityID: UUID()); XCTAssertNotNil(restored.clock)
        restored.stop(activityID: session); XCTAssertNil(restored.clock)
        restored.activate(userID: nil); restored.activate(userID: owner); XCTAssertNil(restored.clock)
    }
    func testInvalidAndSignedOutCommandsDoNotPersist() {
        let suite = "app.fyrup.tests.rest.invalid.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutRestStore(defaults: defaults)
        store.start(activityID: UUID()); XCTAssertNil(store.clock)
        store.activate(userID: UUID()); store.selectDuration(0); XCTAssertEqual(store.selectedDuration, 90)
        store.selectDuration(600); XCTAssertEqual(store.selectedDuration, 600)
        store.start(activityID: UUID()); store.clearDeletedAccount(); XCTAssertNil(store.clock); XCTAssertNil(store.userID)
    }

    func testRestCanBeExtendedAndPersistsTheNewEndTime() {
        let suite = "app.fyrup.tests.rest.extend.\(UUID())", owner = UUID(), session = UUID()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkoutRestStore(defaults: defaults)
        store.activate(userID: owner); store.selectDuration(90)
        store.start(activityID: session, now: Date(timeIntervalSince1970: 1_000))

        store.extend(activityID: UUID(), by: 15)
        XCTAssertEqual(store.clock?.duration, 90)
        store.extend(activityID: session, by: 15)
        XCTAssertEqual(store.clock?.duration, 105)
        XCTAssertEqual(store.clock?.remaining(at: Date(timeIntervalSince1970: 1_050)), 55)

        let restored = WorkoutRestStore(defaults: defaults)
        restored.activate(userID: owner)
        XCTAssertEqual(restored.clock?.duration, 105)
        XCTAssertEqual(restored.clock?.endsAt, Date(timeIntervalSince1970: 1_105))
    }
}
