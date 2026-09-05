import SwiftUI

struct WorkoutRestSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var seconds = ""
    @State private var error: String?
    @FocusState private var editsSeconds: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Sekunden", text: $seconds).keyboardType(.numberPad).focused($editsSeconds)
                        .accessibilityLabel("Eigene Satzpausendauer in Sekunden").accessibilityIdentifier("custom-rest-seconds")
                    Text("Sekunden").foregroundStyle(FYColor.muted)
                }
                Button("Dauer übernehmen") {
                    guard let value = RestDurationInput.seconds(from: seconds) else {
                        error = "Gib 15–600 ganze Sekunden ein."; return
                    }
                    store.rest.selectDuration(value); editsSeconds = false; error = nil; Haptics.impact(.light)
                }.accessibilityIdentifier("save-custom-rest")
                Label("Gespeichert: \(store.rest.selectedDuration) Sekunden", systemImage: "timer").font(.caption)
                if let error { Text(error).font(.caption).foregroundStyle(FYColor.coral) }
            } header: { Text("Deine Dauer") } footer: {
                Text("Gilt für die nächste Satzpause. Eine laufende Pause wird erst mit „Neue Satzpause“ zurückgesetzt. Deine gesamte Session läuft davon unabhängig weiter.")
            }
            Section {
                Toggle("Beim Ablauf erinnern", isOn: Binding(get: { store.rest.reminderEnabled }, set: { store.rest.setReminderEnabled($0) }))
                    .accessibilityIdentifier("rest-reminder-enabled")
                if store.rest.reminderEnabled {
                    Toggle("Mit Ton", isOn: Binding(get: { store.rest.soundEnabled }, set: { store.rest.setSoundEnabled($0) }))
                        .accessibilityIdentifier("rest-reminder-sound")
                    SystemNotificationSettingsRow()
                    Button("Erinnerung erneut prüfen") { store.rest.retryReminder() }
                    if let message = store.rest.reminderMessage { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
                }
            } header: { Text("Freiwillige Erinnerung") } footer: {
                Text("Eine lokale Mitteilung pro Pause – auch bei gesperrtem iPhone. Kein Wiederholungsalarm, keine Übungsnamen oder Gewichte auf dem Sperrbildschirm. Fokus, Stummschaltung und iOS können Ton und Zustellung begrenzen.")
            }
        }.navigationTitle("Deine Satzpause").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Tastatur schließen") { editsSeconds = false } }
            }
            .task { seconds = String(store.rest.selectedDuration) }
    }
}
