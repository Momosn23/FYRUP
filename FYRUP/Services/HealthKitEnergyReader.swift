import Foundation
import HealthKit

@MainActor
protocol ActiveEnergyReading {
    var isAvailable: Bool { get }
    func requestAccess() async throws
    func todayKilocalories(now: Date, calendar: Calendar) async throws -> Double?
}

@MainActor
final class HealthKitEnergyReader: ActiveEnergyReading {
    private let healthStore = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    func requestAccess() async throws {
        guard isAvailable else { throw AppError.validation("Apple Health ist hier nicht verfügbar.") }
        // Separate opt-in from steps. No write, heart-rate, body or resting-energy access.
        try await healthStore.requestAuthorization(toShare: [], read: [HKQuantityType(.activeEnergyBurned)])
    }
    func todayKilocalories(now: Date, calendar: Calendar) async throws -> Double? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: StepDay.bounds(for: now, calendar: calendar).start, end: now)
        let samples = HKSamplePredicate.quantitySample(type: HKQuantityType(.activeEnergyBurned), predicate: predicate)
        let query = HKStatisticsQueryDescriptor(predicate: samples, options: .cumulativeSum)
        let statistics = try await query.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }
}
