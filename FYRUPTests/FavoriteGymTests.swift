import XCTest
@testable import FYRUP

@MainActor
final class FavoriteGymTests: XCTestCase {
    func testOlderPrivateSetupDecodesWithoutFavoriteGym() throws {
        let old = Data(#"{"version":1,"completed":true,"heightCM":180,"weightKG":80,"activeCalorieGoal":450,"energyRequested":false,"liveActivityEnabled":false}"#.utf8)
        let value = try JSONDecoder().decode(PersonalSetupPreferences.self, from: old)
        XCTAssertNil(value.favoriteGymName); XCTAssertNil(value.validationMessage)
        XCTAssertTrue(value.completed); XCTAssertEqual(value.weightKG, 80)
    }

    func testFavoriteGymRoundTripsWithoutEnablingPermissions() throws {
        var value = PersonalSetupPreferences()
        XCTAssertNil(value.favoriteGymName)
        value.favoriteGymName = "Köln · Gym 💪"
        let restored = try JSONDecoder().decode(PersonalSetupPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored, value); XCTAssertNil(restored.validationMessage)
        XCTAssertFalse(restored.energyRequested); XCTAssertFalse(restored.liveActivityEnabled)
        value.favoriteGymName = String(repeating: "G", count: 120)
        XCTAssertNil(value.validationMessage)
    }

    func testInvalidFavoriteDoesNotOverwriteSavedValue() {
        let store = PersonalSetupStore(persistence: MemoryPersonalSetupPersistence())
        store.activate(userID: UUID())
        XCTAssertTrue(store.update { $0.favoriteGymName = "Mein Gym" })
        for name in ["", " Gym", "Gym ", "Gym\nOrt", "Gym\tOrt", "Gym\u{0}Ort", String(repeating: "G", count: 121)] {
            XCTAssertFalse(store.update { $0.favoriteGymName = name })
            XCTAssertEqual(store.value?.favoriteGymName, "Mein Gym")
        }
        XCTAssertTrue(store.update { $0.favoriteGymName = nil })
        XCTAssertNil(store.errorMessage); XCTAssertNil(store.value?.favoriteGymName)
    }

    func testFavoriteGymIsAccountIsolatedAndIndependentOfBodyDeletion() throws {
        let persistence = MemoryPersonalSetupPersistence(), owner = UUID(), other = UUID()
        let store = PersonalSetupStore(persistence: persistence); store.activate(userID: owner)
        XCTAssertTrue(store.update { $0.favoriteGymName = "Privates Gym"; $0.heightCM = 180 })
        XCTAssertTrue(store.deleteMeasurements()); XCTAssertEqual(store.value?.favoriteGymName, "Privates Gym")
        store.activate(userID: other); XCTAssertNil(store.value?.favoriteGymName)
        store.activate(userID: owner); XCTAssertEqual(store.value?.favoriteGymName, "Privates Gym")
        try store.clearDeletedAccount(); XCTAssertNil(persistence.values[owner])
        store.activate(userID: owner); XCTAssertNil(store.value?.favoriteGymName)
    }

    func testUntouchedPlaceFollowsOnlyGymSelectionAndCurrentFavorite() {
        var draft = GymPlaceDraft()
        draft.synchronize(sport: nil, favorite: "Mein Gym"); XCTAssertEqual(draft.value, "")
        draft.synchronize(sport: .gym, favorite: "Mein Gym")
        XCTAssertEqual(draft.value, "Mein Gym"); XCTAssertTrue(draft.usesFavorite)
        draft.synchronize(sport: .gym, favorite: "Neues Gym"); XCTAssertEqual(draft.value, "Neues Gym")
        draft.synchronize(sport: nil, favorite: "Neues Gym"); XCTAssertEqual(draft.value, ""); XCTAssertFalse(draft.usesFavorite)
        draft.synchronize(sport: .gym, favorite: nil); XCTAssertEqual(draft.value, ""); XCTAssertFalse(draft.usesFavorite)
    }

    func testManualPlaceAndDeliberateClearAreNeverSilentlyReplaced() {
        for edited in ["Anderer Treffpunkt", ""] {
            var draft = GymPlaceDraft()
            draft.synchronize(sport: .gym, favorite: "Mein Gym"); draft.edit(edited)
            draft.synchronize(sport: nil, favorite: "Geändertes Gym")
            draft.synchronize(sport: .gym, favorite: "Geändertes Gym")
            XCTAssertEqual(draft.value, edited); XCTAssertTrue(draft.userEdited); XCTAssertFalse(draft.usesFavorite)
        }
    }

    func testExplicitRestoreUsesFavoriteAndNewComposerStartsFresh() {
        var draft = GymPlaceDraft(); draft.edit("Anderer Treffpunkt")
        draft.useFavorite("Mein Gym")
        XCTAssertEqual(draft.value, "Mein Gym"); XCTAssertFalse(draft.userEdited); XCTAssertTrue(draft.usesFavorite)
        draft.edit("")
        var newDraft = GymPlaceDraft(); newDraft.synchronize(sport: .gym, favorite: "Mein Gym")
        XCTAssertEqual(draft.value, ""); XCTAssertEqual(newDraft.value, "Mein Gym")
    }
}
