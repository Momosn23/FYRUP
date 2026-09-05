import XCTest
import UserNotifications
@testable import FYRUP

@MainActor
final class SystemNotificationAuthorizationTests: XCTestCase {
    func testReadsOnlySendableStatusAcrossActorBoundaryWithoutRequestingPermission() async {
        let rawStatus = await SystemNotificationAuthorization.rawStatus()
        XCTAssertNotNil(UNAuthorizationStatus(rawValue: rawStatus))
        XCTAssertGreaterThanOrEqual(rawStatus, 0)
    }
}
