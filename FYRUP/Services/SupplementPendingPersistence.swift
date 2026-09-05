import Foundation
import Security

/// Only opaque dose/request IDs and the chosen status are stored, never supplement names.
@MainActor
protocol SupplementPendingPersistence {
    func load(owner: UUID) throws -> Data?
    func save(_ data: Data, owner: UUID) throws
    func clear(owner: UUID) throws
}

struct KeychainSupplementPendingPersistence: SupplementPendingPersistence {
    private func query(_ owner: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "app.fyrup.supplement-pending.v1",
         kSecAttrAccount as String: owner.uuidString.lowercased()]
    }
    func load(owner: UUID) throws -> Data? {
        var request = query(owner)
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let result = SecItemCopyMatching(request as CFDictionary, &item)
        if result == errSecItemNotFound { return nil }
        guard result == errSecSuccess, let data = item as? Data else { throw AppError.server }
        return data
    }
    func save(_ data: Data, owner: UUID) throws {
        let attributes: [String: Any] = [kSecValueData as String: data,
                                       kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(query(owner) as CFDictionary, attributes as CFDictionary)
        if result == errSecItemNotFound {
            let insert = query(owner).merging(attributes) { _, new in new }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw AppError.server }
        } else if result != errSecSuccess { throw AppError.server }
    }
    func clear(owner: UUID) throws {
        let result = SecItemDelete(query(owner) as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw AppError.server }
    }
}

/// Test/demo storage. Real accounts use the non-synchronizing device Keychain above.
@MainActor
final class MemorySupplementPendingPersistence: SupplementPendingPersistence {
    var values: [UUID: Data] = [:]
    var fails = false
    func load(owner: UUID) throws -> Data? { if fails { throw AppError.server }; return values[owner] }
    func save(_ data: Data, owner: UUID) throws { if fails { throw AppError.server }; values[owner] = data }
    func clear(owner: UUID) throws { if fails { throw AppError.server }; values[owner] = nil }
}
