import XCTest
@testable import FYRUP

@MainActor
final class StepRepositoryTests: XCTestCase {
    private let momoID = DemoRepository.defaultUserID
    private let maxID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let noon = Date(timeIntervalSince1970: 1_788_609_600) // 2026-09-05 12:00 UTC

    private func day(_ date: Date, timezone: String = "UTC") -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone)!
        return StepDay.key(for: date, calendar: calendar)
    }

    private func assertDenied(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("This request must be rejected", file: file, line: line) }
        catch { XCTAssertNotNil(error as? AppError, file: file, line: line) }
    }

    private func sync(_ repository: DemoRepository, userID: UUID? = nil, clock: StepRepositoryTestClock,
                      steps: Int?, revision: Int, observedAt: Date? = nil, timezone: String = "UTC") async throws -> Bool {
        try await repository.syncSteps(userID: userID ?? momoID, localDate: day(clock.now(), timezone: timezone), timezone: timezone,
                                       steps: steps, sharingRevision: revision, observedAt: observedAt ?? clock.now())
    }

    func testRPCEncodesExplicitNullAndOnlyAggregateConsentAndOrderingFields() throws {
        let observed = Date(timeIntervalSince1970: 1_788_609_600.125)
        let body = StepSyncRequest(userID: momoID, localDate: "2026-09-05", timezone: "UTC", steps: nil,
                                   sharingRevision: 3, observedAt: observed)
        let encoded = try JSONEncoder.supabase.encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["p_user", "p_date", "p_timezone", "p_steps", "p_sharing_revision", "p_observed_at"]))
        XCTAssertTrue(json["p_steps"] is NSNull)
        XCTAssertEqual(json["p_sharing_revision"] as? Int, 3)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let encodedObservation = try XCTUnwrap(json["p_observed_at"] as? String)
        let decodedObservation = try XCTUnwrap(formatter.date(from: encodedObservation))
        XCTAssertEqual(decodedObservation.timeIntervalSince1970, observed.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSharingDefaultsToOffAndNoDemoCountsAreFabricated() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.stepSharingPreference(userID: momoID)
        XCTAssertFalse(preference.sharingEnabled)
        XCTAssertEqual(preference.sharingRevision, 0)
        let rejected = try await sync(momo, clock: clock, steps: 8421, revision: 0)
        XCTAssertFalse(rejected)
        let friendValues = try await max.sharedSteps()
        XCTAssertTrue(friendValues.isEmpty)
        let enabled = try await momo.setStepSharing(userID: momoID, enabled: true)
        XCTAssertEqual(enabled.sharingRevision, 1)
        let beforeFirstUpload = try await max.sharedSteps()
        XCTAssertTrue(beforeFirstUpload.isEmpty, "Opt-in alone must not manufacture or republish data")
    }

    func testExplicitUploadIsVisibleOnlyToAcceptedFriendsAndPreferencesStayPrivate() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let stranger = DemoRepository(userID: UUID(), stepStorage: storage)
        let enabled = try await momo.setStepSharing(userID: momoID, enabled: true)
        let accepted = try await sync(momo, clock: clock, steps: 8421, revision: enabled.sharingRevision)
        XCTAssertTrue(accepted)
        let values = try await max.sharedSteps()
        let metric = try XCTUnwrap(values.first)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(metric.userID, momoID)
        XCTAssertEqual(metric.steps, 8421)
        XCTAssertEqual(metric.localDate, day(noon))
        XCTAssertEqual(metric.validUntil, noon.addingTimeInterval(120))
        let ownFriendList = try await momo.sharedSteps()
        let strangerList = try await stranger.sharedSteps()
        XCTAssertTrue(ownFriendList.isEmpty)
        XCTAssertTrue(strangerList.isEmpty)
        await assertDenied { _ = try await max.stepSharingPreference(userID: self.momoID) }
        await assertDenied { _ = try await max.setStepSharing(userID: self.momoID, enabled: false) }
        await assertDenied { _ = try await self.sync(max, userID: self.momoID, clock: clock, steps: 9999, revision: enabled.sharingRevision) }
    }

    func testRevocationWinsOverDelayedUploadAndReenablingRequiresFreshRevision() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let first = try await momo.setStepSharing(userID: momoID, enabled: true)
        _ = try await sync(momo, clock: clock, steps: 8421, revision: first.sharingRevision)
        let off = try await momo.setStepSharing(userID: momoID, enabled: false)
        XCTAssertEqual(off.sharingRevision, first.sharingRevision + 1)
        let hidden = try await max.sharedSteps()
        XCTAssertTrue(hidden.isEmpty)
        clock.advance(1)
        let stale = try await sync(momo, clock: clock, steps: 9000, revision: first.sharingRevision)
        XCTAssertFalse(stale)
        let enabled = try await momo.setStepSharing(userID: momoID, enabled: true)
        let stillHidden = try await max.sharedSteps()
        XCTAssertTrue(stillHidden.isEmpty)
        let oldAfterReenable = try await sync(momo, clock: clock, steps: 9000, revision: first.sharingRevision)
        XCTAssertFalse(oldAfterReenable)
        let enabledAgain = try await momo.setStepSharing(userID: momoID, enabled: true)
        XCTAssertEqual(enabledAgain.sharingRevision, enabled.sharingRevision, "Idempotent settings must not invalidate fresh reads")
        let fresh = try await sync(momo, clock: clock, steps: 9001, revision: enabled.sharingRevision)
        XCTAssertTrue(fresh)
        let visible = try await max.sharedSteps()
        XCTAssertEqual(visible.first?.steps, 9001)
    }

    func testOutOfOrderAndConflictingEqualObservationsCannotOverwriteNewerTotal() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        _ = try await sync(momo, clock: clock, steps: 8000, revision: preference.sharingRevision)
        clock.advance(20)
        let observation = clock.now()
        _ = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision)
        let initialRead = try await max.sharedSteps()
        let initial = try XCTUnwrap(initialRead.first)
        clock.advance(5)
        let older = try await sync(momo, clock: clock, steps: 8200, revision: preference.sharingRevision, observedAt: observation.addingTimeInterval(-1))
        let conflicting = try await sync(momo, clock: clock, steps: 9999, revision: preference.sharingRevision, observedAt: observation)
        let exactRetry = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision, observedAt: observation)
        XCTAssertFalse(older); XCTAssertFalse(conflicting); XCTAssertTrue(exactRetry)
        let afterRead = try await max.sharedSteps()
        let after = try XCTUnwrap(afterRead.first)
        XCTAssertEqual(after.steps, 8421)
        XCTAssertEqual(after.updatedAt, initial.updatedAt)
    }

    func testUnavailableReadWithdrawsDataAndCannotBeResurrectedByOlderCallback() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        _ = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision)
        clock.advance(10)
        let withdrawal = clock.now()
        let withdrawn = try await sync(momo, clock: clock, steps: nil, revision: preference.sharingRevision)
        XCTAssertTrue(withdrawn)
        let empty = try await max.sharedSteps()
        XCTAssertTrue(empty.isEmpty)
        let stale = try await sync(momo, clock: clock, steps: 9000, revision: preference.sharingRevision, observedAt: noon)
        let sameTimeConflict = try await sync(momo, clock: clock, steps: 9000, revision: preference.sharingRevision, observedAt: withdrawal)
        let withdrawalRetry = try await sync(momo, clock: clock, steps: nil, revision: preference.sharingRevision, observedAt: withdrawal)
        XCTAssertFalse(stale); XCTAssertFalse(sameTimeConflict); XCTAssertTrue(withdrawalRetry)
        clock.advance(1)
        let trueZero = try await sync(momo, clock: clock, steps: 0, revision: preference.sharingRevision)
        XCTAssertTrue(trueZero)
        let zero = try await max.sharedSteps()
        XCTAssertEqual(zero.first?.steps, 0, "A measured zero differs from unavailable data")
    }

    func testOwnerMidnightExpiresTheValueAndClampsItsCacheLease() async throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        let midnight = StepDay.bounds(for: noon, calendar: calendar).end
        let clock = StepRepositoryTestClock(midnight.addingTimeInterval(-30))
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        let previousDate = day(clock.now())
        _ = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision)
        let evening = try await max.sharedSteps()
        XCTAssertEqual(evening.first?.validUntil, midnight)
        clock.advance(31)
        let nextDay = try await max.sharedSteps()
        XCTAssertTrue(nextDay.isEmpty)
        await assertDenied {
            _ = try await momo.syncSteps(userID: self.momoID, localDate: previousDate, timezone: "UTC", steps: 8422,
                                        sharingRevision: preference.sharingRevision, observedAt: clock.now())
        }
        let fresh = try await sync(momo, clock: clock, steps: 5, revision: preference.sharingRevision)
        XCTAssertTrue(fresh)
        let today = try await max.sharedSteps()
        XCTAssertEqual(today.first?.steps, 5)
    }

    func testTravelAcrossDateLinePublishesAtMostOneOwnerLocalDay() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        _ = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision, timezone: "UTC")
        clock.advance(1)
        _ = try await sync(momo, clock: clock, steps: 123, revision: preference.sharingRevision, timezone: "Pacific/Kiritimati")
        let values = try await max.sharedSteps()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.localDate, day(clock.now(), timezone: "Pacific/Kiritimati"))
        XCTAssertEqual(values.first?.steps, 123)
    }

    func testBlockingOrRemovingFriendRevokesBothSidesOfSharedDemoStorage() async throws {
        for block in [false, true] {
            let clock = StepRepositoryTestClock(noon)
            let storage = DemoStepStorage(now: { clock.now() })
            let momo = DemoRepository(stepStorage: storage)
            let max = DemoRepository(userID: maxID, stepStorage: storage)
            let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
            _ = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision)
            let before = try await max.sharedSteps()
            XCTAssertEqual(before.count, 1)
            if block { try await momo.block(maxID) } else { try await momo.removeFriend(maxID) }
            let after = try await max.sharedSteps()
            XCTAssertTrue(after.isEmpty)
            let restartedMax = DemoRepository(userID: maxID, stepStorage: storage)
            let afterRestart = try await restartedMax.sharedSteps()
            XCTAssertTrue(afterRestart.isEmpty)
        }
    }

    func testInvalidCountsZonesAndObservationTimesAreRejected() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        for count in [-1, StepDay.maximumSteps + 1] {
            await assertDenied { _ = try await self.sync(momo, clock: clock, steps: count, revision: preference.sharingRevision) }
        }
        for observed in [noon.addingTimeInterval(-86_401), noon.addingTimeInterval(301)] {
            await assertDenied { _ = try await self.sync(momo, clock: clock, steps: 123, revision: preference.sharingRevision, observedAt: observed) }
        }
        await assertDenied {
            _ = try await momo.syncSteps(userID: self.momoID, localDate: self.day(self.noon), timezone: "Invalid/Zone", steps: 123,
                                        sharingRevision: preference.sharingRevision, observedAt: self.noon)
        }
    }

    func testToleratedDeviceClockSkewCannotBlockCorrectlyTimedFutureReads() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let preference = try await momo.setStepSharing(userID: momoID, enabled: true)
        let acceptedSkew = try await sync(momo, clock: clock, steps: 8421, revision: preference.sharingRevision,
                                         observedAt: noon.addingTimeInterval(240))
        XCTAssertTrue(acceptedSkew)
        // The corrected observation intentionally has exactly the clamped receipt
        // timestamp, as on a low-resolution or non-advancing server clock.
        let correctlyTimed = try await sync(momo, clock: clock, steps: 8425, revision: preference.sharingRevision)
        XCTAssertTrue(correctlyTimed)
        let conflictingRepeat = try await sync(momo, clock: clock, steps: 9999, revision: preference.sharingRevision)
        XCTAssertFalse(conflictingRepeat, "After correction, ordinary equal-timestamp conflicts must still be rejected")
        let exactRetry = try await sync(momo, clock: clock, steps: 8425, revision: preference.sharingRevision)
        XCTAssertTrue(exactRetry)
        let values = try await max.sharedSteps()
        XCTAssertEqual(values.first?.steps, 8425)
        let restartedOwner = DemoRepository(stepStorage: storage)
        let restoredPreference = try await restartedOwner.stepSharingPreference(userID: momoID)
        XCTAssertEqual(restoredPreference, preference)
    }

    func testDeletingOneAccountRemovesOnlyItsStepData() async throws {
        let clock = StepRepositoryTestClock(noon)
        let storage = DemoStepStorage(now: { clock.now() })
        let momo = DemoRepository(stepStorage: storage)
        let max = DemoRepository(userID: maxID, stepStorage: storage)
        let momoPreference = try await momo.setStepSharing(userID: momoID, enabled: true)
        let maxPreference = try await max.setStepSharing(userID: maxID, enabled: true)
        _ = try await sync(momo, clock: clock, steps: 8421, revision: momoPreference.sharingRevision)
        _ = try await sync(max, userID: maxID, clock: clock, steps: 5432, revision: maxPreference.sharingRevision)
        try await momo.deleteAccount()
        let maxSees = try await max.sharedSteps()
        XCTAssertTrue(maxSees.isEmpty)
        let maxStillEnabled = try await max.stepSharingPreference(userID: maxID)
        XCTAssertEqual(maxStillEnabled, maxPreference)
        let removedPreference = try await momo.stepSharingPreference(userID: momoID)
        XCTAssertFalse(removedPreference.sharingEnabled)
        clock.advance(1)
        let delayed = try await sync(momo, clock: clock, steps: 9999, revision: momoPreference.sharingRevision)
        XCTAssertFalse(delayed)
    }
}

/// The single clock value is protected for synchronous reads from repository actors.
private final class StepRepositoryTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ value: Date) { self.value = value }
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: TimeInterval) { lock.lock(); defer { lock.unlock() }; value = value.addingTimeInterval(seconds) }
}
