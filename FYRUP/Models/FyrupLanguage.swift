import Foundation

/// Display-only compatibility. Never rewrites stored subtype values or a user's free text.
enum FyrupLanguage {
    static func subtype(_ raw: String?, sport: SportKind, workoutPlanID: UUID? = nil) -> String? {
        guard let raw, workoutPlanID == nil else { return raw }
        switch (sport, raw) {
        case (.gym, "Freies Training"): return "Freies Workout"
        case (.football, "Mannschaftstraining"): return "Team-Session"
        case (.football, "Einzeltraining"), (.basketball, "Einzeltraining"): return "Solo-Session"
        case (.basketball, "Training"): return "Skills"
        case (.racket, "Tennis · Training"): return "Tennis · Üben"
        case (.racket, "Padel · Training"): return "Padel · Üben"
        default: return raw
        }
    }

    /// Only known system templates, selected by notification type, are modernized.
    /// Plan names, invitation notes, usernames and all payload IDs stay untouched.
    static func notification(type: String, title: String, body: String) -> (title: String, body: String) {
        var title = title; var body = body
        switch type {
        case "supplement_reminder": return ("Deine Erinnerung", "Ein Eintrag auf deiner heutigen Liste ist noch offen.")
        case "activity_started":
            title = title.replacingOccurrences(of: " trainiert gerade 🔥$", with: " ist gerade LIVE 🔥", options: .regularExpression)
        case "session_invite":
            if title == "Trainingseinladung 🔥" { title = "Session-Einladung 🔥" }
            title = title.replacingOccurrences(of: " lädt dich zum Training ein\\.$", with: " lädt dich zu einer Session ein.", options: .regularExpression)
        case "session_updated":
            if title == "Training wurde aktualisiert" { title = "Session aktualisiert" }
        case "session_started":
            if title == "Training wurde gestartet 🔥" { title = "Die Session ist jetzt LIVE 🔥" }
        case "session_cancelled":
            if title == "Training abgesagt" { title = "Session abgesagt" }
            if body == "Der Host hat das Training abgesagt." { body = "Der Host hat die Session abgesagt." }
        case "session_joined":
            if body == "Ein Freund hat sich deinem Training angeschlossen." { body = "Ein Freund ist bei deiner Session dabei." }
        case "session_reminder":
            if title == "Training in 30 Minuten 🔥" { title = "Deine Session startet in 30 Minuten 🔥" }
        case "workout_plan_shared":
            if title == "Ein Trainingsplan für dich" { title = "Ein Workout-Plan für dich" }
            title = title.replacingOccurrences(of: " teilt einen Trainingsplan\\.$", with: " teilt einen Workout-Plan.", options: .regularExpression)
        case "weekly_goal":
            body = body.replacingOccurrences(of: "^([0-9]+ / [0-9]+) Trainings\\. Wochenziel geschafft\\.$", with: "$1 Einheiten. Wochenziel geschafft.", options: .regularExpression)
        case "shot_called":
            body = body.replacingOccurrences(of: "^([3-7]) Trainings diese Woche\\.$", with: "$1 Einheiten diese Woche.", options: .regularExpression)
        default: break
        }
        return (title, body)
    }
}

extension Activity {
    var displaySubtype: String? { FyrupLanguage.subtype(subtype, sport: sport, workoutPlanID: workoutPlanID) }
}
extension PlannedSession {
    var displaySubtype: String? { FyrupLanguage.subtype(subtype, sport: sport, workoutPlanID: workoutPlanID) }
}
extension AppNotification {
    var displayTitle: String { FyrupLanguage.notification(type: type, title: title, body: body).title }
    var displayBody: String { FyrupLanguage.notification(type: type, title: title, body: body).body }
}
