import XCTest
@testable import FYRUP

final class WorkoutModelTests: XCTestCase {
    private let owner = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private var bench: GymExercise {
        GymExercise(name: "Bankdrücken Langhantel", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .barbell, isCustom: false)
    }
    private var plan: WorkoutPlan {
        WorkoutPlan(ownerID: owner, name: "Push Day", exercises: [WorkoutPlanExercise(exercise: bench)])
    }

    func testBundledCatalogContainsEveryPromptRequirementWithFrozenIDs() throws {
        let fixtureURL = try XCTUnwrap(Bundle(for: WorkoutModelTests.self).url(forResource: "exercise-catalog-required", withExtension: "tsv"))
        let fixture = try String(contentsOf: fixtureURL, encoding: .utf8)
        let rows = fixture.components(separatedBy: .newlines).filter { !$0.isEmpty && !$0.hasPrefix("#") }
        XCTAssertEqual(rows.count, 127)
        XCTAssertGreaterThanOrEqual(ExerciseLibrary.all.count, 122)
        XCTAssertEqual(Set(ExerciseLibrary.all.map(\.id)).count, ExerciseLibrary.all.count)
        for row in rows {
            let fields = row.components(separatedBy: "\t")
            XCTAssertEqual(fields.count, 3)
            guard fields.count == 3 else { continue }
            let muscle = try XCTUnwrap(MuscleGroup(rawValue: fields[0]))
            let id = try XCTUnwrap(UUID(uuidString: fields[2]))
            let exercise = try XCTUnwrap(ExerciseLibrary.all.first { $0.id == id }, "Fehlt: \(fields[1])")
            XCTAssertTrue(exercise.muscleGroups.contains(muscle), "Falsche Muskelzuordnung: \(fields[1]) → \(fields[0])")
            XCTAssertTrue(exercise.matches(query: fields[1]), "Name/Alias nicht auffindbar: \(fields[1])")
            XCTAssertFalse(exercise.isCustom)
            XCTAssertNil(exercise.createdBy)
            XCTAssertNil(exercise.validationMessage)
        }
    }

    func testExplicitCatalogIDsSurviveReorderingAndInsertedRows() {
        let a = "10000000-0000-0000-0000-000000000001\tBankdrücken\tchest\ttriceps\tbarbell\tstrength"
        let b = "10000000-0000-0000-0000-000000000002\tPlank\tcore\tshoulders\tbodyweight\ttimed"
        let first = ExerciseLibrary.parse("# comment\n\(a)\n\(b)")
        let reordered = ExerciseLibrary.parse("# a different comment\n\(b)\n\n\(a)")
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(Set(first), Set(reordered))
    }

    func testCatalogRejectsBrokenMetadataAndDuplicateIDs() {
        let id = "10000000-0000-0000-0000-000000000001"
        let valid = "\(id)\tBankdrücken\tchest\ttriceps\tbarbell\tstrength"
        XCTAssertEqual(ExerciseLibrary.parse("\(valid)\n\(valid)").count, 1)
        XCTAssertTrue(ExerciseLibrary.parse("\(id)\tBankdrücken\tchest\tinvalid\tbarbell\tstrength").isEmpty)
        XCTAssertTrue(ExerciseLibrary.parse("\(id)\tBankdrücken\tchest\ttriceps,triceps\tbarbell\tstrength").isEmpty)
        XCTAssertTrue(ExerciseLibrary.parse("\(id)\tBankdrücken\tchest\tchest\tbarbell\tstrength").isEmpty)
        XCTAssertTrue(ExerciseLibrary.parse("\(id)\tBankdrücken\tchest\ttriceps\tbarbell\tunknown").isEmpty)
    }

    func testSearchIncludesAliasesAccentsSecondaryMusclesAndEquipment() {
        XCTAssertTrue(bench.matches(query: "BANKDRUCKEN brust"))
        XCTAssertTrue(bench.matches(query: "trizeps langhantel"))
        XCTAssertTrue(bench.matches(query: "bench press"))
        XCTAssertFalse(bench.matches(query: "kabel"))
        let bulgarian = GymExercise(name: "Bulgarian Split Squats", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell)
        XCTAssertTrue(bulgarian.matches(query: "Bulgarian Split Squat"))
        XCTAssertTrue(bulgarian.matches(query: "Bulgarische Gesäß"))
        let farmer = GymExercise(name: "Farmer's Walk", primaryMuscle: .forearms, secondaryMuscles: [.traps])
        XCTAssertTrue(farmer.matches(query: "Farmers Walk"))
    }

    func testDuplicateSuggestionsAreNonBlockingAndOnlyIncludeActiveCustomExercises() {
        var own = GymExercise(name: "Prime Chest Press", primaryMuscle: .chest, createdBy: owner)
        XCTAssertTrue(own.hasSimilarName(to: " PRIME chest-press "))
        XCTAssertTrue(own.hasSimilarName(to: "Prime Chest Pres"))
        XCTAssertFalse(own.hasSimilarName(to: "Prime Shoulder Press"))
        XCTAssertEqual(ExerciseLibrary.duplicateCandidates(named: own.name, in: [own, bench]).map(\.id), [own.id])
        own.isArchived = true
        XCTAssertTrue(ExerciseLibrary.duplicateCandidates(named: own.name, in: [own]).isEmpty)
        XCTAssertTrue(ExerciseLibrary.matching(query: "Prime", in: [own]).isEmpty)
        XCTAssertNil(GymExercise(name: "Prime Chest Press", primaryMuscle: .chest).validationMessage)
    }

    func testNormalizationTrimsInputAndReindexesDragOrder() {
        var value = plan
        value.name = " \nPush Day \n"
        value.category = " Push "
        value.description = "  "
        value.exercises[0].sortOrder = 24
        value.exercises[0].note = "  Am Kabelzug  "
        value.exercises[0].exercise.name = " Prime Chest Press "
        value.exercises[0].exercise.secondaryMuscles = [.chest, .triceps, .triceps, .shoulders]
        value.exercises.insert(WorkoutPlanExercise(exercise: bench, sortOrder: 24), at: 0)
        let normalized = value.normalizedForSaving()
        XCTAssertEqual(normalized.name, "Push Day")
        XCTAssertEqual(normalized.category, "Push")
        XCTAssertNil(normalized.description)
        XCTAssertEqual(normalized.exercises.map(\.sortOrder), [0, 1])
        XCTAssertEqual(normalized.exercises[1].note, "Am Kabelzug")
        XCTAssertEqual(normalized.exercises[1].exercise.name, "Prime Chest Press")
        XCTAssertEqual(normalized.exercises[1].exercise.secondaryMuscles, [.triceps, .shoulders])
        XCTAssertNil(normalized.validationMessage)
    }

    func testPlanRejectsInvalidNumbersIncludingNonFiniteWeights() {
        XCTAssertNil(plan.validationMessage)
        for weight in [Double.nan, Double.infinity, -Double.infinity, -0.1, 2000.1] {
            var value = plan
            value.exercises[0].targetWeight = weight
            XCTAssertNotNil(value.validationMessage)
        }
        for sets in [Int.min, 0, 31, Int.max] {
            var value = plan
            value.exercises[0].targetSets = sets
            XCTAssertNotNil(value.validationMessage)
        }
        var reversed = plan
        reversed.exercises[0].targetRepsMin = 12
        reversed.exercises[0].targetRepsMax = 8
        XCTAssertNotNil(reversed.validationMessage)
        var tooMany = plan
        tooMany.exercises[0].targetRepsMax = 1000
        XCTAssertNotNil(tooMany.validationMessage)
    }

    func testPlanLimitsNamesNotesAndDuplicatePositionsButAllowsExerciseVariants() {
        var value = plan
        value.name = " \n "
        XCTAssertNotNil(value.validationMessage)
        value = plan
        value.description = String(repeating: "x", count: 1001)
        XCTAssertNotNil(value.validationMessage)
        value = plan
        value.exercises[0].note = String(repeating: "x", count: 501)
        XCTAssertNotNil(value.validationMessage)
        value = plan
        value.exercises.append(value.exercises[0])
        XCTAssertNotNil(value.validationMessage)
        value.exercises[1].id = UUID()
        XCTAssertNil(value.validationMessage)
        value.exercises = []
        XCTAssertNotNil(value.validationMessage)
    }

    func testOptionalTrackingAcceptsNoWeightOrRepsAndKeepsActualSetValues() throws {
        let easy = WorkoutSetLog(setNumber: 1, completed: true)
        XCTAssertNil(easy.validationMessage)
        let sets = [8, 8, 7].enumerated().map { WorkoutSetLog(setNumber: $0.offset + 1, weight: 80, reps: $0.element, completed: true) }
        let encoded = try JSONEncoder().encode(sets)
        let decoded = try JSONDecoder().decode([WorkoutSetLog].self, from: encoded)
        XCTAssertEqual(decoded.map(\.weight), [80, 80, 80])
        XCTAssertEqual(decoded.map(\.reps), [8, 8, 7])
        XCTAssertTrue(decoded.allSatisfy { $0.completed && $0.validationMessage == nil })
        XCTAssertNotNil(WorkoutSetLog(setNumber: 1, weight: .nan).validationMessage)
        XCTAssertNotNil(WorkoutSetLog(setNumber: 1, reps: -1).validationMessage)
        XCTAssertNotNil(WorkoutSetLog(setNumber: 31).validationMessage)
    }

    func testCopyOwnsIndependentCustomExercisesAndKeepsRepeatedReferencesConsistent() {
        let max = UUID()
        let custom = GymExercise(name: "Prime Chest Press", primaryMuscle: .chest, createdBy: owner, isArchived: true)
        let original = WorkoutPlan(ownerID: owner, name: "Push Day", visibility: .friends, exercises: [WorkoutPlanExercise(exercise: custom), WorkoutPlanExercise(exercise: custom), WorkoutPlanExercise(exercise: bench)])
        var copy = original.independentCopy(ownerID: max)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.ownerID, max)
        XCTAssertEqual(copy.copiedFromPlanID, original.id)
        XCTAssertEqual(copy.visibility, .private)
        XCTAssertNotEqual(copy.exercises[0].exercise.id, custom.id)
        XCTAssertEqual(copy.exercises[0].exercise.id, copy.exercises[1].exercise.id)
        XCTAssertEqual(copy.exercises[0].exercise.createdBy, max)
        XCTAssertFalse(copy.exercises[0].exercise.isArchived)
        XCTAssertEqual(copy.exercises[2].exercise.id, original.exercises[2].exercise.id)
        XCTAssertTrue(Set(copy.exercises.map(\.id)).isDisjoint(with: original.exercises.map(\.id)))
        copy.exercises[0].exercise.name = "Max Chest Press"
        copy.exercises[0].targetSets = 5
        XCTAssertEqual(original.exercises[0].exercise.name, "Prime Chest Press")
        XCTAssertEqual(original.exercises[0].targetSets, 3)
    }

    func testLogSnapshotsAndSetDataSurviveSourceExerciseArchiving() throws {
        var source = GymExercise(name: "Prime Chest Press", primaryMuscle: .chest, createdBy: owner)
        let row = WorkoutExerciseLog(exercise: source, sortOrder: 0, targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, completed: true, sets: [WorkoutSetLog(setNumber: 1, weight: 80, reps: 8, completed: true)])
        let log = WorkoutLog(activityID: UUID(), planName: "Push Day", exercises: [row])
        source.name = "Anderer Name"
        source.isArchived = true
        let persisted = try JSONDecoder().decode(WorkoutLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(persisted.exercises[0].exercise.name, "Prime Chest Press")
        XCTAssertEqual(persisted.completedExercises, 1)
        XCTAssertEqual(persisted.completedSets, 1)
        XCTAssertEqual(persisted.progress, 1)
        XCTAssertNil(persisted.currentExercise)
        XCTAssertNil(persisted.validationMessage)
        var duplicate = persisted
        duplicate.exercises[0].sets.append(duplicate.exercises[0].sets[0])
        XCTAssertNotNil(duplicate.validationMessage)
    }

    func testExerciseAndPlanCodingUseBackendKeys() throws {
        let value = plan
        let encoded = try JSONEncoder().encode(value)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["owner_id"] as? String, owner.uuidString)
        XCTAssertEqual(object["visibility"] as? String, "private")
        let items = try XCTUnwrap(object["exercises"] as? [[String: Any]])
        XCTAssertEqual(items[0]["target_sets"] as? Int, 3)
        let exercise = try XCTUnwrap(items[0]["exercise"] as? [String: Any])
        XCTAssertEqual(exercise["primary_muscle_group"] as? String, "chest")
        XCTAssertEqual(exercise["secondary_muscles"] as? [String], ["triceps", "shoulders"])
        XCTAssertEqual(try JSONDecoder().decode(WorkoutPlan.self, from: encoded), value)
    }

    func testPrescriptionUsesSecondsForTimedExercisesAndNoDuplicateRange() {
        let plank = GymExercise(name: "Plank", primaryMuscle: .core, exerciseType: "timed")
        XCTAssertEqual(WorkoutPlanExercise(exercise: plank, targetRepsMin: 30, targetRepsMax: 30).prescription, "3 × 30 Sek.")
        XCTAssertEqual(WorkoutPlanExercise(exercise: bench).prescription, "3 × 8–12")
    }
}
