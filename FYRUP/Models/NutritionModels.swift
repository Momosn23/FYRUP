import Foundation

enum NutritionMeal: String, CaseIterable, Codable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String {
        switch self { case .breakfast: "Frühstück"; case .lunch: "Mittagessen"; case .dinner: "Abendessen"; case .snack: "Snacks" }
    }
    var symbol: String {
        switch self { case .breakfast: "sunrise"; case .lunch: "sun.max"; case .dinner: "moon"; case .snack: "carrot" }
    }
}

/// Nährwerte einer expliziten Menge. Fehlende Makros bleiben unbekannt.
struct NutritionValues: Codable, Equatable, Sendable {
    var kcal: Double
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var isValid: Bool {
        kcal.isFinite && (0...100_000).contains(kcal)
        && [protein, carbohydrates, fat].allSatisfy { $0.map { $0.isFinite && (0...10_000).contains($0) } ?? true }
    }
    func scaled(by factor: Double) -> Self {
        .init(kcal: kcal * factor, protein: protein.map { $0 * factor }, carbohydrates: carbohydrates.map { $0 * factor }, fat: fat.map { $0 * factor })
    }
    static func total(_ values: [Self]) -> Self {
        func sum(_ key: KeyPath<Self, Double?>) -> Double? {
            let numbers = values.compactMap { $0[keyPath: key] }
            return numbers.count == values.count ? numbers.reduce(0, +) : nil
        }
        return .init(kcal: values.reduce(0) { $0 + $1.kcal }, protein: sum(\.protein), carbohydrates: sum(\.carbohydrates), fat: sum(\.fat))
    }
}

struct NutritionGoal: Codable, Equatable, Sendable {
    var kcal: Int
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var isValid: Bool {
        (1...20_000).contains(kcal) && NutritionValues(kcal: Double(kcal), protein: protein, carbohydrates: carbohydrates, fat: fat).isValid
    }
}

struct NutritionEntry: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var day: String
    var meal: NutritionMeal
    var grams: Double
    var per100g: NutritionValues
    var source = "Eigene Angabe"
    var consumed: NutritionValues { per100g.scaled(by: grams / 100) }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120
        && NutritionDay.isValid(day)
        && grams.isFinite && grams > 0 && grams <= 10_000 && per100g.isValid && consumed.isValid
        && source.count <= 240 && !source.contains("\n")
    }
}

enum NutritionDay {
    static func isValid(_ key: String) -> Bool {
        guard key.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return false }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...9999).contains(parts[0]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return false }
        return StepDay.key(for: date, calendar: calendar) == key
    }
}

/// Today and the diary use one interpretation of absent, empty and over-goal data.
struct NutritionDayPresentation {
    let calories: Double?
    let goal: Int?
    let remaining: String
    var progress: Double? { guard let calories, let goal, goal > 0 else { return nil }; return calories / Double(goal) }
    init(diary: NutritionDiary?, day: String) {
        guard let diary else { calories = nil; goal = nil; remaining = "Nicht verfügbar"; return }
        goal = diary.goal?.kcal
        calories = diary.goal != nil || !diary.entries(on: day).isEmpty ? diary.total(on: day).kcal : nil
        remaining = diary.remainingText(on: day)
    }
}

struct NutritionDiary: Codable, Equatable, Sendable {
    var goal: NutritionGoal?
    var entries: [NutritionEntry] = []
    func entries(on day: String) -> [NutritionEntry] { entries.filter { $0.day == day } }
    func total(on day: String) -> NutritionValues { .total(entries(on: day).map(\.consumed)) }
    var isValid: Bool { (goal?.isValid ?? true) && entries.allSatisfy(\.isValid) && Set(entries.map(\.id)).count == entries.count }
    func remainingText(on day: String) -> String {
        guard let goal else { return "Ziel einrichten" }
        let remaining = Double(goal.kcal) - total(on: day).kcal
        let number = Int(abs(remaining).rounded()).formatted(.number.locale(Locale(identifier: "de_DE")))
        return remaining < 0 ? "\(number) kcal über deinem Ziel" : "\(number) kcal übrig"
    }
}
