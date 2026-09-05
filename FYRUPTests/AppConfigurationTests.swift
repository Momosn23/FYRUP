import XCTest
@testable import FYRUP

final class AppConfigurationTests: XCTestCase {
    func testLiveActivityIsDeclaredAndItsWidgetIsReallyEmbedded() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool, true)
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let widget = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent("FYRUPLive.appex")))
        XCTAssertEqual(widget.bundleIdentifier, "app.fyrup.ios.live")
        XCTAssertEqual(widget.object(forInfoDictionaryKey: "CFBundleVersion") as? String, Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        XCTAssertTrue(types.contains { ($0["CFBundleURLSchemes"] as? [String])?.contains("fyrup") == true })
    }
    func testAppBundleIncludesBothHealthPurposeDescriptions() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.fyrup.ios")
        for key in ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"] {
            let purpose = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? String, "Missing \(key) in the built app")
            XCTAssertFalse(purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        let updatePurpose = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") as? String)
        XCTAssertTrue(updatePurpose.contains("schreibt keine Daten in Apple Health"), "The purpose must not claim a Health write feature that FYRUP does not request")
    }

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
