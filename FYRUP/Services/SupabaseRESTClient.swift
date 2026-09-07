import Foundation
import OSLog

actor SupabaseRESTClient {
    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let sessionStore: SecureSessionStore
    private let connectivity: ConnectivityMonitor
    private let logger = Logger(subsystem: "app.fyrup.ios", category: "Backend")
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession?, Error>?

    init(configuration: AppConfiguration, urlSession: URLSession = .shared, sessionStore: SecureSessionStore = .init(), connectivity: ConnectivityMonitor = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.sessionStore = sessionStore
        self.connectivity = connectivity
        self.session = sessionStore.load()
    }

    var currentSession: AuthSession? { session }

    func signUp(email: String, password: String) async throws -> AuthSession? {
        let response: AuthResponse = try await authRequest(path: "/auth/v1/signup", body: ["email": email, "password": password])
        return try persist(response)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await authRequest(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password]
        )
        guard let session = try persist(response) else { throw AppError.authentication }
        return session
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let response: AuthResponse = try await authRequest(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: ["provider": "apple", "id_token": idToken, "nonce": nonce]
        )
        guard let session = try persist(response) else { throw AppError.authentication }
        return session
    }

    func resetPassword(email: String) async throws {
        let _: EmptyResponse = try await authRequest(path: "/auth/v1/recover", body: ["email": email])
    }

    func signOut() async {
        if let token = session?.accessToken {
            _ = try? await raw(path: "/auth/v1/logout", method: .post, body: Optional<String>.none, accessToken: token)
        }
        session = nil
        sessionStore.clear()
    }

    func restore() async throws -> AuthSession? {
        try await refreshSession(force: false)
    }

    func select<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await databaseRequest(path: path, method: .get, query: query, body: Optional<String>.none)
    }

    func mutate<Body: Encodable, Result: Decodable>(_ path: String, method: Method = .post, query: [URLQueryItem] = [], body: Body) async throws -> Result {
        try await databaseRequest(path: path, method: method, query: query, body: body)
    }

    func rpc<Body: Encodable, Result: Decodable>(_ name: String, body: Body) async throws -> Result {
        try await databaseRequest(path: "rpc/\(name)", method: .post, query: [], body: body)
    }

    func invokeFunction<Result: Decodable>(_ name: String) async throws -> Result {
        let token = try await validAccessToken()
        var request = URLRequest(url: configuration.supabaseURL.appending(path: "functions/v1/\(name)"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await executeAuthorized(request, operation: "function.\(name)")
    }

    func uploadObject(bucket: String, path: String, data: Data, contentType: String) async throws {
        let token = try await validAccessToken()
        var request = URLRequest(url: storageURL(parts: ["object", bucket] + path.split(separator: "/").map(String.init)))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        let _: EmptyResponse = try await executeAuthorized(request, operation: "storage.upload")
    }

    func downloadObject(bucket: String, path: String) async throws -> Data {
        let token = try await validAccessToken()
        var request = URLRequest(url: storageURL(parts: ["object", "authenticated", bucket] + path.split(separator: "/").map(String.init)))
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await executeDataAuthorized(request, operation: "storage.download")
    }

    private func storageURL(parts: [String]) -> URL {
        parts.reduce(configuration.supabaseURL.appending(path: "storage/v1")) { url, part in
            url.appending(path: part)
        }
    }

    private func databaseRequest<Body: Encodable, Result: Decodable>(path: String, method: Method, query: [URLQueryItem], body: Body?) async throws -> Result {
        let token = try await validAccessToken()
        var components = URLComponents(url: configuration.supabaseURL.appending(path: "rest/v1/\(path)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if let body { request.httpBody = try JSONEncoder.supabase.encode(body) }
        return try await executeAuthorized(request, operation: "database.\(path)", retryTransient: method == .get)
    }

    private func authRequest<Result: Decodable, Body: Encodable>(
        path: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws -> Result {
        let data = try JSONEncoder.supabase.encode(body)
        var request = URLRequest(url: Self.requestURL(
            baseURL: configuration.supabaseURL,
            path: path,
            query: query
        ))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return try await execute(request, operation: "auth.\(path)")
    }

    static func requestURL(baseURL: URL, path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    private func raw<Body: Encodable>(path: String, method: Method, body: Body?, accessToken: String) async throws -> Data {
        var request = URLRequest(url: configuration.supabaseURL.appending(path: path))
        request.httpMethod = method.rawValue
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONEncoder.supabase.encode(body) }
        return try await executeData(request, operation: "auth.logout")
    }

    private func validAccessToken() async throws -> String {
        guard let restored = try await refreshSession(force: false) else { throw AppError.authentication }
        return restored.accessToken
    }

    private func refreshSession(force: Bool) async throws -> AuthSession? {
        guard let existing = session else { return nil }
        if !force && existing.expiresAt > Date().addingTimeInterval(60) { return existing }
        if let refreshTask { return try await refreshTask.value }
        logger.info("Auth refresh started; auth=present network=\(self.connectivity.logLabel, privacy: .public)")
        let task = Task { try await self.performSessionRefresh(refreshToken: existing.refreshToken) }
        refreshTask = task
        do {
            let result = try await task.value
            refreshTask = nil
            logger.info("Auth refresh succeeded")
            return result
        } catch {
            refreshTask = nil
            if error as? AppError == .authentication {
                session = nil
                sessionStore.clear()
                logger.error("Auth refresh rejected; local session cleared")
            } else {
                logger.error("Auth refresh failed without clearing the local session")
            }
            throw error
        }
    }

    private func performSessionRefresh(refreshToken: String) async throws -> AuthSession? {
        let response: AuthResponse = try await authRequest(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: ["refresh_token": refreshToken]
        )
        guard let renewed = try persist(response) else { throw AppError.server }
        return renewed
    }

    private func executeAuthorized<T: Decodable>(_ original: URLRequest, operation: String, retryTransient: Bool = false) async throws -> T {
        do {
            return try await execute(original, operation: operation, retryTransient: retryTransient)
        } catch AppError.authentication {
            guard let renewed = try await sessionAfterUnauthorized(original) else { throw AppError.authentication }
            var retry = original
            retry.setValue("Bearer \(renewed.accessToken)", forHTTPHeaderField: "Authorization")
            logger.info("Retrying request after auth refresh operation=\(operation, privacy: .public)")
            return try await execute(retry, operation: operation, retryTransient: retryTransient)
        }
    }

    private func executeDataAuthorized(_ original: URLRequest, operation: String) async throws -> Data {
        do { return try await executeData(original, operation: operation) }
        catch AppError.authentication {
            guard let renewed = try await sessionAfterUnauthorized(original) else { throw AppError.authentication }
            var retry = original
            retry.setValue("Bearer \(renewed.accessToken)", forHTTPHeaderField: "Authorization")
            logger.info("Retrying data request after auth refresh operation=\(operation, privacy: .public)")
            return try await executeData(retry, operation: operation)
        }
    }

    private func sessionAfterUnauthorized(_ request: URLRequest) async throws -> AuthSession? {
        let rejected = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        // Another in-flight request may already have rotated the token while this
        // response was travelling. Reuse that result instead of rotating twice.
        if let current = session, rejected != current.accessToken { return current }
        return try await refreshSession(force: true)
    }

    private func execute<T: Decodable>(_ request: URLRequest, operation: String, retryTransient: Bool = false) async throws -> T {
        let data = try await executeData(request, operation: operation, retryTransient: retryTransient)
        if data.isEmpty, T.self == EmptyResponse.self { return EmptyResponse() as! T }
        do { return try JSONDecoder.supabase.decode(T.self, from: data) }
        catch {
            logger.error("Response decoding failed operation=\(operation, privacy: .public)")
            throw AppError.server
        }
    }

    private func executeData(_ request: URLRequest, operation: String, retryTransient: Bool = false) async throws -> Data {
        let requestID = String(UUID().uuidString.prefix(8))
        let maximumAttempts = retryTransient ? 3 : 1
        for attempt in 1...maximumAttempts {
            logger.info("Request started id=\(requestID, privacy: .public) operation=\(operation, privacy: .public) method=\(request.httpMethod ?? "GET", privacy: .public) attempt=\(attempt, privacy: .public) auth=\(request.value(forHTTPHeaderField: "Authorization") == nil ? "none" : "present", privacy: .public) network=\(self.connectivity.logLabel, privacy: .public)")
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw AppError.serverUnavailable }
                guard 200..<300 ~= http.statusCode else {
                    let backend = try? JSONDecoder().decode(BackendError.self, from: data)
                    let mapped = Self.appError(status: http.statusCode, code: backend?.code, message: backend?.message)
                    logger.error("Request failed id=\(requestID, privacy: .public) operation=\(operation, privacy: .public) http=\(http.statusCode, privacy: .public) code=\(backend?.code ?? "none", privacy: .public) network=\(self.connectivity.logLabel, privacy: .public)")
                    if attempt < maximumAttempts, mapped == .serverUnavailable {
                        logger.info("Transient retry scheduled id=\(requestID, privacy: .public)")
                        try await Task.sleep(for: .milliseconds(250 * attempt))
                        continue
                    }
                    throw mapped
                }
                logger.info("Request succeeded id=\(requestID, privacy: .public) operation=\(operation, privacy: .public) http=\(http.statusCode, privacy: .public)")
                return data
            } catch let error as AppError {
                throw error
            } catch let error as URLError {
                let mapped = Self.appError(urlError: error, networkAvailable: connectivity.isAvailable)
                logger.error("Request transport failure id=\(requestID, privacy: .public) operation=\(operation, privacy: .public) urlCode=\(error.errorCode, privacy: .public) network=\(self.connectivity.logLabel, privacy: .public)")
                if attempt < maximumAttempts {
                    logger.info("Transport retry scheduled id=\(requestID, privacy: .public)")
                    try await Task.sleep(for: .milliseconds(250 * attempt))
                    continue
                }
                throw mapped
            } catch {
                logger.error("Request failed without transport or backend code id=\(requestID, privacy: .public) operation=\(operation, privacy: .public)")
                throw AppError.server
            }
        }
        throw AppError.serverUnavailable
    }

    static func appError(urlError: URLError, networkAvailable: Bool?) -> AppError {
        if networkAvailable == false { return .offline }
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .networkConnectionLost:
            return networkAvailable == false ? .offline : .serverUnavailable
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            return .serverUnavailable
        default:
            return .serverUnavailable
        }
    }

    static func appError(status: Int, code: String?, message: String?) -> AppError {
        let text = [code, message].compactMap { $0 }.joined(separator: " ").lowercased()
        if status == 401 { return .authentication }
        if status == 403 { return .accessDenied }
        if status == 408 || status == 429 || (500...599).contains(status) { return .serverUnavailable }
        if text.contains("refresh_token") || text.contains("refresh token") || text.contains("invalid_grant") { return .authentication }
        if text.contains("invalid login credentials") { return .conflict("E-Mail oder Passwort ist falsch.") }
        if text.contains("email not confirmed") { return .conflict("Bitte bestätige zuerst deine E-Mail-Adresse.") }
        if text.contains("user already registered") { return .conflict("Für diese E-Mail gibt es bereits ein Konto.") }
        if text.contains("password") && (text.contains("characters") || text.contains("weak")) { return .validation("Das Passwort muss mindestens 8 Zeichen lang sein.") }
        if text.contains("reserved_username") { return .conflict("Dieser Username ist reserviert.") }
        if text.contains("username") && (text.contains("duplicate") || code == "23505") { return .conflict("Dieser Username ist bereits vergeben.") }
        if text.contains("invalid_group_name") { return .validation("Der Gruppenname braucht 2–40 Zeichen.") }
        if text.contains("group_name_exists") { return .conflict("Du hast bereits eine Gruppe mit diesem Namen.") }
        if text.contains("already_live") { return .conflict("Du bist bereits LIVE.") }
        if text.contains("weekly_commitment_exists") { return .conflict("Dein Shot für diese Woche ist bereits gespeichert.") }
        if text.contains("notification_preferences_conflict") { return .conflict("Die Einstellungen wurden inzwischen geändert. Bitte prüfe den aktuellen Stand, bevor du speicherst.") }
        if text.contains("invalid_notification_preferences") { return .validation("Bitte lade deine Mitteilungseinstellungen erneut und prüfe alle Kategorien.") }
        if text.contains("weekly_week_changed") { return .conflict("Die Woche hat gewechselt. Prüfe dein aktuelles Ziel und bestätige es erneut.") }
        if text.contains("weekly_goal_not_confirmed") { return .validation("Bestätige zuerst dein persönliches Wochenziel.") }
        if text.contains("weekly_goal_already_reached") { return .conflict("Du hast dein Wochenziel bereits erreicht. Ein neuer Call ist nächste Woche möglich.") }
        if text.contains("already_sent_today") { return .conflict("Diesen Freund hast du heute bereits motiviert.") }
        if text.contains("friendship_exists") { return .conflict("Diese Freundschaftsanfrage gibt es bereits.") }
        if text.contains("start_in_past") { return .validation("Wähle bitte einen Zeitpunkt in der Zukunft.") }
        if text.contains("session_not_editable") { return .conflict("Diese Session kann nicht mehr geändert werden.") }
        if text.contains("plan_not_available") { return .conflict("Dieser Plan ist nicht mehr verfügbar oder wurde archiviert.") }
        if text.contains("copy_request_mismatch") { return .conflict("Diese Kopieranfrage gehört zu einem anderen Plan.") }
        if text.contains("copy_result_unavailable") { return .conflict("Deine zuvor erstellte Kopie wurde archiviert oder gelöscht. Es wurde keine weitere Kopie angelegt.") }
        if text.contains("invalid_copy_request") { return .validation("Bitte aktualisiere FYRUP und öffne den Plan erneut, damit deine Kopie sicher zugeordnet werden kann.") }
        if text.contains("not_friends") { return .conflict("Du kannst den Plan nur mit akzeptierten Freunden teilen.") }
        if text.contains("forbidden") || code == "42501" { return .accessDenied }
        if text.contains("invalid_exercise") || text.contains("invalid_plan") || text.contains("invalid_prescription") || code == "23514" {
            return .validation("Prüfe Name, Übungen, Sätze, Wiederholungen und optionale Gewichte.")
        }
        if text.contains("invalid_log") || text.contains("incomplete_log") || text.contains("invalid_sets") || text.contains("duplicate_set_number") {
            return .validation("Das Protokoll konnte nicht gespeichert werden. Prüfe deine Satzangaben und versuche es erneut.")
        }
        if text.contains("invalid_session") || text.contains("invalid_link") { return .conflict("Diese gemeinsame Session ist nicht mehr verfügbar. Aktualisiere deine Einladungen.") }
        if text.contains("invalid_schedule") { return .validation("Prüfe Datum, Uhrzeit und geplante Dauer.") }
        if text.contains("not_live") || text.contains("activity_not_live") { return .conflict("Diese Aktivität ist nicht mehr LIVE. Aktualisiere die Ansicht.") }
        if status == 409 || code == "23505" { return .conflict("Diese Aktion wurde bereits ausgeführt.") }
        if status == 400 && (text.contains("provider") || text.contains("id_token") || text.contains("nonce")) {
            return .conflict("Die Apple-Anmeldung konnte nicht bestätigt werden. Versuche es erneut.")
        }
        return .server
    }

    private func persist(_ response: AuthResponse) throws -> AuthSession? {
        guard let accessToken = response.accessToken, let refreshToken = response.refreshToken, let user = response.user else { return nil }
        let value = AuthSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)), userID: user.id)
        try sessionStore.save(value)
        session = value
        return value
    }
}

private struct AuthResponse: Decodable {
    struct User: Decodable { let id: UUID }
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: User?
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", user }
}

private struct EmptyResponse: Codable {}

private struct BackendError: Decodable {
    let code: String?
    let message: String?
}

extension JSONEncoder {
    static var supabase: JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
}

extension JSONDecoder {
    static var supabase: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return value
    }
}
