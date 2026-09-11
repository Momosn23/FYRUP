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
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!store.isActivityCurrent).accessibilityIdentifier("start-rest-timer")
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

/// Focused, distraction-free pause screen shown after a completed set.
/// The same persisted clock powers this screen, notifications and Live Activity.
struct WorkoutRestFocusView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let activityID: UUID

    private var ownsLiveSession: Bool {
        store.session?.userID == store.myActivity?.userID && store.myActivity?.id == activityID && store.myActivity?.status == .live
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let clock = store.rest.clock.flatMap { $0.activityID == activityID ? $0 : nil }
            let remaining = clock?.remaining(at: context.date) ?? store.rest.selectedDuration
            let ringProgress = clock.map { max(0, 1 - $0.progress(at: context.date)) } ?? 1

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        FYRUPWordmark(size: 21)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                        }.accessibilityLabel("Satzpause schließen")
                    }
                    Text("Satzpause").font(.largeTitle.weight(.black))
                    Text("Nimm dir die Zeit. Stark wird man in den Pausen.")
                        .font(.title3).foregroundStyle(FYColor.muted)

                    ZStack {
                        Circle().stroke(FYColor.line, lineWidth: 10)
                        Circle().trim(from: 0, to: ringProgress)
                            .stroke(FYColor.lime, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .linear(duration: 0.25), value: ringProgress)
                        VStack(spacing: 5) {
                            Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                                .font(.system(size: 48, weight: .black, design: .rounded)).monospacedDigit()
                            Text("Min : Sek").font(.caption).foregroundStyle(FYColor.muted)
                        }
                    }
                    .frame(width: 224, height: 224).frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("rest-focus-countdown")

                    HStack(spacing: 7) {
                        ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
                            Button {
                                store.rest.selectDuration(seconds); Haptics.impact(.light)
                            } label: {
                                Text("\(seconds) s").font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundStyle(store.rest.selectedDuration == seconds ? FYColor.ink : FYColor.muted)
                                    .background(store.rest.selectedDuration == seconds ? FYColor.limeSoft : .clear, in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(store.rest.selectedDuration == seconds ? FYColor.lime : FYColor.line))
                            }.buttonStyle(FYPressStyle()).disabled(!ownsLiveSession || clock != nil)
                                .accessibilityIdentifier("rest-focus-duration-\(seconds)")
                        }
                    }

                    HStack(spacing: 12) {
                        Button("+15 s") { store.rest.extend(activityID: activityID, by: 15); Haptics.impact(.light) }
                            .buttonStyle(OutlineButtonStyle()).disabled(clock == nil || !ownsLiveSession)
                        Button("Überspringen") { store.rest.stop(activityID: activityID); dismiss() }
                            .buttonStyle(OutlineButtonStyle()).disabled(!ownsLiveSession)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ALS NÄCHSTES").font(.caption.weight(.heavy)).tracking(0.7).foregroundStyle(FYColor.muted)
                        HStack {
                            Image("SportGymHero").resizable().scaledToFill().frame(width: 76, height: 58).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Dein Workout fortsetzen").font(.headline)
                                Text("Nächsten Satz oder nächste Übung öffnen").font(.caption).foregroundStyle(FYColor.muted)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }
                    }
                    .padding(.top, 6).overlay(alignment: .top) { Divider().overlay(FYColor.line) }
                }.padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button(clock == nil ? "Satzpause starten" : "Weiter") {
                    if clock == nil { store.rest.start(activityID: activityID); Haptics.impact(.light) }
                    else { store.rest.stop(activityID: activityID); dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(!ownsLiveSession)
                .padding(.horizontal, 20).padding(.vertical, 12).background(FYColor.background)
                .accessibilityIdentifier("rest-focus-primary")
            }
        }
        .background(FYColor.background).preferredColorScheme(.light)
    }
}
