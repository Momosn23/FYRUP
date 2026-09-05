import XCTest
@testable import FYRUP

@MainActor
final class FriendRevocationTests: XCTestCase {
    func testConfirmedRemovalClearsCrewGroupsAndDiskFeedAndSurvivesRefresh() async throws {
        let repository = DemoRepository()
        let store = AppStore(repository: repository)
        await store.bootstrap()
        let owner = try XCTUnwrap(store.profile?.id)
        defer { FeedCache.clear(userID: owner) }
        let removed = try XCTUnwrap(store.crew.first { $0.profile.username == "max" })
        XCTAssertTrue(FeedCache.load(userID: owner)?.1.contains { $0.id == removed.id } == true)
        await store.removeFriend(removed.profile)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.revokedFriendIDs.contains(removed.id))
        XCTAssertFalse(store.crew.contains { $0.id == removed.id })
        XCTAssertFalse(store.trainingGroups.flatMap(\.members).contains { $0.id == removed.id })
        XCTAssertFalse(FeedCache.load(userID: owner)?.1.contains { $0.id == removed.id } == true)
        await store.refresh()
        XCTAssertFalse(store.crew.contains { $0.id == removed.id })
        await store.logout()
        XCTAssertNil(FeedCache.load(userID: owner))
        XCTAssertTrue(store.revokedFriendIDs.isEmpty)
    }

    func testConfirmedBlockAlsoClosesPrivacyDependentCaches() async throws {
        let store = AppStore(repository: DemoRepository())
        await store.bootstrap()
        let owner = try XCTUnwrap(store.profile?.id)
        defer { FeedCache.clear(userID: owner) }
        let blocked = try XCTUnwrap(store.crew.first)
        let before = store.friendAccessRevision
        await store.block(blocked.profile)
        XCTAssertNil(store.errorMessage)
        XCTAssertGreaterThan(store.friendAccessRevision, before)
        XCTAssertTrue(store.revokedFriendIDs.contains(blocked.id))
        XCTAssertFalse(store.crew.contains { $0.id == blocked.id })
        let plans = await store.workouts.sharedPlans(ownerID: blocked.id)
        XCTAssertNil(plans)
    }
}
