import Foundation

/// Private, device-only preferences, never encoded into Profile or feed payloads.
struct PersonalSetupPreferences: Codable, Equatable, Sendable {
    var version = 1
    var completed = false
    var heightCM: Double?
    var weightKG: Double?
    var measurementsUpdatedAt: Date?
    var activeCalorieGoal: Int?
    var energyRequested = false
    var liveActivityEnabled = false
    var favoriteGymName: String?
    var favoriteGymPlace: SessionPlace?
    var setupPage: Int?

    var validationMessage: String? {
        if version != 1 { return "Diese Einstellungen benötigen eine neuere App-Version." }
        if let setupPage, !(0...3).contains(setupPage) { return "Der gespeicherte Einrichtungsschritt ist ungültig." }
        if let measurementsUpdatedAt, !measurementsUpdatedAt.timeIntervalSince1970.isFinite { return "Der Zeitpunkt deiner Körperdaten ist ungültig. Speichere sie erneut." }
        if let heightCM, !heightCM.isFinite || !(50...260).contains(heightCM) { return "Prüfe deine Körpergröße in cm (50–260)." }
        if let weightKG, !weightKG.isFinite || !(20...450).contains(weightKG) { return "Prüfe dein Gewicht in kg (20–450)." }
        if let activeCalorieGoal, !(50...5000).contains(activeCalorieGoal) { return "Prüfe dein frei gewähltes Bewegungsziel (50–5.000 kcal)." }
        if let name = favoriteGymName, name.isEmpty || name.count > 120 || name != name.trimmingCharacters(in: .whitespacesAndNewlines) || name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return "Gib einen Gym-Namen mit höchstens 120 Zeichen ohne Zeilenumbrüche ein."
        }
        if let favoriteGymPlace, favoriteGymPlace.validationMessage != nil || favoriteGymName != favoriteGymPlace.name {
            return "Wähle dein Stammgym erneut auf der Karte aus."
        }
        return nil
    }
}
