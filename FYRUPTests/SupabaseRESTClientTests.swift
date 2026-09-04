import XCTest
@testable import FYRUP

final class SupabaseRESTClientTests: XCTestCase {
    func testGrantTypeRemainsAQueryParameter() throws {
        let url = SupabaseRESTClient.requestURL(
            baseURL: try XCTUnwrap(URL(string: "https://example.supabase.co")),
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")]
        )

        XCTAssertEqual(url.path, "/auth/v1/token")
        XCTAssertEqual(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "grant_type", value: "id_token")]
        )
        XCTAssertFalse(url.absoluteString.contains("token%3F"))
    }
}
