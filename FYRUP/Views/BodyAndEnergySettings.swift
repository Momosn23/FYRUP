import SwiftUI

struct BodyAndEnergySettings: View {
    @Environment(AppStore.self) private var store
    @State private var height = ""
    @State private var weight = ""
    @State private var goal = ""
    @State private var error: String?
    @State private var saved = false
    @State private var confirmsDelete = false
    @State private var baseline: [String] = ["", "", ""]
    @FocusState private var focusedField: String?
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 13) {
                Label("Deine Körperdaten · privat", systemImage: "figure.stand").font(.headline)
                metricField("Körpergröße", unit: "cm", value: $height, id: "setup-height")
                metricField("Gewicht", unit: "kg", value: $weight, id: "setup-weight")
                Text("Freiwillig und geschützt auf diesem iPhone. Keine Übertragung an Freunde, FYRUP-Server oder KI.").font(.caption).foregroundStyle(FYColor.muted)
                if store.setup.value?.heightCM != nil || store.setup.value?.weightKG != nil {
                    Button("Körperdaten löschen", role: .destructive) { confirmsDelete = true }.font(.caption).frame(minHeight: 44)
                }
            }.fyCard()
            VStack(alignment: .leading, spacing: 13) {
                Label("Bewegungskalorien", systemImage: "flame.fill").font(.headline)
                Text("FYRUP zeigt die geschätzte aktive Energie aus Apple Health. Das ist Bewegung – nicht dein gesamter Tagesbedarf und keine Vorgabe zum Essen oder Abnehmen.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
                Button(store.setup.value?.energyRequested == true ? "Energiedaten in Health prüfen" : "Energiedaten aus Apple Health anzeigen") { Task { await store.energy.connect() } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(store.energy.isBusy || !store.energy.isAvailable || store.setup.value == nil)
                    .accessibilityIdentifier("setup-connect-energy")
                Text("Eigene, getrennte Lesefreigabe für „Aktive Energie“. Keine Schreibberechtigung. Schritte und Sessions werden nicht zusätzlich addiert – so vermeiden wir Doppelzählung.").font(.caption).foregroundStyle(FYColor.muted)
                Text("Die Schätzung kommt von Apple Health. Für dessen Berechnung gelten die dort hinterlegten Körperdaten; deine Angaben in FYRUP ändern Apple Health nicht.").font(.caption).foregroundStyle(FYColor.muted)
                metricField("Dein Bewegungsziel pro Tag · optional", unit: "kcal", value: $goal, id: "setup-calorie-goal")
                Text("Selbst gewählt, keine Empfehlung. Leer lassen, um das Ziel auszuschalten.").font(.caption).foregroundStyle(FYColor.muted)
                if store.setup.value?.energyRequested == true {
                    Button("Energieanzeige in FYRUP ausschalten") { store.energy.disconnect() }.font(.caption).frame(minHeight: 44)
                }
            }.fyCard()
            if let message = error ?? store.setup.errorMessage ?? store.energy.errorMessage { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
            Button("Körperdaten & Ziel speichern") { save() }.buttonStyle(OutlineButtonStyle()).disabled(store.setup.value == nil)
                .accessibilityIdentifier("save-body-and-goal")
            if saved { Label("Privat auf diesem iPhone gespeichert", systemImage: "checkmark.shield.fill").font(.caption).foregroundStyle(FYColor.lime).accessibilityIdentifier("body-data-saved") }
        }.onAppear { loadFields() }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focusedField = nil } } }
            .onChange(of: [height, weight, goal]) { _, current in saved = false; onEditingChanged(current != baseline) }
            .onChange(of: store.session?.userID) { _, _ in loadFields() }
            .confirmationDialog("Körperdaten auf diesem iPhone löschen?", isPresented: $confirmsDelete) {
                Button("Körperdaten löschen", role: .destructive) { if store.setup.deleteMeasurements() { loadFields(); onEditingChanged(false) } }
                Button("Behalten", role: .cancel) {}
            }
    }
    private func metricField(_ title: String, unit: String, value: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            HStack { TextField("Optional", text: value).keyboardType(.decimalPad).focused($focusedField, equals: id).accessibilityLabel(title).accessibilityIdentifier(id); Text(unit).foregroundStyle(FYColor.muted) }
                .padding(13).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private func loadFields() {
        height = store.setup.value?.heightCM.map { String($0) } ?? ""
        weight = store.setup.value?.weightKG.map { String($0) } ?? ""
        goal = store.setup.value?.activeCalorieGoal.map(String.init) ?? ""
        baseline = [height, weight, goal]
        saved = false; error = nil
    }
    private func save() {
        func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }
        error = nil; saved = false
        for text in [height, weight, goal] where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = number(text), parsed.isFinite else { error = "Prüfe deine Eingabe. Verwende Zahlen und bei Bedarf ein Komma."; return }
        }
        let parsedGoal = number(goal)
        if let parsedGoal, parsedGoal.rounded() != parsedGoal || !(50...5000).contains(parsedGoal) { error = "Gib ein ganzzahliges Bewegungsziel von 50–5.000 kcal ein oder lass es leer."; return }
        saved = store.setup.update {
            $0.heightCM = number(height); $0.weightKG = number(weight)
            $0.measurementsUpdatedAt = $0.heightCM != nil || $0.weightKG != nil ? .now : nil
            $0.activeCalorieGoal = parsedGoal.map(Int.init)
        }
        if saved { baseline = [height, weight, goal]; onEditingChanged(false) }
    }
}

struct ActiveEnergyCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            NavigationLink {
                ScrollView { BodyAndEnergySettings().padding(20).padding(.bottom, 80) }.background(FYColor.background).navigationTitle("Bewegungskalorien")
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(FYColor.coral.opacity(0.12), lineWidth: 7)
                        if let amount = store.energy.kilocalories, let target = store.setup.value?.activeCalorieGoal {
                            Circle().trim(from: 0, to: min(1, amount / Double(target))).stroke(FYColor.coral, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                        }
                        Image(systemName: "flame.fill").font(.title2).foregroundStyle(FYColor.coral)
                    }.frame(width: 60, height: 60).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Bewegung heute").font(.headline)
                        if let amount = store.energy.kilocalories {
                            Text("≈ \(Int(amount.rounded())) kcal").font(.title2.bold()).contentTransition(.numericText())
                            if let target = store.setup.value?.activeCalorieGoal {
                                Text(amount >= Double(target) ? "Dein Tagesziel ist erreicht" : "Noch ≈ \(Int(ceil(Double(target) - amount))) kcal bis zu deinem Ziel").font(.caption).foregroundStyle(FYColor.muted)
                            }
                            if let updated = store.energy.updatedAt { Text("Apple Health · Stand \(updated.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(FYColor.muted) }
                        } else { Text(store.setup.value?.energyRequested == true ? "Noch keine Energiedaten verfügbar" : "Kalorienanzeige einrichten").font(.subheadline).foregroundStyle(FYColor.muted) }
                        Text("Geschätzte aktive Energie, kein Gesamtbedarf").font(.caption2).foregroundStyle(FYColor.muted)
                    }
                    Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted)
                }.foregroundStyle(FYColor.ink).fyCard()
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: store.energy.kilocalories)
            }.buttonStyle(FYPressStyle()).accessibilityIdentifier("active-energy-card")
        }
    }
}
