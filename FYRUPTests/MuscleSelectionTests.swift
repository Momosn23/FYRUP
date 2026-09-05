import XCTest
@testable import FYRUP

final class MuscleSelectionTests: XCTestCase {
    func testGymMappingRoundTripsEveryAreaAndRejectsUnmappedCategories() {
        let areas = Set(GymBodyArea.allCases)
        XCTAssertEqual(MuscleSelection.groups(for: areas).count, areas.count)
        XCTAssertEqual(MuscleSelection.areas(for: MuscleSelection.groups(for: areas)), areas)
        XCTAssertEqual(MuscleSelection.areas(for: [.fullBody, .other]), [])
        XCTAssertEqual(MuscleSelection.gymGroups, MuscleSelection.anatomical)
        XCTAssertEqual(MuscleSelection.areas(for: [.core, .chest]), [.core, .chest])
    }

    func testPresetsCoverEveryAnatomicalMuscleWithoutInventingAnOtherRegion() {
        XCTAssertEqual(MuscleSelection.upper.union(MuscleSelection.lower).union([.core]), MuscleSelection.anatomical)
        XCTAssertTrue(MuscleSelection.upper.isDisjoint(with: MuscleSelection.lower))
        XCTAssertEqual(MuscleSelection.Preset.whole.groups, MuscleSelection.anatomical.union([.fullBody]))
        XCTAssertFalse(MuscleSelection.Preset.whole.groups.contains(.other))
        XCTAssertEqual(MuscleSelection.Preset.lower.groups.intersection(MuscleSelection.gymGroups), [.quads, .hamstrings, .glutes, .calves, .adductors])
    }

    func testDiagramActuallyContainsAllThirteenAnatomicalMuscles() {
        let front = BodyPatch.patches(.front), back = BodyPatch.patches(.back)
        XCTAssertEqual(Set((front + back).map(\.muscle)), MuscleSelection.anatomical)
        XCTAssertTrue(Set(front.map(\.muscle)).isSuperset(of: [.chest, .biceps, .core, .quads, .adductors]))
        XCTAssertTrue(Set(back.map(\.muscle)).isSuperset(of: [.back, .triceps, .traps, .hamstrings, .glutes, .calves]))
        for patch in front + back {
            XCTAssertGreaterThan(patch.bounds.width, 0)
            XCTAssertGreaterThan(patch.bounds.height, 0)
            XCTAssertTrue(patch.points.allSatisfy { (0...100).contains($0.x) && (0...260).contains($0.y) })
            XCTAssertEqual(patch.mirrored.mirrored.points, patch.points)
        }
    }

    func testFilterMatchesPrimaryOrSecondaryAndCombinesMusclesAsAlternatives() {
        let bench = GymExercise(name: "Bankdrücken", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders])
        XCTAssertTrue(MuscleSelection.matches(bench, selected: []))
        XCTAssertTrue(MuscleSelection.matches(bench, selected: [.chest]))
        XCTAssertTrue(MuscleSelection.matches(bench, selected: [.triceps]))
        XCTAssertTrue(MuscleSelection.matches(bench, selected: [.calves, .shoulders]))
        XCTAssertFalse(MuscleSelection.matches(bench, selected: [.core, .back]))
        XCTAssertFalse(MuscleSelection.matches(bench, selected: [.other, .fullBody]))
        XCTAssertTrue(MuscleSelection.matches(bench, selected: MuscleSelection.Preset.whole.groups))
    }

    func testEveryMuscleFilterReturnsOnlyMatchingCatalogExercises() {
        XCTAssertEqual(ExerciseLibrary.all.count, 122)
        for muscle in MuscleGroup.allCases {
            let found = ExerciseLibrary.all.filter { MuscleSelection.matches($0, selected: [muscle]) }
            XCTAssertTrue(found.allSatisfy { $0.primaryMuscle == muscle || $0.secondaryMuscles.contains(muscle) })
        }
        let core = ExerciseLibrary.all.filter { MuscleSelection.matches($0, selected: [.core]) }
        XCTAssertTrue(core.contains { $0.name == "Plank" })
        XCTAssertTrue(core.contains { $0.name == "Copenhagen Plank" }, "Secondary muscles must be included.")
        XCTAssertFalse(core.contains { $0.name == "Bankdrücken Langhantel" })
    }
}
