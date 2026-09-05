import Foundation

/// Explicit --demo --steps-demo UI fixture, never selected by the production entry point.
@MainActor
struct StepPreviewReader: StepReading {
    let isAvailable = true
    func requestAccess() async throws {}
    func todaySteps(now: Date, calendar: Calendar) async throws -> Int? { 8421 }
}
