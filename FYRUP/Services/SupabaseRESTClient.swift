import Foundation

actor SupabaseRESTClient {
    enum Method: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let sessionStore: SecureSessionStore
    private var session: AuthSession?

    init(configuration: AppConfiguration, urlSession: URLSession = .shared, sessionStore: SecureSessionStore = .init()) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.sessionStore = sessionStore
        self.session = sessionStore.load()
    }

    var currentSession: AuthSession? { session }

    func signUp(email: String, password: String) async throws -> AuthSession? {
        let response: AuthResponse = try await authRequest(path: "/auth/v1/signup", body: ["email": email, "password": password])
        return try persist(response)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await authRequest(path: "/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
        guard let session = try persist(response) else { throw AppError.authentication }
        return session
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let response: AuthResponse = try await authRequest(path: "/auth/v1/token?grant_type=id_token", body: ["provider": "apple", "id_token": idToken, "nonce": nonce])
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
        guard let existing = session else { return nil }
        if existing.expiresAt > Date().addingTimeInterval(60) { return existing }
        let response: AuthResponse = try await authRequest(path: "/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": existing.refreshToken])
        return try persist(response)
    }

    func select<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await databaseRequest(path: path, method: .get, query: query, body: Optional<String>.none)
    }

    func mutate<Body: Encodable, Result: Decodable>(_ path: String, method: Method = .post, body: Body) async throws -> Result {
        try await databaseRequest(path: path, method: method, query: [], body: body)
    }

    func rpc<Body: Encodable, Result: Decodable>(_ name: String, body: Body) async throws -> Result {
        try await databaseRequest(path: "rpc/\(name)", method: .post, query: [], body: body)
    }

    func invokeFunction<Result: Decodable>(_ name: String) async throws -> Result {
        guard let token = session?.accessToken else { throw AppError.authentication }
        var request = URLRequest(url: configuration.supabaseURL.appending(path: "functions/v1/\(name)"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await execute(request)
    }

    private func databaseRequest<Body: Encodable, Result: Decodable>(path: String, method: Method, query: [URLQueryItem], body: Body?) async throws -> Result {
        guard let token = session?.accessToken else { throw AppError.authentication }
        var components = URLComponents(url: configuration.supabaseURL.appending(path: "rest/v1/\(path)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if let body { request.httpBody = try JSONEncoder.supabase.encode(body) }
        return try await execute(request)
    }

    private func authRequest<Result: Decodable, Body: Encodable>(path: String, body: Body) async throws -> Result {
        let data = try JSONEncoder.supabase.encode(body)
        var request = URLRequest(url: configuration.supabaseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return try await execute(request)
    }

    private func raw<Body: Encodable>(path: String, method: Method, body: Body?, accessToken: String) async throws -> Data {
        var request = URLRequest(url: configuration.supabaseURL.appending(path: path))
        request.httpMethod = method.rawValue
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONEncoder.supabase.encode(body) }
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw AppError.server }
        return data
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AppError.network }
            guard 200..<300 ~= http.statusCode else {
                if http.statusCode == 401 { throw AppError.authentication }
                if http.statusCode == 409 { throw AppError.conflict("Diese Aktion wurde bereits ausgeführt.") }
                throw AppError.server
            }
            if data.isEmpty, T.self == EmptyResponse.self { return EmptyResponse() as! T }
            return try JSONDecoder.supabase.decode(T.self, from: data)
        } catch let error as AppError { throw error }
        catch is URLError { throw AppError.network }
        catch { throw AppError.server }
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
