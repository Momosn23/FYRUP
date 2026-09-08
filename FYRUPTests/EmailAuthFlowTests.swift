import Foundation
import XCTest
@testable import FYRUP

final class EmailAuthFlowTests: XCTestCase {
    func testPKCEUsesRandomURLSafeProofAndKnownSHA256Vector() throws {
        let first = try PendingEmailAuth.make(kind: .signup, email: "  fixture@example.invalid  ")
        let second = try PendingEmailAuth.make(kind: .signup, email: "fixture@example.invalid")
        XCTAssertEqual(first.email, "fixture@example.invalid")
        XCTAssertEqual(first.verifier.count, 43)
        XCTAssertNotEqual(first.verifier, second.verifier)
        XCTAssertNotNil(first.verifier.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression))
        let vector = PendingEmailAuth(id: UUID(), kind: .signup, email: "fixture@example.invalid",
                                     verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", createdAt: .now, lastSentAt: .now)
        XCTAssertEqual(vector.challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testCallbackRejectsOtherHostsPathsFragmentsAndDuplicateCodes() throws {
        XCTAssertEqual(try EmailAuthCallback.code(from: URL(string: "fyrup://auth-callback?code=fixture-code")!), "fixture-code")
        for input in ["https://auth-callback?code=x", "fyrup://evil?code=x", "fyrup://auth-callback/other?code=x",
                      "fyrup://auth-callback:443?code=x", "fyrup://user@auth-callback?code=x", "fyrup://auth-callback?code=x&code=y",
                      "fyrup://auth-callback#access_token=fixture", "fyrup://auth-callback?error=expired&code=x", "fyrup://auth-callback?code="] {
            XCTAssertThrowsError(try EmailAuthCallback.code(from: URL(string: input)!))
        }
    }

    func testExpiryCooldownMaskedEmailAndColdResume() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let pending = try PendingEmailAuth.make(kind: .recovery, email: "fixture@example.invalid", now: now)
        XCTAssertTrue(pending.isValid(at: now.addingTimeInterval(3599)))
        XCTAssertFalse(pending.isValid(at: now.addingTimeInterval(3600)))
        XCTAssertFalse(pending.isValid(at: now.addingTimeInterval(-1)))
        XCTAssertFalse(pending.canResend(at: now.addingTimeInterval(59)))
        XCTAssertTrue(pending.canResend(at: now.addingTimeInterval(60)))
        XCTAssertEqual(pending.maskedEmail, "f•••@example.invalid")
        let reopened = try JSONDecoder().decode(PendingEmailAuth.self, from: JSONEncoder().encode(pending))
        XCTAssertEqual(reopened.verifier, pending.verifier)
        XCTAssertEqual(reopened.kind, .recovery)
        XCTAssertNil(reopened.recoverySession)
    }

    func testRecoveryExchangesCodeWithoutActivatingNormalSessionAndUpdatesPassword() async throws {
        let host = "auth-\(UUID().uuidString.lowercased()).invalid"
        let persistence = EmailAuthMemory()
        let keychain = SecureSessionStore(service: "app.fyrup.test.auth.\(UUID())")
        defer { keychain.clear(); EmailAuthProtocol.registry.remove(host) }
        let pending = try PendingEmailAuth.make(kind: .recovery, email: "fixture@example.invalid")
        persistence.save(pending)
        let owner = UUID()
        let requests = EmailAuthRequests()
        EmailAuthProtocol.registry.set(host) { request in
            requests.append(request)
            if request.url?.path == "/auth/v1/token" {
                let body = try Self.body(request)
                XCTAssertEqual(body["code_verifier"] as? String, pending.verifier)
                XCTAssertEqual(body["auth_code"] as? String, "fixture-code")
                return (200, Data("{\"access_token\":\"fixture-access\",\"refresh_token\":\"fixture-refresh\",\"expires_in\":3600,\"user\":{\"id\":\"\(owner)\"}}".utf8))
            }
            if request.url?.path == "/auth/v1/user" {
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access")
                XCTAssertEqual(try Self.body(request)["password"] as? String, "FixtureOnly42")
            }
            return (200, Data("{}".utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [EmailAuthProtocol.self]
        let network = URLSession(configuration: configuration)
        defer { network.invalidateAndCancel() }
        let client = SupabaseRESTClient(configuration: .init(supabaseURL: URL(string: "https://\(host)")!, publishableKey: "fixture-key", environment: "test"),
                                        urlSession: network, sessionStore: keychain, emailAuthPersistence: persistence)
        let result = try await client.completeEmailAuth(URL(string: "fyrup://auth-callback?code=fixture-code")!)
        guard case .passwordRecovery = result else { return XCTFail("Recovery must not sign in") }
        let normal = await client.currentSession
        XCTAssertNil(normal); XCTAssertNil(keychain.load())
        XCTAssertEqual(persistence.load()?.recoverySession?.userID, owner)
        do { _ = try await client.completeEmailAuth(URL(string: "fyrup://auth-callback?code=fixture-code")!); XCTFail("Must reject reuse") } catch { }
        try await client.updateRecoveredPassword("FixtureOnly42")
        XCTAssertNil(persistence.load()); XCTAssertNil(keychain.load())
        XCTAssertEqual(requests.paths, ["/auth/v1/token", "/auth/v1/user", "/auth/v1/logout"])
    }

    func testNoPendingRequestRejectsBeforeAnyNetworkCall() async throws {
        let memory = EmailAuthMemory()
        let keychain = SecureSessionStore(service: "app.fyrup.test.auth.\(UUID())")
        defer { keychain.clear() }
        let client = SupabaseRESTClient(configuration: .init(supabaseURL: URL(string: "https://unused.invalid")!, publishableKey: "fixture-key", environment: "test"), sessionStore: keychain, emailAuthPersistence: memory)
        do { _ = try await client.completeEmailAuth(URL(string: "fyrup://auth-callback?code=fixture-code")!); XCTFail("Missing local proof") }
        catch { XCTAssertTrue(error is EmailAuthFailure) }
    }

    func testRejectedSignupLeavesNoPendingStateButUncertainDeliveryKeepsProof() async throws {
        let host = "auth-\(UUID().uuidString.lowercased()).invalid"
        let memory = EmailAuthMemory()
        let keychain = SecureSessionStore(service: "app.fyrup.test.auth.\(UUID())")
        defer { keychain.clear(); EmailAuthProtocol.registry.remove(host) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [EmailAuthProtocol.self]
        let network = URLSession(configuration: config); defer { network.invalidateAndCancel() }
        let client = SupabaseRESTClient(configuration: .init(supabaseURL: URL(string: "https://\(host)")!, publishableKey: "fixture", environment: "test"), urlSession: network, sessionStore: keychain, emailAuthPersistence: memory)
        EmailAuthProtocol.registry.set(host) { _ in (422, Data("{\"code\":422,\"error_code\":\"weak_password\",\"msg\":\"Password is weak\"}".utf8)) }
        do { _ = try await client.signUp(email: "fixture@example.invalid", password: "short"); XCTFail("Must reject") } catch { }
        XCTAssertNil(memory.load(), "Known rejection cannot show confirmation on cold start")
        EmailAuthProtocol.registry.set(host) { _ in throw URLError(.networkConnectionLost) }
        do { _ = try await client.signUp(email: "fixture@example.invalid", password: "FixtureOnly42"); XCTFail("No success claim") } catch { }
        XCTAssertNotNil(memory.load(), "A lost response must not destroy the local proof for a possibly sent email")
        XCTAssertNil(keychain.load())
    }

    func testSignupResendUsesFreshProofRedirectAndCooldownWithoutActivatingSession() async throws {
        let host = "auth-\(UUID().uuidString.lowercased()).invalid"
        let memory = EmailAuthMemory()
        let keychain = SecureSessionStore(service: "app.fyrup.test.auth.\(UUID())")
        defer { keychain.clear(); EmailAuthProtocol.registry.remove(host) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [EmailAuthProtocol.self]
        let network = URLSession(configuration: config); defer { network.invalidateAndCancel() }
        let client = SupabaseRESTClient(configuration: .init(supabaseURL: URL(string: "https://\(host)")!, publishableKey: "fixture", environment: "test"), urlSession: network, sessionStore: keychain, emailAuthPersistence: memory)
        let requests = EmailAuthRequests()
        EmailAuthProtocol.registry.set(host) { request in
            requests.append(request)
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "redirect_to" })?.value, PendingEmailAuth.redirect)
            let body = try Self.body(request)
            XCTAssertEqual(body["code_challenge"] as? String, memory.load()?.challenge)
            XCTAssertEqual(body["code_challenge_method"] as? String, "s256")
            if request.url?.path == "/auth/v1/resend" {
                XCTAssertEqual(body["type"] as? String, "signup"); XCTAssertNil(body["password"])
            }
            return (200, Data("{}".utf8))
        }
        let result = try await client.signUp(email: "fixture@example.invalid", password: "FixtureOnly42")
        XCTAssertNil(result); XCTAssertNil(keychain.load())
        let first = try XCTUnwrap(memory.load())
        do { try await client.resendSignupEmail(); XCTFail("Cooldown") } catch { XCTAssertTrue(error is EmailAuthFailure) }
        XCTAssertEqual(requests.paths.count, 1)
        var elapsed = first; elapsed.lastSentAt = .now.addingTimeInterval(-61); memory.save(elapsed)
        try await client.resendSignupEmail()
        let second = try XCTUnwrap(memory.load())
        XCTAssertNotEqual(first.verifier, second.verifier)
        XCTAssertEqual(requests.paths, ["/auth/v1/signup", "/auth/v1/resend"])
        XCTAssertNil(keychain.load())
        var old = second; old.lastSentAt = .now.addingTimeInterval(-61); memory.save(old)
        EmailAuthProtocol.registry.set(host) { _ in (403, Data("{\"error_code\":\"email_address_not_authorized\"}".utf8)) }
        do { try await client.resendSignupEmail(); XCTFail("Rejected resend") } catch { }
        XCTAssertEqual(memory.load()?.verifier, second.verifier, "A known rejection must preserve the previous valid link")
    }

    private static func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }; data.append(contentsOf: bytes.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class EmailAuthMemory: EmailAuthPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var value: PendingEmailAuth?
    func load() -> PendingEmailAuth? { lock.withLock { value } }
    func save(_ pending: PendingEmailAuth) { lock.withLock { value = pending } }
    func clear() { lock.withLock { value = nil } }
}

private final class EmailAuthRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ request: URLRequest) { lock.withLock { values.append(request.url?.path ?? "") } }
    var paths: [String] { lock.withLock { values } }
}

private final class EmailAuthProtocol: URLProtocol, @unchecked Sendable {
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [String: @Sendable (URLRequest) throws -> (Int, Data)] = [:]
        func set(_ host: String, handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) { lock.withLock { handlers[host] = handler } }
        func remove(_ host: String) { _ = lock.withLock { handlers.removeValue(forKey: host) } }
        func handler(_ host: String) -> (@Sendable (URLRequest) throws -> (Int, Data))? { lock.withLock { handlers[host] } }
    }
    static let registry = Registry()
    override class func canInit(with request: URLRequest) -> Bool { registry.handler(request.url?.host ?? "") != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.registry.handler(request.url?.host ?? ""), let url = request.url else { throw URLError(.badURL) }
            let (status, data) = try handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
