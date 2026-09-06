import Foundation
import XCTest
@testable import FYRUP

final class SupportContactTests: XCTestCase {
    func testSupportAddressAndPreparedEmailURL() throws {
        XCTAssertEqual(FyrupSupportContact.email, "Kundenservice@objektsignal.com")
        let url = try XCTUnwrap(FyrupSupportContact.emailURL())
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, FyrupSupportContact.email)
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "subject" })?.value, "FYRUP Support")
        XCTAssertNil(components.queryItems?.first(where: { $0.name == "body" }))
    }
}
