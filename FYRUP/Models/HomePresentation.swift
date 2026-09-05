import Foundation

enum HomePresentation {
    /// Re-evaluated by the header's TimelineView and when the app becomes active.
    static func greeting(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<11: "Guten Morgen"
        case 11..<18: "Hallo"
        case 18..<23: "Guten Abend"
        default: "Schön, dass du da bist"
        }
    }
}

enum RestDurationInput {
    static func seconds(from input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(text), (15...600).contains(value) else { return nil }
        return value
    }
}

struct WorkoutRestClock: Codable, Equatable, Sendable {
    let activityID: UUID
    let startedAt: Date
    let duration: Int

    var endsAt: Date { startedAt.addingTimeInterval(TimeInterval(duration)) }
    var isValid: Bool { (15...600).contains(duration) && startedAt.timeIntervalSince1970.isFinite }
    func remaining(at date: Date) -> Int {
        guard isValid, date.timeIntervalSince1970.isFinite else { return 0 }
        return Int(min(Double(duration), max(0, ceil(endsAt.timeIntervalSince(date)))))
    }
    func progress(at date: Date) -> Double {
        guard isValid else { return 0 }
        return 1 - Double(remaining(at: date)) / Double(duration)
    }
}
