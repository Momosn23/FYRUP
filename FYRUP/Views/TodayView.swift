import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).foregroundStyle(FYColor.muted).textCase(.uppercase)
                HStack { Text("HEUTE 🔥").font(.system(size: 36, weight: .black)); Spacer(); NavigationLink { NotificationCenterView() } label: { Image(systemName: "bell.fill").font(.title3).overlay(alignment: .topTrailing) { if store.notifications.contains(where: { $0.readAt == nil }) { Circle().fill(FYColor.lime).frame(width: 8, height: 8) } } }.accessibilityLabel("Mitteilungen") }
                MyStatusCard(activity: store.myActivity)
                ForEach(store.invitations.filter { $0.status == .pending }) { invitation in InvitationCard(invitation: invitation) }
                CrewGoalCard(summary: store.goals)
                Text("DEINE CREW").font(.headline.weight(.black)).padding(.top, 6)
                if store.crew.isEmpty {
                    ContentUnavailableView("Deine Crew ist noch leer", systemImage: "person.2", description: Text("Füge Freunde hinzu und bewegt euch gemeinsam."))
                    Button("FREUND HINZUFÜGEN") { store.selectedTab = 1 }.buttonStyle(SecondaryButtonStyle())
                } else {
                    ForEach(store.crew) { member in CrewCard(member: member) }
                }
            }.padding(20)
        }.background(FYColor.background).refreshable { await store.refresh() }.navigationBarHidden(true)
    }
}

private struct InvitationCard: View {
    @Environment(AppStore.self) private var store
    let invitation: SessionInvitation
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("\(invitation.host.displayName) geht trainieren. You in?").font(.headline)
            HStack { Image(systemName: invitation.session.sport.symbol).foregroundStyle(FYColor.lime); Text(invitation.session.sport.title).bold(); if let subtype = invitation.session.subtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
            Text(invitation.session.startsAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(FYColor.muted)
            HStack {
                Button("✓ Dabei") { Task { await store.respond(to: invitation, status: .accepted) } }.buttonStyle(PrimaryButtonStyle())
                Menu("Antwort") { Button("Vielleicht") { Task { await store.respond(to: invitation, status: .maybe) } }; Button("Kann nicht") { Task { await store.respond(to: invitation, status: .declined) } } }.buttonStyle(SecondaryButtonStyle())
            }
        }.fyCard()
    }
}

private struct MyStatusCard: View {
    @Environment(AppStore.self) private var store
    let activity: Activity?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DU").font(.caption.weight(.black)).foregroundStyle(FYColor.muted)
            if let activity {
                StatusBadge(status: activity.status == .live ? .live : activity.status == .completed ? .done : .planned)
                ActivityLabel(activity: activity)
                if activity.status == .live { LiveTimer(start: activity.startedAt ?? .now); NavigationLink("TRAINING ÖFFNEN") { LiveActivityView() }.buttonStyle(PrimaryButtonStyle()) }
                else if [.planned, .ready].contains(activity.status), let date = activity.plannedAt {
                    Text(date.formatted(date: .omitted, time: .shortened)).foregroundStyle(FYColor.muted)
                    Button("TRAINING STARTEN") { Task { await store.start(sport: activity.sport, subtype: activity.subtype, plannedSessionID: activity.plannedSessionID) } }.buttonStyle(PrimaryButtonStyle())
                    if let sessionID = activity.plannedSessionID { Button("Training absagen") { Task { await store.cancelPlannedSession(sessionID) } }.font(.footnote).foregroundStyle(FYColor.muted) }
                }
                else if activity.status == .completed { Text("Heute geschafft ✓").foregroundStyle(FYColor.muted) }
            } else {
                StatusBadge(status: .notYet)
                Text("Noch nichts geplant").font(.title2.bold())
                HStack { Button("JETZT LOS") { store.showsActivityComposer = true }.buttonStyle(PrimaryButtonStyle()); Button("PLANEN") { store.showsActivityComposer = true }.buttonStyle(SecondaryButtonStyle()) }
            }
        }.fyCard()
    }
}

private struct CrewCard: View {
    @Environment(AppStore.self) private var store
    let member: CrewMember
    @State private var showJoin = false
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { AvatarView(profile: member.profile); VStack(alignment: .leading) { Text(member.profile.displayName).font(.headline); Text("@\(member.profile.username)").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); StatusBadge(status: member.todayStatus) }
            if let activity = member.activity {
                ActivityLabel(activity: activity)
                if activity.status == .live { LiveTimer(start: activity.startedAt ?? .now).font(.subheadline).foregroundStyle(FYColor.muted); Button("MITZIEHEN 🔥") { showJoin = true }.buttonStyle(PrimaryButtonStyle()) }
                else if [.planned, .ready].contains(activity.status), let date = activity.plannedAt { Text(date.formatted(date: .omitted, time: .shortened)).foregroundStyle(FYColor.muted); if let sessionID = activity.plannedSessionID { Button("MITMACHEN") { Task { await store.joinPlannedSession(sessionID) } }.buttonStyle(SecondaryButtonStyle()) } }
                else if activity.status == .completed {
                    HStack { ForEach(ReactionKind.allCases, id: \.rawValue) { reaction in Button(reaction.rawValue) { Task { await store.react(activity, reaction: reaction) } }.buttonStyle(.plain).font(.title2) }; Menu { Button("Reaktion entfernen") { Task { await store.react(activity, reaction: nil) } } } label: { Image(systemName: "ellipsis.circle").foregroundStyle(FYColor.muted) } }
                }
            } else { Button("FYR UP 🔥") { Task { await store.fyrup(member) } }.buttonStyle(SecondaryButtonStyle()) }
            Text("\(member.weeklyCount) Trainings diese Woche").font(.caption).foregroundStyle(FYColor.muted)
        }.fyCard().sheet(isPresented: $showJoin) { ActivityComposerView(linkedActivityID: member.activity?.id) }
    }
}

struct LiveTimer: View {
    let start: Date
    var body: some View { TimelineView(.periodic(from: .now, by: 1)) { context in Text(Self.format(context.date.timeIntervalSince(start))).font(.system(.title2, design: .monospaced).weight(.bold)).contentTransition(.numericText()) } }
    static func format(_ interval: TimeInterval) -> String { let seconds = max(0, Int(interval)); return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
}

private struct CrewGoalCard: View {
    let summary: GoalSummary
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Text("CREW GOAL").font(.caption.weight(.black)); Spacer(); Text("\(summary.crewCount) / \(summary.crewTarget)").bold() }; ProgressView(value: Double(summary.crewCount), total: Double(summary.crewTarget)).tint(FYColor.lime); Text("Gemeinsam diese Woche").font(.caption).foregroundStyle(FYColor.muted) }.fyCard() }
}
