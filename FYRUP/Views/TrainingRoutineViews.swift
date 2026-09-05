import SwiftUI

struct TrainingRoutineEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOnboarding: Bool
    @State private var draft: TrainingRoutine?
    @State private var sport: SportKind = .gym
    @State private var hasEdits = false
    @State private var confirmsReload = false
    private let dayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isOnboarding {
                    Button { store.route = .weeklyGoalSetup } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }.accessibilityLabel("Zurück")
                    Text("Dein Trainingsrhythmus").font(.largeTitle.weight(.black))
                }
                Text("Was möchtest du diese Woche machen?").font(.title3.bold())
                Text("Laufen, Gym oder beides: Setze dir eigene Ziele. Feste Tage und Dauer sind freiwillig – du kannst jederzeit spontan trainieren.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
                if let value = draft {
                    ForEach(value.goals) { goal in goalCard(goal) }
                    if value.goals.count < SportKind.allCases.count {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Sportart", selection: $sport) {
                                ForEach(SportKind.allCases.filter { item in !value.goals.contains { $0.sport == item } }) { item in Text(item.title).tag(item) }
                            }
                            Button {
                                guard draft?.goals.contains(where: { $0.sport == sport }) != true else { return }
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { draft?.goals.append(.init(sport: sport)); hasEdits = true }
                                selectAvailableSport()
                            } label: { Label("Sportart hinzufügen", systemImage: "plus") }
                                .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("routine-add-sport")
                        }.fyCard()
                    }
                    if value.goals.isEmpty { Text("Noch keine Vorgaben. Dein Training bleibt frei planbar.").font(.footnote).foregroundStyle(FYColor.muted) }
                    if let message = value.validationMessage { Text(message).font(.footnote).foregroundStyle(FYColor.coral) }
                    Button(isOnboarding ? "Speichern & weiter" : "Wochenplan speichern") {
                        Task {
                            guard let draft, await store.personal.saveRoutine(draft) else { return }
                            hasEdits = false
                            if isOnboarding { await store.saveOnboardingStep("friends") } else { dismiss() }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(value.validationMessage != nil || store.personal.isSavingRoutine)
                        .accessibilityIdentifier("save-training-routine")
                } else if store.personal.isLoadingRoutine { ProgressView("Wochenplan laden …").frame(maxWidth: .infinity) }
                if let error = store.personal.routineError {
                    Text(error).font(.footnote).foregroundStyle(FYColor.coral)
                    Button("Aktuellen Plan erneut laden") {
                        if hasEdits { confirmsReload = true } else { Task { await reload() } }
                    }.disabled(store.personal.isSavingRoutine)
                }
                Text("Dieser Rhythmus ist nur für dich. Er erstellt keine Einladungen. Dein Streak-Wochenziel bleibt unverändert und zählt ausschließlich abgeschlossene Trainings.")
                    .font(.caption).foregroundStyle(FYColor.muted)
                if isOnboarding {
                    Button("Später festlegen") { Task { await store.saveOnboardingStep("friends") } }
                        .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("skip-training-routine")
                        .disabled(store.personal.isSavingRoutine || store.isBusy)
                }
            }.padding(22).padding(.bottom, isOnboarding ? 24 : 80)
        }.background(FYColor.background)
            .navigationTitle(isOnboarding ? "" : "Mein Wochenplan").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(FYColor.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .task { await reload() }
            .onChange(of: store.profile?.id) { _, _ in draft = nil; dismiss() }
            .confirmationDialog("Lokale Änderungen verwerfen?", isPresented: $confirmsReload) {
                Button("Neu laden", role: .destructive) { Task { await reload() } }
                Button("Weiter bearbeiten", role: .cancel) {}
            } message: { Text("Nur deine noch nicht gespeicherten Änderungen in diesem Formular werden ersetzt.") }
    }
    private func reload() async {
        await store.personal.loadRoutine()
        if store.personal.routineError == nil { draft = store.personal.routine; hasEdits = false; selectAvailableSport() }
    }
    private func selectAvailableSport() {
        sport = SportKind.allCases.first { item in draft?.goals.contains(where: { $0.sport == item }) != true } ?? .gym
    }
    private func update(_ sport: SportKind, _ change: (inout TrainingRoutineGoal) -> Void) {
        guard var value = draft, let index = value.goals.firstIndex(where: { $0.sport == sport }) else { return }
        change(&value.goals[index]); draft = value; hasEdits = true
    }
    private func goalCard(_ goal: TrainingRoutineGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(goal.sport.title, systemImage: goal.sport.symbol).font(.headline)
                Spacer()
                Button { draft?.goals.removeAll { $0.sport == goal.sport }; hasEdits = true; selectAvailableSport() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(FYColor.muted) }
                    .accessibilityLabel("\(goal.sport.title) aus Wochenplan entfernen")
            }
            Stepper("\(goal.sessions)× pro Woche", value: Binding(get: { goal.sessions }, set: { number in update(goal.sport) { $0.sessions = number; $0.weekdays = Array($0.weekdays.sorted().prefix(number)) } }), in: 1...7)
                .accessibilityIdentifier("routine-frequency-\(goal.sport.rawValue)")
            Toggle("Dauer festlegen", isOn: Binding(get: { goal.minutes != nil }, set: { enabled in update(goal.sport) { $0.minutes = enabled ? 30 : nil } }))
            if let minutes = goal.minutes {
                Stepper("Je \(minutes) Minuten", value: Binding(get: { minutes }, set: { number in update(goal.sport) { $0.minutes = number } }), in: 5...360, step: 5)
            }
            Text("Wochentage · optional").font(.caption.weight(.semibold)).foregroundStyle(FYColor.muted)
            HStack(spacing: 5) {
                ForEach(1...7, id: \.self) { day in
                    let chosen = goal.weekdays.contains(day)
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            update(goal.sport) {
                                if chosen { $0.weekdays.removeAll { $0 == day } }
                                else { $0.weekdays.append(day); $0.weekdays.sort(); $0.sessions = max($0.sessions, $0.weekdays.count) }
                            }
                        }
                        Haptics.impact(.light)
                    } label: {
                        Text(dayNames[day - 1]).font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(chosen ? Color.white : FYColor.ink)
                            .background(chosen ? FYColor.lime : FYColor.elevated, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityAddTraits(chosen ? .isSelected : [])
                        .accessibilityIdentifier("routine-\(goal.sport.rawValue)-day-\(day)")
                }
            }
            Text(goal.weekdays.isEmpty ? "Alle Einheiten flexibel – ohne festen Tag." : "\(goal.weekdays.count) feste Tage · \(max(0, goal.sessions - goal.weekdays.count)) Einheiten flexibel.")
                .font(.caption).foregroundStyle(FYColor.muted)
        }.fyCard().disabled(store.personal.isSavingRoutine)
    }
}

struct TrainingWeekCard: View {
    @Environment(AppStore.self) private var store
    @State private var selectedDay: Date?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let days = TrainingWeekLogic.days(containing: context.date)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("Deine Woche").font(.headline)
                    Spacer()
                    NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { Image(systemName: "slider.horizontal.3").frame(width: 34, height: 30) }
                        .accessibilityLabel("Wochenplan bearbeiten")
                }
                HStack(spacing: 5) {
                    ForEach(days, id: \.self) { day in
                        let done = completed(day).count
                        let planned = scheduled(day).count + desired(day).count
                        let today = Calendar.current.isDate(day, inSameDayAs: context.date)
                        Button { selectedDay = day; Haptics.impact(.light) } label: {
                            VStack(spacing: 5) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "de_DE")))).font(.system(size: 11, weight: .semibold))
                                Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                                Image(systemName: store.personal.week == nil ? "ellipsis" : done > 0 ? "checkmark.circle.fill" : planned > 0 ? "circle.dashed" : "minus")
                                    .font(.caption).foregroundStyle(done > 0 ? FYColor.lime : planned > 0 ? FYColor.cyan : FYColor.line)
                                    .frame(height: 16)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(today ? FYColor.limeSoft : FYColor.elevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(today ? FYColor.lime : .clear))
                        }.buttonStyle(.plain).accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).day().month())): " + (store.personal.week == nil ? "Noch nicht geladen" : "\(done) abgeschlossen, \(planned) vorgemerkt"))
                            .accessibilityIdentifier("training-week-day-\(TrainingWeekLogic.weekday(day))")
                    }
                }
                if store.personal.weekError != nil {
                    Button("Wochenübersicht erneut laden") { Task { await store.personal.loadWeek() } }.font(.caption).foregroundStyle(FYColor.coral)
                } else if store.personal.week == nil {
                    Text("Deine Woche wird geladen …").font(.caption).foregroundStyle(FYColor.muted)
                } else {
                    Text("✓ Erledigt     ◌ Vorgemerkt · Tippe auf einen Tag")
                        .font(.system(size: 11)).foregroundStyle(FYColor.muted)
                }
            }.fyCard()
                .task(id: days.first) { await store.personal.loadWeek(); if store.personal.routine == nil { await store.personal.loadRoutine() } }
        }
        .onChange(of: store.friendAccessRevision) { _, _ in store.personal.invalidateWeekAccess(); Task { await store.personal.loadWeek() } }
        .onChange(of: store.myActivity) { _, _ in Task { await store.personal.loadWeek() } }
        .sheet(isPresented: Binding(get: { selectedDay != nil }, set: { if !$0 { selectedDay = nil } })) {
            if let day = selectedDay { NavigationStack { TrainingDayView(day: day) } }
        }
    }
    private func completed(_ day: Date) -> [Activity] {
        guard let owner = store.profile?.id else { return [] }
        return TrainingWeekLogic.completed(store.personal.week?.activities ?? [], owner: owner, day: day)
    }
    private func scheduled(_ day: Date) -> [PlannedSession] { store.personal.week?.sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: day) } ?? [] }
    private func desired(_ day: Date) -> [TrainingRoutineGoal] {
        let represented = Set(completed(day).map(\.sport) + scheduled(day).map(\.sport))
        return store.personal.routine?.goals.filter { $0.weekdays.contains(TrainingWeekLogic.weekday(day)) && !represented.contains($0.sport) } ?? []
    }
}

private struct TrainingDayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: Date
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE")))).font(.title2.bold())
                if let owner = store.profile?.id, store.personal.week != nil {
                    let done = TrainingWeekLogic.completed(store.personal.week?.activities ?? [], owner: owner, day: day)
                    let sessions = store.personal.week?.sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: day) } ?? []
                    let represented = Set(done.map(\.sport) + sessions.map(\.sport))
                    ForEach(done) { activity in
                        HStack { Label(activity.sport.title, systemImage: "checkmark.circle.fill").foregroundStyle(FYColor.lime); Spacer(); Text("Erledigt").font(.caption.bold()) }.fyCard()
                    }
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(session.sport.title, systemImage: session.sport.symbol).bold()
                            Text("Geplant · \(session.startsAt.formatted(date: .omitted, time: .shortened))" + (session.durationMinutes.map { " · \($0) Min." } ?? "")).font(.subheadline).foregroundStyle(FYColor.muted)
                        }.fyCard()
                    }
                    let desires = store.personal.routine?.goals.filter { $0.weekdays.contains(TrainingWeekLogic.weekday(day)) && !represented.contains($0.sport) } ?? []
                    ForEach(desires) { goal in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(goal.sport.title, systemImage: goal.sport.symbol).bold()
                            Text("Dein Wunsch für diesen Tag" + (goal.minutes.map { " · \($0) Min." } ?? "")).font(.subheadline).foregroundStyle(FYColor.muted)
                        }.fyCard()
                    }
                    if done.isEmpty && sessions.isEmpty && desires.isEmpty { Text("Hier steht noch nichts an. Zeit für eine Pause oder spontanes Training.").foregroundStyle(FYColor.muted).fyCard() }
                    if let routine = store.personal.routine, !routine.goals.isEmpty {
                        Text("Deine Wochenziele").font(.headline).padding(.top, 8)
                        ForEach(routine.goals) { goal in
                            let count = TrainingWeekLogic.completedCount(sport: goal.sport, activities: store.personal.week?.activities ?? [], owner: owner, now: day)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(goal.sport.title).bold(); Spacer(); Text("\(count) / \(goal.sessions)").monospacedDigit() }
                                ProgressView(value: min(1, Double(count) / Double(goal.sessions))).tint(FYColor.lime)
                                Text(goal.summary + (goal.weekdays.isEmpty ? " · Tage frei" : "")).font(.caption).foregroundStyle(FYColor.muted)
                            }.fyCard()
                        }
                    }
                }
                if store.personal.week == nil, store.personal.weekError == nil { ProgressView("Woche laden …") }
                if let error = store.personal.weekError { Text(error).foregroundStyle(FYColor.coral).font(.footnote) }
                NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { Text("Wochenplan bearbeiten") }.buttonStyle(PrimaryButtonStyle())
                Text("Vorgemerkt ist nicht erledigt. Nur tatsächlich abgeschlossene Aktivitäten erhalten einen Haken.").font(.caption).foregroundStyle(FYColor.muted)
            }.padding(22)
        }.background(FYColor.background).navigationTitle("Deine Woche").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .task { await store.personal.loadWeek(now: day) }
    }
}
