import Foundation

struct SessionIntervalConfiguration: Codable, Equatable, Sendable {
    let workSeconds: Int
    let recoverySeconds: Int
    let rounds: Int

    static func supports(_ sport: SportKind) -> Bool {
        [.running, .cycling, .swimming, .martialArts, .other].contains(sport)
    }
    var totalSeconds: Int? {
        // Validate before multiplication, including data restored from disk.
        guard (5...3600).contains(workSeconds), (0...3600).contains(recoverySeconds), (1...99).contains(rounds) else { return nil }
        let total = workSeconds * rounds + recoverySeconds * (rounds - 1)
        return total <= 21600 ? total : nil
    }
    static func parse(work: String, recovery: String, rounds: String) -> Self? {
        func integer(_ text: String) -> Int? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
            return Int(trimmed)
        }
        guard let work = integer(work), let recovery = integer(recovery), let rounds = integer(rounds) else { return nil }
        let value = Self(workSeconds: work, recoverySeconds: recovery, rounds: rounds)
        return value.totalSeconds == nil ? nil : value
    }
}

struct SessionIntervalPosition: Equatable, Sendable {
    enum Phase: String, Sendable { case work, recovery, completed }
    let phase: Phase
    let round: Int
    let remaining: Int
    let progress: Double
}

struct SessionIntervalClock: Codable, Equatable, Sendable {
    let activityID: UUID
    let startedAtActiveSeconds: Double
    let configuration: SessionIntervalConfiguration

    var isValid: Bool {
        configuration.totalSeconds != nil && startedAtActiveSeconds.isFinite && (0...604800).contains(startedAtActiveSeconds)
    }
    /// Uses actual active session time, not wall time: a paused session also
    /// pauses its intervals. Backgrounding does not require a running process.
    func position(activeSeconds: Double) -> SessionIntervalPosition? {
        guard isValid, activeSeconds.isFinite, activeSeconds >= startedAtActiveSeconds,
              activeSeconds <= 604800, let total = configuration.totalSeconds else { return nil }
        let elapsed = activeSeconds - startedAtActiveSeconds
        if elapsed >= Double(total) { return .init(phase: .completed, round: configuration.rounds, remaining: 0, progress: 1) }
        let cycle = configuration.workSeconds + configuration.recoverySeconds
        let index = min(configuration.rounds - 1, Int(elapsed / Double(cycle)))
        let offset = max(0, elapsed - Double(index * cycle))
        let isWork = offset < Double(configuration.workSeconds)
        let phaseDuration = isWork ? configuration.workSeconds : configuration.recoverySeconds
        let phaseElapsed = isWork ? offset : offset - Double(configuration.workSeconds)
        return .init(phase: isWork ? .work : .recovery, round: index + 1,
                     remaining: Int(ceil(Double(phaseDuration) - phaseElapsed)),
                     progress: min(1, max(0, phaseElapsed / Double(phaseDuration))))
    }
}
