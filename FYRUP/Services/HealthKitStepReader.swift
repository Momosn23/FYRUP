import Foundation
import HealthKit

@MainActor
protocol StepReading {
    var isAvailable: Bool { get }
    func requestAccess() async throws
    func todaySteps(now: Date, calendar: Calendar) async throws -> Int?
}

@MainActor
final class HealthKitStepReader: StepReading {
    private let healthStore = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async throws {
        guard isAvailable else { throw AppError.validation("Apple Health ist auf diesem Gerät nicht verfügbar.") }
        // Read only. Successful completion means the dialog was handled, not that read access was granted.
        try await healthStore.requestAuthorization(toShare: [], read: [HKQuantityType(.stepCount)])
    }

    func todaySteps(now: Date = .now, calendar: Calendar = .current) async throws -> Int? {
        guard isAvailable else { return nil }
        // Include overlapping samples, as in Apple's statistics example; do not discard
        // an entire sample merely because it starts just before local midnight.
        let predicate = HKQuery.predicateForSamples(withStart: StepDay.bounds(for: now, calendar: calendar).start, end: now)
        let samples = HKSamplePredicate.quantitySample(type: HKQuantityType(.stepCount), predicate: predicate)
        // No separateBySource: HealthKit merges sources itself. Never enumerate raw samples or devices.
        // https://developer.apple.com/documentation/healthkit/hkstatistics
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: .cumulativeSum)
        let statistics = try await query.result(for: healthStore)
        return StepDay.count(from: statistics?.sumQuantity()?.doubleValue(for: .count()))
    }
}
