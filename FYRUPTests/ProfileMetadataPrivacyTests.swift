import XCTest
@testable import FYRUP

@MainActor
final class ProfileMetadataPrivacyTests: XCTestCase {
    func testOldMetadataCannotOverwriteNewVisibility() async throws {
        let repository = DemoRepository()
        let restoredSession = try await repository.restoreSession()
        let session = try XCTUnwrap(restoredSession)
        let loaded = try await repository.profile(userID: session.userID)
        var old = try XCTUnwrap(loaded)
        _ = try await repository.saveActivityVisibility(userID: session.userID, value: .nobody, expected: .friends)
        old.displayName = "New name"; old.city = "Köln"; old.avatarPath = "own/avatar.jpg"
        try await repository.saveProfile(old)
        let saved = try await repository.profile(userID: session.userID)
        XCTAssertEqual(saved?.displayName, "New name"); XCTAssertEqual(saved?.city, "Köln")
        XCTAssertEqual(saved?.avatarPath, "own/avatar.jpg"); XCTAssertEqual(saved?.activityVisibility, "nobody")
    }

    func testAppStoreUsesConfirmedProfileInsteadOfStaleDraft() async throws {
        let repository = DemoRepository()
        let tested = AppStore(repository: repository); await tested.bootstrap()
        let owner = try XCTUnwrap(tested.profile?.id)
        XCTAssertEqual(tested.profile?.activityVisibility, "friends")
        _ = try await repository.saveActivityVisibility(userID: owner, value: .nobody, expected: .friends)
        await tested.updateProfile(displayName: "Edited", username: "edited_owner", birthYear: 1998, city: "Bonn", bio: "Hi", sports: [.gym], avatarJPEG: nil)
        XCTAssertNil(tested.errorMessage)
        XCTAssertEqual(tested.profile?.displayName, "Edited")
        XCTAssertEqual(tested.profile?.activityVisibility, "nobody")
        XCTAssertEqual(tested.activityPrivacy.confirmedValue, .nobody)
    }
}
