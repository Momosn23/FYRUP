import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                crewStrip.fyEntrance(delay: 0.06)
                if let live = store.myActivity, live.status == .live {
                    NavigationLink { LiveActivityView() } label: {
                        LiveSessionVisual(activity: live, compact: true)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.right").foregroundStyle(.white).padding(20)
                            }
                    }.buttonStyle(FYPressStyle()).accessibilityLabel("ÖFFNEN").accessibilityIdentifier("open-live-activity")
                    if live.sport == .gym { WorkoutRestView(activityID: live.id, compact: true) }
                } else { startHero }
                if store.setup.value?.completed != true { PersonalSetupHomeCard() }
                TrainingWeekCard()
                if store.isRefreshing && store.crew.isEmpty && store.myActivity == nil {
                    FeedSkeleton()
                } else {
                    if let activity = store.myActivity, activity.status != .live { MyFeedCard(activity: activity) }
                    OwnWeeklyCard(compact: true)
                    OwnStepsCard()
                    ActiveEnergyCard()
                    BlindInboxCards()
                    ForEach(store.invitations.filter { $0.status == .pending }) { invitation in InvitationCard(invitation: invitation) }
                    Text("Deine Crew").font(.headline).padding(.top, 4)
                    ForEach(store.crew) { member in CrewFeedCard(member: member) }
                    if store.crew.isEmpty {
                        EmptyCrewCard { store.selectedTab = 1 }
                    }
                    SupplementHomeCard()
                    MotivationCard()
                    if !store.crew.isEmpty { NavigationLink { CrewGoalView() } label: { CrewGoalCard(summary: store.goals) }.buttonStyle(.plain).accessibilityIdentifier("crew-goal") }
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 80)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.myActivity?.status)
        }
        .background(FYColor.background)
        .refreshable { await store.refresh(); await store.personal.loadWeek(); await store.personal.loadRoutine(); await store.supplements.refresh(); await store.steps.refresh(force: true); await store.energy.refresh(force: true); await store.weekly.refresh(force: true); await store.weekly.refreshFriends(); await store.blind.refreshSummaries() }
        .navigationBarHidden(true)
        .task {
            await store.prepareNotificationRegistration()
            await store.supplements.refresh()
            await store.steps.refresh()
            await store.energy.refresh()
            await store.weekly.refresh()
            await store.weekly.refreshFriends()
            if !store.showsActivityComposer { await store.weekly.prepareCelebration() }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await store.refresh()
                await store.personal.loadWeek()
                await store.supplements.refresh()
                await store.steps.refresh()
                await store.energy.refresh()
                await store.weekly.refresh()
                await store.weekly.refreshFriends()
                await store.blind.refreshSummaries()
            }
        }
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(HomePresentation.greeting(at: context.date)).font(.caption).foregroundStyle(FYColor.muted).accessibilityIdentifier("home-greeting")
                Text("\(store.profile?.displayName.components(separatedBy: " ").first ?? "Du") 👋").font(.title2.weight(.black))
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.caption2).foregroundStyle(FYColor.muted)
            }
            Spacer()
            Button { store.activityComposerMode = 0; store.showsActivityComposer = true } label: { Image(systemName: "plus").font(.headline).frame(width: 36, height: 36).background(FYColor.elevated, in: Circle()).overlay(Circle().stroke(FYColor.line)) }
            NavigationLink { NotificationCenterView() } label: {
                Image(systemName: "bell").font(.headline).frame(width: 36, height: 36)
                    .overlay(alignment: .topTrailing) { if store.notifications.contains(where: { $0.readAt == nil }) { Circle().fill(FYColor.coral).frame(width: 7, height: 7).offset(x: -4, y: 5) } }
            }.accessibilityLabel("Mitteilungen")
            if let profile = store.profile { AvatarView(profile: profile).scaleEffect(0.78).frame(width: 38, height: 38) }
        }.foregroundStyle(FYColor.ink)
        }
    }

    private var startHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DEIN TAG. DEIN TEMPO.").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.9))
            Text("Gemeinsam\nweiterkommen.").font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(.white)
            HStack(spacing: 10) {
                Button("JETZT LOS") { store.activityComposerMode = 0; store.showsActivityComposer = true }.buttonStyle(PrimaryButtonStyle())
                Button("FÜR SPÄTER PLANEN") { store.activityComposerMode = 1; store.showsActivityComposer = true }
                    .font(.caption2.bold()).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.35)))
                    .buttonStyle(FYPressStyle())
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                SportPhoto(sport: store.profile?.sports.first ?? .running)
                    .overlay(LinearGradient(colors: [.black.opacity(0.68), .black.opacity(0.28)], startPoint: .leading, endPoint: .trailing))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: FYColor.ink.opacity(0.12), radius: 16, y: 6).fyEntrance(delay: 0.1)
            .accessibilityIdentifier("home-start-hero")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .opacity(pulses && !reduceMotion ? 0.46 : 0.85)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulses)
        .onAppear { pulses = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduced in pulses = !reduced }
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
                            if activity.status == .live { LiveActivityTimer(activity: activity).font(.caption).foregroundStyle(FYColor.live) }
                            else if let plannedAt = activity.plannedAt { Text("· \(plannedAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(FYColor.muted) }
                        }
                    } else {
                        Text("Noch nichts geplant").font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                }
                Spacer()
                if let activity, activity.status == .live { NavigationLink { LiveActivityView() } label: { Image(systemName: "flame.fill").foregroundStyle(FYColor.coral) }.accessibilityLabel("ÖFFNEN").accessibilityIdentifier("open-live-activity") }
                else if let activity, let sessionID = activity.plannedSessionID, let hosted = store.hostedSessions.first(where: { $0.id == sessionID }) { NavigationLink { HostedSessionView(hosted: hosted) } label: { Image(systemName: "chevron.right.circle.fill").foregroundStyle(FYColor.planned) }.accessibilityLabel("SESSION ÖFFNEN") }
                else if activity != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime) }
            }
            if activity == nil {
                HStack(spacing: 10) {
                    Button("JETZT LOS") { store.activityComposerMode = 0; store.showsActivityComposer = true }.buttonStyle(HomeActionStyle(primary: true))
                    Button("FÜR SPÄTER PLANEN") { store.activityComposerMode = 1; store.showsActivityComposer = true }.buttonStyle(HomeActionStyle(primary: false))
                }
            } else if let activity, [.planned, .ready].contains(activity.status), let sessionID = activity.plannedSessionID, let hosted = store.hostedSessions.first(where: { $0.id == sessionID }) {
                NavigationLink { HostedSessionView(hosted: hosted) } label: { Text("SESSION ÖFFNEN") }.buttonStyle(SecondaryButtonStyle())
            }
        }.fyCard()
    }
    private func todayStatus(_ activity: Activity) -> TodayStatus { activity.status == .live ? .live : activity.status == .completed ? .done : .planned }
    private func activityTitle(_ activity: Activity) -> String { [activity.sport.title, activity.displaySubtype].compactMap { $0 }.joined(separator: " · ") }
}

private struct HomeActionStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
            .foregroundStyle(primary ? .white : FYColor.ink)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(primary ? FYColor.lime.opacity(configuration.isPressed ? 0.75 : 1) : .white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primary ? FYColor.lime : FYColor.line))
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
                Text("Finde Freunde und sieh, wer heute aktiv ist.").font(.caption).foregroundStyle(FYColor.muted)
            }
            Spacer(minLength: 4)
            Button(action: action) { Image(systemName: "plus").font(.headline).frame(width: 36, height: 36).background(.white, in: Circle()).foregroundStyle(.black) }
                .accessibilityLabel("Freund hinzufügen")
        }.fyCard()
    }
}

private struct InvitationCard: View {
    let invitation: SessionInvitation
    var body: some View {
        NavigationLink { InvitationDetailView(invitation: invitation) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "envelope.badge.fill").foregroundStyle(FYColor.lime); Text("Einladung von \(invitation.host.displayName)").font(.headline); Spacer(); Image(systemName: "chevron.right").foregroundStyle(FYColor.muted) }
                HStack { Image(systemName: invitation.session.sport.symbol).foregroundStyle(invitation.session.sport.accentColor); Text(invitation.session.sport.title).bold(); if let subtype = invitation.session.displaySubtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
                Text(invitation.session.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(FYColor.muted)
            }.fyCard().foregroundStyle(FYColor.ink)
        }.buttonStyle(.plain).accessibilityIdentifier("session-invitation")
    }
}

struct InvitationDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let invitation: SessionInvitation

    var body: some View {
        Group {
            if store.revokedFriendIDs.contains(invitation.host.id) {
                ContentUnavailableView("Einladung nicht mehr verfügbar", systemImage: "lock", description: Text("Ihr seid nicht mehr verbunden."))
            } else { invitationContent }
        }
    }

    private var invitationContent: some View {
        ScrollView { VStack(spacing: 18) {
            Spacer()
            AvatarView(profile: invitation.host).scaleEffect(1.7).padding(24)
            Text("\(invitation.host.displayName) lädt dich zu\neiner Session ein!").font(.title2.weight(.black)).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 9) {
                Label([invitation.session.sport.title, invitation.session.displaySubtype].compactMap { $0 }.joined(separator: " · "), systemImage: invitation.session.sport.symbol).font(.headline)
                Text(invitation.session.startsAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(FYColor.muted)
                if let duration = invitation.session.durationMinutes { Text("ca. \(duration) Minuten").foregroundStyle(FYColor.muted) }
                if let place = invitation.session.placeName { Text(place).foregroundStyle(FYColor.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading).fyCard()
            if let planID = invitation.session.workoutPlanID {
                NavigationLink { WorkoutPlanDetailView(planID: planID, sessionID: invitation.sessionID, allowsStarting: false) } label: {
                    Label("Vollständigen Workout-Plan ansehen", systemImage: "list.bullet.rectangle")
                }.buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("invitation-workout-plan")
                Text("Sieh dir vor deiner Antwort alle Übungen und Vorgaben an.").font(.caption).foregroundStyle(FYColor.muted)
            }
            Button("✓ Dabei") { Task { await store.respond(to: invitation, status: .accepted); if store.errorMessage == nil { dismiss() } } }.buttonStyle(PrimaryButtonStyle()).disabled(store.isBusy)
            Button("🤔 Vielleicht") { Task { await store.respond(to: invitation, status: .maybe); if store.errorMessage == nil { dismiss() } } }.buttonStyle(OutlineButtonStyle()).disabled(store.isBusy)
            Button("✕ Kann nicht") { Task { await store.respond(to: invitation, status: .declined); if store.errorMessage == nil { dismiss() } } }.buttonStyle(OutlineButtonStyle()).disabled(store.isBusy)
            Spacer()
        }.padding(22) }.background(FYColor.background).navigationBarTitleDisplayMode(.inline)
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
                    Text([activity.sport.title, activity.displaySubtype].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(FYColor.muted)
                    HStack(spacing: 5) {
                        StatusBadge(status: member.todayStatus)
                        if activity.status == .live { LiveActivityTimer(activity: activity).font(.caption).foregroundStyle(FYColor.live) }
                        else if let time = activity.plannedAt { Text("· \(time.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(FYColor.muted) }
                    }
                    NavigationLink { ActivityDetailView(activity: activity, owner: member.profile) } label: { Text("Details").font(.caption2).foregroundStyle(FYColor.cyan) }
                } else { Text("Noch nichts heute").font(.caption).foregroundStyle(FYColor.muted) }
                FriendStepsLine(userID: member.id)
                FriendWeeklyLine(userID: member.id)
            }
            Spacer()
            action
        }.fyCard().fullScreenCover(isPresented: $showJoin) {
            if let activity = member.activity, let planID = activity.workoutPlanID {
                NavigationStack {
                    WorkoutPlanDetailView(planID: planID, linkedActivityID: activity.id)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { showJoin = false } } }
                }
            } else { ActivityComposerView(linkedActivityID: member.activity?.id) }
        }
    }
    @ViewBuilder private var action: some View {
        if let activity = member.activity, activity.status == .live {
            Button("MITZIEHEN 🔥") { showJoin = true }.font(.caption2.bold()).foregroundStyle(FYColor.ink).padding(.horizontal, 10).padding(.vertical, 12).background(.white, in: Capsule()).accessibilityIdentifier("join-live-activity")
        } else if let activity = member.activity, activity.status == .completed {
            HStack(spacing: 5) {
                ForEach(ReactionKind.allCases, id: \.rawValue) { reaction in
                    Button(reaction.rawValue) { Task { await store.react(activity, reaction: reaction) } }
                        .font(.body).accessibilityLabel("Mit \(reaction.rawValue) reagieren")
                }
            }
        } else if let sessionID = member.activity?.plannedSessionID {
            Button("MITMACHEN") { Task { await store.joinPlannedSession(sessionID) } }.font(.caption2.bold()).foregroundStyle(FYColor.ink).padding(.horizontal, 10).padding(.vertical, 12).background(.white, in: Capsule())
        } else { Button("FYR UP 🔥") { Task { await store.fyrup(member) } }.font(.caption.bold()).foregroundStyle(FYColor.coral) }
    }
}

struct LiveTimer: View {
    let start: Date
    var body: some View { TimelineView(.periodic(from: .now, by: 1)) { context in Text(Self.format(context.date.timeIntervalSince(start))).fontDesign(.monospaced).fontWeight(.bold).monospacedDigit().contentTransition(.numericText()) } }
    // Pure value formatting has no UI state and is also used by non-UI tests.
    nonisolated static func format(_ interval: TimeInterval) -> String { let seconds = max(0, Int(interval)); return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
}

struct LiveActivityTimer: View {
    let activity: Activity
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(LiveTimer.format(activity.duration(at: context.date) ?? 0))
                .fontDesign(.monospaced).fontWeight(.bold).monospacedDigit()
                .accessibilityLabel(activity.pausedAt == nil ? "Aktive Zeit" : "Aktive Zeit, pausiert")
        }
    }
}

private struct MotivationCard: View {
    var body: some View { Text("„Gemeinsam stärker.\nHeute zählt.“").font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity).foregroundStyle(FYColor.ink.opacity(0.82)).fyCard() }
}

private struct CrewGoalCard: View {
    let summary: GoalSummary
    var body: some View { VStack(alignment: .leading, spacing: 9) { HStack { Text("UNSER CREW-ZIEL").font(.caption.weight(.black)); Spacer(); Text("\(summary.crewCount) / \(summary.crewTarget)").bold() }; ProgressView(value: Double(summary.crewCount), total: Double(max(summary.crewTarget, 1))).tint(FYColor.lime); HStack { Text("Gemeinsam diese Woche").font(.caption).foregroundStyle(FYColor.muted); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted) } }.fyCard() }
}

struct CrewGoalView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Unsere Crew").font(.largeTitle.weight(.black))
                Text("Gemeinsam \(store.goals.crewTarget) Einheiten diese Woche.").foregroundStyle(FYColor.muted)
                VStack(spacing: 12) {
                    ProgressView(value: Double(store.goals.crewCount), total: Double(max(store.goals.crewTarget, 1))).tint(FYColor.lime).scaleEffect(x: 1, y: 2)
                    HStack { Spacer(); Text("\(store.goals.crewCount) / \(store.goals.crewTarget)").font(.title3.bold()) }
                }.fyCard()
                ForEach(store.crew) { member in
                    HStack(spacing: 12) {
                        AvatarView(profile: member.profile)
                        Text(member.profile.displayName).font(.headline)
                        Spacer()
                        Text("\(member.weeklyCount)").font(.headline).foregroundStyle(FYColor.lime)
                    }.fyCard()
                }
                Text("Noch \(max(0, store.goals.crewTarget - store.goals.crewCount)) bis zum Crew-Ziel! 💪")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(FYColor.ink).frame(maxWidth: .infinity).fyCard()
            }.padding(18)
        }.background(FYColor.background).navigationTitle("Crew-Ziel").navigationBarTitleDisplayMode(.inline)
    }
}
