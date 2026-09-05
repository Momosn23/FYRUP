import XCTest
@testable import FYRUP

final class WorkoutTrackingInputTests: XCTestCase {
    func testEmptyTrackingFieldsDoNotFabricateTargetValues() throws {
        let set = WorkoutSetLog(setNumber: 1)
        let result = try WorkoutSetEntryInput().applying(to: set, completed: true)
        XCTAssertNil(result.weight)
        XCTAssertNil(result.reps)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.id, set.id)
    }

    func testGermanDecimalCommaAndWhitespaceAreAccepted() throws {
        let result = try WorkoutSetEntryInput(weight: " 80,5 ", reps: " 8 ").applying(to: WorkoutSetLog(setNumber: 1), completed: true)
        XCTAssertEqual(result.weight, 80.5)
        XCTAssertEqual(result.reps, 8)
    }

    func testDecimalPrecisionSurvivesOpeningAndResaving() throws {
        for value in [80.05, 80.005, 0.05, 80, 0] {
            let original = WorkoutSetLog(setNumber: 1, weight: value, reps: 8, completed: true)
            let input = WorkoutSetEntryInput(set: original)
            let result = try input.applying(to: original, completed: true)
            XCTAssertEqual(result.weight, value)
            XCTAssertEqual(result.reps, 8)
        }
    }

    func testInvalidMeasurementsAreRejectedBeforeMutation() {
        let original = WorkoutSetLog(setNumber: 1, weight: 80, reps: 8)
        for weight in ["NaN", "inf", "-1", "2001", "80kg", "80,5,1"] {
            let input = WorkoutSetEntryInput(weight: weight, reps: "8")
            XCTAssertNotNil(input.validationMessage)
            XCTAssertThrowsError(try input.applying(to: original, completed: true))
        }
        for reps in ["8.5", "8,5", "-1", "1000", "abc"] {
            let input = WorkoutSetEntryInput(weight: "80", reps: reps)
            XCTAssertNotNil(input.validationMessage)
            XCTAssertThrowsError(try input.applying(to: original, completed: true))
        }
        XCTAssertEqual(original.weight, 80)
        XCTAssertEqual(original.reps, 8)
        XCTAssertFalse(original.completed)
    }

    func testValueOnlySaveDoesNotMarkAnOpenSetCompleted() throws {
        let result = try WorkoutSetEntryInput(weight: "80", reps: "8").applying(to: WorkoutSetLog(setNumber: 1), completed: false)
        XCTAssertEqual(result.weight, 80)
        XCTAssertEqual(result.reps, 8)
        XCTAssertFalse(result.completed)
        XCTAssertNil(result.completedAt)
    }

    func testActualSetSeriesPreservesEightyByEightEightSeven() throws {
        let values = [8, 8, 7]
        let results = try values.enumerated().map { index, reps in
            try WorkoutSetEntryInput(weight: "80", reps: String(reps)).applying(to: WorkoutSetLog(setNumber: index + 1), completed: true)
        }
        XCTAssertEqual(results.map(\.weight), [80, 80, 80])
        XCTAssertEqual(results.map(\.reps), [8, 8, 7])
        XCTAssertEqual(results.map(\.setNumber), [1, 2, 3])
        XCTAssertTrue(results.allSatisfy(\.completed))
    }
}
