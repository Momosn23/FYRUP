import XCTest
@testable import FYRUP

@MainActor
final class PersonalTrainingTests: XCTestCase {
    private let owner = DemoRepository.defaultUserID
    private let other = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let calendar = TrainingWeekLogic.calendar(timezone: TimeZone(identifier: "Europe/Berlin")!)
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func denied(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("Must reject", file: file, line: line) } catch { }
    }
    private func activity(owner: UUID? = nil, status: ActivityStatus = .completed, end: Date) -> Activity {
        Activity(id: UUID(), userID: owner ?? self.owner, sport: .gym, subtype: nil, status: status,
                 plannedAt: nil, startedAt: end.addingTimeInterval(-600), endedAt: status == .completed ? end : nil,
                 distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)
    }

    func testRoutineValidatesFixedFlexibleAndOptionalDuration() {
        XCTAssertNil(TrainingRoutine().validationMessage)
        XCTAssertNil(TrainingRoutineGoal(sport: .gym, sessions: 2, minutes: 60, weekdays: [1, 5]).validationMessage)
        XCTAssertNil(TrainingRoutineGoal(sport: .running, sessions: 1).validationMessage)
        for number in [0, 8, Int.max] { XCTAssertNotNil(TrainingRoutineGoal(sport: .gym, sessions: number).validationMessage) }
        for minutes in [0, 4, 361] { XCTAssertNotNil(TrainingRoutineGoal(sport: .gym, minutes: minutes).validationMessage) }
        for days in [[0], [8], [1, 1], [1, 2, 3]] { XCTAssertNotNil(TrainingRoutineGoal(sport: .gym, weekdays: days).validationMessage) }
        XCTAssertNotNil(TrainingRoutine(goals: [.init(sport: .gym), .init(sport: .gym)]).validationMessage)
        XCTAssertNotNil(TrainingRoutine(revision: Int.max).validationMessage)
    }
    func testDaySummaryDistinguishesMissingDataFromEmptyDay() {
        let day = date("2026-09-08T12:00:00Z")
        XCTAssertEqual(WeeklyDaySummary(snapshot: nil, ownerID: owner, day: day, calendar: calendar).title, "Noch nicht geladen")
        XCTAssertEqual(WeeklyDaySummary(snapshot: .init(), ownerID: owner, day: day, calendar: calendar).title, "Keine Session geplant")
    }
    func testDaySummaryKeepsUpcomingSessionAlongsideActualCompletions() {
        let day = date("2026-09-08T12:00:00Z")
        let done = activity(end: day)
        let session = PlannedSession(id: UUID(), hostID: owner, sport: .gym, subtype: "Mein Push Day", startsAt: day.addingTimeInterval(3600),
                                     durationMinutes: 60, note: nil, placeName: nil, friendsCanJoin: false, status: "planned")
        var cancelled = session; cancelled.status = "cancelled"
        let summary = WeeklyDaySummary(snapshot: .init(activities: [done, done, activity(owner: other, end: day)], sessions: [cancelled, session, session]),
                                       ownerID: owner, day: day, calendar: calendar)
        XCTAssertEqual(summary.completed.count, 1)
        XCTAssertEqual(summary.planned.count, 1)
        XCTAssertEqual(summary.title, "Mein Push Day")
        XCTAssertEqual(summary.detail, "1 abgeschlossen · 1 geplant")
    }
    func testFeedbackSupportsOptionalEffortReplacementAndClear() throws {
        let exercise = UUID(); var value = PersonalWorkoutFeedback(activityID: UUID())
        value.setEffort(.easy, for: exercise); value.setEffort(.hardcore, for: exercise)
        XCTAssertEqual(value.exercises.count, 1); XCTAssertEqual(value.effort(for: exercise), .hardcore)
        value.setEffort(nil, for: exercise); XCTAssertTrue(value.exercises.isEmpty)
        value.feeling = .okay; value.note = "Mein privater Rückblick"
        XCTAssertEqual(try JSONDecoder().decode(PersonalWorkoutFeedback.self, from: JSONEncoder().encode(value)), value)
        value.note = String(repeating: "x", count: 501); XCTAssertNotNil(value.validationMessage)
        value.note = String(repeating: "e\u{301}", count: 251); XCTAssertNotNil(value.validationMessage, "Match server Unicode scalar length, not grapheme count")
    }
    func testWeekIsMondayThroughSundayAcrossISOYearBoundary() {
        let days = TrainingWeekLogic.days(containing: date("2027-01-01T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(TrainingWeekLogic.weekday(days[0], calendar: calendar), 1)
        XCTAssertEqual(TrainingWeekLogic.weekday(days[6], calendar: calendar), 7)
        XCTAssertEqual(calendar.component(.day, from: days[0]), 28)
        XCTAssertEqual(calendar.component(.month, from: days[0]), 12)
    }
    func testDSTWeeksContainSevenLocalDaysWithoutFixedSecondAssumption() {
        let spring = TrainingWeekLogic.interval(containing: date("2026-03-29T12:00:00Z"), calendar: calendar)!
        let autumn = TrainingWeekLogic.interval(containing: date("2026-10-25T12:00:00Z"), calendar: calendar)!
        XCTAssertEqual(spring.duration, 167 * 3600)
        XCTAssertEqual(autumn.duration, 169 * 3600)
        XCTAssertEqual(TrainingWeekLogic.days(containing: spring.start, calendar: calendar).count, 7)
    }
    func testOnlyOwnActualCompletionAndUniqueIDsProduceCheckmark() {
        let end = date("2026-09-01T22:30:00Z") // Sept 2 locally, even if started yesterday.
        var own = activity(end: end); own.startedAt = end.addingTimeInterval(-7200)
        let items = [own, own, activity(owner: other, end: end), activity(status: .live, end: end), activity(status: .cancelled, end: end)]
        XCTAssertEqual(TrainingWeekLogic.completed(items, owner: owner, day: end, calendar: calendar).map(\.id), [own.id])
        XCTAssertTrue(TrainingWeekLogic.completed(items, owner: owner, day: end.addingTimeInterval(-86400), calendar: calendar).isEmpty)
        XCTAssertEqual(TrainingWeekLogic.completedCount(sport: .gym, activities: items, owner: owner, now: end, calendar: calendar), 1)
        XCTAssertEqual(TrainingWeekLogic.completedCount(sport: .running, activities: items, owner: owner, now: end, calendar: calendar), 0)
    }
    func testRoutinePersistsAndStaleDeviceCannotOverwrite() async throws {
        let suite = "FYRUP.PersonalTests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let repo = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite))
        let initial = try await repo.trainingRoutine(); XCTAssertEqual(initial.revision, 0)
        var draft = initial; draft.goals = [.init(sport: .gym, sessions: 2, minutes: 60, weekdays: [1, 5]), .init(sport: .running)]
        let saved = try await repo.saveTrainingRoutine(draft)
        XCTAssertEqual(saved.revision, 1)
        await denied { _ = try await repo.saveTrainingRoutine(draft) }
        let restarted = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite))
        let restored = try await restarted.trainingRoutine(); XCTAssertEqual(restored, saved)
        let stranger = DemoRepository(userID: other, workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite))
        let foreign = try await stranger.trainingRoutine(); XCTAssertTrue(foreign.goals.isEmpty)
        var clear = restored; clear.goals = []
        let cleared = try await restarted.saveTrainingRoutine(clear)
        XCTAssertEqual(cleared.revision, 2); XCTAssertTrue(cleared.goals.isEmpty)
    }
    func testFeedbackActualLogPersistsPrivatelyAfterRelaunch() async throws {
        let suite = "FYRUP.PersonalFeedbackTests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let storage = DemoWorkoutStorage(persistenceSuiteName: suite)
        let repo = DemoRepository(workoutStorage: storage)
        let plan = try await repo.saveWorkoutPlan(WorkoutPlan(ownerID: owner, name: "Private Push", exercises: [.init(exercise: ExerciseLibrary.all[0], sortOrder: 0)]))
        let started = try await repo.startWorkout(planID: plan.id, linkedActivityID: nil, sessionID: nil)
        let log = try await repo.workoutLog(activityID: started.id)
        let exercise = try XCTUnwrap(log.exercises.first?.id)
        var draft = try await repo.workoutFeedback(activityID: started.id)
        draft.setEffort(.hardcore, for: exercise)
        let effort = try await repo.saveWorkoutFeedback(draft)
        var premature = effort; premature.feeling = .great
        await denied { _ = try await repo.saveWorkoutFeedback(premature) }
        var invalid = effort; invalid.setEffort(.easy, for: UUID())
        await denied { _ = try await repo.saveWorkoutFeedback(invalid) }
        let ended = try await repo.completeActivity(id: started.id, distanceMeters: nil)
        var review = effort; review.feeling = .okay; review.note = "  Private reflection  "
        let saved = try await repo.saveWorkoutFeedback(review)
        XCTAssertEqual(saved.note, "Private reflection")
        await denied { _ = try await repo.saveWorkoutFeedback(review) }
        let restarted = DemoRepository(workoutStorage: DemoWorkoutStorage(persistenceSuiteName: suite))
        let restored = try await restarted.workoutFeedback(activityID: started.id)
        XCTAssertEqual(restored, saved)
        let stranger = DemoRepository(userID: other, workoutStorage: storage)
        await denied { _ = try await stranger.workoutFeedback(activityID: started.id) }
        await denied { _ = try await stranger.saveWorkoutFeedback(saved) }
        let export = try XCTUnwrap(WorkoutShareSummary(activity: ended, log: log, ownerID: owner))
        XCTAssertFalse(export.text.contains("Private")); XCTAssertFalse(export.text.contains("Hardcore")); XCTAssertFalse(export.text.contains("reflection"))
    }
    func testReadFailureDoesNotInventEmptyRoutineOrAllowOverwrite() async {
        let repo = PersonalTrainingStub(); await repo.failReads(true)
        let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        await store.loadRoutine(); XCTAssertNil(store.routine); XCTAssertNotNil(store.routineError)
        let saved = await store.saveRoutine(TrainingRoutine()); XCTAssertFalse(saved)
        let writes = await repo.routineWrites; XCTAssertEqual(writes, 0)
    }
    func testStoreKeepsConfirmedRoutineWhenSaveFails() async {
        let repo = PersonalTrainingStub(); let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        await store.loadRoutine(); var draft = store.routine!; draft.goals = [.init(sport: .gym)]
        await repo.failWrites(true)
        let saved = await store.saveRoutine(draft)
        XCTAssertFalse(saved); XCTAssertEqual(store.routine?.revision, 0); XCTAssertTrue(store.routine?.goals.isEmpty == true)
        XCTAssertNotNil(store.routineError)
    }
    func testHeldRoutineReadCannotReturnAfterLogout() async {
        let repo = PersonalTrainingStub(); await repo.holdRoutine()
        let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        let request = Task { await store.loadRoutine() }
        for _ in 0..<100 { if await repo.hasHeldRoutine { break }; await Task.yield() }
        let held = await repo.hasHeldRoutine; XCTAssertTrue(held)
        store.activate(userID: nil); await repo.releaseRoutine(); await request.value
        XCTAssertNil(store.routine); XCTAssertNil(store.userID); XCTAssertFalse(store.isLoadingRoutine)
    }
    func testHeldWeekReadCannotReappearAfterFriendRevocation() async {
        let repo = PersonalTrainingStub(); await repo.holdWeek()
        let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        let request = Task { await store.loadWeek() }
        for _ in 0..<100 { if await repo.hasHeldWeek { break }; await Task.yield() }
        let held = await repo.hasHeldWeek; XCTAssertTrue(held)
        store.invalidateWeekAccess(); await repo.releaseWeek(); await request.value
        XCTAssertNil(store.week); XCTAssertFalse(store.isLoadingWeek)
    }
    func testStoreRejectsUnexpectedForeignActivityInWeek() async {
        let repo = PersonalTrainingStub(); await repo.setWeek(TrainingWeekSnapshot(activities: [activity(owner: other, end: .now)]))
        let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        await store.loadWeek(); XCTAssertNil(store.week); XCTAssertNotNil(store.weekError)
    }
    func testFeedbackSaveFailureRetainsConfirmedEffortAndLogoutClearsIt() async {
        let repo = PersonalTrainingStub(); let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        let id = UUID(); await store.loadFeedback(activityID: id)
        var value = store.feedback[id]!; value.setEffort(.easy, for: UUID())
        let initiallySaved = await store.saveFeedback(value); XCTAssertTrue(initiallySaved)
        await repo.failWrites(true)
        value = store.feedback[id]!; value.feeling = .great
        let saved = await store.saveFeedback(value); XCTAssertFalse(saved)
        XCTAssertNil(store.feedback[id]?.feeling); XCTAssertEqual(store.feedback[id]?.exercises.count, 1)
        store.activate(userID: other)
        XCTAssertTrue(store.feedback.isEmpty); XCTAssertTrue(store.feedbackErrors.isEmpty)
    }
    func testConcurrentFeedbackLoadWaitsForTheConfirmedResult() async {
        let repo = PersonalTrainingStub(); await repo.holdFeedback()
        let store = PersonalTrainingStore(repository: repo); store.activate(userID: owner)
        let id = UUID()
        let first = Task { await store.loadFeedback(activityID: id) }
        for _ in 0..<100 { if await repo.hasHeldFeedback { break }; await Task.yield() }
        let held = await repo.hasHeldFeedback
        XCTAssertTrue(held)
        let second = Task { await store.loadFeedback(activityID: id) }
        await Task.yield()
        XCTAssertTrue(store.loadingFeedback.contains(id))
        await repo.releaseFeedback(activityID: id)
        await first.value; await second.value
        XCTAssertNotNil(store.feedback[id])
        XCTAssertFalse(store.loadingFeedback.contains(id))
    }
    func testLegacyConfirmedGoalResumesNamedPreferencesWithoutRepeatingConfirmation() async throws {
        let repository = DemoRepository(startsWithoutProfile: true)
        let store = AppStore(repository: repository); await store.bootstrap()
        await store.saveProfile(displayName: "QA", username: "qa_routine", sports: [.gym])
        await store.saveOnboardingStep("weekly_goal")
        await store.confirmOnboardingGoal(4)
        XCTAssertEqual(store.route, .personalSetup)
        XCTAssertEqual(store.setup.journeyStep, .days)
        let reopened = AppStore(repository: repository); await reopened.bootstrap()
        XCTAssertEqual(reopened.route, .personalSetup)
        XCTAssertEqual(reopened.setup.journeyStep, .days)
        await reopened.saveOnboardingStep("friends")
        XCTAssertEqual(reopened.route, .personalSetup)
        XCTAssertEqual(reopened.setup.journeyStep, .days, "A legacy server marker must not overwrite a named private cursor")
    }
}

private actor PersonalTrainingStub: PersonalTrainingRepository {
    private var readFails = false
    private var writeFails = false
    private var holdsRoutine = false
    private var holdsWeek = false
    private var holdsFeedback = false
    private var routineContinuation: CheckedContinuation<TrainingRoutine, Never>?
    private var weekContinuation: CheckedContinuation<TrainingWeekSnapshot, Never>?
    private var feedbackContinuation: CheckedContinuation<PersonalWorkoutFeedback, Never>?
    private var routine = TrainingRoutine()
    private var snapshot = TrainingWeekSnapshot()
    private var feedback: [UUID: PersonalWorkoutFeedback] = [:]
    private(set) var routineWrites = 0
    var hasHeldRoutine: Bool { routineContinuation != nil }
    var hasHeldWeek: Bool { weekContinuation != nil }
    var hasHeldFeedback: Bool { feedbackContinuation != nil }
    func failReads(_ enabled: Bool) { readFails = enabled }
    func failWrites(_ enabled: Bool) { writeFails = enabled }
    func holdRoutine() { holdsRoutine = true }
    func holdWeek() { holdsWeek = true }
    func holdFeedback() { holdsFeedback = true }
    func releaseRoutine() { routineContinuation?.resume(returning: routine); routineContinuation = nil; holdsRoutine = false }
    func releaseWeek() { weekContinuation?.resume(returning: snapshot); weekContinuation = nil; holdsWeek = false }
    func releaseFeedback(activityID: UUID) {
        feedbackContinuation?.resume(returning: feedback[activityID] ?? PersonalWorkoutFeedback(activityID: activityID))
        feedbackContinuation = nil; holdsFeedback = false
    }
    func setWeek(_ value: TrainingWeekSnapshot) { snapshot = value }
    func trainingRoutine() async throws -> TrainingRoutine {
        if readFails { throw AppError.server }
        if holdsRoutine { return await withCheckedContinuation { routineContinuation = $0 } }
        return routine
    }
    func saveTrainingRoutine(_ value: TrainingRoutine) async throws -> TrainingRoutine {
        routineWrites += 1
        if writeFails { throw AppError.server }
        guard value.revision == routine.revision else { throw AppError.server }
        routine = value; routine.revision += 1; return routine
    }
    func trainingWeek(start: Date, end: Date) async throws -> TrainingWeekSnapshot {
        if readFails { throw AppError.server }
        if holdsWeek { return await withCheckedContinuation { weekContinuation = $0 } }
        return snapshot
    }
    func workoutFeedback(activityID: UUID) async throws -> PersonalWorkoutFeedback {
        if readFails { throw AppError.server }
        if holdsFeedback { return await withCheckedContinuation { feedbackContinuation = $0 } }
        return feedback[activityID] ?? PersonalWorkoutFeedback(activityID: activityID)
    }
    func saveWorkoutFeedback(_ value: PersonalWorkoutFeedback) async throws -> PersonalWorkoutFeedback {
        if writeFails { throw AppError.server }
        var saved = value; saved.revision += 1; saved.note = WorkoutLimits.optionalText(saved.note)
        feedback[saved.activityID] = saved; return saved
    }
}
