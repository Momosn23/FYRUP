import SwiftUI

/// A commitment is always rendered from the authorized weekly state, never a local toggle.
struct ShotStatusBadge: View {
    let commitment: WeeklyCommitment
    var body: some View {
        Label(commitment.title, systemImage: "target")
            .font(.caption.weight(.black)).foregroundStyle(commitment.achieved ? FYColor.coral : FYColor.lime)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(commitment.achieved ? FYColor.coral.opacity(0.10) : FYColor.limeSoft, in: Capsule())
    }
}

struct OwnShotCard: View {
    @Environment(AppStore.self) private var store
    @State private var confirmsShot = false
    var body: some View {
        if let week = store.weekly.currentWeek {
            VStack(alignment: .leading, spacing: 14) {
                if let commitment = week.commitment {
                    ShotStatusBadge(commitment: commitment).accessibilityIdentifier("own-shot-status")
                    Text(commitment.achieved ? "Gesagt. Gemacht." : "Diese Woche hole ich mein Ziel.").font(.title3.bold())
                    Text("Dein Call: \(commitment.weeklyGoal) Einheiten · Stand: \(week.progressText)")
                        .font(.subheadline).foregroundStyle(FYColor.muted).accessibilityIdentifier("own-shot-progress")
                    Text(commitment.statusText).font(.footnote).foregroundStyle(FYColor.muted)
                    if !commitment.reactionCounts.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(ShotReaction.allCases) { reaction in
                                if let count = commitment.reactionCounts.first(where: { $0.reaction == reaction })?.count {
                                    Text("\(reaction.rawValue) \(count)").font(.subheadline.bold())
                                }
                            }
                        }.accessibilityLabel("Reaktionen deiner Freunde")
                    }
                } else if !week.flameEarned {
                    Label("Diese Woche. Dein Wort.", systemImage: "target").font(.headline)
                    Text("Sag deiner Crew, dass du dein Wochenziel holen willst. Freiwillig – dein Ziel bleibt genau dasselbe.")
                        .font(.subheadline).foregroundStyle(FYColor.muted)
                    Button("CALL MY SHOT 🎯") { confirmsShot = true }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!store.weekly.isStateConfirmed || store.shot.isCalling)
                        .accessibilityIdentifier("open-call-my-shot")
                } else {
                    Label("Deine Flamme ist schon verdient", systemImage: "flame.fill").font(.headline).foregroundStyle(FYColor.coral)
                    Text("Ein Call ist vor dem Erreichen des Ziels möglich. Nächste Woche kannst du wieder entscheiden.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                }
                ShotErrorMessage()
            }.fyCard()
                .sheet(isPresented: $confirmsShot) { ShotConfirmationView() }
        }
    }
}

private struct ShotConfirmationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "target").font(.system(size: 56)).foregroundStyle(FYColor.lime).padding(.top, 16)
                    Text("Willst du dich festlegen?").font(.largeTitle.weight(.black))
                    if let week = store.weekly.currentWeek {
                        Text("Dein Wochenziel").font(.subheadline).foregroundStyle(FYColor.muted)
                        Text("\(week.weeklyGoal) Einheiten").font(.system(size: 38, weight: .black, design: .rounded))
                        Text("Deine Freunde sehen, dass du diese Woche dein Ziel angekündigt hast.").font(.title3)
                        Text("Einmal pro Woche. Dein aktuelles Wochenziel lässt sich dadurch nicht ändern. Pausen gehören dazu – keine Minuspunkte, wenn es diese Woche nicht klappt.")
                            .font(.subheadline).foregroundStyle(FYColor.muted)
                        if week.commitment != nil {
                            Label("Dein Shot ist gespeichert.", systemImage: "checkmark.circle.fill").foregroundStyle(FYColor.lime)
                            Button("Fertig") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                        } else if !week.flameEarned {
                            Button("SHOT CALLEN") {
                                Task { if await store.shot.call(expectedWeekID: week.id) { Haptics.success(); dismiss() } }
                            }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("confirm-call-my-shot")
                                .disabled(store.shot.isCalling || !store.weekly.isStateConfirmed)
                        } else {
                            Text("Du hast dein Ziel bereits erreicht. Für diese Woche ist kein nachträglicher Call möglich.").font(.subheadline)
                        }
                    } else {
                        Text("Die aktuelle Woche wird geprüft. Bitte warte einen Moment.").foregroundStyle(FYColor.muted)
                    }
                    if store.shot.isCalling || store.weekly.isLoading { ProgressView().frame(maxWidth: .infinity) }
                    ShotErrorMessage()
                    Button("Abbrechen") { dismiss() }.buttonStyle(OutlineButtonStyle()).disabled(store.shot.isCalling)
                }.padding(24)
            }.background(FYColor.background).foregroundStyle(FYColor.ink)
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityElement(children: .contain).accessibilityIdentifier("shot-confirmation-screen")
        }.tint(FYColor.lime).interactiveDismissDisabled(store.shot.isCalling)
            .task { await store.weekly.refresh(force: true) }
    }
}

struct FriendShotContent: View {
    @Environment(AppStore.self) private var store
    let week: WeeklyProgress
    var body: some View {
        if let commitment = week.commitment {
            VStack(alignment: .leading, spacing: 12) {
                ShotStatusBadge(commitment: commitment).accessibilityIdentifier("friend-shot-status")
                Text("Angekündigt: \(commitment.weeklyGoal) Einheiten · Aktuell: \(week.progressText)")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
                HStack(spacing: 10) {
                    ForEach(ShotReaction.allCases) { reaction in
                        Button {
                            Task { _ = await store.shot.react(commitmentID: commitment.id, reaction: commitment.myReaction == reaction ? nil : reaction) }
                        } label: {
                            HStack(spacing: 5) {
                                Text(reaction.rawValue)
                                Text("\(commitment.reactionCounts.first(where: { $0.reaction == reaction })?.count ?? 0)").font(.caption.bold())
                            }.padding(12).background(commitment.myReaction == reaction ? FYColor.limeSoft : FYColor.elevated, in: Capsule())
                        }.buttonStyle(.plain).disabled(store.shot.isReacting(commitmentID: commitment.id))
                            .accessibilityLabel("Auf Call reagieren: \(reaction.rawValue)")
                            .accessibilityValue(commitment.myReaction == reaction ? "Ausgewählt" : "Nicht ausgewählt")
                            .accessibilityIdentifier("reaction-shot-\(reaction == .target ? "target" : reaction == .fire ? "fire" : "strong")")
                    }
                }
                ShotErrorMessage()
            }
        }
    }
}

/// Notifications link to a fresh authorized friend state; missing access never falls back to saved notification data.
struct FriendWeeklyDestination: View {
    @Environment(AppStore.self) private var store
    let userID: UUID
    @State private var isLoading = true
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading { ProgressView("Woche wird geladen …").frame(maxWidth: .infinity) }
                else if store.weekly.friend(userID: userID)?.currentWeek != nil && store.crew.contains(where: { $0.id == userID }) {
                    Text(store.crew.first(where: { $0.id == userID })?.profile.displayName ?? "Dein Freund").font(.largeTitle.bold())
                    FriendWeeklyCard(userID: userID)
                } else { ContentUnavailableView("Woche nicht verfügbar", systemImage: "person.crop.circle.badge.questionmark", description: Text("Diese Mitteilung ist nicht mehr aktuell oder die Freundschaft wurde beendet.")) }
            }.padding(20)
        }.background(FYColor.background).navigationTitle("Wochenziel").navigationBarTitleDisplayMode(.inline)
            .task { _ = await store.weekly.loadFriend(userID: userID); isLoading = false }
    }
}

private struct ShotErrorMessage: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        if let error = store.shot.errorMessage { Text(error).font(.footnote).foregroundStyle(FYColor.muted) }
    }
}
