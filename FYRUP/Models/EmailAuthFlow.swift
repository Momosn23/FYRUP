import CryptoKit
import Foundation
import Security

enum EmailAuthKind: String, Codable, Sendable { case signup, recovery }

struct PendingEmailAuth: Codable, Sendable {
    let id: UUID
    let kind: EmailAuthKind
    let email: String
    let verifier: String
    let createdAt: Date
    var lastSentAt: Date
    var recoverySession: AuthSession?

    static let redirect = "fyrup://auth-callback"
    static let minimumPasswordLength = 6 // Production settings verified 08.09.2026; no composition requirements.

    static func make(kind: EmailAuthKind, email: String, now: Date = .now) throws -> Self {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw AppError.server }
        return Self(id: UUID(), kind: kind, email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    verifier: base64URL(Data(bytes)), createdAt: now, lastSentAt: now)
    }

    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    func isValid(at date: Date) -> Bool { date >= createdAt && date.timeIntervalSince(createdAt) < 3600 }
    func canResend(at date: Date) -> Bool { date.timeIntervalSince(lastSentAt) >= 60 }
    var maskedEmail: String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, let initial = parts[0].first else { return "deine E-Mail-Adresse" }
        return "\(initial)•••@\(parts[1])"
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

enum EmailAuthCallback {
    static func matches(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "fyrup" && url.host?.lowercased() == "auth-callback"
            && url.user == nil && url.password == nil && url.port == nil && (url.path.isEmpty || url.path == "/")
    }
    static func code(from url: URL) throws -> String {
        guard matches(url), url.fragment == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              !items.contains(where: { $0.name == "error" || $0.name == "error_code" }),
              items.filter({ $0.name == "code" }).count == 1,
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty, code.utf8.count <= 2048 else { throw EmailAuthFailure.invalidLink }
        // Never accept access/refresh tokens supplied by a URL. The server must verify our local PKCE proof.
        return code
    }
}

enum EmailAuthFailure: Error, LocalizedError {
    case invalidLink, expiredLink, waitBeforeResending, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidLink: "Dieser Link passt nicht zur aktuellen Anfrage. Fordere in dieser App einen neuen Link an."
        case .expiredLink: "Dieser Link ist abgelaufen oder wurde bereits verwendet. Fordere einen neuen Link an."
        case .waitBeforeResending: "Bitte warte eine Minute, bevor du einen weiteren Link anforderst."
        case .unavailable: "Diese Anmeldung ist hier noch nicht verfügbar."
        }
    }
}

enum EmailAuthCompletion: Sendable { case signedIn(AuthSession), passwordRecovery }

protocol EmailAuthPersistence: Sendable {
    func load() throws -> PendingEmailAuth?
    func save(_ value: PendingEmailAuth) throws
    func clear()
}

struct SecureEmailAuthPersistence: EmailAuthPersistence {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.fyrup.email-auth", kSecAttrAccount as String: "pending"]
    }
    func load() throws -> PendingEmailAuth? {
        var lookup = query; lookup[kSecReturnData as String] = true; lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AppError.server }
        return try JSONDecoder().decode(PendingEmailAuth.self, from: data)
    }
    func save(_ value: PendingEmailAuth) throws {
        let data = try JSONEncoder().encode(value)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw AppError.server }
        var insert = query; insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw AppError.server }
    }
    func clear() { SecItemDelete(query as CFDictionary) }
}
