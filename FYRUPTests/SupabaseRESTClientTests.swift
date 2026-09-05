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

    func testBackendErrorsBecomeUsefulGermanMessages() {
        XCTAssertEqual(
            SupabaseRESTClient.appError(status: 400, code: "P0001", message: "reserved_username"),
            .conflict("Dieser Username ist reserviert.")
        )
        XCTAssertEqual(
            SupabaseRESTClient.appError(status: 400, code: nil, message: "Invalid login credentials"),
            .conflict("E-Mail oder Passwort ist falsch.")
        )
        XCTAssertEqual(
            SupabaseRESTClient.appError(status: 400, code: nil, message: "Apple id_token provider error"),
            .conflict("Die Apple-Anmeldung konnte nicht bestätigt werden. Versuche es erneut.")
        )
    }

    func testWorkoutErrorsDoNotExposeTechnicalMessages() {
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "forbidden"), .accessDenied)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "plan_not_available"), .conflict("Dieser Plan ist nicht mehr verfügbar oder wurde archiviert."))
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "23514", message: "check constraint"), .validation("Prüfe Name, Übungen, Sätze, Wiederholungen und optionale Gewichte."))
    }

    func testShotErrorsExplainConfirmedStateWithoutLeakingBackendCodes() {
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "weekly_commitment_exists"), .conflict("Dein Shot für diese Woche ist bereits gespeichert."))
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "weekly_goal_not_confirmed"), .validation("Bestätige zuerst dein persönliches Wochenziel."))
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "weekly_goal_already_reached"), .conflict("Du hast dein Wochenziel bereits erreicht. Ein neuer Call ist nächste Woche möglich."))
        XCTAssertTrue(SupabaseRESTClient.appError(status: 403, code: "42501", message: "permission denied").isAccessDenied)
    }
}
