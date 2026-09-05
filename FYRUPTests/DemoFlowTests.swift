import XCTest
@testable import FYRUP

final class DemoFlowTests: XCTestCase {
    func testAuthRegistrationLoginLogoutAndRestore() async throws {
        let repository = DemoRepository()
        let signup = try await repository.signUp(email: "momo@example.com", password: "password123")
        XCTAssertNotNil(signup)
        let login = try await repository.signIn(email: "momo@example.com", password: "password123")
        let restored = try await repository.restoreSession()
        XCTAssertEqual(login.userID, restored?.userID)
        await repository.signOut()
    }

    func testActivityLifecycleAndSingleLiveConstraint() async throws {
        let repository = DemoRepository()
        let restored = try await repository.restoreSession()
        let session = try XCTUnwrap(restored)
        let activity = try await repository.startActivity(userID: session.userID, sport: .gym, subtype: "Push", linkedActivityID: nil, plannedSessionID: nil, placeName: "  FYRUP Gym  ")
        XCTAssertEqual(activity.status, .live)
        XCTAssertEqual(activity.placeName, "FYRUP Gym")
        do {
            _ = try await repository.startActivity(userID: session.userID, sport: .running, subtype: nil, linkedActivityID: nil, plannedSessionID: nil)
            XCTFail("Second live activity must fail")
        } catch { XCTAssertEqual(error as? AppError, .conflict("Du bist bereits LIVE.")) }
        let completed = try await repository.completeActivity(id: activity.id, distanceMeters: nil)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertNotNil(completed.endedAt)
    }

    func testFyrupDailyLimit() async throws {
        let repository = DemoRepository()
        let restored = try await repository.restoreSession()
        let session = try XCTUnwrap(restored)
        let feed = try await repository.today(userID: session.userID)
        let crew = feed.1
        let leon = try XCTUnwrap(crew.first { $0.profile.username == "leon" })
        try await repository.fyrup(leon.id)
        do { try await repository.fyrup(leon.id); XCTFail("Duplicate FYR UP must fail") }
        catch { XCTAssertNotNil(error as? AppError) }
    }

    func testPlanCreatesPlannedActivity() async throws {
        let repository = DemoRepository()
        let restored = try await repository.restoreSession()
        let session = try XCTUnwrap(restored)
        try await repository.planSession(userID: session.userID, sport: .gym, subtype: "Push", startsAt: Date().addingTimeInterval(3600), duration: 75, note: nil, placeName: "FYRUP Gym", friendsCanJoin: true, friendIDs: [])
        let feed = try await repository.today(userID: session.userID)
        XCTAssertEqual(feed.0?.status, .planned)
        let hosted = try await repository.hostedSessions()
        XCTAssertEqual(hosted.first?.session.placeName, "FYRUP Gym")
        XCTAssertEqual(hosted.first?.session.friendsCanJoin, true)
    }

    func testTrainingGroupCanBeCreatedAndDeleted() async throws {
        let repository = DemoRepository()
        let restored = try await repository.restoreSession()
        let session = try XCTUnwrap(restored)
        let feed = try await repository.today(userID: session.userID)
        let friends = feed.1
        let max = try XCTUnwrap(friends.first { $0.profile.username == "max" })
        try await repository.createTrainingGroup(name: "Weekend Crew", memberIDs: [max.id])
        let groupsAfterCreate = try await repository.trainingGroups()
        let created = try XCTUnwrap(groupsAfterCreate.first { $0.name == "Weekend Crew" })
        XCTAssertEqual(created.members.map(\.id), [max.id])
        try await repository.deleteTrainingGroup(id: created.id)
        let groupsAfterDelete = try await repository.trainingGroups()
        XCTAssertFalse(groupsAfterDelete.contains { $0.id == created.id })
    }

    func testGymProgramsSelectConcreteBodyAreas() {
        XCTAssertEqual(GymProgram.push.areas, [.chest, .shoulders, .triceps])
        XCTAssertTrue(GymProgram.legs.areas.contains(.quads))
        XCTAssertEqual(Set(GymProgram.fullBody.areas), Set(GymBodyArea.allCases))
    }
}
