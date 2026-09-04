import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                crewStrip
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.caption).foregroundStyle(FYColor.muted)
                    Text("Heute").font(.title2.weight(.bold))
                }.padding(.top, 4)
                if store.isRefreshing && store.crew.isEmpty && store.myActivity == nil {
                    FeedSkeleton()
                } else {
                    MyFeedCard(activity: store.myActivity)
                    ForEach(store.invitations.filter { $0.status == .pending }) { invitation in InvitationCard(invitation: invitation) }
                    ForEach(store.crew) { member in CrewFeedCard(member: member) }
                    if store.crew.isEmpty {
                        EmptyCrewCard { store.selectedTab = 2 }
                    }
                    MotivationCard()
                    if !store.crew.isEmpty { CrewGoalCard(summary: store.goals) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 24)
        }
        .background(FYColor.background)
        .refreshable { await store.refresh() }
        .navigationBarHidden(true)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await store.refresh()
            }
        }
    }

    private var header: some View {
        HStack {
            FYRUPWordmark(size: 27)
            Spacer()
            Button { store.activityComposerMode = 0; store.showsActivityComposer = true } label: { Image(systemName: "plus").font(.headline).frame(width: 36, height: 36).background(FYColor.elevated, in: Circle()).overlay(Circle().stroke(FYColor.line)) }
            NavigationLink { NotificationCenterView() } label: {
                Image(systemName: "bell").font(.headline).frame(width: 36, height: 36)
                    .overlay(alignment: .topTrailing) { if store.notifications.contains(where: { $0.readAt == nil }) { Circle().fill(FYColor.coral).frame(width: 7, height: 7).offset(x: -4, y: 5) } }
            }.accessibilityLabel("Mitteilungen")
        }.foregroundStyle(.white)
    }

    private var crewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                StoryAvatar(profile: store.profile, status: store.myActivity.map { $0.status == .live ? .live : $0.status == .completed ? .done : .planned } ?? .notYet, label: "Du")
                ForEach(store.crew) { member in StoryAvatar(profile: member.profile, status: member.todayStatus, label: member.profile.displayName.components(separatedBy: " ").first ?? member.profile.displayName) }
            }
        }
    }
}

private struct FeedSkeleton: View {
    @State private var pulses = false
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle().fill(FYColor.elevated).frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(FYColor.elevated).frame(width: index == 0 ? 92 : 128, height: 12)
                        Capsule().fill(FYColor.elevated).frame(maxWidth: index == 0 ? 180 : 220).frame(height: 10)
                    }
                    Spacer()
                }.fyCard()
            }
        }
        .opacity(pulses ? 0.46 : 0.85)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulses)
        .onAppear { pulses = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heute-Feed wird geladen")
    }
}

private struct StoryAvatar: View {
    let profile: Profile?
    let status: TodayStatus
    let label: String
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(ringColor, lineWidth: 2).frame(width: 52, height: 52)
                if let profile { AvatarView(profile: profile).scaleEffect(0.88) }
                else { Circle().fill(FYColor.elevated).frame(width: 46, height: 46).overlay(Image(systemName: "person.fill").foregroundStyle(FYColor.muted)) }
                Circle().fill(ringColor).frame(width: 12, height: 12).overlay(Image(systemName: status == .done ? "checkmark" : "flame.fill").font(.system(size: 7)).foregroundStyle(.black)).offset(x: 19, y: 19)
            }
            Text(label).font(.caption2).lineLimit(1).frame(width: 58)
        }
    }
    private var ringColor: Color { switch status { case .live: FYColor.live; case .planned: FYColor.planned; case .done: FYColor.lime; case .notYet: FYColor.muted } }
}

private struct MyFeedCard: View {
    @Environment(AppStore.self) private var store
    let activity: Activity?
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let profile = store.profile { AvatarView(profile: profile) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile?.displayName ?? "Du").font(.headline)
                    if let activity {
                        Text(activityTitle(activity)).font(.subheadline).foregroundStyle(FYColor.muted)
                        HStack(spacing: 5) {
                            StatusBadge(status: todayStatus(activity))
                            if activity.status == .live { LiveTimer(start: activity.startedAt ?? .now).font(.caption).foregroundStyle(FYColor.live) }
                            else if let plannedAt = activity.plannedAt { Text("· \(plannedAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(FYColor.muted) }
                        }
                    } else {
                        Text("Heute ist noch alles offen").font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                }
                Spacer()
                if let activity, activity.status == .live { NavigationLink { LiveActivityView() } label: { Image(systemName: "flame.fill").foregroundStyle(FYColor.coral) }.accessibilityLabel("TRAINING ÖFFNEN") }
                else if let activity, let sessionID = activity.plannedSessionID, let hosted = store.hostedSessions.first(where: { $0.id == sessionID }) { NavigationLink { HostedSessionView(hosted: hosted) } label: { Image(systemName: "chevron.right.circle.fill").foregroundStyle(FYColor.planned) }.accessibilityLabel("TRAINING ÖFFNEN") }
                else if activity != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime) }
            }
            if activity == nil {
                HStack(spacing: 10) {
                    Button("JETZT LOS") { store.activityComposerMode = 0; store.showsActivityComposer = true }.buttonStyle(HomeActionStyle(primary: true))
                    Button("FÜR SPÄTER PLANEN") { store.activityComposerMode = 1; store.showsActivityComposer = true }.buttonStyle(HomeActionStyle(primary: false))
                }
            } else if let activity, [.planned, .ready].contains(activity.status), let sessionID = activity.plannedSessionID, let hosted = store.hostedSessions.first(where: { $0.id == sessionID }) {
                NavigationLink { HostedSessionView(hosted: hosted) } label: { Text("TRAINING ÖFFNEN") }.buttonStyle(SecondaryButtonStyle())
            }
        }.fyCard()
    }
    private func todayStatus(_ activity: Activity) -> TodayStatus { activity.status == .live ? .live : activity.status == .completed ? .done : .planned }
    private func activityTitle(_ activity: Activity) -> String { [activity.sport.title, activity.subtype].compactMap { $0 }.joined(separator: " · ") }
}

private struct HomeActionStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
            .foregroundStyle(primary ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(primary ? .white.opacity(configuration.isPressed ? 0.75 : 1) : FYColor.elevated, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primary ? .clear : FYColor.line))
    }
}

private struct EmptyCrewCard: View {
    let action: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(FYColor.lime.opacity(0.12)).frame(width: 48, height: 48)
                Image(systemName: "person.2.fill").foregroundStyle(FYColor.lime)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Deine Crew ist noch leer").font(.subheadline.bold())
                Text("Finde Freunde und seht, wer heute durchzieht.").font(.caption).foregroundStyle(FYColor.muted)
            }
            Spacer(minLength: 4)
            Button(action: action) { Image(systemName: "plus").font(.headline).frame(width: 36, height: 36).background(.white, in: Circle()).foregroundStyle(.black) }
                .accessibilityLabel("Freund hinzufügen")
        }.fyCard()
    }
}

private struct InvitationCard: View {
    @Environment(AppStore.self) private var store
    let invitation: SessionInvitation
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "envelope.badge.fill").foregroundStyle(FYColor.violet); Text("Einladung von \(invitation.host.displayName)").font(.headline); Spacer() }
            HStack { Image(systemName: invitation.session.sport.symbol).foregroundStyle(invitation.session.sport.accentColor); Text(invitation.session.sport.title).bold(); if let subtype = invitation.session.subtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
            Text(invitation.session.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(FYColor.muted)
            HStack {
                Button("Ablehnen") { Task { await store.respond(to: invitation, status: .declined) } }.buttonStyle(SecondaryButtonStyle())
                Button("Vielleicht") { Task { await store.respond(to: invitation, status: .maybe) } }.buttonStyle(SecondaryButtonStyle())
                Button("Dabei") { Task { await store.respond(to: invitation, status: .accepted) } }.buttonStyle(PrimaryButtonStyle())
            }
        }.fyCard().overlay(alignment: .topTrailing) { Image(systemName: "flame.fill").foregroundStyle(FYColor.coral).padding(14) }
    }
}

private struct CrewFeedCard: View {
    @Environment(AppStore.self) private var store
    let member: CrewMember
    @State private var showJoin = false
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(profile: member.profile)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.profile.displayName).font(.headline)
                if let activity = member.activity {
                    Text([activity.sport.title, activity.subtype].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(FYColor.muted)
                    HStack(spacing: 5) {
                        StatusBadge(status: member.todayStatus)
                        if activity.status == .live { LiveTimer(start: activity.startedAt ?? .now).font(.caption).foregroundStyle(FYColor.live) }
                        else if let time = activity.plannedAt { Text("· \(time.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(FYColor.muted) }
                    }
                    NavigationLink { ActivityDetailView(activity: activity, owner: member.profile) } label: { Text("Details").font(.caption2).foregroundStyle(FYColor.cyan) }
                } else { Text("Noch nichts heute").font(.caption).foregroundStyle(FYColor.muted) }
            }
            Spacer()
            action
        }.fyCard().sheet(isPresented: $showJoin) { ActivityComposerView(linkedActivityID: member.activity?.id) }
    }
    @ViewBuilder private var action: some View {
        if let activity = member.activity, activity.status == .live {
            Button("Dabei?") { showJoin = true }.font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 14).padding(.vertical, 9).background(.white, in: Capsule())
        } else if let activity = member.activity, activity.status == .completed {
            HStack(spacing: 5) {
                ForEach(ReactionKind.allCases, id: \.rawValue) { reaction in
                    Button(reaction.rawValue) { Task { await store.react(activity, reaction: reaction) } }
                        .font(.body).accessibilityLabel("Mit \(reaction.rawValue) reagieren")
                }
            }
        } else if let sessionID = member.activity?.plannedSessionID {
            Button("Dabei?") { Task { await store.joinPlannedSession(sessionID) } }.font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 14).padding(.vertical, 9).background(.white, in: Capsule())
        } else { Button("FYR UP 🔥") { Task { await store.fyrup(member) } }.font(.caption.bold()).foregroundStyle(FYColor.coral) }
    }
}

struct LiveTimer: View {
    let start: Date
    var body: some View { TimelineView(.periodic(from: .now, by: 1)) { context in Text(Self.format(context.date.timeIntervalSince(start))).fontDesign(.monospaced).fontWeight(.bold).monospacedDigit().contentTransition(.numericText()) } }
    static func format(_ interval: TimeInterval) -> String { let seconds = max(0, Int(interval)); return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
}

private struct MotivationCard: View {
    var body: some View { Text("„Disziplin heute.\nEin besseres morgen.“").font(.subheadline).multilineTextAlignment(.center).frame(maxWidth: .infinity).foregroundStyle(.white.opacity(0.82)).fyCard() }
}

private struct CrewGoalCard: View {
    let summary: GoalSummary
    var body: some View { VStack(alignment: .leading, spacing: 9) { HStack { Text("CREW GOAL").font(.caption.weight(.black)); Spacer(); Text("\(summary.crewCount) / \(summary.crewTarget)").bold() }; ProgressView(value: Double(summary.crewCount), total: Double(summary.crewTarget)).tint(FYColor.lime); Text("Gemeinsam diese Woche").font(.caption).foregroundStyle(FYColor.muted) }.fyCard() }
}
