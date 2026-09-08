import Foundation

/// Private planning preferences, not activity completions, appointments or consent.
/// Nil means skipped/not decided; no illustrative reference value is a default.
struct SetupChoices: Codable, Equatable, Sendable {
    var primaryGoal: SetupPrimaryGoal?
    var additionalGoals: Set<SetupAdditionalGoal> = []
    var preferredDays: Set<SetupWeekday> = []
    var preferredTime: SetupTimePreference?
}

enum SetupPrimaryGoal: String, Codable, CaseIterable, Sendable {
    case buildMuscle, feelFitter, loseWeight, stayActive
    var title: String {
        switch self {
        case .buildMuscle: "Muskeln aufbauen"
        case .feelFitter: "Fitter werden"
        case .loseWeight: "Abnehmen"
        case .stayActive: "Aktiv bleiben"
        }
    }
    var symbol: String {
        switch self {
        case .buildMuscle: "dumbbell"
        case .feelFitter: "figure.run"
        case .loseWeight: "target"
        case .stayActive: "figure.walk"
        }
    }
    var detail: String {
        switch self {
        case .buildMuscle: "Stärker werden. Fortschritte festhalten."
        case .feelFitter: "Mehr Ausdauer. Mehr Energie im Alltag."
        case .loseWeight: "Deine Gewohnheiten bewusst gestalten."
        case .stayActive: "Bewegung zu einem Teil deines Alltags machen."
        }
    }
}

enum SetupAdditionalGoal: String, Codable, CaseIterable, Sendable {
    case friends, steps, nutrition, consistency
    var title: String {
        switch self {
        case .friends: "Mit Freunden aktiv sein"
        case .steps: "Mehr Schritte machen"
        case .nutrition: "Besser essen"
        case .consistency: "Regelmäßiger aktiv sein"
        }
    }
    var symbol: String {
        switch self {
        case .friends: "person.2"
        case .steps: "shoeprints.fill"
        case .nutrition: "fork.knife"
        case .consistency: "calendar"
        }
    }
    var detail: String {
        switch self {
        case .friends: "Gemeinsam macht’s mehr Spaß."
        case .steps: "Mehr Bewegung in deinen Alltag bringen."
        case .nutrition: "Mahlzeiten und eigene Ziele im Blick."
        case .consistency: "Eine feste Routine aufbauen."
        }
    }
}

/// ISO ordering is explicit, independent of Calendar.current's Sunday-based index.
enum SetupWeekday: Int, Codable, CaseIterable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
    var title: String {
        switch self {
        case .monday: "Montag"
        case .tuesday: "Dienstag"
        case .wednesday: "Mittwoch"
        case .thursday: "Donnerstag"
        case .friday: "Freitag"
        case .saturday: "Samstag"
        case .sunday: "Sonntag"
        }
    }
    var shortTitle: String { String(title.prefix(2)) }
    var calendarWeekday: Int { rawValue % 7 + 1 }
}

enum SetupTimePreference: String, Codable, CaseIterable, Sendable {
    case morning, midday, evening, flexible
    var title: String {
        switch self {
        case .morning: "Morgens"
        case .midday: "Mittags"
        case .evening: "Abends"
        case .flexible: "Unterschiedlich"
        }
    }
    var detail: String {
        switch self {
        case .morning: "06:00–12:00"
        case .midday: "12:00–17:00"
        case .evening: "17:00–22:00"
        case .flexible: "So, wie es für dich passt."
        }
    }
    var symbol: String {
        switch self {
        case .morning: "sun.max"
        case .midday: "sun.max.fill"
        case .evening: "moon"
        case .flexible: "clock"
        }
    }
}
