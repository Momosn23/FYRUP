import Foundation

/// Stable keys, not indices into a changing array. Private and account-scoped.
enum SetupJourneyStep: String, Codable, CaseIterable, Sendable {
    case body, primaryGoal, additionalGoals, weeklyGoal, days, time
    case supplements, nutrition, health, permissions, privacy, friends, firstActivity, summary

    var position: Int { Self.allCases.firstIndex(of: self)! + 1 }
    var next: Self? { Self.allCases.dropFirst(position).first }
    var previous: Self? { position > 1 ? Self.allCases[position - 2] : nil }
    var title: String {
        switch self {
        case .body: "Körperdaten"
        case .primaryGoal: "Dein Hauptziel"
        case .additionalGoals: "Zusätzlich wichtig"
        case .weeklyGoal: "Wochenziel wählen"
        case .days: "Aktive Tage wählen"
        case .time: "Lieblingsuhrzeit wählen"
        case .supplements: "Deine Supplements"
        case .nutrition: "Ernährung einrichten"
        case .health: "Apple Health verbinden"
        case .permissions: "Berechtigungen"
        case .privacy: "Deine Privatsphäre"
        case .friends: "Freunde finden"
        case .firstActivity: "Deine erste Einheit"
        case .summary: "Alles bereit!"
        }
    }
    var subtitle: String {
        switch self {
        case .body: "Freiwillige Angaben für deine persönlichen Ziele."
        case .primaryGoal: "Was ist dir gerade am wichtigsten?"
        case .additionalGoals: "Wähle alles, was dir wichtig ist."
        case .weeklyGoal: "Wie oft willst du pro Woche aktiv sein?"
        case .days: "Das sind Planungswünsche, keine bereits erledigten Einheiten."
        case .time: "Wann bist du am liebsten aktiv?"
        case .supplements: "Deine eigene Liste. Du entscheidest, was dazugehört."
        case .nutrition: "Mahlzeiten und eigene Tagesziele – wenn du möchtest."
        case .health: "Deine Schritte im Blick. Nur mit deiner Entscheidung."
        case .permissions: "Du entscheidest für jede Funktion einzeln."
        case .privacy: "Private Daten bleiben getrennt von deiner Crew."
        case .friends: "Gemeinsam loslegen – oder erst einmal für dich."
        case .firstActivity: "Was möchtest du nach der Einrichtung machen?"
        case .summary: "Das hast du eingerichtet. Tippe eine Zeile zum Bearbeiten."
        }
    }

    /// Existing four-page values retain their meaning, never get re-indexed.
    static func legacyPage(_ page: Int?) -> Self {
        switch page {
        case 0: .health
        case 1: .body
        case 2: .permissions
        case 3: .summary
        default: .body
        }
    }
    static func legacyProfile(_ step: String?, privatePage: Int?) -> Self {
        switch step {
        case "weekly_goal": .weeklyGoal
        case "friends": .friends
        case "complete": legacyPage(privatePage)
        default: .body
        }
    }
}

enum SetupFirstAction: String, Codable, CaseIterable, Sendable {
    case now, plan, later
    var title: String {
        switch self { case .now: "Jetzt loslegen"; case .plan: "Für später planen"; case .later: "Später" }
    }
    var detail: String {
        switch self {
        case .now: "Danach Sport auswählen und bewusst starten."
        case .plan: "Danach eine Session im Kalender planen."
        case .later: "Erst einmal auf Heute umsehen."
        }
    }
    var symbol: String {
        switch self { case .now: "play"; case .plan: "calendar"; case .later: "arrow.right" }
    }
}

struct SetupJourneyProgress: Codable, Equatable, Sendable {
    var version = 1
    var step: SetupJourneyStep = .body
    var firstAction: SetupFirstAction?
}
