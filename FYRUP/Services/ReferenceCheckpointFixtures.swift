import Foundation

/// Fixture data only. Renders use the production navigation, forms and stores.
/// The entry point is unavailable in physical-device Release/TestFlight builds.
#if DEBUG || targetEnvironment(simulator)
@MainActor enum ReferenceCheckpointFixtures {
    static let date = Date(timeIntervalSince1970: 1_747_899_660) // 2025-05-22 09:41 Europe/Berlin.
    static func make() -> AppStore {
        NSTimeZone.default = TimeZone(identifier: "Europe/Berlin")!
        let instant = date
        let repository = DemoRepository(weeklyStorage: DemoWeeklyFlameStorage(now: { instant }), now: { instant })
        let defaults = UserDefaults(suiteName: "app.fyrup.reference.\(UUID().uuidString)")!
        let store = AppStore(repository: repository,
            steps: StepStore(repository: repository, reader: StepPreviewReader(), defaults: defaults, now: { instant }),
            supplements: SupplementStore(repository: repository, persistence: MemorySupplementPendingPersistence(), clock: { instant }))
        store.referenceSnapshot = true; store.referenceDate = date
        return store
    }
    static func seed(_ store: AppStore, repository: DemoRepository) async throws {
        let owner = DemoRepository.defaultUserID
        try await repository.configureReferenceActivities(at: date)
        _ = store.setup.update { $0.completed = true; $0.heightCM = 180; $0.weightKG = 75; $0.targetWeightKG = 70 }
        _ = store.nutrition.saveGoal(.init(kcal: 2500, protein: 180, carbohydrates: 300, fat: 90))
        _ = store.nutrition.save(.init(id: UUID(uuidString: "00000000-0000-4000-8000-000000000100")!, name: "Beispielmahlzeit", day: StepDay.key(for: date), meal: .lunch,
                                     grams: 500, per100g: .init(kcal: 370, protein: 24, carbohydrates: 36, fat: 12)))
        await store.steps.activate(userID: owner); store.steps.setGoal(10000); await store.steps.connect()
        for (index, name) in ["Kreatin", "Vitamin D3", "Omega 3", "Magnesium"].enumerated() {
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", 200 + index))!
            _ = try await repository.saveSupplement(.init(id: id, ownerID: owner, name: name, remindersEnabled: false))
        }
        await store.supplements.refresh()
        if let first = store.supplements.snapshot?.doses.first { await store.supplements.mark(first.id, as: .taken) }
        if ProcessInfo.processInfo.arguments.contains("--reference-body") { _ = store.setup.update { $0.completed = false; $0.setupPage = 1 } }
    }
}

extension DemoRepository {
    func configureReferenceActivities(at date: Date) async throws {
        activities.removeAll { $0.userID == meID }
        for offset in 1...3 {
            let end = Calendar.current.date(byAdding: .day, value: -offset, to: date)!
            activities.append(Activity(id: UUID(), userID: meID, sport: offset == 2 ? .running : .gym, subtype: offset == 2 ? "Easy Run" : "Push", status: .completed,
                                       plannedAt: nil, startedAt: end.addingTimeInterval(-1920), endedAt: end, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil))
        }
        if let index = activities.firstIndex(where: { $0.userID == crew.first?.id }) { activities[index].subtype = "Push" }
        _ = try await weeklyState(userID: meID, timezone: "Europe/Berlin")
        for activity in activities where activity.userID == meID && activity.status == .completed { try await weeklyStorage.recordCompletion(activity) }
    }
}
#endif
