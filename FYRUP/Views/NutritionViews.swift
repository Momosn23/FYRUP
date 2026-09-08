import SwiftUI

struct NutritionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var day = Date()
    @State private var initializedDay = false
    @State private var showsGoal = false
    @State private var editing: NutritionEntry?
    @State private var selectedMeal: NutritionMeal?
    private var dayKey: String { StepDay.key(for: day) }
    private var entries: [NutritionEntry] { store.nutrition.diary?.entries(on: dayKey) ?? [] }
    private var totals: NutritionValues { .total(entries.map(\.consumed)) }
    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: store.presentationDate) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { moveDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Vorheriger Tag")
                    Spacer()
                    Text(isToday ? "Heute" : day.formatted(date: .abbreviated, time: .omitted)).font(.body.weight(.medium))
                    Spacer()
                    Button { moveDay(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Nächster Tag")
                }
                if let diary = store.nutrition.diary {
                    let value = NutritionDayPresentation(diary: diary, day: dayKey)
                    Button { showsGoal = true } label: {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
                        layout {
                            FYProgressRing(progress: value.progress, symbol: "flame.fill", accent: FYColor.nutrition, diameter: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text((value.calories.map { Int($0.rounded()).formatted() } ?? "–") + (diary.goal.map { " / \($0.kcal.formatted())" } ?? " kcal"))
                                    .font(.title3.bold()).monospacedDigit()
                                Text(isToday ? "Kalorien heute" : "Kalorien an diesem Tag").font(.subheadline).foregroundStyle(FYColor.muted)
                                Text(diary.remainingText(on: dayKey)).font(.footnote).foregroundStyle(FYColor.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }.foregroundStyle(FYColor.ink).fyCard(padding: 12)
                    }.buttonStyle(.plain).accessibilityIdentifier("nutrition-goal-summary")
                    VStack(spacing: 12) {
                        macro("Protein", value: totals.protein, goal: diary.goal?.protein, color: FYColor.lime)
                        macro("Kohlenhydrate", value: totals.carbohydrates, goal: diary.goal?.carbohydrates, color: FYColor.cyan)
                        macro("Fett", value: totals.fat, goal: diary.goal?.fat, color: FYColor.nutrition)
                    }
                    VStack(spacing: 0) {
                        ForEach(NutritionMeal.allCases) { meal in
                            let mealEntries = entries.filter { $0.meal == meal }
                            Button { selectedMeal = meal } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: meal.symbol).font(.title3).foregroundStyle(FYColor.nutrition)
                                        .frame(width: 36, height: 36).background(FYColor.elevated, in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(meal.title).font(.subheadline.weight(.medium))
                                        Text(mealEntries.isEmpty ? "Noch nichts eingetragen" : "\(Int(NutritionValues.total(mealEntries.map(\.consumed)).kcal.rounded()).formatted()) kcal")
                                            .font(.footnote).foregroundStyle(FYColor.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted)
                                }.frame(minHeight: 44).foregroundStyle(FYColor.ink).padding(.vertical, 6).contentShape(Rectangle())
                            }.buttonStyle(FYPressStyle()).accessibilityIdentifier("nutrition-meal-\(meal.rawValue)")
                            if meal != NutritionMeal.allCases.last { Divider() }
                        }
                    }.fyCard(padding: 12)
                    Text("Erfasste Nahrung – unabhängig von deiner aktiven Energie. Dieses Tagebuch wird derzeit privat auf diesem iPhone gespeichert.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                }
                if let error = store.nutrition.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(FYColor.coral)
                    if store.nutrition.diary == nil {
                        Button("Erneut öffnen") { store.nutrition.activate(owner: store.session?.userID) }.buttonStyle(OutlineButtonStyle())
                    }
                }
            }.padding(.horizontal, FYLayout.page).padding(.vertical, 8)
        }.background(FYColor.background).navigationTitle("Ernährung").navigationBarTitleDisplayMode(.inline)
            .onAppear { if !initializedDay { day = store.presentationDate; initializedDay = true } }
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Ziele") { showsGoal = true }.disabled(store.nutrition.diary == nil) } }
            .safeAreaInset(edge: .bottom) {
                Button("Eintragen") { editing = emptyEntry(.snack) }.buttonStyle(PrimaryButtonStyle())
                    .disabled(store.nutrition.diary == nil).padding(.horizontal, FYLayout.page).padding(.vertical, 12).background(FYColor.background)
                    .accessibilityIdentifier("nutrition-add-entry")
            }
            .sheet(isPresented: $showsGoal) { NutritionGoalView() }
            .sheet(item: $editing) { entry in NutritionEntryEditor(entry: entry) }
            .sheet(item: $selectedMeal) { meal in NutritionMealEntriesView(day: dayKey, meal: meal) }
    }
    private func emptyEntry(_ meal: NutritionMeal) -> NutritionEntry {
        .init(name: "", day: dayKey, meal: meal, grams: 0, per100g: .init(kcal: 0))
    }
    private func moveDay(_ offset: Int) { if let value = Calendar.current.date(byAdding: .day, value: offset, to: day) { day = value } }
    private func macro(_ title: String, value: Double?, goal: Double?, color: Color) -> some View {
        VStack(spacing: 6) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
            layout {
                Text(title).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                Text(value.map { "\(Int($0.rounded()))" } ?? "Unvollständig")
                    + Text(goal.map { " / \(Int($0.rounded())) g" } ?? (value == nil ? "" : " g"))
            }.font(.footnote)
            ProgressView(value: value.flatMap { value in goal.flatMap { $0 > 0 ? min(1, value / $0) : nil } } ?? 0).tint(color)
        }
    }
}

/// Details are one tap away; the overview stays compact without hiding totals.
private struct NutritionMealEntriesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: String
    let meal: NutritionMeal
    @State private var editing: NutritionEntry?
    private var entries: [NutritionEntry] { store.nutrition.diary?.entries(on: day).filter { $0.meal == meal } ?? [] }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if entries.isEmpty { Text("Noch nichts eingetragen. Ergänze deine eigenen Angaben.").foregroundStyle(FYColor.muted) }
                    ForEach(entries) { entry in
                        Button { editing = entry } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name).font(.body.weight(.medium))
                                    Text("\(entry.grams.formatted()) g · \(Int(entry.consumed.kcal.rounded()).formatted()) kcal").font(.footnote).foregroundStyle(FYColor.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.caption)
                            }.foregroundStyle(FYColor.ink).fyCard()
                        }.buttonStyle(FYPressStyle()).accessibilityIdentifier("nutrition-entry-\(entry.id)")
                    }
                }.padding(FYLayout.page)
            }.background(FYColor.background).navigationTitle(meal.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Eintrag hinzufügen") { editing = .init(name: "", day: day, meal: meal, grams: 0, per100g: .init(kcal: 0)) }
                        .buttonStyle(PrimaryButtonStyle()).disabled(store.nutrition.diary == nil)
                        .accessibilityIdentifier("nutrition-meal-add").padding(FYLayout.page).background(FYColor.background)
                }
                .sheet(item: $editing) { entry in NutritionEntryEditor(entry: entry) }
        }
    }
}

struct NutritionGoalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var error: String?
    @FocusState private var inputFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Deine Ernährungsziele").font(.title.bold())
                    Text("Trage dein eigenes Tagesziel ein. Makroziele sind optional und lassen sich jederzeit ändern.").foregroundStyle(FYColor.muted)
                    FYInputField(title: "Kalorien pro Tag", placeholder: "Dein Ziel", text: $kcal, unit: "kcal").keyboardType(.numberPad).focused($inputFocused)
                    FYInputField(title: "Protein · optional", placeholder: "", text: $protein, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    FYInputField(title: "Kohlenhydrate · optional", placeholder: "", text: $carbohydrates, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    FYInputField(title: "Fett · optional", placeholder: "", text: $fat, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    if let message = error ?? store.nutrition.errorMessage { Text(message).font(.footnote).foregroundStyle(FYColor.coral) }
                }.padding(20)
            }.background(FYColor.background)
                .safeAreaInset(edge: .bottom) {
                    Button("Ziele speichern") { save() }.buttonStyle(PrimaryButtonStyle()).padding(20).background(FYColor.background)
                        .accessibilityIdentifier("nutrition-save-goal")
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { inputFocused = false } }
                }
                .onAppear {
                    guard let goal = store.nutrition.diary?.goal else { return }
                    kcal = String(goal.kcal); protein = goal.protein.map { String($0) } ?? ""
                    carbohydrates = goal.carbohydrates.map { String($0) } ?? ""; fat = goal.fat.map { String($0) } ?? ""
                }
        }
    }
    private func save() {
        guard let calories = Int(kcal), [protein, carbohydrates, fat].allSatisfy({ $0.isEmpty || NutritionNumber.parse($0) != nil }) else { error = "Prüfe deine Zielwerte."; return }
        if store.nutrition.saveGoal(.init(kcal: calories, protein: NutritionNumber.parse(protein), carbohydrates: NutritionNumber.parse(carbohydrates), fat: NutritionNumber.parse(fat))) { dismiss() }
    }
}

private struct NutritionEntryEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: NutritionEntry
    @State private var name = ""
    @State private var meal = NutritionMeal.snack
    @State private var grams = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var error: String?
    @State private var confirmsDelete = false
    @FocusState private var inputFocused: Bool
    private var exists: Bool { store.nutrition.diary?.entries.contains { $0.id == entry.id } == true }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FYInputField(title: "Lebensmittel", placeholder: "Name", text: $name).focused($inputFocused)
                    Picker("Mahlzeit", selection: $meal) { ForEach(NutritionMeal.allCases) { Text($0.title).tag($0) } }
                    FYInputField(title: "Gegessene Menge", placeholder: "", text: $grams, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    Text("Nährwerte pro 100 g").font(.headline)
                    Text("Übernimm die Angaben von der Verpackung. Nicht bekannte Makros lässt du leer.").font(.footnote).foregroundStyle(FYColor.muted)
                    FYInputField(title: "Energie", placeholder: "", text: $kcal, unit: "kcal").keyboardType(.decimalPad).focused($inputFocused)
                    FYInputField(title: "Protein · optional", placeholder: "", text: $protein, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    FYInputField(title: "Kohlenhydrate · optional", placeholder: "", text: $carbohydrates, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    FYInputField(title: "Fett · optional", placeholder: "", text: $fat, unit: "g").keyboardType(.decimalPad).focused($inputFocused)
                    if let message = error ?? store.nutrition.errorMessage { Text(message).font(.footnote).foregroundStyle(FYColor.coral) }
                    if exists { Button("Eintrag löschen", role: .destructive) { confirmsDelete = true } }
                }.padding(20)
            }.background(FYColor.background).navigationTitle(exists ? "Eintrag bearbeiten" : "Lebensmittel eintragen").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) { Button("Speichern") { save() }.buttonStyle(PrimaryButtonStyle()).padding(20).background(FYColor.background) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { inputFocused = false } }
                }
                .confirmationDialog("Eintrag löschen?", isPresented: $confirmsDelete) {
                    Button("Löschen", role: .destructive) { if store.nutrition.remove(entry.id) { dismiss() } }
                    Button("Behalten", role: .cancel) {}
                }
                .onAppear {
                    name = entry.name; meal = entry.meal
                    guard exists else { return }
                    grams = String(entry.grams); kcal = String(entry.per100g.kcal)
                    protein = entry.per100g.protein.map { String($0) } ?? ""
                    carbohydrates = entry.per100g.carbohydrates.map { String($0) } ?? ""; fat = entry.per100g.fat.map { String($0) } ?? ""
                }
        }
    }
    private func save() {
        guard let amount = NutritionNumber.parse(grams), let calories = NutritionNumber.parse(kcal),
              [protein, carbohydrates, fat].allSatisfy({ $0.isEmpty || NutritionNumber.parse($0) != nil }) else { error = "Prüfe Menge und Nährwerte."; return }
        var updated = entry; updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.meal = meal; updated.grams = amount
        updated.per100g = .init(kcal: calories, protein: NutritionNumber.parse(protein), carbohydrates: NutritionNumber.parse(carbohydrates), fat: NutritionNumber.parse(fat))
        if store.nutrition.save(updated) { dismiss() }
    }
}

enum NutritionNumber {
    static func parse(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(value), number.isFinite, number >= 0 else { return nil }
        return number
    }
}
