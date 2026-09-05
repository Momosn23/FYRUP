import XCTest
@testable import FYRUP

final class FeaturePresentationTests: XCTestCase {
    private let owner = UUID(uuidString: "83000000-0000-0000-0000-000000000001")!
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    func testStepNumbersAlwaysUseGermanGrouping() {
        for (value, expected) in [(0, "0"), (999, "999"), (1000, "1.000"), (7500, "7.500"), (8421, "8.421"), (10000, "10.000"), (100000, "100.000")] {
            XCTAssertEqual(StepCountFormat.string(value), expected)
        }
    }

    func testPlanLabelsUseSingularAndDoNotInventFocus() {
        var plan = WorkoutPlan(ownerID: owner, name: "Push Day", exercises: [WorkoutPlanExercise(exercise: exercise)])
        XCTAssertEqual(WorkoutPlanText.exerciseCount(0), "0 Übungen")
        XCTAssertEqual(WorkoutPlanText.subtitle(plan), "1 Übung")
        plan.category = "  "
        XCTAssertEqual(WorkoutPlanText.subtitle(plan), "1 Übung")
        plan.category = " Push "
        XCTAssertEqual(WorkoutPlanText.subtitle(plan), "1 Übung · Push")
        plan.exercises.append(WorkoutPlanExercise(exercise: exercise, sortOrder: 1))
        XCTAssertEqual(WorkoutPlanText.subtitle(plan), "2 Übungen · Push")
    }

    func testShareSummaryExportsOnlySportActiveDurationAndAggregateCount() throws {
        let activity = completedActivity()
        let log = workoutLog(activityID: activity.id)
        let summary = try XCTUnwrap(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
        XCTAssertEqual(summary.ownerID, owner)
        XCTAssertEqual(summary.text, "Workout geschafft mit FYRUP! 💪\nGym · 00:55:00 aktive Zeit\n1 von 2 Übungen abgeschlossen.")
        for secret in ["Privater Planname", "Geheime Übung", "Private Notiz", "Privater Ort", "137.5", "Kilogramm", "Wiederholungen", "Satz", owner.uuidString, activity.id.uuidString] {
            XCTAssertFalse(summary.text.contains(secret), "Export leaked \(secret)")
        }
    }

    func testShareSummaryRejectsAnotherAccountAndUnmatchedLog() {
        let activity = completedActivity()
        let log = workoutLog(activityID: activity.id)
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: nil))
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: UUID()))
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: workoutLog(activityID: UUID()), ownerID: owner))
    }

    func testShareSummaryRequiresReallyCompletedActivityAndRecordedEnd() {
        var activity = completedActivity()
        let log = workoutLog(activityID: activity.id)
        activity.status = .live
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
        activity.status = .cancelled
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
        activity.status = .completed; activity.endedAt = nil
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
    }

    func testShareSummaryRejectsMalformedTimeAndLog() {
        var activity = completedActivity()
        var log = workoutLog(activityID: activity.id)
        activity.endedAt = start.addingTimeInterval(-1)
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
        activity.endedAt = Date(timeIntervalSince1970: .infinity)
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
        activity = completedActivity(id: activity.id)
        log.exercises = []
        XCTAssertNil(WorkoutShareSummary(activity: activity, log: log, ownerID: owner))
    }

    private var exercise: GymExercise {
        GymExercise(name: "Geheime Übung", primaryMuscle: .chest, secondaryMuscles: [], equipment: .barbell, isCustom: true, createdBy: owner)
    }
    private func completedActivity(id: UUID = UUID()) -> Activity {
        Activity(id: id, userID: owner, sport: .gym, subtype: "Privater Planname", status: .completed,
                 plannedAt: nil, startedAt: start, endedAt: start.addingTimeInterval(3600), distanceMeters: nil,
                 plannedDurationMinutes: nil, note: "Private Notiz · Privater Ort", plannedSessionID: nil,
                 workoutPlanID: UUID(), pausedSeconds: 300)
    }
    private func workoutLog(activityID: UUID) -> WorkoutLog {
        let completed = WorkoutExerciseLog(exercise: exercise, sortOrder: 0, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12,
                                           targetWeight: 140, note: "Private Notiz", completed: true, completedAt: start.addingTimeInterval(3300),
                                           sets: [WorkoutSetLog(setNumber: 1, weight: 137.5, reps: 9, completed: true, completedAt: start.addingTimeInterval(3200))])
        let open = WorkoutExerciseLog(exercise: exercise, sortOrder: 1, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, sets: [])
        return WorkoutLog(activityID: activityID, planName: "Privater Planname", exercises: [completed, open])
    }
}
