import XCTest
@testable import FYRUP

@MainActor
final class AppStoreConnectivityTests: XCTestCase {
    func testTemporaryProfileReadFailureDoesNotDiscardRestoredLogin() async {
        let repository = DemoRepository()
        await repository.simulateProfileReadFailure(.offline)
        let store = AppStore(repository: repository)
        await store.bootstrap()
        XCTAssertEqual(store.route, .loading)
        XCTAssertEqual(store.session?.userID, DemoRepository.defaultUserID)
        XCTAssertNil(store.errorMessage)
        await repository.simulateProfileReadFailure(nil)
        await store.handleNetworkReturn()
        XCTAssertEqual(store.route, .main)
        XCTAssertEqual(store.profile?.id, DemoRepository.defaultUserID)
        XCTAssertNil(store.errorMessage)
    }

    func testInvalidProfileAuthorizationStillRequiresLogin() async {
        let repository = DemoRepository()
        await repository.simulateProfileReadFailure(.authentication)
        let store = AppStore(repository: repository)
        await store.bootstrap()
        XCTAssertEqual(store.route, .signedOut)
        XCTAssertNil(store.session)
        XCTAssertEqual(store.errorMessage, AppError.authentication.errorDescription)
    }

    func testNetworkReturnAndInterfaceSwitchRequestRefreshButUnchangedPathDoesNot() {
        XCTAssertTrue(ConnectivityMonitor.shouldReconnect(wasAvailable: false, isAvailable: true, interfacesChanged: false))
        XCTAssertTrue(ConnectivityMonitor.shouldReconnect(wasAvailable: true, isAvailable: true, interfacesChanged: true))
        XCTAssertFalse(ConnectivityMonitor.shouldReconnect(wasAvailable: true, isAvailable: true, interfacesChanged: false))
        XCTAssertFalse(ConnectivityMonitor.shouldReconnect(wasAvailable: true, isAvailable: false, interfacesChanged: true))
        XCTAssertFalse(ConnectivityMonitor.shouldReconnect(wasAvailable: nil, isAvailable: true, interfacesChanged: true))
    }

    func testReconnectReloadsTodayWithoutDiscardingCachedFeed() async {
        let repository = DemoRepository()
        let store = AppStore(repository: repository)
        await store.bootstrap()
        XCTAssertEqual(store.route, .main)
        let originalCrew = store.crew

        await repository.simulateUnavailableFeed(true)
        await store.refresh()
        XCTAssertEqual(store.crew, originalCrew)
        XCTAssertNil(store.errorMessage, "Automatische Aktualisierungen bleiben bei einem vorübergehenden Netzausfall still.")

        await repository.simulateUnavailableFeed(false)
        await store.handleNetworkReturn()
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.crew, originalCrew)
        XCTAssertTrue(store.isActivityCurrent)
    }

    func testBackgroundRetryDoesNotTurnAnUnconfirmedWriteIntoApparentSuccess() async {
        let repository = DemoRepository()
        let store = AppStore(repository: repository)
        await store.bootstrap()
        store.errorMessage = AppError.network.errorDescription
        await repository.simulateUnavailableFeed(true)
        await store.refresh()
        XCTAssertEqual(store.errorMessage, AppError.network.errorDescription)
        await repository.simulateUnavailableFeed(false)
        await store.handleNetworkReturn()
        XCTAssertEqual(store.errorMessage, AppError.network.errorDescription, "Do not erase an explicit failed-save result from a background task")
    }
}
