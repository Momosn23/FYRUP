import SwiftUI

struct WorkoutRestView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let activityID: UUID
    var compact = false
    @State private var showsOptions = false
    private var ownsLiveSession: Bool {
        store.session?.userID == store.myActivity?.userID && store.myActivity?.id == activityID && store.myActivity?.status == .live
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let clock = store.rest.clock.flatMap { $0.activityID == activityID ? $0 : nil }
            let remaining = clock?.remaining(at: context.date)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(FYColor.lime.opacity(0.15), lineWidth: 4)
                        Circle().trim(from: 0, to: clock?.progress(at: context.date) ?? 0)
                            .stroke(FYColor.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: remaining == 0 ? "checkmark" : "timer").font(.title3).foregroundStyle(FYColor.lime)
                    }.frame(width: 44, height: 44).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remaining == 0 ? "Pause geschafft" : "Satzpause").font(.headline)
                        Text(clock == nil ? "Kurz durchatmen. Dann weiter." : "Deine Session läuft weiter.").font(.caption).foregroundStyle(FYColor.muted)
                    }
                    Spacer(minLength: 4)
                    if let remaining {
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.title2.bold()).monospacedDigit().contentTransition(.numericText())
                            .accessibilityLabel("Satzpause: \(remaining) Sekunden verbleibend").accessibilityIdentifier("rest-countdown")
                    }
                }
                if !compact {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 6) { durationButtons }
                }
                Button { showsOptions = true } label: {
                    HStack { Text("\(store.rest.selectedDuration) s · Dauer & Erinnerung"); Spacer(); Image(systemName: "slider.horizontal.3") }
                        .font(.caption.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityIdentifier("rest-options").disabled(!ownsLiveSession)
                HStack(spacing: 10) {
                    Button(clock == nil ? "Satzpause starten" : "Neue Satzpause") {
                        store.rest.start(activityID: activityID); Haptics.impact(.light)
                    }.buttonStyle(OutlineButtonStyle()).disabled(!store.isActivityCurrent).accessibilityIdentifier("start-rest-timer")
                    if clock != nil {
                        Button("Beenden") { store.rest.stop(activityID: activityID) }
                            .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("stop-rest-timer")
                    }
                }.disabled(!ownsLiveSession)
                if let message = store.rest.reminderMessage { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
            }.fyCard()
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clock == nil)
        }.sheet(isPresented: $showsOptions) { NavigationStack { WorkoutRestSettingsView() } }
    }

    private var durationButtons: some View {
        ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
            Button {
                store.rest.selectDuration(seconds); Haptics.impact(.light)
            } label: {
                Text("\(seconds) s").font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(store.rest.selectedDuration == seconds ? FYColor.lime : FYColor.muted)
                    .background(store.rest.selectedDuration == seconds ? FYColor.limeSoft : FYColor.elevated, in: Capsule())
            }.buttonStyle(FYPressStyle()).accessibilityLabel("\(seconds) Sekunden Satzpause")
                .accessibilityAddTraits(store.rest.selectedDuration == seconds ? .isSelected : [])
                .accessibilityIdentifier("rest-duration-\(seconds)").disabled(!ownsLiveSession)
        }
    }
}
