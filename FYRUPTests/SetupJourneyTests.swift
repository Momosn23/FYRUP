import XCTest
@testable import FYRUP

@MainActor final class SetupJourneyTests: XCTestCase {
    func testNamedSequenceHasStableBidirectionalLinksAndNoImplicitFirstAction() {
        XCTAssertEqual(SetupJourneyStep.allCases.count, 14)
        XCTAssertNil(SetupJourneyStep.body.previous)
        XCTAssertNil(SetupJourneyStep.summary.next)
        for step in SetupJourneyStep.allCases {
            if let next = step.next { XCTAssertEqual(next.previous, step) }
            XCTAssertFalse(step.title.isEmpty)
        }
        XCTAssertNil(SetupJourneyProgress().firstAction)
    }

    func testOldPageMeaningsRemainUnchanged() {
        XCTAssertEqual(SetupJourneyStep.legacyPage(0), .health)
        XCTAssertEqual(SetupJourneyStep.legacyPage(1), .body)
        XCTAssertEqual(SetupJourneyStep.legacyPage(2), .permissions)
        XCTAssertEqual(SetupJourneyStep.legacyPage(3), .summary)
        XCTAssertEqual(SetupJourneyStep.legacyPage(nil), .body)
        XCTAssertEqual(SetupJourneyStep.legacyProfile("friends", privatePage: nil), .friends)
        XCTAssertEqual(SetupJourneyStep.legacyProfile("weekly_goal", privatePage: 0), .weeklyGoal)
    }

    func testOldSavedPreferencesDecodeWithoutNewJourneyAndKeepBodyData() throws {
        var old = PersonalSetupPreferences()
        old.setupPage = 2; old.heightCM = 181; old.weightKG = 82
        let encoded = try JSONEncoder().encode(old)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "setupJourney"); json.removeValue(forKey: "setupChoices")
        let restored = try JSONDecoder().decode(PersonalSetupPreferences.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.setupJourney); XCTAssertNil(restored.setupChoices)
        XCTAssertNil(restored.validationMessage)
        XCTAssertEqual(restored.heightCM, 181); XCTAssertEqual(restored.weightKG, 82)
        XCTAssertEqual(SetupJourneyStep.legacyPage(restored.setupPage), .permissions)
    }

    func testNamedCursorAndChoicesSurviveReloadWithoutGrantingConsent() throws {
        let persistence = MemoryPersonalSetupPersistence(), owner = UUID()
        let first = PersonalSetupStore(persistence: persistence); first.activate(userID: owner)
        XCTAssertTrue(first.beginJourney(at: .body))
        XCTAssertTrue(first.update { $0.setupChoices = .init(primaryGoal: .feelFitter, preferredDays: [.monday, .saturday], preferredTime: .flexible) })
        XCTAssertTrue(first.moveJourney(to: .time))
        let reopened = PersonalSetupStore(persistence: persistence); reopened.activate(userID: owner)
        XCTAssertEqual(reopened.journeyStep, .time)
        XCTAssertEqual(reopened.value?.setupChoices?.preferredDays, [.monday, .saturday])
        XCTAssertTrue(reopened.beginJourney(at: .health))
        XCTAssertEqual(reopened.journeyStep, .time, "Entering again does not reset the saved cursor")
        XCTAssertEqual(reopened.value?.liveActivityEnabled, false)
        XCTAssertEqual(reopened.value?.energyRequested, false)
        XCTAssertNil(reopened.value?.activeCalorieGoal)
        XCTAssertNil(reopened.value?.heightCM)
        XCTAssertEqual(reopened.value?.completed, false)
        let encoded = try JSONEncoder().encode(try XCTUnwrap(reopened.value))
        XCTAssertEqual(try JSONDecoder().decode(PersonalSetupPreferences.self, from: encoded), reopened.value)
    }

    func testNewSetupStateNeverLeaksAcrossAccountsOrReopensCompletedSetup() {
        let store = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence()), owner = UUID()
        store.activate(userID: owner)
        XCTAssertTrue(store.beginJourney(at: .friends))
        XCTAssertTrue(store.update { $0.setupJourney?.firstAction = .plan })
        XCTAssertTrue(store.finishSetup())
        store.activate(userID: UUID())
        XCTAssertNil(store.value?.setupJourney)
        XCTAssertEqual(store.value?.completed, false)
        store.activate(userID: owner)
        XCTAssertEqual(store.value?.setupJourney?.firstAction, .plan)
        XCTAssertTrue(store.moveJourney(to: .body))
        XCTAssertEqual(store.value?.completed, true)
    }

    func testFutureJourneyVersionAndInvalidStepDoNotSilentlyResetChoices() throws {
        var value = PersonalSetupPreferences(); value.setupJourney = .init(version: 2, step: .days)
        XCTAssertNotNil(value.validationMessage)
        XCTAssertThrowsError(try JSONDecoder().decode(SetupJourneyStep.self, from: Data("\"removed-page\"".utf8)))
    }

    func testBodyInputUsesLocaleWithoutInventingOrRoundingMeasurements() {
        var preferences = PersonalSetupPreferences()
        preferences.heightCM = 180; preferences.weightKG = 75.125; preferences.targetWeightKG = nil
        let german = BodyMeasurementsDraft(preferences, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(german.height, "180")
        XCTAssertEqual(german.weight, "75,125")
        XCTAssertEqual(german.targetWeight, "")
        XCTAssertNil(german.validationMessage)
        var restored = PersonalSetupPreferences(); german.apply(to: &restored)
        XCTAssertEqual(restored.weightKG, preferences.weightKG)
        XCTAssertEqual(BodyMeasurementsDraft(preferences, locale: Locale(identifier: "en_US")).weight, "75.125")
        XCTAssertEqual(BodyMeasurementsDraft().height, "")
    }

    func testOptionalSetupCanFinishWithoutSportsOrAutomaticGoalAndReopenOnToday() async throws {
        let repository = DemoRepository(startsWithoutProfile: true)
        let store = AppStore(repository: repository); await store.bootstrap()
        await store.saveProfile(displayName: "QA", username: "qa_optional")
        XCTAssertEqual(store.profile?.activityVisibility, "nobody")
        await store.saveOnboardingSports([])
        XCTAssertEqual(store.route, .personalSetup)
        XCTAssertEqual(store.setup.journeyStep, .body)
        let finished = await store.finishOnboarding()
        XCTAssertTrue(finished)
        XCTAssertEqual(store.route, .main)
        XCTAssertEqual(store.profile?.sports, [])
        XCTAssertEqual(store.profile?.onboardingStep, "done")
        // MainTabView activates this store on arrival. Without mounting that
        // view, explicitly perform the same read instead of comparing nil to false.
        let owner = try XCTUnwrap(store.session?.userID)
        await store.weekly.activate(userID: owner)
        let weekly = try XCTUnwrap(store.weekly.state)
        XCTAssertTrue(store.weekly.isStateConfirmed)
        XCTAssertFalse(weekly.goalConfirmed)
        XCTAssertNil(weekly.currentWeek)
        XCTAssertNil(store.setup.value?.heightCM)
        let reopened = AppStore(repository: repository); await reopened.bootstrap()
        XCTAssertEqual(reopened.route, .main, "An empty sports preference is not incomplete authentication")
        XCTAssertEqual(reopened.weekly.state?.goalConfirmed, false)
    }
}
