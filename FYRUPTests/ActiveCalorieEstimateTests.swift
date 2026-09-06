import XCTest
@testable import FYRUP

final class ActiveCalorieEstimateTests: XCTestCase {
    private let owner = UUID()
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testAppleHealthWinsWithoutAddingStepsOrActivities() {
        let value = ActiveCalorieEstimate.make(healthKilocalories: 420, steps: 10_000, heightCM: 180, weightKG: 80,
            ownerID: owner, activities: [completedGym()], feedback: [:], now: now, calendar: calendar)
        XCTAssertEqual(value?.kilocalories, 420)
        XCTAssertEqual(value?.source, .appleHealth)
        XCTAssertFalse(value?.includesSteps ?? true)
    }

    func testFallbackRequiresBothBodyValuesAndRealInput() {
        XCTAssertNil(ActiveCalorieEstimate.make(healthKilocalories: nil, steps: 8_000, heightCM: nil, weightKG: 70,
            ownerID: owner, activities: [], feedback: [:], now: now, calendar: calendar))
        XCTAssertNil(ActiveCalorieEstimate.make(healthKilocalories: nil, steps: nil, heightCM: 175, weightKG: 70,
            ownerID: owner, activities: [], feedback: [:], now: now, calendar: calendar))
    }

    func testStepsUseDocumentedDeterministicEstimate() {
        let value = ActiveCalorieEstimate.make(healthKilocalories: nil, steps: 10_000, heightCM: 175, weightKG: 70,
            ownerID: owner, activities: [], feedback: [:], now: now, calendar: calendar)
        XCTAssertEqual(value?.kilocalories ?? 0, 310.629375, accuracy: 0.001)
        XCTAssertTrue(value?.includesSteps == true)
    }

    func testCompletedGymNeedsExplicitEffortAndNeverAddsToSteps() {
        let activity = completedGym()
        var review = PersonalWorkoutFeedback(activityID: activity.id)
        review.exercises = [.init(exerciseID: UUID(), effort: .hardcore)]
        let value = ActiveCalorieEstimate.make(healthKilocalories: nil, steps: 1_000, heightCM: 175, weightKG: 80,
            ownerID: owner, activities: [activity, activity], feedback: [activity.id: review], now: now, calendar: calendar)
        // 60 min at 6 MET, active share only. This is larger than the step estimate,
        // and duplicate activity IDs are counted once.
        XCTAssertEqual(value?.kilocalories ?? 0, 420, accuracy: 0.001)
        XCTAssertTrue(value?.includesExplicitActivityEffort == true)
    }

    func testReviewedNonGymActivityUsesSportAndCompletionFeeling() throws {
        var running = completedGym()
        running.sport = .running
        var review = PersonalWorkoutFeedback(activityID: running.id)
        review.feeling = .tough
        let value = try XCTUnwrap(ActiveCalorieEstimate.make(healthKilocalories: nil, steps: nil,
            heightCM: 175, weightKG: 80, ownerID: owner, activities: [running],
            feedback: [running.id: review], now: now, calendar: calendar))
        // Running base 7 MET × 1.2 for the explicit tough signal, active share only.
        XCTAssertEqual(value.kilocalories, 621.6, accuracy: 0.001)
        XCTAssertTrue(value.includesExplicitActivityEffort)
    }

    func testUnreviewedNonGymActivityDoesNotInventEnergy() {
        var running = completedGym()
        running.sport = .running
        XCTAssertNil(ActiveCalorieEstimate.make(healthKilocalories: nil, steps: nil,
            heightCM: 175, weightKG: 80, ownerID: owner, activities: [running],
            feedback: [:], now: now, calendar: calendar))
    }

    func testPlannedCancelledForeignAndOtherDayActivitiesDoNotCount() {
        var values = [completedGym()]
        values[0].status = .planned
        let foreign = completedGym(userID: UUID())
        var old = completedGym(); old.endedAt = calendar.date(byAdding: .day, value: -1, to: now)
        XCTAssertNil(ActiveCalorieEstimate.make(healthKilocalories: nil, steps: nil, heightCM: 175, weightKG: 80,
            ownerID: owner, activities: values + [foreign, old], feedback: [:], now: now, calendar: calendar))
    }

    private func completedGym(userID: UUID? = nil) -> Activity {
        Activity(id: UUID(), userID: userID ?? owner, sport: .gym, subtype: "Push", status: .completed,
                 plannedAt: nil, startedAt: now.addingTimeInterval(-3600), endedAt: now,
                 distanceMeters: nil, plannedDurationMinutes: 60, note: nil, plannedSessionID: nil)
    }
}
