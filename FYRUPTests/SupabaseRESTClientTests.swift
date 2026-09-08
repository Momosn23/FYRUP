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

    func testNetworkAuthServerAndPermissionFailuresStayDistinct() {
        XCTAssertEqual(SupabaseRESTClient.appError(urlError: URLError(.notConnectedToInternet), networkAvailable: false), .offline)
        XCTAssertEqual(SupabaseRESTClient.appError(urlError: URLError(.timedOut), networkAvailable: true), .serverUnavailable)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 401, code: nil, message: nil), .authentication)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "refresh_token_not_found", message: "Invalid Refresh Token"), .authentication)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 403, code: nil, message: nil), .accessDenied)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 503, code: nil, message: nil), .serverUnavailable)
        XCTAssertEqual(SupabaseRESTClient.appError(status: 400, code: "P0001", message: "unknown_failure"), .server)
    }

    func testConnectionMessagesDoNotCallEveryFailureOffline() {
        XCTAssertEqual(AppError.offline.errorDescription, "Die Aktion wurde noch nicht bestätigt. Versuche es erneut.")
        XCTAssertTrue(AppError.serverUnavailable.errorDescription?.contains("Server") == true)
        XCTAssertTrue(AppError.authentication.errorDescription?.contains("melde dich erneut") == true)
        XCTAssertTrue(AppError.accessDenied.errorDescription?.contains("keinen Zugriff") == true)
        XCTAssertTrue(AppError.server.errorDescription?.contains("Daten konnten nicht geladen") == true)
    }

    func testSilentConnectionClassificationDoesNotHideAuthOrPermissionErrors() {
        for error in [AppError.offline, .network, .serverUnavailable] { XCTAssertTrue(AppError.isTransientConnection(error)) }
        for error in [AppError.authentication, .accessDenied, .configuration, .server, .validation("Prüfe Eingaben")] {
            XCTAssertFalse(AppError.isTransientConnection(error))
        }
        XCTAssertTrue(AppError.isTransientConnection(URLError(.networkConnectionLost)))
        XCTAssertTrue(AppError.isTransientConnection(URLError(.notConnectedToInternet)))
        XCTAssertFalse(AppError.isTransientConnection(URLError(.cancelled)))
        XCTAssertFalse(AppError.isTransientConnection(URLError(.badURL)))
    }
}
