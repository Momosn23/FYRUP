import Foundation
import Security

@MainActor
protocol PersonalSetupPersisting {
    func load(userID: UUID) throws -> PersonalSetupPreferences?
    func save(_ value: PersonalSetupPreferences, userID: UUID) throws
    func delete(userID: UUID) throws
}

/// Body measurements must not enter unprotected preferences, iCloud, a shared
/// widget container, diagnostics or the public profile table.
@MainActor
struct SecurePersonalSetupPersistence: PersonalSetupPersisting {
    private func query(_ userID: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.fyrup.private-setup",
         kSecAttrAccount as String: userID.uuidString,
         kSecAttrSynchronizable as String: false]
    }
    func load(userID: UUID) throws -> PersonalSetupPreferences? {
        var query = query(userID)
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AppError.server }
        return try JSONDecoder().decode(PersonalSetupPreferences.self, from: data)
    }
    func save(_ value: PersonalSetupPreferences, userID: UUID) throws {
        let data = try JSONEncoder().encode(value)
        let query = query(userID)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insert = query.merging(attributes) { _, new in new }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw AppError.server }
        } else if status != errSecSuccess { throw AppError.server }
    }
    func delete(userID: UUID) throws {
        let status = SecItemDelete(query(userID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AppError.server }
    }
}

@MainActor
final class MemoryPersonalSetupPersistence: PersonalSetupPersisting {
    var values: [UUID: PersonalSetupPreferences] = [:]
    func load(userID: UUID) throws -> PersonalSetupPreferences? { values[userID] }
    func save(_ value: PersonalSetupPreferences, userID: UUID) throws { values[userID] = value }
    func delete(userID: UUID) throws { values[userID] = nil }
}
