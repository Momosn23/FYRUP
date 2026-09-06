import XCTest
@testable import FYRUP

@MainActor
final class AppStoreConnectivityTests: XCTestCase {
    func testReconnectReloadsTodayWithoutDiscardingCachedFeed() async {
        let repository = DemoRepository()
        let store = AppStore(repository: repository)
        await store.bootstrap()
        XCTAssertEqual(store.route, .main)
        let originalCrew = store.crew

        await repository.simulateUnavailableFeed(true)
        await store.refresh()
        XCTAssertEqual(store.crew, originalCrew)
        XCTAssertTrue(store.errorMessage?.contains("Kein Internet") == true)

        await repository.simulateUnavailableFeed(false)
        await store.handleNetworkReturn()
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.crew, originalCrew)
        XCTAssertTrue(store.isActivityCurrent)
    }
}
