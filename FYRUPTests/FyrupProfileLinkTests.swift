import XCTest
@testable import FYRUP

final class FyrupProfileLinkTests: XCTestCase {
    func testAcceptsStrictProfileLinkAndNormalizesUsername() {
        let link = FyrupProfileLink(username: "Momo_FYRUP")
        XCTAssertEqual(link?.username, "momo_fyrup")
        XCTAssertEqual(link?.url.absoluteString, "fyrup://profile/momo_fyrup")
    }

    func testRejectsCredentialsPortsQueriesFragmentsAndExtraPaths() {
        for raw in ["https://profile/momo", "fyrup://user/momo", "fyrup://name:secret@profile/momo",
                    "fyrup://profile:99/momo", "fyrup://profile/momo?token=x", "fyrup://profile/momo#x",
                    "fyrup://profile/momo/extra", "fyrup://profile/a", "fyrup://profile/mo%20mo"] {
            XCTAssertNil(URL(string: raw).flatMap(FyrupProfileLink.init(url:)), raw)
        }
    }
}
