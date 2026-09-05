import SwiftUI

struct WeeklyGoalSelectionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isOnboarding: Bool
    @State private var selection = 4
    @State private var didLoadSelection = false

    private var firstConfirmation: Bool { store.weekly.state?.goalConfirmed != true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isOnboarding {
                    Button { store.route = store.profile?.sports.contains(.gym) == true ? .gymSetup : .sportsSetup } label: {
                        Image(systemName: "chevron.left").frame(width: 32, height: 32)
                    }.accessibilityLabel("Zurück")
                }
                Image(systemName: "flame").font(.system(size: 42)).foregroundStyle(FYColor.lime).padding(.top, 16)
                Text(firstConfirmation ? "Dein Wochenziel" : isOnboarding ? "Dein Ziel steht" : "Wochenziel ändern")
                    .font(.system(size: 30, weight: .black))
                Text("Wie oft willst du pro Woche trainieren?").font(.title3.bold())
                Text("Setze dir ein realistisches Ziel. Wenn du es erreichst, verdienst du deine Flamme. Pausen gehören dazu – es gibt kein Tagesziel.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
                if let current = store.weekly.currentWeek {
                    Label("Aktuell: \(current.weeklyGoal) Trainings pro Woche", systemImage: "calendar").font(.subheadline.bold())
                }
                VStack(spacing: 10) {
                    ForEach(WeeklyGoal.options, id: \.self) { goal in
                        Button { selection = goal; Haptics.impact(.light) } label: {
                            HStack {
                                Text("\(goal)×").font(.title2.weight(.bold)).frame(width: 48, alignment: .leading)
                                Text("pro Woche").font(.subheadline)
                                Spacer()
                                Image(systemName: selection == goal ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == goal ? FYColor.lime : FYColor.line)
                            }.padding(15).foregroundStyle(FYColor.ink)
                                .background(selection == goal ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection == goal ? FYColor.lime : FYColor.line))
                        }.buttonStyle(.plain).accessibilityIdentifier("weekly-goal-\(goal)")
                            .accessibilityAddTraits(selection == goal ? .isSelected : [])
                            .disabled(store.weekly.isSavingGoal || (isOnboarding && !firstConfirmation))
                    }
                }
                if !firstConfirmation && !isOnboarding {
                    Text("Dein neues Ziel gilt ab nächster Woche. Das aktuelle Ziel und bereits verdiente Flammen bleiben unverändert.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                }
                WeeklyErrorMessage()
                Button(isOnboarding && !firstConfirmation ? "Weiter" : firstConfirmation ? "Ziel festlegen" : "Für nächste Woche speichern") {
                    Task {
                        if isOnboarding { await store.confirmOnboardingGoal(selection) }
                        else {
                            let saved = firstConfirmation ? await store.weekly.confirmGoal(selection) : await store.weekly.scheduleGoal(selection)
                            if saved { dismiss() }
                        }
                    }
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("confirm-weekly-goal")
                    .disabled(store.weekly.isSavingGoal || !store.weekly.isStateConfirmed || store.isBusy)
                if store.weekly.isLoading { ProgressView().frame(maxWidth: .infinity) }
            }.padding(22).padding(.bottom, 32)
        }.background(FYColor.background).foregroundStyle(FYColor.ink)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard let userID = store.session?.userID else { return }
                await store.weekly.activate(userID: userID)
                loadSelection()
            }
            .onChange(of: store.weekly.state) { _, _ in loadSelection() }
    }
    private func loadSelection() {
        guard !didLoadSelection, let state = store.weekly.state else { return }
        selection = isOnboarding ? (state.currentWeek?.weeklyGoal ?? state.suggestedWeeklyGoal) : (state.nextWeeklyGoal ?? state.currentWeek?.weeklyGoal ?? state.suggestedWeeklyGoal)
        didLoadSelection = true
    }
}

struct OwnWeeklyCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        NavigationLink { WeeklyFlameDetailView() } label: {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                VStack(alignment: .leading, spacing: 13) {
                    HStack { Text("Deine Woche").font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(FYColor.muted) }
                    if let week = store.weekly.currentWeek { WeeklyProgressContent(week: week) }
                    else if store.weekly.needsGoalConfirmation == true {
                        Text("Lege dein persönliches Wochenziel fest.").font(.subheadline).foregroundStyle(FYColor.muted)
                        Label("Ziel auswählen", systemImage: "target").font(.subheadline.bold()).foregroundStyle(FYColor.lime)
                    } else {
                        Text(store.weekly.isLoading ? "Deine Woche wird geladen …" : "Wochenziel gerade nicht verfügbar. Zum Prüfen öffnen.")
                            .font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                }.fyCard().foregroundStyle(FYColor.ink)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("own-weekly-card")
    }
}

private struct WeeklyProgressContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let week: WeeklyProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(week.progressText).font(.system(size: 32, weight: .black, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("Trainings").font(.subheadline).foregroundStyle(FYColor.muted)
                Spacer(minLength: 0)
                Image(systemName: week.flameEarned ? "flame.fill" : "flame")
                    .font(.title).foregroundStyle(week.flameEarned ? FYColor.coral : FYColor.muted)
                    .accessibilityLabel(week.flameEarned ? "Wochenflamme verdient" : "Wochenziel noch offen")
            }
            ProgressView(value: week.fraction).tint(week.flameEarned ? FYColor.coral : FYColor.lime)
            Text(week.motivationText).font(.subheadline.weight(.medium)).foregroundStyle(week.flameEarned ? FYColor.coral : FYColor.muted)
        }.animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: week.completedWorkouts)
    }
}

struct WeeklyFlameDetailView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Deine Flames").font(.largeTitle.weight(.black))
                if let week = store.weekly.currentWeek { WeeklyProgressContent(week: week).fyCard() }
                if let state = store.weekly.state, state.goalConfirmed {
                    HStack {
                        streakMetric(state.currentStreak, title: "Wochen in Folge")
                        Spacer()
                        streakMetric(state.bestStreak, title: "Dein Bestwert")
                    }.fyCard()
                    Text("Der Streak zählt erfolgreich abgeschlossene Wochen. Deine aktuelle Flamme gehört dir schon, sobald du dein Ziel erreicht hast.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                    if let goal = state.nextWeeklyGoal { Label("Ab nächster Woche: \(goal) Trainings", systemImage: "calendar.badge.clock").font(.subheadline).fyCard() }
                }
                NavigationLink { WeeklyGoalSelectionView(isOnboarding: false) } label: {
                    Label(store.weekly.needsGoalConfirmation == true ? "Wochenziel festlegen" : "Wochenziel ändern", systemImage: "target")
                }.buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("edit-weekly-goal")
                WeeklyErrorMessage()
                Text("Wochenhistorie").font(.headline)
                if store.weekly.history.isEmpty {
                    Text("Hier erscheinen deine abgeschlossenen Wochen. Neue Woche, neue Chance.").font(.subheadline).foregroundStyle(FYColor.muted).fyCard()
                }
                ForEach(store.weekly.history) { week in
                    HStack {
                        Image(systemName: week.flameEarned ? "flame.fill" : "circle").foregroundStyle(week.flameEarned ? FYColor.coral : FYColor.muted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Woche ab \(weeklyDateLabel(week.weekStartDate))").font(.subheadline.bold())
                            Text(week.flameEarned ? "Persönliches Ziel geschafft" : "Diese Woche nicht erreicht").font(.caption).foregroundStyle(FYColor.muted)
                        }
                        Spacer()
                        Text(week.progressText).font(.subheadline.bold()).monospacedDigit()
                    }.fyCard()
                }
                Text("Nur abgeschlossene FYRUP-Trainings zählen. Schritte, geplante und abgebrochene Trainings zählen nicht. Sehr kurze Einheiten unter einer aktiven Minute werden gespeichert, geben aber keinen Wochen-Credit.")
                    .font(.caption).foregroundStyle(FYColor.muted)
            }.padding(20).padding(.bottom, 32)
        }.background(FYColor.background).foregroundStyle(FYColor.ink)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.weekly.refresh(force: true) }
        }.task {
            await store.weekly.refresh(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await store.weekly.refresh()
            }
        }
    }
    private func streakMetric(_ count: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text("\(count)").font(.title.weight(.black)); Text(title).font(.caption).foregroundStyle(FYColor.muted) }
    }
}

struct FriendWeeklyLine: View {
    @Environment(AppStore.self) private var store
    let userID: UUID
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if store.crew.contains(where: { $0.id == userID }), let week = store.weekly.friend(userID: userID)?.currentWeek {
                HStack(spacing: 4) {
                    Text(week.progressText).monospacedDigit()
                    if week.flameEarned { Image(systemName: "flame.fill").foregroundStyle(FYColor.coral) }
                }.font(.caption.bold()).foregroundStyle(FYColor.muted)
            }
        }
    }
}

struct FriendWeeklyCard: View {
    @Environment(AppStore.self) private var store
    let userID: UUID
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if store.crew.contains(where: { $0.id == userID }), let state = store.weekly.friend(userID: userID), let week = state.currentWeek {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Diese Woche").font(.headline)
                    WeeklyProgressContent(week: week)
                    Text("\(state.currentStreak) Wochen in Folge").font(.subheadline).foregroundStyle(FYColor.muted)
                    if week.flameEarned {
                        HStack(spacing: 10) {
                            ForEach(ReactionKind.allCases, id: \.self) { reaction in
                                Button {
                                    Task { _ = await store.weekly.react(weekID: week.id, reaction: week.myReaction == reaction ? nil : reaction) }
                                } label: {
                                    HStack(spacing: 5) { Text(reaction.rawValue); Text("\(week.reactionCounts.first(where: { $0.reaction == reaction })?.count ?? 0)").font(.caption.bold()) }
                                        .padding(10).background(week.myReaction == reaction ? FYColor.limeSoft : FYColor.elevated, in: Capsule())
                                }.buttonStyle(.plain).disabled(store.weekly.isReacting(weekID: week.id))
                                    .accessibilityLabel("Auf Wochenflamme reagieren: \(reaction.rawValue)")
                            }
                        }
                    }
                }.fyCard()
            }
        }
    }
}

private struct WeeklyErrorMessage: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        if let message = store.weekly.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text(message).font(.subheadline).foregroundStyle(FYColor.muted)
                Button("Erneut prüfen") { Task { await store.weekly.refresh(force: true) } }
                    .font(.subheadline.bold()).foregroundStyle(FYColor.lime).disabled(store.weekly.isLoading)
            }.fyCard()
        }
    }
}

struct FlameCelebrationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let celebration: WeeklyFlameCelebration
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(FYColor.coral.opacity(0.10)).frame(width: 200, height: 200)
                Circle().stroke(FYColor.coral.opacity(0.12), lineWidth: 12).frame(width: 156, height: 156)
                Image(systemName: "flame.fill").font(.system(size: 98)).foregroundStyle(FYColor.coral)
                    .shadow(color: FYColor.coral.opacity(0.24), radius: 24)
            }.scaleEffect(appeared ? 1 : 0.82).opacity(appeared ? 1 : 0)
            Text("WOCHENZIEL GESCHAFFT").font(.title2.weight(.black)).multilineTextAlignment(.center)
            Text("\(celebration.week.progressText) Trainings").font(.title.weight(.bold)).monospacedDigit()
            Text("Deine Flamme gehört dir.").font(.title3).foregroundStyle(FYColor.muted)
            Text("Stark. Nächste Woche wieder.").font(.subheadline).foregroundStyle(FYColor.muted)
            Spacer()
            Button("Weiter") { store.weekly.dismissCelebration() }.buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("dismiss-flame-celebration")
        }.padding(28).background(FYColor.background).foregroundStyle(FYColor.ink)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.72)) { appeared = true }
                Haptics.success()
            }
    }
}

private func weeklyDateLabel(_ value: String) -> String {
    let parts = value.split(separator: "-")
    return parts.count == 3 ? "\(parts[2]).\(parts[1]).\(parts[0])" : value
}
