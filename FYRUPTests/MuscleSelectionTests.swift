import XCTest
import SwiftUI
@testable import FYRUP

final class MuscleSelectionTests: XCTestCase {
    func testEachBodyMuscleHasOneControlAndAnActivationPointInsideItsPaintedShape() {
        for side in [MuscleBodySide.front, .back] {
            let regions = BodyMuscleRegion.regions(side)
            XCTAssertEqual(regions.count, Set(BodyPatch.patches(side).map(\.muscle)).count)
            for region in regions {
                let bounds = region.bounds, point = region.activationPoint
                XCTAssertTrue((0...1).contains(point.x)); XCTAssertTrue((0...1).contains(point.y))
                let absolute = CGPoint(x: bounds.minX + bounds.width * point.x, y: bounds.minY + bounds.height * point.y)
                XCTAssertTrue(BodyMuscleShape(region: region).path(in: bounds).contains(absolute), "\(region.muscle) must have a real painted activation point")
            }
            XCTAssertEqual(regions.filter { $0.muscle == .core }.count, 1)
        }
    }
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
