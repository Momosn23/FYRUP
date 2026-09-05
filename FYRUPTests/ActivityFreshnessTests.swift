import XCTest
@testable import FYRUP

@MainActor
final class ActivityFreshnessTests: XCTestCase {
    func testFailedRefreshCannotResurrectCompletedActivityFromCache() async throws {
        let owner = UUID(), repository = DemoRepository(userID: owner)
        defer { FeedCache.clear(userID: owner) }
        let store = AppStore(repository: repository); await store.bootstrap()
        await store.start(sport: .running, subtype: nil)
        let started = try XCTUnwrap(store.myActivity)
        XCTAssertEqual(started.status, .live); XCTAssertTrue(store.isActivityCurrent)
        XCTAssertTrue(store.intervals.start(activity: started, configuration: .init(workSeconds: 30, recoverySeconds: 15, rounds: 3)))
        await repository.simulateUnavailableFeed(true)
        let completed = await store.finish(distanceMeters: nil)
        XCTAssertEqual(completed?.status, .completed)
        XCTAssertEqual(store.myActivity?.status, .completed, "The old LIVE cache must not replace the confirmed completion")
        XCTAssertTrue(store.isActivityCurrent); XCTAssertNil(store.intervals.clock)
        XCTAssertEqual(FeedCache.load(userID: owner)?.0?.status, .completed)
    }

    func testFailedRefreshCannotResurrectCancelledActivityFromCache() async throws {
        let owner = UUID(), repository = DemoRepository(userID: owner)
        defer { FeedCache.clear(userID: owner) }
        let store = AppStore(repository: repository); await store.bootstrap()
        await store.start(sport: .gym, subtype: nil)
        let started = try XCTUnwrap(store.myActivity)
        store.rest.start(activityID: started.id)
        await repository.simulateUnavailableFeed(true); await store.cancelCurrent()
        XCTAssertNil(store.myActivity); XCTAssertNil(store.rest.clock); XCTAssertTrue(store.isActivityCurrent)
        XCTAssertNil(FeedCache.load(userID: owner)?.0)
    }

    func testOfflineColdStartCacheIsNotAuthoritativeUntilSuccessfulRead() async throws {
        let owner = UUID(), repository = DemoRepository(userID: owner)
        defer { FeedCache.clear(userID: owner) }
        let first = AppStore(repository: repository); await first.bootstrap(); await first.start(sport: .running, subtype: nil)
        let live = try XCTUnwrap(first.myActivity)
        await repository.simulateUnavailableFeed(true)
        let cold = AppStore(repository: repository); await cold.bootstrap()
        XCTAssertEqual(cold.myActivity?.id, live.id); XCTAssertFalse(cold.isActivityCurrent)
        await repository.simulateUnavailableFeed(false); await cold.refresh()
        XCTAssertTrue(cold.isActivityCurrent)
        await cold.logout(); XCTAssertFalse(cold.isActivityCurrent)
    }
}
