import SwiftUI

struct TodayDashboardContent: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
            HStack {
                FYRUPWordmark(size: 23)
                Spacer()
                NavigationLink { NotificationCenterView() } label: {
                    Image(systemName: "bell").font(.title3).frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if store.notifications.contains(where: { $0.readAt == nil }) { Circle().fill(FYColor.lime).frame(width: 7, height: 7).padding(6) }
                        }
                }.accessibilityLabel("Mitteilungen")
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let date = store.referenceDate ?? context.date
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HomePresentation.greeting(at: date)).font(.subheadline).foregroundStyle(FYColor.muted).accessibilityIdentifier("home-greeting")
                        Text(store.profile?.displayName ?? "Heute").font(.title.bold()).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    WeatherDateCard(date: date)
                }
            }
            }
            VStack(spacing: 10) {
                let metricLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                metricLayout {
                    NavigationLink { StepSettingsView() } label: {
                        metric(value: store.steps.todaysSteps.map(StepCountFormat.string), goal: store.steps.goal.map(StepCountFormat.string),
                               title: "Schritte heute", detail: stepDetail, symbol: "shoeprints.fill", progress: store.steps.progress, accent: FYColor.lime)
                    }.buttonStyle(.plain).accessibilityIdentifier("own-steps-card")
                    NavigationLink { NutritionView() } label: {
                        let value = NutritionDayPresentation(diary: store.nutrition.diary, day: StepDay.key(for: store.presentationDate))
                        metric(value: value.calories.map { Int($0.rounded()).formatted() }, goal: value.goal?.formatted(),
                               title: "Kalorien heute", detail: value.remaining,
                               symbol: "flame.fill", progress: value.progress, accent: FYColor.nutrition)
                    }.buttonStyle(.plain).accessibilityIdentifier("home-nutrition-card")
                }
                Divider().overlay(FYColor.line)
                TodayWeekStrip()
                NavigationLink { WeeklyFlameDetailView() } label: {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        Label { Text("Deine Streak").font(.subheadline.weight(.semibold)) }
                            icon: { Image(systemName: "flame.fill").foregroundStyle(FYColor.nutrition) }
                        if !typeSize.isAccessibilitySize { Spacer() }
                        Text(store.weekly.currentWeek.map { "\($0.progressText) Einheiten" } ?? "Wochenziel öffnen").font(.footnote).foregroundStyle(FYColor.muted)
                        if !typeSize.isAccessibilitySize { Image(systemName: "chevron.right").font(.caption) }
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).foregroundStyle(FYColor.ink)
                }.accessibilityIdentifier("own-weekly-card")
            }.padding(.vertical, 8)
            TodayWorkoutFeature()
            TodaySupplementsSection()
            VStack(alignment: .leading, spacing: 8) {
                let headerLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
                headerLayout {
                    FYSectionHeader(title: "Deine Crew")
                    if !typeSize.isAccessibilitySize { Spacer() }
                    NavigationLink { FriendsView() } label: {
                        Text("Alle anzeigen").font(.footnote.weight(.semibold)).frame(minHeight: 44).contentShape(Rectangle())
                    }.foregroundStyle(FYColor.lime).accessibilityIdentifier("open-crew")
                }
                if store.crew.isEmpty {
                    NavigationLink { FriendsView() } label: {
                        ZStack(alignment: .bottomLeading) {
                            Image("FriendsCrewHero")
                                .resizable().scaledToFill().frame(height: 142).clipped()
                            LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gemeinsam loslegen").font(.headline)
                                Text("Finde Freunde oder teile deinen Einladungslink.").font(.footnote)
                            }.foregroundStyle(.white).padding(14)
                        }
                        .frame(maxWidth: .infinity, minHeight: 142)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }.buttonStyle(.plain).accessibilityIdentifier("invite-first-friend")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) { ForEach(store.crew) { TodayCrewCard(member: $0) } }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                FYSectionHeader(title: "Mehr für dich")
                NavigationLink { WorkoutPlansView() } label: { destination("Workout-Pläne", symbol: "dumbbell") }
                if store.nutrition.diary?.goal != nil { NavigationLink { NutritionView() } label: { destination("Ernährung", symbol: "fork.knife") } }
                NavigationLink { SupplementsView() } label: { destination("Supplements", symbol: "pills") }
                if store.setup.value?.completed != true { PersonalSetupHomeCard() }
                if !store.crew.isEmpty { NavigationLink { CrewGoalView() } label: { destination("Crew-Ziel", symbol: "person.3") }.accessibilityIdentifier("crew-goal") }
            }
        }
    }
    private var stepDetail: String {
        guard let count = store.steps.todaysSteps else { return store.steps.healthRequested ? "Keine Daten verfügbar" : "Einrichten" }
        guard let goal = store.steps.goal else { return "Ziel auswählen" }
        return count >= goal ? "Ziel erreicht" : "Noch \(StepCountFormat.string(goal - count)) Schritte"
    }
    private func metric(value: String?, goal: String?, title: String, detail: String, symbol: String, progress: Double?, accent: Color) -> some View {
        VStack(spacing: 4) {
            FYProgressRing(progress: progress, symbol: symbol, accent: accent, diameter: typeSize.isAccessibilitySize ? 64 : 52)
            Text(value ?? "–").font(.headline) + Text(goal.map { " / \($0)" } ?? "").font(.subheadline).foregroundColor(FYColor.muted)
            Text(title).font(.caption).foregroundStyle(FYColor.muted)
            Text(detail).font(.caption).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(FYColor.ink).frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }
    private func destination(_ title: String, symbol: String) -> some View {
        HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").font(.caption) }
            .foregroundStyle(FYColor.ink).padding(.vertical, 12)
    }
}

private struct TodayWorkoutFeature: View {
    @Environment(AppStore.self) private var store

    private var nextSession: PlannedSession? {
        store.personal.week?.sessions
            .filter { ["planned", "ready"].contains($0.status) && $0.startsAt >= store.presentationDate.addingTimeInterval(-3600) }
            .sorted { $0.startsAt < $1.startsAt }.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FYSectionHeader(title: store.myActivity?.status == .live ? "Dein Workout" : "Dein nächstes Workout")
            if let live = store.myActivity, live.status == .live {
                NavigationLink { LiveActivityView() } label: {
                    photoCard(sport: live.sport,
                              eyebrow: "LIVE · \(live.sport.title)",
                              title: live.displaySubtype ?? live.sport.title,
                              detail: nil,
                              action: "ÖFFNEN") {
                        AnyView(LiveActivityTimer(activity: live).font(.subheadline.bold()).monospacedDigit())
                    }
                }
                .buttonStyle(FYPressStyle()).accessibilityIdentifier("open-live-activity")
            } else if let session = nextSession, let hosted = store.hostedSessions.first(where: { $0.id == session.id }) {
                NavigationLink { HostedSessionView(hosted: hosted) } label: {
                    photoCard(sport: session.sport,
                              eyebrow: "PLANNED · \(session.startsAt.formatted(date: .abbreviated, time: .shortened))",
                              title: session.displaySubtype ?? session.sport.title,
                              detail: session.placeName,
                              action: "SESSION ÖFFNEN") { AnyView(EmptyView()) }
                }
                .buttonStyle(FYPressStyle()).accessibilityLabel("SESSION ÖFFNEN")
            } else if let session = nextSession {
                Button {
                    store.selectedWeekDate = session.startsAt
                    store.selectedTab = 1
                } label: {
                    photoCard(sport: session.sport,
                              eyebrow: "PLANNED · \(session.startsAt.formatted(date: .abbreviated, time: .shortened))",
                              title: session.displaySubtype ?? session.sport.title,
                              detail: session.placeName,
                              action: "SESSION ÖFFNEN") { AnyView(EmptyView()) }
                }
                .buttonStyle(FYPressStyle()).accessibilityLabel("SESSION ÖFFNEN")
            } else {
                Button {
                    store.activityComposerMode = 0
                    store.showsActivityComposer = true
                } label: {
                    photoCard(sport: .gym,
                              eyebrow: "DEIN MOMENT",
                              title: "Wähle dein nächstes Workout",
                              detail: "Workout-Plan oder freies Workout",
                              action: "JETZT LOS") { AnyView(EmptyView()) }
                }
                .buttonStyle(FYPressStyle()).accessibilityLabel("JETZT LOS")
            }
        }
    }

    private func photoCard<Trailing: View>(sport: SportKind, eyebrow: String, title: String, detail: String?, action: String,
                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        ZStack(alignment: .bottomLeading) {
            SportPhoto(sport: sport)
            LinearGradient(colors: [.black.opacity(0.04), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(eyebrow).font(.caption.weight(.heavy)).tracking(0.5)
                    Spacer()
                    trailing()
                }
                Text(title).font(.title2.weight(.black)).fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty { Text(detail).font(.footnote).opacity(0.86) }
                HStack {
                    Text(action).font(.subheadline.bold())
                    Image(systemName: "arrow.right").font(.caption.bold())
                }.padding(.top, 3)
            }.foregroundStyle(.white).padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 218)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(FYColor.line, lineWidth: 0.6))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TodayWeekStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = store.referenceDate ?? context.date
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: typeSize.isAccessibilitySize ? 3 : 7), spacing: 8) {
                ForEach(TrainingWeekLogic.days(containing: date), id: \.self) { day in
                    let done = store.profile.map { TrainingWeekLogic.completed(store.personal.week?.activities ?? [], owner: $0.id, day: day).count > 0 } ?? false
                    let planned = store.personal.week?.sessions.contains { Calendar.current.isDate($0.startsAt, inSameDayAs: day) } == true
                    let today = Calendar.current.isDate(day, inSameDayAs: date)
                    Button { store.selectedWeekDate = day; store.selectedTab = 1 } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption)
                            Image(systemName: done ? "checkmark.circle.fill" : planned ? "clock" : "circle")
                                .font(.body).foregroundStyle(done ? FYColor.lime : FYColor.line)
                                .padding(3).overlay(Circle().stroke(today ? FYColor.lime : .clear, lineWidth: 1.5))
                        }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()).foregroundStyle(FYColor.muted)
                    }.buttonStyle(.plain).accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(done ? "Abgeschlossen" : planned ? "Geplant" : "Offen")")
                        .accessibilityIdentifier("training-week-day-\(TrainingWeekLogic.weekday(day))")
                }
            }
        }
    }
}

private struct TodaySupplementsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var contentWidth: CGFloat = 70
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let headerLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
            headerLayout {
                FYSectionHeader(title: "Supplements heute")
                if !typeSize.isAccessibilitySize { Spacer() }
                NavigationLink { SupplementsView() } label: {
                    Text("Alle ansehen").font(.footnote.weight(.semibold)).frame(minHeight: 44).contentShape(Rectangle())
                }.foregroundStyle(FYColor.lime).accessibilityIdentifier("open-supplements")
            }
            if let snapshot = store.supplements.snapshot, store.supplements.isCurrentDay, !snapshot.doses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.doses) { dose in
                            let plan = snapshot.plans.first { $0.id == dose.planID }
                            let name = plan?.name ?? "Supplement"
                            Button { Task { await store.supplements.mark(dose.id, as: dose.status == .taken ? .open : .taken) } } label: {
                                VStack(spacing: 5) {
                                    Image("SupplementsHero").resizable().scaledToFill().frame(width: 42, height: 34).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).accessibilityHidden(true)
                                    Text(name).font(.caption.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                    if let amount = plan?.amount { Text(amount.title).font(.caption).foregroundStyle(FYColor.muted).fixedSize(horizontal: false, vertical: true) }
                                    Image(systemName: dose.status == .taken ? "checkmark.circle.fill" : "circle").font(.body).foregroundStyle(dose.status == .taken ? FYColor.lime : FYColor.line)
                                }.frame(width: contentWidth).padding(.horizontal, 5).padding(.vertical, 8).background(.white, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(FYPressStyle()).foregroundStyle(FYColor.ink)
                                .disabled(store.supplements.changesDisabled || store.supplements.pending.contains { $0.doseID == dose.id })
                                .accessibilityLabel("\(name), \(dose.status.title)").accessibilityHint(dose.status == .taken ? "Einnahme rückgängig machen" : "Als genommen markieren")
                                .accessibilityIdentifier("supplement-taken-\(dose.id)")
                        }
                    }
                }
            } else {
                NavigationLink { SupplementsView() } label: {
                    HStack {
                        Image(systemName: "pills").foregroundStyle(FYColor.lime)
                        Text(store.supplements.snapshot?.plans.isEmpty == false ? "Heute keine offenen Einträge" : "Bei Bedarf eigene Supplements einrichten").font(.subheadline)
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.foregroundStyle(FYColor.ink).fyCard()
                }.buttonStyle(.plain)
            }
        }
    }
}

private struct TodayCrewCard: View {
    @Environment(AppStore.self) private var store
    let member: CrewMember
    @State private var joining = false
    @ScaledMetric(relativeTo: .body) private var contentWidth: CGFloat = 90
    var body: some View {
        VStack(spacing: 4) {
            NavigationLink { FriendProfileView(member: member) } label: {
                HStack(spacing: 6) {
                    AvatarView(profile: member.profile, size: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(member.profile.displayName).font(.footnote.bold()).lineLimit(2)
                        if member.todayStatus == .live { Text("LIVE").font(.caption2.bold()).foregroundStyle(FYColor.lime) }
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Text(member.activity.map { [$0.sport.title, $0.displaySubtype].compactMap { $0 }.joined(separator: " · ") } ?? "Noch nichts geteilt")
                .font(.caption).foregroundStyle(FYColor.muted).lineLimit(2).frame(minHeight: 28)
            if let activity = member.activity {
                if activity.status == .live {
                    Button { joining = true } label: { actionLabel("MITZIEHEN 🔥") }.accessibilityIdentifier("join-live-activity")
                } else if activity.status == .completed {
                    Button { Task { await store.react(activity, reaction: .applause) } } label: { actionLabel("Stark! 🙌") }
                } else if let id = activity.plannedSessionID {
                    Button { Task { await store.joinPlannedSession(id) } } label: { actionLabel("MITMACHEN") }
                }
            } else { Button { Task { await store.fyrup(member) } } label: { actionLabel("FYR UP 🔥") } }
        }.frame(width: contentWidth).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .fullScreenCover(isPresented: $joining) {
                if let activity = member.activity, let planID = activity.workoutPlanID {
                    NavigationStack { WorkoutPlanDetailView(planID: planID, linkedActivityID: activity.id)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { joining = false } } } }
                } else { ActivityComposerView(linkedActivityID: member.activity?.id) }
            }
    }
    private func actionLabel(_ title: String) -> some View {
        Text(title).font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
    }
}
