import SwiftUI

struct BlindWorkoutsView: View {
    @Environment(AppStore.self) private var store
    @State private var createsWorkout = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Überraschung.\nVon deiner Crew.").font(.largeTitle.weight(.black))
                Text("Baut euch gegenseitig ein Training. Du entscheidest, ob es zu dir passt – und deckst die Übungen erst beim Trainieren auf.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
                Button { createsWorkout = true } label: { Label("Blind Workout erstellen", systemImage: "eye") }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("create-blind-workout")
                    .disabled(store.crew.isEmpty)
                if store.crew.isEmpty { Text("Füge zuerst einen Freund hinzu. Blind Workouts bleiben zwischen euch.").font(.footnote).foregroundStyle(FYColor.muted) }
                if store.blind.isLoadingSummaries { ProgressView().frame(maxWidth: .infinity) }
                BlindErrorBanner { await store.blind.refreshSummaries() }
                ForEach([true, false], id: \.self) { received in
                    let values = store.blind.summaries.filter { ($0.recipientID == store.profile?.id) == received }
                    if !values.isEmpty {
                        Text(received ? "Für dich" : "Von dir gebaut").font(.headline).padding(.top, 8)
                        ForEach(values) { item in
                            NavigationLink { BlindWorkoutDetailView(id: item.id) } label: { BlindSummaryCard(summary: item) }
                                .buttonStyle(.plain).accessibilityLabel(item.displayTitle)
                        }
                    }
                }
                if store.blind.summaries.isEmpty && !store.blind.isLoadingSummaries {
                    ContentUnavailableView("Noch keine Blind Workouts", systemImage: "eye", description: Text("Dein erstes Überraschungs-Training beginnt mit einem Freund."))
                }
            }.padding(20).padding(.bottom, 32)
        }.background(FYColor.background).foregroundStyle(FYColor.ink)
            .navigationTitle("Blind Workouts").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $createsWorkout) { BlindWorkoutComposerView() }
            .task { await store.blind.refreshSummaries() }
            .refreshable { await store.blind.refreshSummaries() }
    }
}

struct BlindInboxCards: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ForEach(store.blind.summaries.filter { $0.recipientID == store.profile?.id && [.sent, .accepted, .planned].contains($0.status) }) { item in
            NavigationLink { BlindWorkoutDetailView(id: item.id) } label: { BlindSummaryCard(summary: item) }
                .buttonStyle(.plain).accessibilityIdentifier("blind-inbox-\(item.id.uuidString)")
                .accessibilityLabel(item.displayTitle)
        }
    }
}

private struct BlindSummaryCard: View {
    @Environment(AppStore.self) private var store
    let summary: BlindWorkoutSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye").foregroundStyle(FYColor.violet)
                Text(summary.recipientID == store.profile?.id ? "Von \(summary.creatorName)" : "Für \(summary.recipientName)").font(.subheadline.bold())
                Spacer()
                Text(summary.status.title).font(.caption.bold()).foregroundStyle(summary.status == .completed ? FYColor.lime : FYColor.muted)
            }
            Text(summary.displayTitle).font(.headline)
            Text("\(summary.exerciseCount) Übungen · ca. \(summary.estimatedDurationMinutes) Min.").font(.subheadline).foregroundStyle(FYColor.muted)
            if let date = summary.scheduledAt, summary.status == .planned { Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar").font(.caption) }
        }.fyCard().foregroundStyle(FYColor.ink)
    }
}

struct BlindWorkoutComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BlindWorkoutDraft
    @State private var selectsExercise = false
    @State private var editedExercise: WorkoutPlanExercise?
    @State private var confirmsDiscard = false
    @State private var editMode: EditMode = .inactive
    private let emptyRecipient = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    init(recipientID: UUID? = nil) {
        _draft = State(initialValue: BlindWorkoutDraft(recipientID: recipientID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, title: nil))
    }
    private var canSend: Bool { store.crew.contains(where: { $0.id == draft.recipientID }) && draft.validationMessage == nil && !store.blind.isBusy }
    private var hasChanges: Bool { !draft.exercises.isEmpty || !(draft.title ?? "").isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Ein Training, das erst unterwegs seine Übungen verrät.").font(.headline)
                    Text("Wähle vertraute Übungen und passende Vorgaben. Keine Straf- oder Schmerz-Challenges. Dein Freund kann jederzeit ablehnen oder aufhören.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                }
                Section("Für wen?") {
                    Picker("Freund", selection: $draft.recipientID) {
                        Text("Freund auswählen").tag(emptyRecipient)
                        ForEach(store.crew) { member in Text(member.profile.displayName).tag(member.id) }
                    }.accessibilityIdentifier("blind-recipient")
                    TextField("Name (optional)", text: Binding(get: { draft.title ?? "" }, set: { draft.title = $0 }))
                        .accessibilityIdentifier("blind-title")
                    Picker("Fokus", selection: $draft.focus) { ForEach(BlindWorkoutFocus.allCases) { Text($0.title).tag($0) } }
                    Stepper("ca. \(draft.estimatedDurationMinutes) Minuten", value: $draft.estimatedDurationMinutes, in: 5...180, step: 5)
                }
                Section {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, row in
                        Button { editedExercise = row } label: {
                            HStack(alignment: .top) {
                                Text("\(index + 1)").bold().foregroundStyle(FYColor.lime).frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) { Text(row.exercise.name).font(.subheadline.bold()); Text(row.prescription).font(.caption).foregroundStyle(FYColor.muted) }
                                Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(FYColor.muted)
                            }.foregroundStyle(FYColor.ink)
                        }.accessibilityIdentifier("blind-draft-exercise-\(index)")
                    }.onDelete { draft.exercises.remove(atOffsets: $0) }
                        .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button { selectsExercise = true } label: { Label("Übung hinzufügen", systemImage: "plus.circle.fill") }
                        .disabled(draft.exercises.count >= 12).accessibilityIdentifier("add-blind-exercise")
                } header: { Text("Deine Übungsreihenfolge") } footer: { Text("Tippe eine Übung für Sätze, Wiederholungen und optionale Notizen an. Mit Sortieren kannst du die Reihenfolge ändern.") }
                if !draft.exercises.isEmpty {
                    Section("Das sieht dein Freund vor dem Start") {
                        Label("\(draft.focus.title) · \(draft.exercises.count) Übungen · ca. \(draft.estimatedDurationMinutes) Min.", systemImage: "eye")
                        Text(Set(draft.exercises.map { $0.exercise.equipment.title }).sorted().joined(separator: " · ")).font(.subheadline)
                        Text("Die einzelnen Übungen werden nicht vorab übertragen.").font(.caption).foregroundStyle(FYColor.muted)
                    }
                }
                if let validation = draft.validationMessage { Text(validation).font(.footnote).foregroundStyle(FYColor.muted) }
                BlindErrorBanner { await store.blind.refreshSummaries() }
            }.disabled(store.blind.isBusy).scrollContentBackground(.hidden).background(FYColor.background)
                .environment(\.editMode, $editMode)
                .navigationTitle("Blind Workout").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { if hasChanges { confirmsDiscard = true } else { dismiss() } } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Schließen").disabled(store.blind.isBusy)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(editMode.isEditing ? "Fertig" : "Sortieren") { editMode = editMode.isEditing ? .inactive : .active }
                            .disabled(store.blind.isBusy).accessibilityIdentifier("sort-blind-exercises")
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button("BLIND WORKOUT SENDEN") {
                        Task { if await store.blind.send(draft.normalizedForSending()) { await store.blind.refreshSummaries(); dismiss() } }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!canSend).accessibilityIdentifier("send-blind-workout")
                        .padding(18).background(.ultraThinMaterial)
                }
                .sheet(isPresented: $selectsExercise) {
                    ExerciseLibraryView { exercise in
                        guard draft.exercises.count < 12 else { return }
                        draft.exercises.append(WorkoutPlanExercise(exercise: exercise, sortOrder: draft.exercises.count))
                        selectsExercise = false
                    }
                }
                .sheet(item: $editedExercise) { entry in
                    WorkoutPrescriptionEditor(entry: entry, isBlind: true) { changed in
                        if let index = draft.exercises.firstIndex(where: { $0.id == changed.id }) { draft.exercises[index] = changed }
                    }
                }
                .interactiveDismissDisabled(hasChanges || store.blind.isBusy)
                .confirmationDialog("Entwurf verwerfen?", isPresented: $confirmsDiscard) {
                    Button("Verwerfen", role: .destructive) { dismiss() }
                    Button("Weiter bearbeiten", role: .cancel) {}
                } message: { Text("Dieses Blind Workout wurde noch nicht gesendet.") }
        }.tint(FYColor.lime)
    }
}

struct BlindWorkoutDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: UUID
    @State private var equipmentConfirmed = false
    @State private var mode = TrackingMode.easy
    @State private var selectedSet: TrackingSetSelection?
    @State private var plansLater = false
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var confirmsCancel = false
    @State private var copiedPlan: WorkoutPlan?
    @State private var confirmsDiscardSetDrafts = false
    @State private var restoredDraftMode = false
    @State private var completionCelebration: UUID?
    private var state: BlindWorkoutState? { store.blind.state(id: id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let value = state {
                    BlindSummaryCard(summary: value.summary)
                    if value.viewerRole == .creator {
                        Text("Deine Vorgaben").font(.headline)
                        Text("Du siehst deinen Aufbau. Tatsächliche Gewichte und Satzwerte deines Freundes bleiben privat.").font(.footnote).foregroundStyle(FYColor.muted)
                        ForEach(value.visibleExercises) { exercise in revealedExercise(exercise, editable: false) }
                        if value.summary.status == .completed { feedback(value) }
                    } else {
                        recipientContent(value)
                    }
                    if value.canCopy {
                        Button { Task { copiedPlan = await store.blind.copy(id: id) } } label: { Label("Als eigenen Trainingsplan speichern", systemImage: "square.and.arrow.down") }
                            .buttonStyle(OutlineButtonStyle()).disabled(store.blind.isBusy).accessibilityIdentifier("copy-blind-workout")
                    }
                    if ![.completed, .cancelled, .declined].contains(value.summary.status) && (value.summary.status != .sent || value.viewerRole == .creator) {
                        Button("Workout abbrechen") { confirmsCancel = true }.font(.footnote).foregroundStyle(FYColor.muted)
                            .frame(maxWidth: .infinity, minHeight: 44).disabled(store.blind.isBusy)
                    }
                    if [.completed, .cancelled, .declined].contains(value.summary.status) {
                        Button("Fertig") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    }
                } else if store.blind.isLoading {
                    ProgressView("Workout wird geladen …").frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ContentUnavailableView("Workout gerade nicht verfügbar", systemImage: "eye.slash", description: Text("Prüfe die Verbindung. Nach einer beendeten Freundschaft bleiben private Inhalte verborgen."))
                    if store.myActivity?.blindWorkoutID == id {
                        Button("Mein laufendes Workout abbrechen") { confirmsCancel = true }.buttonStyle(OutlineButtonStyle())
                    }
                }
                BlindErrorBanner { _ = await store.blind.load(id: id) }
            }.padding(20).padding(.bottom, 76)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: state?.currentExercise?.id)
        }.background(FYColor.background).foregroundStyle(FYColor.ink)
            .overlay { TrainingConfetti(trigger: completionCelebration) }
            .navigationTitle("Blind Workout").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbarBackground(FYColor.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .accessibilityElement(children: .contain).accessibilityIdentifier("blind-detail-screen")
            .task { _ = await store.blind.load(id: id) }
            .refreshable { _ = await store.blind.load(id: id) }
            .onChange(of: store.blind.selectedState) { _, value in
                if let selection = selectedSet {
                    guard let value, let owner = store.profile?.id,
                          WorkoutSetDraftContext.blind(ownerID: owner, state: value, exerciseID: selection.exerciseID, setID: selection.set.id) != nil else { selectedSet = nil; return }
                }
                if !restoredDraftMode, let activityID = value?.activity?.id, store.trackingDrafts.hasInput(activityID: activityID) {
                    mode = .track; restoredDraftMode = true
                }
            }
            .sheet(item: $selectedSet) { selection in
                WorkoutSetEntrySheet(selection: selection) { updated in
                    guard let exercise = state?.currentExercise, exercise.id == selection.exerciseID else { return false }
                    var sets = exercise.sets
                    if let index = sets.firstIndex(where: { $0.id == updated.id }) { sets[index] = updated }
                    else { return false }
                    return await store.blind.saveExercise(id: id, exerciseID: exercise.id, sets: sets, complete: false)
                }
            }
            .sheet(isPresented: $plansLater) {
                NavigationStack {
                    Form { DatePicker("Datum & Uhrzeit", selection: $startsAt, in: Date()...) }
                        .navigationTitle("Später trainieren").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { plansLater = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Planen") { Task { if await store.blind.plan(id: id, startsAt: startsAt) { plansLater = false; await store.refresh() } } }.disabled(store.blind.isBusy) }
                        }
                }.presentationDetents([.medium]).tint(FYColor.lime)
            }
            .navigationDestination(item: $copiedPlan) { plan in
                WorkoutPlanDetailView(planID: plan.id)
                    .safeAreaInset(edge: .top) {
                        Label("Als eigener Plan gespeichert", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold()).foregroundStyle(FYColor.lime).padding(10)
                            .frame(maxWidth: .infinity).background(FYColor.limeSoft)
                            .accessibilityIdentifier("blind-copy-confirmed")
                    }
            }
            .confirmationDialog("Workout abbrechen?", isPresented: $confirmsCancel, titleVisibility: .visible) {
                Button("Workout abbrechen", role: .destructive) {
                    let activityID = state?.activity?.id
                    Task { if await store.blind.cancel(id: id) { if let activityID { store.trackingDrafts.clearActivity(activityID) }; await store.refresh() } }
                }
                Button("Weiter trainieren", role: .cancel) {}
            } message: { Text("Du kannst jederzeit aufhören. Lokale, noch nicht gespeicherte Satzentwürfe werden dabei verworfen. Es gibt keine negative Bewertung und keinen Wochen-Credit für einen Abbruch.") }
            .confirmationDialog("Lokale Satzentwürfe verwerfen?", isPresented: $confirmsDiscardSetDrafts, titleVisibility: .visible) {
                Button("Lokale Satzentwürfe verwerfen", role: .destructive) { if let activityID = state?.activity?.id { store.trackingDrafts.clearActivity(activityID) } }
                Button("Behalten", role: .cancel) {}
            } message: { Text("Deine bereits gespeicherten Satzwerte bleiben unverändert. Nur unbestätigte Eingaben auf diesem Gerät werden entfernt.") }
    }

    @ViewBuilder private func recipientContent(_ value: BlindWorkoutState) -> some View {
        switch value.summary.status {
        case .sent, .accepted, .planned:
            VStack(alignment: .leading, spacing: 12) {
                Label("Das brauchst du", systemImage: "dumbbell").font(.headline)
                Text(value.summary.requiredEquipment.map(\.title).joined(separator: " · "))
                Text(value.summary.muscleGroups.map(\.title).joined(separator: " · ")).font(.subheadline).foregroundStyle(FYColor.muted)
                Text("Du siehst vor dem Start keine einzelnen Übungen. Starte nur, wenn Equipment und Fokus für dich passen.").font(.footnote).foregroundStyle(FYColor.muted)
            }.fyCard()
            if value.summary.status == .sent {
                Toggle("Equipment verfügbar", isOn: $equipmentConfirmed).tint(FYColor.lime).accessibilityIdentifier("confirm-blind-equipment")
                Button("ANNEHMEN") { Task { _ = await store.blind.respond(id: id, accept: true, equipmentConfirmed: equipmentConfirmed) } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(!equipmentConfirmed || store.blind.isBusy).accessibilityIdentifier("accept-blind-workout")
                Button("ABLEHNEN") { Task { _ = await store.blind.respond(id: id, accept: false, equipmentConfirmed: false) } }
                    .buttonStyle(OutlineButtonStyle()).disabled(store.blind.isBusy)
            } else {
                Button("BLIND WORKOUT STARTEN") {
                    Task { if await store.blind.start(id: id) { store.myActivity = state?.activity; await store.refresh() } }
                }.buttonStyle(PrimaryButtonStyle()).disabled(store.blind.isBusy).accessibilityIdentifier("start-blind-workout")
                Button("Später planen") { plansLater = true }.buttonStyle(OutlineButtonStyle())
            }
        case .live:
            if let activity = value.activity {
                LiveActivityTimer(activity: activity).font(.system(size: 38, weight: .bold, design: .monospaced))
                HStack { Text("\(value.summary.completedExercises) / \(value.summary.exerciseCount) Übungen").bold(); Spacer(); if activity.pausedAt != nil { Text("Pausiert").foregroundStyle(FYColor.muted) } }
                ProgressView(value: value.summary.progress).tint(FYColor.lime)
                Picker("Trainingsmodus", selection: $mode) { ForEach(TrackingMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    .accessibilityIdentifier("blind-tracking-mode")
                Text(mode == .easy ? "Übung ansehen, in deinem Tempo trainieren und abhaken." : "Tatsächliche Satzwerte sind freiwillig und bleiben privat.")
                    .font(.footnote).foregroundStyle(FYColor.muted)
                if store.trackingDrafts.hasInput(activityID: activity.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Lokale Satzentwürfe vorhanden", systemImage: "square.and.pencil").font(.subheadline.bold())
                        Text("Öffne den Satz der aktuell freigegebenen Übung, um deine Eingaben zu prüfen. Vor dem Weiterschalten musst du sie speichern oder verwerfen. Frühere oder noch verborgene Übungen werden nicht aus einem Entwurf geöffnet.").font(.footnote)
                        Button("Lokale Satzentwürfe verwerfen") { confirmsDiscardSetDrafts = true }.font(.caption.bold()).disabled(store.blind.isBusy)
                    }.fyCard().accessibilityIdentifier("restored-blind-set-draft")
                }
                if let error = store.trackingDrafts.errorMessage { Text(error).font(.footnote).foregroundStyle(FYColor.coral) }
                if let current = value.currentExercise {
                    revealedExercise(current, editable: true).id(current.id)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                    Button("ÜBUNG ABSCHLIESSEN") {
                        Task {
                            let saved = await store.blind.saveExercise(id: id, exerciseID: current.id, sets: current.sets, complete: true)
                            if saved { Haptics.impact(.light) }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(store.blind.isBusy || store.trackingDrafts.hasInput(activityID: activity.id)).accessibilityIdentifier("complete-blind-exercise")
                }
                let hidden = max(0, value.summary.exerciseCount - value.visibleExercises.count)
                if hidden > 0 {
                    HStack { Image(systemName: "eye.slash"); Text("Noch \(hidden) \(hidden == 1 ? "Übung bleibt" : "Übungen bleiben") eine Überraschung").font(.subheadline); Spacer(); Image(systemName: "lock.fill") }
                        .foregroundStyle(FYColor.muted).fyCard()
                }
                if value.canFinish {
                    Button("BLIND WORKOUT BEENDEN") {
                        Task {
                            if await store.blind.finish(id: id) {
                                completionCelebration = UUID()
                                await store.refresh(); await store.weekly.refresh(force: true); await store.weekly.prepareCelebration()
                            }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(store.blind.isBusy || store.trackingDrafts.hasInput(activityID: activity.id)).accessibilityIdentifier("finish-blind-workout")
                }
                Button(activity.pausedAt == nil ? "Training pausieren" : "Training fortsetzen") {
                    Task {
                        store.myActivity = activity
                        await store.setPaused(activity.pausedAt == nil)
                        _ = await store.blind.load(id: id)
                    }
                }.buttonStyle(OutlineButtonStyle()).disabled(store.blind.isBusy || store.isBusy)
                if value.summary.completedExercises > 0 {
                    DisclosureGroup("Bereits geschafft") { ForEach(value.visibleExercises.filter(\.completed)) { exercise in revealedExercise(exercise, editable: false) } }
                }
            }
        case .completed:
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(FYColor.lime)
                Text("BLIND WORKOUT DONE").font(.title2.weight(.black)).accessibilityIdentifier("blind-workout-completed")
                Text("\(value.summary.completedExercises) / \(value.summary.exerciseCount) Übungen").font(.headline)
                if let duration = value.activity?.duration { Text(duration < 60 ? "\(Int(duration)) Sekunden" : "\(Int(duration / 60)) Minuten").foregroundStyle(FYColor.muted) }
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
            if let activity = value.activity { WorkoutFeedbackButton(activityID: activity.id) }
            feedback(value)
            ForEach(value.visibleExercises) { exercise in revealedExercise(exercise, editable: false) }
        case .cancelled, .declined:
            Text(value.summary.status == .declined ? "Dieses Workout hast du abgelehnt. Entscheide selbst, was zu dir passt." : "Dieses Workout wurde nicht abgeschlossen. Das ist okay.")
                .foregroundStyle(FYColor.muted).fyCard()
        }
    }

    private func revealedExercise(_ exercise: WorkoutExerciseLog, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.exercise.name).font(.title3.bold())
            Text("\(exercise.targetSets) × \(exercise.targetRepsMin)–\(exercise.targetRepsMax) \(exercise.exercise.repetitionUnit)").font(.subheadline)
            if let weight = exercise.targetWeight { Text("Vorgabe: \(weight.formatted()) kg – passe sie an dein Können an.").font(.caption).foregroundStyle(FYColor.muted) }
            if let note = exercise.note { Text(note).font(.footnote).foregroundStyle(FYColor.muted) }
            if editable && mode == .track {
                ForEach(exercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in
                    Button {
                        guard let state, let owner = store.profile?.id,
                              let context = WorkoutSetDraftContext.blind(ownerID: owner, state: state, exerciseID: exercise.id, setID: set.id) else { return }
                        selectedSet = TrackingSetSelection(exerciseID: exercise.id, exerciseName: exercise.exercise.name, unit: exercise.exercise.repetitionUnit, set: set, isBlind: true, draftContext: context)
                    }
                    label: { WorkoutSetRow(set: set, unit: exercise.exercise.repetitionUnit, editable: true) }
                        .buttonStyle(.plain).disabled(store.blind.isBusy).accessibilityIdentifier("blind-set-\(set.setNumber)")
                }
            } else if !editable && state?.viewerRole == .recipient {
                ForEach(exercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in WorkoutSetRow(set: set, unit: exercise.exercise.repetitionUnit, editable: false) }
            }
            if state?.viewerRole == .recipient, let activity = state?.activity {
                ExerciseEffortControl(activityID: activity.id, exerciseID: exercise.id, editable: editable)
                    .disabled(store.blind.isBusy)
            }
        }.fyCard().accessibilityElement(children: .contain)
    }

    private func feedback(_ value: BlindWorkoutState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(value.viewerRole == .recipient ? value.summary.creatorName : value.summary.recipientName) reagieren").font(.headline)
            HStack(spacing: 14) {
                ForEach(ReactionKind.allCases, id: \.self) { reaction in
                    Button { Task { _ = await store.blind.react(id: id, reaction: value.myReaction == reaction ? nil : reaction) } } label: {
                        Text(reaction.rawValue).font(.title2).padding(12).background(value.myReaction == reaction ? FYColor.limeSoft : FYColor.elevated, in: Circle())
                    }.buttonStyle(.plain).disabled(store.blind.isBusy).accessibilityLabel("Reagieren: \(reaction.rawValue)")
                }
            }
        }.fyCard()
    }
}

private struct BlindErrorBanner: View {
    @Environment(AppStore.self) private var store
    let retry: () async -> Void
    var body: some View {
        if let error = store.blind.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text(error).font(.subheadline).foregroundStyle(FYColor.muted)
                Button("Erneut prüfen") { Task { await retry() } }.font(.subheadline.bold()).disabled(store.blind.isBusy)
            }.fyCard()
        }
    }
}
