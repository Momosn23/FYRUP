import XCTest
@testable import FYRUP

final class ActiveCalorieGoalSuggestionTests: XCTestCase {
    func testSuggestionRequiresValidWeight() {
        XCTAssertNil(ActiveCalorieGoalSuggestion.make(level: .balanced, heightCM: 180,
            weightKG: nil, stepGoal: 8_000, routine: nil))
        XCTAssertNil(ActiveCalorieGoalSuggestion.make(level: .balanced, heightCM: 180,
            weightKG: 10, stepGoal: 8_000, routine: nil))
    }

    func testLevelChangesTransparentOnDeviceSuggestion() throws {
        let gentle = try XCTUnwrap(ActiveCalorieGoalSuggestion.make(level: .gentle,
            heightCM: nil, weightKG: 80, stepGoal: nil, routine: nil))
        let ambitious = try XCTUnwrap(ActiveCalorieGoalSuggestion.make(level: .ambitious,
            heightCM: nil, weightKG: 80, stepGoal: nil, routine: nil))
        XCTAssertEqual(gentle.kilocalories, 75)
        XCTAssertEqual(ambitious.kilocalories, 350)
        XCTAssertGreaterThan(ambitious.kilocalories, gentle.kilocalories)
        XCTAssertFalse(gentle.usedStepGoal)
        XCTAssertFalse(gentle.usedWeeklyRoutine)
    }

    func testStepGoalCanRaiseSuggestionWithoutBeingAdded() throws {
        let value = try XCTUnwrap(ActiveCalorieGoalSuggestion.make(level: .gentle,
            heightCM: 175, weightKG: 70, stepGoal: 10_000, routine: nil))
        XCTAssertEqual(value.kilocalories, 300)
        XCTAssertTrue(value.usedStepGoal)
        XCTAssertFalse(value.usedWeeklyRoutine)
    }

    func testWeeklyRoutineUsesAverageDayAndDoesNotAddStepGoal() throws {
        let routine = TrainingRoutine(goals: [
            .init(sport: .running, sessions: 3, minutes: 60, weekdays: [1, 3, 5])
        ])
        let value = try XCTUnwrap(ActiveCalorieGoalSuggestion.make(level: .gentle,
            heightCM: 175, weightKG: 70, stepGoal: 10_000, routine: routine))
        XCTAssertEqual(value.kilocalories, 300)
        XCTAssertTrue(value.usedStepGoal)
        XCTAssertTrue(value.usedWeeklyRoutine)
    }

    func testInvalidRoutineEntryIsIgnoredAndResultIsBounded() throws {
        let invalid = TrainingRoutine(goals: [.init(sport: .gym, sessions: 7, minutes: 360, weekdays: [1, 2, 3, 4, 5, 6, 7])])
        let value = try XCTUnwrap(ActiveCalorieGoalSuggestion.make(level: .ambitious,
            heightCM: 250, weightKG: 450, stepGoal: StepDay.maximumSteps, routine: invalid))
        XCTAssertEqual(value.kilocalories, 2_000)
    }
}
