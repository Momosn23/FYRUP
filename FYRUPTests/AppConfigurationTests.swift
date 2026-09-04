import XCTest
@testable import FYRUP

final class AppConfigurationTests: XCTestCase {
    func testLoadsValidBackendResourceValues() throws {
        let configuration = try XCTUnwrap(AppConfiguration.load(values: [
            "SUPABASE_URL": "https://example.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "public-anon-key",
            "APP_ENVIRONMENT": "production"
        ]))

        XCTAssertEqual(configuration.supabaseURL.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(configuration.publishableKey, "public-anon-key")
        XCTAssertEqual(configuration.environment, "production")
    }

    func testRejectsTemplateValues() {
        XCTAssertNil(AppConfiguration.load(values: [
            "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY"
        ]))
    }

    func testRejectsNonHTTPSBackendURL() {
        XCTAssertNil(AppConfiguration.load(values: [
            "SUPABASE_URL": "http://example.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "public-anon-key"
        ]))
    }
}
