import SwiftUI

struct StepSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var explainsHealth = false
    @State private var customGoal = ""

    var body: some View {
        Form {
            Section("Apple Health") {
                Label(store.steps.healthStatusText, systemImage: "heart.text.clipboard")
                Button(store.steps.healthRequested ? "Apple Health prüfen" : "Apple Health verbinden") { explainsHealth = true }
                    .accessibilityIdentifier("connect-health")
                Text("Apple Health verrät FYRUP nicht, ob du den Lesezugriff erlaubt hast. Ohne verfügbare Daten zeigen wir deshalb keine erfundene Null.")
                    .font(.caption).foregroundStyle(FYColor.muted)
            }
            Section {
                Toggle("Meine Schritte anzeigen", isOn: Binding(get: { store.steps.showSteps }, set: { store.steps.setShowSteps($0) }))
                    .accessibilityIdentifier("show-own-steps")
            } footer: { Text("Diese Einstellung gilt nur für deine eigene Ansicht auf diesem Gerät.") }
            Section {
                if store.steps.isSharingPreferenceCurrent, let enabled = store.steps.sharingEnabled {
                    Toggle("Schritte mit Freunden teilen", isOn: Binding(get: { enabled }, set: { value in Task { await store.steps.setSharing(value) } }))
                        .disabled(store.steps.isChangingSharing).accessibilityIdentifier("share-steps")
                } else {
                    Label(store.steps.isChangingSharing ? "Freigabe wird bestätigt …" : "Freigabe noch nicht bestätigt", systemImage: "lock.shield")
                    Button("Freigabe prüfen") { Task { await store.steps.refresh(force: true) } }.disabled(store.steps.isBusy)
                    Button("Freigabe ausschalten") { Task { await store.steps.setSharing(false) } }.disabled(store.steps.isBusy)
                }
                Text("Wenn aktiviert, können deine bestätigten FYRUP-Freunde deine heutige Schrittzahl sehen. Apple-Health-Zugriff allein gibt nichts frei.")
                    .font(.caption).foregroundStyle(FYColor.muted)
                if store.steps.isSharingPreferenceCurrent && store.steps.sharingEnabled == false {
                    Label("Deine Schritte sind nicht für Freunde freigegeben.", systemImage: "lock.fill").font(.caption).foregroundStyle(FYColor.lime)
                }
            } header: { Text("Deine Kontrolle") }
            Section {
                Picker("Tägliches Schrittziel", selection: goalChoice) {
                    Text("Kein Ziel").tag(0)
                    ForEach([5000, 7500, 10000, 12500], id: \.self) { Text($0.formatted()).tag($0) }
                    Text("Eigener Wert").tag(-1)
                }
                if goalChoice.wrappedValue == -1 {
                    TextField("z. B. 8.000", text: $customGoal).keyboardType(.numberPad).accessibilityIdentifier("custom-step-goal")
                    Button("Schrittziel übernehmen") { if let count = Int(customGoal) { store.steps.setGoal(count) } }
                        .disabled(Int(customGoal).map { !(1000...100000).contains($0) } ?? true)
                }
            } header: { Text("Dein persönliches Ziel · optional") } footer: { Text("Das Schrittziel bleibt privat. Schritte ersetzen keine Trainings und geben keine Wochenflammen.") }
            if let message = store.steps.message {
                Section { Text(message).foregroundStyle(FYColor.coral); Button("Erneut versuchen") { Task { await store.steps.refresh(force: true) } } }
            }
        }
        .scrollContentBackground(.hidden).background(FYColor.background)
        .navigationTitle("Schritte").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .tint(FYColor.lime).preferredColorScheme(.light)
        .sheet(isPresented: $explainsHealth) { HealthExplanationView() }
        .task { await store.steps.refresh(force: true) }
        .onAppear { customGoal = store.steps.goal.map(String.init) ?? "" }
    }

    @State private var editingCustomGoal = false
    private var goalChoice: Binding<Int> {
        Binding(get: {
            if editingCustomGoal { return -1 }
            guard let goal = store.steps.goal else { return 0 }
            return [5000, 7500, 10000, 12500].contains(goal) ? goal : -1
        }, set: { value in
            editingCustomGoal = value == -1
            if value != -1 { store.steps.setGoal(value == 0 ? nil : value) }
        })
    }
}

struct HealthExplanationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "figure.walk").font(.system(size: 64)).foregroundStyle(FYColor.lime)
                        .frame(maxWidth: .infinity).padding(.top, 28)
                    Text("Deine tägliche Bewegung").font(.largeTitle.weight(.black))
                    Text("Sieh deine Schritte direkt in FYRUP und vergleiche dich auf Wunsch mit deinen Freunden.").foregroundStyle(FYColor.muted)
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Deine Schritte bleiben unter deiner Kontrolle.", systemImage: "lock.shield")
                        Label("Du entscheidest, ob Freunde sie sehen.", systemImage: "person.2")
                        Label("Die Freigabe kann jederzeit ausgeschaltet werden.", systemImage: "switch.2")
                    }.font(.subheadline).fyCard()
                    Text("FYRUP fragt ausschließlich nach „Schritte lesen“. Keine Herzfrequenz, kein Schlaf, kein Standort und keine Schreibberechtigung. Die separate Freigabe an Freunde ist standardmäßig aus und wird durch diesen Dialog nicht geändert.")
                        .font(.caption).foregroundStyle(FYColor.muted)
                    if store.steps.healthRequested {
                        Text("Du kannst den Zugriff auch in Apple Health unter deinem Profil → Apps → FYRUP prüfen. Fehlende Daten bedeuten nicht automatisch eine abgelehnte Berechtigung.").font(.caption).foregroundStyle(FYColor.muted)
                    }
                    if let message = store.steps.message { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
                    Button(store.steps.isAuthorizing ? "Apple Health wird geöffnet …" : "Mit Apple Health verbinden") {
                        Task { await store.steps.connect(); if store.steps.healthRequested && store.steps.message == nil { dismiss() } }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(store.steps.isAuthorizing || !store.steps.isAvailable)
                        .accessibilityIdentifier("confirm-connect-health")
                    Button("Nicht jetzt") { dismiss() }.frame(maxWidth: .infinity).foregroundStyle(FYColor.muted).padding(.bottom, 12)
                }.padding(24)
            }.background(FYColor.background).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.tint(FYColor.lime).preferredColorScheme(.light)
    }
}

struct OwnStepsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if store.steps.showSteps {
                NavigationLink { StepSettingsView() } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Dein Tag", systemImage: "figure.walk").font(.headline)
                            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted)
                        }
                        if let count = store.steps.todaysSteps {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(count.formatted()).font(.title2.weight(.black)).contentTransition(.numericText())
                                Text("Schritte").font(.subheadline).foregroundStyle(FYColor.muted)
                                Spacer()
                            }
                            if let progress = store.steps.progress, let goal = store.steps.goal {
                                ProgressView(value: progress).tint(FYColor.lime)
                                Text("\(count.formatted()) / \(goal.formatted()) · dein privates Ziel").font(.caption).foregroundStyle(FYColor.muted)
                            }
                        } else { Text("Keine Schrittdaten verfügbar").font(.subheadline).foregroundStyle(FYColor.muted) }
                    }.fyCard().foregroundStyle(FYColor.ink)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.steps.todaysSteps)
                }.buttonStyle(.plain).accessibilityIdentifier("own-steps-card")
            }
        }
    }
}

struct FriendStepsLine: View {
    @Environment(AppStore.self) private var store
    let userID: UUID
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if store.crew.contains(where: { $0.id == userID }), let metric = store.steps.shared.first(where: { $0.userID == userID }) {
                Label("\(metric.steps.formatted()) Schritte heute", systemImage: "figure.walk")
                    .font(.caption).foregroundStyle(FYColor.muted).accessibilityIdentifier("friend-steps-\(userID)")
            }
        }
    }
}
