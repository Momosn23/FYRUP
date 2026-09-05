import SwiftUI

struct WorkoutPlansView: View {
    @Environment(AppStore.self) private var store
    var onSelect: ((WorkoutPlan) -> Void)? = nil
    @State private var newPlan: WorkoutPlan?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SportHeroCard(sport: .gym, title: "Deine Trainingspläne", subtitle: "Dein Training. Deine Reihenfolge. Deine Crew.")
                Button {
                    if let userID = store.profile?.id { newPlan = WorkoutPlan(ownerID: userID) }
                } label: { Label("Neuen Trainingsplan erstellen", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("create-workout-plan")
                ForEach(store.workoutDrafts.drafts) { savedDraft in
                    Button { newPlan = savedDraft.original } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.pencil").foregroundStyle(FYColor.lime)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(savedDraft.edited.name.isEmpty ? "Unbenannter Plan" : savedDraft.edited.name).font(.headline)
                                Text("Lokalen Entwurf fortsetzen · noch nicht geteilt").font(.caption).foregroundStyle(FYColor.muted)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.fyCard()
                    }.buttonStyle(.plain).accessibilityIdentifier("resume-workout-draft")
                }
                if let error = store.workoutDrafts.errorMessage { Text(error).font(.caption).foregroundStyle(FYColor.coral) }
                if store.workouts.isLoadingPlans && store.workouts.plans.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                if let error = store.workouts.errorMessage { WorkoutErrorBanner(message: error) { Task { await store.workouts.loadPlans() } } }
                if store.workouts.plans.isEmpty && !store.workouts.isLoadingPlans && store.workouts.errorMessage == nil {
                    ContentUnavailableView("Dein erster Plan", systemImage: "list.clipboard", description: Text("Stelle deine Lieblingsübungen zusammen. Gewichte kannst du später freiwillig tracken."))
                }
                ForEach(store.workouts.plans) { plan in
                    if let onSelect {
                        Button { onSelect(plan) } label: { WorkoutPlanCard(plan: plan) }.buttonStyle(.plain)
                    } else {
                        NavigationLink { WorkoutPlanDetailView(planID: plan.id) } label: { WorkoutPlanCard(plan: plan) }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .background(FYColor.background).navigationTitle("Meine Pläne").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .task { await store.workouts.loadPlans() }
        .refreshable { await store.workouts.loadPlans() }
        .fullScreenCover(item: $newPlan) { plan in
            WorkoutPlanEditorView(plan: plan) { saved in onSelect?(saved) }
        }
    }
}

struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(FYColor.lime)
                .frame(width: 54, height: 58).background(FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(plan.name).font(.headline).foregroundStyle(FYColor.ink)
                Text([plan.category, "\(plan.exercises.count) Übungen"].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(FYColor.muted)
                Label(plan.visibility == .private ? "Privater Plan" : "Für Freunde sichtbar", systemImage: plan.visibility == .private ? "lock" : "person.2")
                    .font(.caption2).foregroundStyle(FYColor.muted)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(FYColor.muted)
        }.fyCard().accessibilityElement(children: .combine).accessibilityLabel(plan.name)
            .accessibilityHint("\(plan.exercises.count) Übungen. \(plan.visibility == .private ? "Privater Plan" : "Für Freunde sichtbar")")
    }
}

struct WorkoutPlanEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: WorkoutPlan
    @State private var showsLibrary = false
    @State private var editingEntry: WorkoutPlanExercise?
    @State private var confirmDiscard = false
    @State private var restoredDraft = false
    private let original: WorkoutPlan
    var onSaved: (WorkoutPlan) -> Void = { _ in }

    init(plan: WorkoutPlan, onSaved: @escaping (WorkoutPlan) -> Void = { _ in }) {
        _draft = State(initialValue: plan); original = plan; self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if restoredDraft {
                    Section { Label("Dein ungespeicherter Entwurf wurde wiederhergestellt.", systemImage: "arrow.counterclockwise").font(.subheadline).foregroundStyle(FYColor.lime) }
                }
                Section {
                    TextField("z. B. Push Day", text: $draft.name).accessibilityLabel("Planname").accessibilityIdentifier("workout-plan-name")
                    Picker("Fokus (optional)", selection: category) {
                        Text("Ohne Fokus").tag("")
                        ForEach(Self.categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Beschreibung (optional)", text: description, axis: .vertical).lineLimit(2...4)
                } header: { Text("Dein Plan") } footer: { Text("Sätze und Wiederholungen sind Vorgaben. Tatsächliche Werte kannst du beim Training freiwillig eintragen.") }
                Section {
                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, entry in
                        Button { editingEntry = entry } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)").font(.caption.bold()).foregroundStyle(FYColor.lime).frame(width: 25)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.exercise.name).font(.subheadline.bold()).foregroundStyle(FYColor.ink)
                                    Text(entry.prescription).font(.caption).foregroundStyle(FYColor.muted)
                                }
                                Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(FYColor.muted)
                            }.padding(.vertical, 5)
                        }.accessibilityIdentifier("plan-exercise-\(index)")
                        .accessibilityAction(named: "Nach oben") { move(entry.id, direction: -1) }
                        .accessibilityAction(named: "Nach unten") { move(entry.id, direction: 1) }
                    }
                    .onMove { source, destination in draft.exercises.move(fromOffsets: source, toOffset: destination); normalizeOrder() }
                    .onDelete { offsets in draft.exercises.remove(atOffsets: offsets); normalizeOrder() }
                    Button { showsLibrary = true } label: { Label("Übung hinzufügen", systemImage: "plus.circle.fill") }
                        .foregroundStyle(FYColor.lime).accessibilityIdentifier("add-plan-exercise")
                        .disabled(draft.exercises.count >= 40)
                } header: { Text("Übungen · \(draft.exercises.count)") } footer: { Text("Tippe eine Übung an, um die Vorgaben anzupassen. Über „Sortieren“ kannst du die Reihenfolge ändern.") }
                Section {
                    Picker("Sichtbarkeit", selection: $draft.visibility) {
                        Text("Privat").tag(PlanVisibility.private)
                        Text("Freunde").tag(PlanVisibility.friends)
                    }
                    Text(draft.visibility == .private ? "Nur du siehst den Plan, bis du ihn gezielt teilst oder jemanden dazu einlädst." : "Deine akzeptierten Freunde können diesen Plan in deinem Profil ansehen und eine eigene Kopie speichern.")
                        .font(.caption).foregroundStyle(FYColor.muted)
                } header: { Text("Unter deiner Kontrolle") }
                if let error = store.workouts.errorMessage { Section { Text(error).foregroundStyle(FYColor.coral).accessibilityIdentifier("workout-error") } }
                if let error = store.workoutDrafts.errorMessage { Section { Text(error).foregroundStyle(FYColor.coral) } }
            }
            .scrollContentBackground(.hidden).background(FYColor.background)
            .navigationTitle(original.name.isEmpty ? "Plan erstellen" : "Plan bearbeiten").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { if draft == original { dismiss() } else { confirmDiscard = true } }.disabled(store.workouts.isBusy) }
                ToolbarItem(placement: .primaryAction) { EditButton().accessibilityLabel("Sortieren") }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 5) {
                    if let validation = draft.validationMessage { Text(validation).font(.caption).foregroundStyle(FYColor.muted) }
                    Button(store.workouts.isBusy ? "Wird gespeichert …" : "Plan speichern") {
                        Task {
                            if let saved = await store.workouts.savePlan(draft) { store.workoutDrafts.remove(id: draft.id); Haptics.success(); onSaved(saved); dismiss() }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(store.workouts.isBusy || draft.validationMessage != nil)
                        .accessibilityIdentifier("save-workout-plan")
                }.padding(16).background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showsLibrary) {
                ExerciseLibraryView { exercise in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        draft.exercises.append(WorkoutPlanExercise(exercise: exercise, sortOrder: draft.exercises.count))
                    }
                    showsLibrary = false
                }
            }
            .sheet(item: $editingEntry) { entry in
                WorkoutPrescriptionEditor(entry: entry) { saved in
                    if let index = draft.exercises.firstIndex(where: { $0.id == saved.id }) { draft.exercises[index] = saved }
                }
            }
            .confirmationDialog("Ungespeicherte Änderungen verwerfen?", isPresented: $confirmDiscard) {
                Button("Verwerfen", role: .destructive) { store.workoutDrafts.remove(id: draft.id); dismiss() }
                Button("Weiter bearbeiten", role: .cancel) {}
            }
            .interactiveDismissDisabled(draft != original)
            .onAppear {
                if !restoredDraft, let saved = store.workoutDrafts.draft(id: original.id) {
                    draft = saved.edited; restoredDraft = true
                }
            }
            .onChange(of: draft) { _, edited in store.workoutDrafts.save(edited: edited, original: original) }
        }.tint(FYColor.lime).preferredColorScheme(.light)
    }

    private var category: Binding<String> { Binding(get: { draft.category ?? "" }, set: { draft.category = $0.isEmpty ? nil : $0 }) }
    private var description: Binding<String> { Binding(get: { draft.description ?? "" }, set: { draft.description = $0.isEmpty ? nil : $0 }) }
    private func normalizeOrder() { for index in draft.exercises.indices { draft.exercises[index].sortOrder = index } }
    private func move(_ id: UUID, direction: Int) {
        guard let source = draft.exercises.firstIndex(where: { $0.id == id }), draft.exercises.indices.contains(source + direction) else { return }
        draft.exercises.swapAt(source, source + direction); normalizeOrder()
    }
    static let categories = ["Push", "Pull", "Legs", "Upper Body", "Lower Body", "Full Body", "Chest", "Back", "Arms", "Shoulders", "Cardio", "Custom"]
}

private struct WorkoutPrescriptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: WorkoutPlanExercise
    @State private var weight: String
    let onSave: (WorkoutPlanExercise) -> Void
    init(entry: WorkoutPlanExercise, onSave: @escaping (WorkoutPlanExercise) -> Void) {
        _entry = State(initialValue: entry)
        _weight = State(initialValue: entry.targetWeight.map { String($0) } ?? "")
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(entry.exercise.name).font(.headline); Text(entry.exercise.primaryMuscle.title).foregroundStyle(FYColor.muted) }
                Section("Vorgaben") {
                    Stepper("\(entry.targetSets) Sätze", value: $entry.targetSets, in: 1...30)
                    Stepper("Mindestens \(entry.targetRepsMin) \(unit)", value: $entry.targetRepsMin, in: 1...999)
                    Stepper("Höchstens \(entry.targetRepsMax) \(unit)", value: $entry.targetRepsMax, in: 1...999)
                    TextField("Zielgewicht in kg (optional)", text: $weight).keyboardType(.decimalPad)
                    TextField("Notiz (optional)", text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                }
                if !isValid { Text("Prüfe den Bereich und das optionale Gewicht.").font(.caption).foregroundStyle(FYColor.coral) }
            }.scrollContentBackground(.hidden).background(FYColor.background)
                .navigationTitle("Übung anpassen").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Übernehmen") { entry.targetWeight = parsedWeight; onSave(entry); dismiss() }.disabled(!isValid) }
                }
        }.tint(FYColor.lime)
    }
    private var unit: String { entry.exercise.exerciseType == "timed" ? "Sekunden" : "Wiederholungen" }
    private var parsedWeight: Double? { Double(weight.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }
    private var isValid: Bool {
        entry.targetRepsMax >= entry.targetRepsMin && (weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedWeight.map { $0.isFinite && (0...2000).contains($0) } == true)
    }
}

struct WorkoutPlanDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    var linkedActivityID: UUID? = nil
    var sessionID: UUID? = nil
    var allowsStarting = true
    @State private var plan: WorkoutPlan?
    @State private var isLoading = true
    @State private var editPlan: WorkoutPlan?
    @State private var showsPlanning = false
    @State private var showsSharing = false
    @State private var showsLive = false
    @State private var copiedPlan: WorkoutPlan?
    @State private var confirmArchive = false
    @State private var showsIndependentTraining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let plan {
                    SportHeroCard(sport: .gym, title: plan.name, subtitle: "\(plan.exercises.count) Übungen · \(plan.category ?? "Dein Fokus")")
                    if let description = plan.description, !description.isEmpty { Text(description).foregroundStyle(FYColor.muted) }
                    ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 13) {
                            Text("\(index + 1)").font(.headline).foregroundStyle(FYColor.lime).frame(width: 25)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.exercise.name).font(.headline)
                                Text(entry.prescription).font(.subheadline).foregroundStyle(FYColor.muted)
                                Text("\(entry.exercise.primaryMuscle.title) · \(entry.exercise.equipment.title)").font(.caption).foregroundStyle(FYColor.muted)
                                if let note = entry.note, !note.isEmpty { Text(note).font(.caption).foregroundStyle(FYColor.muted) }
                            }; Spacer(minLength: 0)
                        }.fyCard()
                    }
                    Text("Du trainierst mit deinem eigenen Protokoll. Tatsächliche Gewichte und Wiederholungen bleiben privat.").font(.caption).foregroundStyle(FYColor.muted)
                    if allowsStarting { Button(linkedActivityID == nil ? "Mit diesem Plan starten" : "Diesen Plan einmal mittrainieren") {
                        Task {
                            await store.start(sport: .gym, subtype: plan.name, linked: linkedActivityID, plannedSessionID: sessionID, workoutPlanID: plan.id)
                            if store.errorMessage == nil && store.myActivity?.status == .live { showsLive = true }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(store.isBusy).accessibilityIdentifier("start-workout-plan") }
                    if plan.ownerID == store.profile?.id {
                        Button("Training planen & Freunde einladen") { showsPlanning = true }.buttonStyle(OutlineButtonStyle())
                        Button("Plan mit Freunden teilen") { showsSharing = true }.buttonStyle(OutlineButtonStyle())
                        Button("Plan archivieren", role: .destructive) { confirmArchive = true }.frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else {
                        Button("In meine Pläne kopieren") { Task { copiedPlan = await store.workouts.copyPlan(id: planID) } }
                            .buttonStyle(OutlineButtonStyle()).disabled(store.workouts.isBusy).accessibilityIdentifier("copy-workout-plan")
                    }
                } else if isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let error = store.workouts.errorMessage { WorkoutErrorBanner(message: error) { Task { await load() } } }
                if plan == nil && !isLoading && linkedActivityID != nil {
                    Text("Ein privater Plan muss zuerst mit dir geteilt werden. Du kannst inzwischen ein eigenes Training starten.").font(.subheadline).foregroundStyle(FYColor.muted)
                    Button("Eigenes Training starten") { showsIndependentTraining = true }.buttonStyle(OutlineButtonStyle())
                }
                if let error = store.errorMessage { Text(error).font(.callout).foregroundStyle(FYColor.coral) }
            }.padding(20)
        }.background(FYColor.background).navigationTitle("Trainingsplan").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbar { if let plan, plan.ownerID == store.profile?.id { Button("Bearbeiten") { editPlan = plan } } }
            .task(id: planID) { await load() }
            .fullScreenCover(item: $editPlan) { draft in WorkoutPlanEditorView(plan: draft) { plan = $0 } }
            .fullScreenCover(isPresented: $showsPlanning) { if let plan { ActivityComposerView(initialMode: 1, selectedWorkoutPlan: plan) } }
            .sheet(isPresented: $showsSharing) { WorkoutPlanShareView(planID: planID) }
            .fullScreenCover(isPresented: $showsIndependentTraining) { ActivityComposerView() }
            .navigationDestination(isPresented: $showsLive) { LiveActivityView() }
            .alert("Eigene Kopie gespeichert", isPresented: Binding(get: { copiedPlan != nil }, set: { if !$0 { copiedPlan = nil } })) {
                Button("OK") { copiedPlan = nil }
            } message: { Text("Du kannst sie unter Meine Pläne ändern. Das Original und eigene Übungen deines Freundes bleiben unverändert.") }
            .confirmationDialog("Plan archivieren?", isPresented: $confirmArchive) {
                Button("Archivieren", role: .destructive) { Task { if await store.workouts.archivePlan(id: planID) { dismiss() } } }
                Button("Behalten", role: .cancel) {}
            } message: { Text("Der Plan verschwindet aus deiner Auswahl. Abgeschlossene Trainings bleiben erhalten.") }
    }
    private func load() async { isLoading = true; plan = await store.workouts.plan(id: planID); isLoading = false }
}

private struct WorkoutPlanShareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State private var selected = Set<UUID>()
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Ausgewählte Freunde können den vollständigen Plan ansehen und als unabhängige Kopie speichern. Deine Trainingsprotokolle werden nicht geteilt.").font(.subheadline).foregroundStyle(FYColor.muted) }
                if store.crew.isEmpty { Text("Füge zuerst einen Freund zu deiner Crew hinzu.") }
                ForEach(store.crew) { member in
                    Button { selected.formSymmetricDifference([member.id]) } label: {
                        HStack { AvatarView(profile: member.profile); Text(member.profile.displayName).foregroundStyle(FYColor.ink); Spacer(); Image(systemName: selected.contains(member.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(FYColor.lime) }
                    }
                }
                if let error = store.workouts.errorMessage { Text(error).foregroundStyle(FYColor.coral) }
            }.scrollContentBackground(.hidden).background(FYColor.background).navigationTitle("Plan teilen")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Mit \(selected.count) Freunden teilen") { Task { if await store.workouts.sharePlan(id: planID, friendIDs: Array(selected)) { dismiss() } } }
                        .buttonStyle(PrimaryButtonStyle()).disabled(selected.isEmpty || store.workouts.isBusy).padding(16).background(.ultraThinMaterial)
                }
        }.tint(FYColor.lime)
    }
}

struct WorkoutErrorBanner: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle").font(.subheadline)
            Button("Erneut versuchen", action: retry).font(.subheadline.bold())
        }.foregroundStyle(FYColor.ink).frame(maxWidth: .infinity, alignment: .leading).fyCard().accessibilityIdentifier("workout-error")
    }
}
