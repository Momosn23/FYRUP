import Foundation

@MainActor protocol NutritionPersisting {
    func load(owner: UUID) throws -> NutritionDiary?
    func save(_ diary: NutritionDiary, owner: UUID) throws
    func delete(owner: UUID) throws
}

/// Private first implementation. Server synchronization is tracked separately.
/// Files are account-scoped, protected while locked and excluded from backups.
@MainActor struct ProtectedNutritionPersistence: NutritionPersisting {
    private func file(_ owner: UUID) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var directory = base.appendingPathComponent("PrivateNutrition", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory.appendingPathComponent(owner.uuidString.lowercased()).appendingPathExtension("json")
    }
    func load(owner: UUID) throws -> NutritionDiary? {
        let url = try file(owner)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(NutritionDiary.self, from: Data(contentsOf: url))
    }
    func save(_ diary: NutritionDiary, owner: UUID) throws {
        try JSONEncoder().encode(diary).write(to: file(owner), options: [.atomic, .completeFileProtection])
    }
    func delete(owner: UUID) throws {
        let url = try file(owner)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

@MainActor final class MemoryNutritionPersistence: NutritionPersisting {
    var values: [UUID: NutritionDiary] = [:]
    func load(owner: UUID) throws -> NutritionDiary? { values[owner] }
    func save(_ diary: NutritionDiary, owner: UUID) throws { values[owner] = diary }
    func delete(owner: UUID) throws { values[owner] = nil }
}
