import SwiftUI

struct SessionIntervalView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let activity: Activity
    var compact = false
    @State private var showsConfiguration = false
    private var ownsSession: Bool {
        store.session?.userID == activity.userID && store.myActivity?.id == activity.id && activity.status == .live
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let clock = store.intervals.clock.flatMap { $0.activityID == activity.id ? $0 : nil }
            let position = activity.duration(at: context.date).flatMap { clock?.position(activeSeconds: $0) }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(FYColor.limeSoft, lineWidth: 5)
                        Circle().trim(from: 0, to: position?.progress ?? 0)
                            .stroke(position?.phase == .recovery ? FYColor.violet : FYColor.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: position?.phase == .completed ? "checkmark" : "repeat").foregroundStyle(FYColor.lime)
                    }.frame(width: 44, height: 44).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(position)).font(.headline).accessibilityIdentifier("interval-phase")
                        if let position, let clock {
                            Text("Runde \(position.round) / \(clock.configuration.rounds)").font(.caption).foregroundStyle(FYColor.muted)
                        } else { Text("Belastung, Erholung, Runden – du wählst.").font(.caption).foregroundStyle(FYColor.muted) }
                    }
                    Spacer(minLength: 0)
                    if let position {
                        Text(String(format: "%02d:%02d", position.remaining / 60, position.remaining % 60))
                            .font(.title2.bold()).monospacedDigit().contentTransition(reduceMotion ? .identity : .numericText())
                            .accessibilityLabel("\(position.remaining) Sekunden verbleibend").accessibilityIdentifier("interval-countdown")
                    }
                }
                if activity.pausedAt != nil { Text("Pausiert – zusammen mit deiner Session.").font(.caption.bold()).foregroundStyle(FYColor.muted) }
                if position?.phase == .completed { Text("Intervalle geschafft. Deine Aktivität läuft weiter, bis du sie abschließt.").font(.caption).foregroundStyle(FYColor.muted) }
                if clock != nil && position == nil { Text("Der aktuelle Zeitstand ist noch nicht verfügbar. Aktualisiere deine Session.").font(.caption).foregroundStyle(FYColor.muted) }
                if !compact || clock == nil {
                    Text("Kein automatischer Ton oder Hinweis im Hintergrund. Die Anzeige folgt der aktiven Session-Zeit; eine Session-Pause hält auch die Intervalle an.").font(.caption2).foregroundStyle(FYColor.muted)
                }
                HStack {
                    Button(clock == nil ? "Intervalle einstellen" : "Neue Intervalle") { showsConfiguration = true }
                        .buttonStyle(OutlineButtonStyle()).disabled(!ownsSession || !store.isActivityCurrent).accessibilityIdentifier("configure-intervals")
                    if clock != nil {
                        Button("Timer beenden") { store.intervals.stop(activityID: activity.id) }
                            .font(.caption.bold()).frame(minHeight: 44).disabled(!ownsSession).accessibilityIdentifier("stop-intervals")
                    }
                }
            }.fyCard().animation(reduceMotion ? nil : .linear(duration: 0.4), value: position?.remaining)
        }.accessibilityIdentifier("interval-timer-panel")
            .sheet(isPresented: $showsConfiguration) { SessionIntervalSettings(activityID: activity.id) }
    }
    private func title(_ position: SessionIntervalPosition?) -> String {
        switch position?.phase {
        case .work: "Belastung"
        case .recovery: "Erholung"
        case .completed: "Intervalle geschafft"
        case nil: "Dein Intervalltimer"
        }
    }
}

private struct SessionIntervalSettings: View {
    private enum Field: Hashable { case work, recovery, rounds }
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let activityID: UUID
    @State private var work = "", recovery = "", rounds = ""
    @State private var loaded = false
    @State private var message: String?
    @FocusState private var focusedField: Field?
    private var configuration: SessionIntervalConfiguration? { .parse(work: work, recovery: recovery, rounds: rounds) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dein Rhythmus. Deine Wahl.").font(.headline)
                    Text("Lege deine Zeiten selbst fest. Die Werte sind keine persönliche Belastungsempfehlung.").font(.caption)
                }
                Section("Deine Intervalle") {
                    field("Belastung in Sekunden", text: $work, id: "interval-work", focus: .work)
                    field("Erholung in Sekunden", text: $recovery, id: "interval-recovery", focus: .recovery)
                    field("Runden", text: $rounds, id: "interval-rounds", focus: .rounds)
                    Text("Belastung 5–3.600 s, Erholung 0–3.600 s, 1–99 Runden; insgesamt höchstens 6 Stunden. Nach der letzten Runde keine zusätzliche Erholung.").font(.caption).foregroundStyle(FYColor.muted)
                    if let total = configuration?.totalSeconds { Text("Gesamt: \(total / 60) min \(total % 60) s").font(.subheadline.bold()) }
                }
                Section {
                    Button("Intervalltimer starten") {
                        guard let configuration, let activity = store.myActivity, activity.id == activityID,
                              store.isActivityCurrent, store.session?.userID == activity.userID,
                              store.intervals.start(activity: activity, configuration: configuration) else {
                            message = "Starte die Intervalle in deiner eigenen, laufenden und nicht pausierten Session."; return
                        }
                        Haptics.impact(.light); dismiss()
                    }.disabled(configuration == nil).accessibilityIdentifier("start-intervals")
                    Text("Ersetzt einen laufenden Intervalltimer, aber ändert weder deine Aktivität noch dein Wochenziel.").font(.caption)
                    if let message { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
                }
            }.navigationTitle("Intervalltimer").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focusedField = nil } }
                }
                .onAppear {
                    guard !loaded else { return }; loaded = true
                    if let value = store.intervals.lastConfiguration {
                        work = String(value.workSeconds); recovery = String(value.recoverySeconds); rounds = String(value.rounds)
                    }
                }
        }
    }
    private func field(_ title: String, text: Binding<String>, id: String, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold())
            TextField(title, text: text).keyboardType(.numberPad).focused($focusedField, equals: focus).accessibilityIdentifier(id)
        }
    }
}
