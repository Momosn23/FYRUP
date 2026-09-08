import XCTest
@testable import FYRUP

@MainActor final class WeatherStoreTests: XCTestCase {
    private let city = WeatherPlace(name: "Teststadt", latitude: 50, longitude: 7)

    func testNoCityMakesNoRequestAndInvalidCoordinatesAreRejected() async {
        let source = WeatherTestReader(), store = CurrentWeatherStore(reader: WeatherTestReader())
        await store.select(nil)
        XCTAssertNil(store.value)
        let checked = CurrentWeatherStore(reader: source)
        await checked.select(.init(name: "", latitude: .nan, longitude: 400))
        XCTAssertEqual(source.requests, 0); XCTAssertNil(checked.place)
    }

    func testCacheExpiresAtThirtyMinutesNotEveryRedraw() async {
        let source = WeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        await store.select(city); XCTAssertEqual(source.requests, 1); XCTAssertNotNil(store.value)
        source.clock = source.clock.addingTimeInterval(1799)
        await store.refresh(); await store.select(city)
        XCTAssertEqual(source.requests, 1)
        source.clock = source.clock.addingTimeInterval(1)
        await store.refresh(); XCTAssertEqual(source.requests, 2)
    }

    func testVisiblePageMinuteTicksUseCacheThenRenewWithoutReopening() async {
        let source = WeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        await store.select(city)
        for _ in 0..<29 {
            source.clock = source.clock.addingTimeInterval(60)
            await store.refresh()
        }
        XCTAssertEqual(source.requests, 1)
        source.clock = source.clock.addingTimeInterval(60)
        await store.refresh()
        XCTAssertEqual(source.requests, 2)
        XCTAssertEqual(store.value?.receivedAt, source.clock)
    }

    func testOfflineWeatherRecoversAfterBackoffWithoutChangingCity() async {
        let source = WeatherTestReader()
        source.failure = .offline
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        await store.select(city)
        XCTAssertEqual(store.failure, .offline)
        source.failure = nil
        source.clock = source.clock.addingTimeInterval(59)
        await store.refresh()
        XCTAssertEqual(source.requests, 1)
        source.clock = source.clock.addingTimeInterval(1)
        await store.refresh()
        XCTAssertEqual(source.requests, 2)
        XCTAssertNotNil(store.value)
        XCTAssertNil(store.failure)
    }

    func testRemovingPlaceCannotRestoreItFromALateResponse() async {
        let source = DelayedWeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        let pending = Task { await store.select(city) }
        for _ in 0..<100 where source.requests == 0 { await Task.yield() }
        await store.select(nil)
        source.resolve()
        await pending.value
        XCTAssertNil(store.place)
        XCTAssertNil(store.value)
        XCTAssertFalse(store.isLoading)
    }

    func testNewCityNeverShowsOldWeatherAndFailureDoesNotRetryContinuously() async {
        let source = WeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        await store.select(city); XCTAssertNotNil(store.value)
        source.failure = .quota
        await store.select(.init(name: "Andere Stadt", latitude: 49, longitude: 8))
        XCTAssertNil(store.value); XCTAssertEqual(store.failure, .quota)
        await store.refresh(); XCTAssertEqual(source.requests, 2)
        source.clock = source.clock.addingTimeInterval(1800); source.failure = nil
        await store.refresh(); XCTAssertEqual(source.requests, 3); XCTAssertNotNil(store.value)
    }

    func testAccountResetDiscardsPlaceAndCachedData() async {
        let source = WeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        await store.select(city); store.reset()
        XCTAssertNil(store.place); XCTAssertNil(store.value)
        await store.select(city); XCTAssertEqual(source.requests, 2)
    }

    func testParallelRequestsShareOneOperationAndResetRejectsLateResult() async {
        let source = DelayedWeatherTestReader()
        let store = CurrentWeatherStore(reader: source, now: { source.clock })
        let first = Task { await store.select(city) }
        for _ in 0..<100 where source.requests == 0 { await Task.yield() }
        let second = Task { await store.refresh() }
        await Task.yield()
        XCTAssertEqual(source.requests, 1)
        store.reset()
        source.resolve()
        await first.value; await second.value
        XCTAssertNil(store.place); XCTAssertNil(store.value)
    }
}

@MainActor private class WeatherTestReader: CurrentWeatherReading {
    var clock = Date(timeIntervalSince1970: 1_700_000_000)
    var requests = 0
    var failure: WeatherFailure?
    func current(for place: WeatherPlace) async throws -> CurrentWeatherSnapshot {
        requests += 1
        if let failure { throw failure }
        return snapshot()
    }
    func snapshot() -> CurrentWeatherSnapshot {
        .init(observedAt: clock, receivedAt: clock, temperatureCelsius: 18, condition: "Fixture", symbol: "sun.max",
              attributionMark: URL(string: "https://example.invalid/fixture-mark.png")!, attributionLink: URL(string: "https://example.invalid/fixture-attribution")!)
    }
}

@MainActor private final class DelayedWeatherTestReader: WeatherTestReader {
    private var continuation: CheckedContinuation<CurrentWeatherSnapshot, any Error>?
    override func current(for place: WeatherPlace) async throws -> CurrentWeatherSnapshot {
        requests += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func resolve() { continuation?.resume(returning: snapshot()); continuation = nil }
}
