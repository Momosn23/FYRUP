import XCTest
@testable import FYRUP

final class DiscoveryContentTests: XCTestCase {
    private let owner = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private let other = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private var bench: GymExercise {
        GymExercise(name: "Bankdrücken Langhantel", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .barbell, isCustom: false)
    }

    func testNoAccountDoesNotExposeCachedLibraryOrPlans() {
        XCTAssertTrue(DiscoveryContent.exercises([bench], owner: nil, query: "").isEmpty)
        XCTAssertTrue(DiscoveryContent.plans([WorkoutPlan(ownerID: owner, name: "Privat")], owner: nil, query: "").isEmpty)
    }

    func testLibraryExcludesArchivedAndOtherUsersCustomExercises() {
        let shared = bench
        let own = GymExercise(name: "Eigene Übung", primaryMuscle: .back, createdBy: owner)
        let foreign = GymExercise(name: "Fremde Übung", primaryMuscle: .back, createdBy: other)
        let orphan = GymExercise(name: "Ohne Eigentümer", primaryMuscle: .back)
        var archived = bench; archived.isArchived = true
        XCTAssertEqual(Set(DiscoveryContent.exercises([shared, own, foreign, orphan, archived], owner: owner, query: "").map(\.id)), [shared.id, own.id])
    }

    func testSearchMatchesAccentsAliasesMusclesAndEquipmentTogether() {
        let exercise = bench
        XCTAssertEqual(DiscoveryContent.exercises([exercise], owner: owner, query: "  BANKDRUCKEN   Trizeps ").map(\.id), [exercise.id])
        XCTAssertEqual(DiscoveryContent.exercises([exercise], owner: owner, query: "bench press langhantel").map(\.id), [exercise.id])
        XCTAssertTrue(DiscoveryContent.exercises([exercise], owner: owner, query: "Bankdrücken Kabelzug").isEmpty)
    }

    func testPlanSearchUsesOnlyOwnPlansAndTheirExerciseMetadata() {
        let own = WorkoutPlan(ownerID: owner, name: "Push Day", category: "Gym", exercises: [WorkoutPlanExercise(exercise: bench)])
        let foreign = WorkoutPlan(ownerID: other, name: "Push Day", category: "Gym", visibility: .friends, exercises: own.exercises)
        XCTAssertEqual(DiscoveryContent.plans([foreign, own], owner: owner, query: "push trizeps").map(\.id), [own.id])
        XCTAssertTrue(DiscoveryContent.plans([own], owner: owner, query: "Rücken").isEmpty)
    }

    func testDuplicateRowsAppearOnlyOnceInSortedResults() {
        let first = GymExercise(name: "Alpha", primaryMuscle: .core, isCustom: false)
        let last = GymExercise(name: "Zeta", primaryMuscle: .core, isCustom: false)
        XCTAssertEqual(DiscoveryContent.exercises([last, first, last], owner: owner, query: "").map(\.id), [first.id, last.id])
        let a = WorkoutPlan(ownerID: owner, name: "Alpha")
        let z = WorkoutPlan(ownerID: owner, name: "Zeta")
        XCTAssertEqual(DiscoveryContent.plans([z, a, z], owner: owner, query: "").map(\.id), [a.id, z.id])
    }

    func testPlanAndLibrarySearchShareWordBoundaryRules() {
        let exercise = bench
        let plan = WorkoutPlan(ownerID: owner, name: "Push-Day", exercises: [WorkoutPlanExercise(exercise: exercise)])
        XCTAssertTrue(DiscoveryContent.exercises([exercise], owner: owner, query: "Rücken").isEmpty)
        XCTAssertTrue(DiscoveryContent.plans([plan], owner: owner, query: "Rücken").isEmpty)
        XCTAssertEqual(DiscoveryContent.plans([plan], owner: owner, query: "PUSH bankdrü lang").map(\.id), [plan.id])
        XCTAssertEqual(DiscoveryContent.plans([plan], owner: owner, query: "day bench-pre").map(\.id), [plan.id])
    }

    func testSportSearchUsesActualSportChoices() {
        XCTAssertEqual(DiscoveryContent.sports(query: "LAUFEN"), [.running])
        XCTAssertEqual(DiscoveryContent.sports(query: ""), SportKind.allCases)
        XCTAssertTrue(DiscoveryContent.sports(query: "gibt-es-nicht").isEmpty)
    }

    func testDeferredFoodContentIsNotOfferedAsAnAvailableFilter() {
        XCTAssertEqual(DiscoverySection.allCases.map(\.title), ["Alle", "Workouts", "Übungen", "Sportarten"])
    }
}
