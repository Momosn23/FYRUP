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
                    Image(systemName: "bell").font(.title3).frame(width: 44, height: 44).background(.white, in: Circle())
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
            VStack(spacing: 6) {
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
                Divider()
                TodayWeekStrip()
                NavigationLink { WeeklyFlameDetailView() } label: {
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(FYColor.nutrition)
                        Text("Deine Streak").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(store.weekly.currentWeek.map { "\($0.progressText) Einheiten" } ?? "Wochenziel öffnen").font(.footnote).foregroundStyle(FYColor.muted)
                        Image(systemName: "chevron.right").font(.caption)
                    }.frame(minHeight: 44).foregroundStyle(FYColor.ink)
                }.accessibilityIdentifier("own-weekly-card")
            }.fyCard(padding: 12)
            TodaySupplementsSection()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    FYSectionHeader(title: "Deine Crew")
                    Spacer()
                    NavigationLink("Alle anzeigen") { FriendsView() }.font(.footnote.weight(.semibold)).foregroundStyle(FYColor.lime).frame(minHeight: 44).accessibilityIdentifier("open-crew")
                }
                if store.crew.isEmpty {
                    NavigationLink { FriendsView() } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Gemeinsam loslegen", systemImage: "person.2").font(.body.weight(.semibold))
                            Text("Finde Freunde oder teile deinen Einladungslink.").font(.footnote).foregroundStyle(FYColor.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).fyCard()
                    }.buttonStyle(.plain).accessibilityIdentifier("invite-first-friend")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) { ForEach(store.crew) { TodayCrewCard(member: $0) } }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                FYSectionHeader(title: "Heute für dich")
                if let live = store.myActivity, live.status == .live {
                    NavigationLink { LiveActivityView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: live.sport.symbol).font(.title2).foregroundStyle(FYColor.lime)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LIVE · \(live.sport.title)").font(.headline)
                                LiveActivityTimer(activity: live).font(.subheadline).foregroundStyle(FYColor.muted)
                            }
                            Spacer(); Text("ÖFFNEN").font(.footnote.bold())
                        }.foregroundStyle(FYColor.ink).fyCard()
                    }.buttonStyle(.plain).accessibilityIdentifier("open-live-activity")
                } else {
                    Button("JETZT LOS") { store.activityComposerMode = 0; store.showsActivityComposer = true }.buttonStyle(PrimaryButtonStyle())
                }
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

struct TodayWeekStrip: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = store.referenceDate ?? context.date
            HStack(spacing: 4) {
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
                        }.frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(FYColor.muted)
                    }.buttonStyle(.plain).accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(done ? "Abgeschlossen" : planned ? "Geplant" : "Offen")")
                        .accessibilityIdentifier("training-week-day-\(TrainingWeekLogic.weekday(day))")
                }
            }
        }
    }
}

private struct TodaySupplementsSection: View {
    @Environment(AppStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var contentWidth: CGFloat = 70
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                FYSectionHeader(title: "Supplements heute")
                Spacer()
                NavigationLink("Alle ansehen") { SupplementsView() }.font(.footnote.weight(.semibold)).foregroundStyle(FYColor.lime).frame(minHeight: 44).accessibilityIdentifier("open-supplements")
            }
            if let snapshot = store.supplements.snapshot, store.supplements.isCurrentDay, !snapshot.doses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.doses) { dose in
                            let plan = snapshot.plans.first { $0.id == dose.planID }
                            let name = plan?.name ?? "Supplement"
                            Button { Task { await store.supplements.mark(dose.id, as: dose.status == .taken ? .open : .taken) } } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: supplementSymbol(name)).font(.title3).foregroundStyle(FYColor.muted)
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
    private func supplementSymbol(_ name: String) -> String {
        // Decorative only; never infers intake time, amount or medical advice.
        switch name.lowercased().replacingOccurrences(of: " ", with: "") {
        case "vitamind", "vitamind3": "sun.max"
        case "magnesium": "moon"
        default: "pills.fill"
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
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
            Text(member.activity.map { [$0.sport.title, $0.displaySubtype].compactMap { $0 }.joined(separator: " · ") } ?? "Noch nichts geteilt")
                .font(.caption).foregroundStyle(FYColor.muted).lineLimit(2).frame(minHeight: 28)
            if let activity = member.activity {
                if activity.status == .live {
                    Button("MITZIEHEN 🔥") { joining = true }.font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("join-live-activity")
                } else if activity.status == .completed {
                    Button("Stark! 🙌") { Task { await store.react(activity, reaction: .applause) } }.font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                } else if let id = activity.plannedSessionID {
                    Button("MITMACHEN") { Task { await store.joinPlannedSession(id) } }.font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                }
            } else { Button("FYR UP 🔥") { Task { await store.fyrup(member) } }.font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44) }
        }.frame(width: contentWidth).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
            .fullScreenCover(isPresented: $joining) {
                if let activity = member.activity, let planID = activity.workoutPlanID {
                    NavigationStack { WorkoutPlanDetailView(planID: planID, linkedActivityID: activity.id)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { joining = false } } } }
                } else { ActivityComposerView(linkedActivityID: member.activity?.id) }
            }
    }
}
