import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var segment = "Alle"
    @State private var muscles: Set<MuscleGroup> = []
    @State private var showsMuscles = false
    @State private var showsNewExercise = false
    @State private var editingExercise: GymExercise?
    @State private var archivingExercise: GymExercise?
    let onSelect: (GymExercise) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted)
                        TextField("Übung oder Muskel suchen", text: $query).autocorrectionDisabled().accessibilityIdentifier("exercise-search")
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Suche löschen") }
                    }.padding(14).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 13))
                    Picker("Bibliothek", selection: $segment) { ForEach(["Alle", "Favoriten", "Eigene"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
                    Button { showsMuscles = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.stand").font(.title2).foregroundStyle(FYColor.lime)
                                .frame(width: 44, height: 48).background(FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Muskeln auswählen").font(.subheadline.bold())
                                Text(muscles.isEmpty ? "Entdecke deinen Fokus an der Körperfigur" : MuscleSelection.ordered(muscles).map(\.title).joined(separator: ", "))
                                    .font(.caption).foregroundStyle(FYColor.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(FYColor.muted)
                        }.foregroundStyle(FYColor.ink).fyCard()
                    }.buttonStyle(.plain).accessibilityIdentifier("open-library-muscles")
                    if !muscles.isEmpty {
                        HStack {
                            Text(filteredExercises.count == 1 ? "1 passende Übung" : "\(filteredExercises.count) passende Übungen").font(.caption).foregroundStyle(FYColor.muted)
                            Spacer()
                            Button("Alle Muskeln") { muscles = [] }.font(.caption.bold()).frame(minHeight: 44)
                                .accessibilityIdentifier("clear-library-muscles")
                        }
                    }
                    Button { showsNewExercise = true } label: { Label("Eigene Übung erstellen", systemImage: "plus.circle.fill") }
                        .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("create-custom-exercise")
                    if store.workouts.isLoadingLibrary && store.workouts.exercises.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                    if let error = store.workouts.errorMessage { WorkoutErrorBanner(message: error) { Task { await store.workouts.loadLibrary() } } }
                    if filteredExercises.isEmpty && !store.workouts.isLoadingLibrary && store.workouts.errorMessage == nil {
                        ContentUnavailableView("Keine passende Übung", systemImage: "magnifyingglass", description: Text("Passe deine Suche an oder erstelle oben deine eigene Übung."))
                    }
                    ForEach(filteredExercises) { exercise in exerciseRow(exercise) }
                }.padding(20)
            }.background(FYColor.background).navigationTitle("Übung auswählen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .task { await store.workouts.loadLibrary() }
                .sheet(isPresented: $showsNewExercise) {
                    if let userID = store.profile?.id {
                        CustomExerciseEditorView(exercise: GymExercise(name: query, primaryMuscle: MuscleSelection.ordered(muscles).first ?? .chest, createdBy: userID), isNew: true) { saved in
                            showsNewExercise = false
                            onSelect(saved)
                        }
                    }
                }
                .sheet(item: $editingExercise) { exercise in
                    CustomExerciseEditorView(exercise: exercise, isNew: false) { _ in editingExercise = nil }
                }
                .sheet(isPresented: $showsMuscles) {
                    NavigationStack {
                        ScrollView {
                            MuscleBodyPicker(selection: $muscles, identifierPrefix: "library-muscle").padding(20)
                        }.background(FYColor.background).navigationTitle("Muskelgruppen").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showsMuscles = false }.accessibilityIdentifier("apply-library-muscles") } }
                            .safeAreaInset(edge: .bottom) {
                                Button(filteredExercises.count == 1 ? "1 Übung ansehen" : "\(filteredExercises.count) Übungen ansehen") { showsMuscles = false }
                                    .buttonStyle(PrimaryButtonStyle()).padding(16).background(.ultraThinMaterial)
                                    .accessibilityIdentifier("show-muscle-exercises")
                            }
                    }.tint(FYColor.lime)
                }
                .confirmationDialog("Übung archivieren?", isPresented: Binding(get: { archivingExercise != nil }, set: { if !$0 { archivingExercise = nil } })) {
                    Button("Archivieren", role: .destructive) {
                        if let exercise = archivingExercise { Task { _ = await store.workouts.archiveExercise(id: exercise.id); archivingExercise = nil } }
                    }
                    Button("Behalten", role: .cancel) { archivingExercise = nil }
                } message: { Text("Die Übung verschwindet aus der normalen Auswahl. Bestehende Workout-Pläne und abgeschlossene Workouts bleiben erhalten.") }
        }.tint(FYColor.lime).preferredColorScheme(.light)
    }

    private var filteredExercises: [GymExercise] {
        store.workouts.exercises.filter { exercise in
            !exercise.isArchived
                && (segment != "Eigene" || (exercise.isCustom && exercise.createdBy == store.profile?.id))
                && (segment != "Favoriten" || store.workouts.favorites.contains(exercise.id))
                && MuscleSelection.matches(exercise, selected: muscles)
                && exercise.matches(query: query)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func exerciseRow(_ exercise: GymExercise) -> some View {
        HStack(spacing: 11) {
            Button { onSelect(exercise) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell").foregroundStyle(FYColor.lime).frame(width: 34, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name).font(.subheadline.bold()).foregroundStyle(FYColor.ink)
                        Text("\(exercise.primaryMuscle.title) · \(exercise.equipment.title)").font(.caption).foregroundStyle(FYColor.muted)
                        if !muscles.isEmpty && !exercise.secondaryMuscles.isEmpty {
                            Text("Zusätzlich: \(exercise.secondaryMuscles.map(\.title).joined(separator: ", "))")
                                .font(.caption2).foregroundStyle(FYColor.muted)
                        }
                        if exercise.isCustom { Text("Eigene Übung").font(.caption2.bold()).foregroundStyle(FYColor.lime) }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus.circle").foregroundStyle(FYColor.lime)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("exercise-\(exercise.id.uuidString.lowercased())")
            Button { Task { await store.workouts.toggleFavorite(id: exercise.id) } } label: {
                Image(systemName: store.workouts.favorites.contains(exercise.id) ? "star.fill" : "star").foregroundStyle(FYColor.planned).frame(width: 44, height: 44)
            }.buttonStyle(.plain).disabled(store.workouts.isBusy)
                .accessibilityLabel("\(exercise.name): \(store.workouts.favorites.contains(exercise.id) ? "Favorit entfernen" : "Als Favorit speichern")")
            if exercise.isCustom && exercise.createdBy == store.profile?.id {
                Menu {
                    Button("Bearbeiten") { editingExercise = exercise }
                    Button("Archivieren", role: .destructive) { archivingExercise = exercise }
                } label: { Image(systemName: "ellipsis").foregroundStyle(FYColor.muted).frame(width: 35, height: 44) }
                    .accessibilityLabel("\(exercise.name) verwalten")
            }
        }.fyCard()
    }
}

private struct CustomExerciseEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GymExercise
    @State private var duplicateConfirmed = false
    let isNew: Bool
    let onSaved: (GymExercise) -> Void
    init(exercise: GymExercise, isNew: Bool, onSaved: @escaping (GymExercise) -> Void) {
        _draft = State(initialValue: exercise); self.isNew = isNew; self.onSaved = onSaved
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Deine Übung") {
                    TextField("z. B. Prime Chest Press", text: $draft.name).accessibilityLabel("Übungsname").accessibilityIdentifier("custom-exercise-name")
                    Picker("Hauptmuskel", selection: $draft.primaryMuscle) { ForEach(MuscleGroup.allCases) { Text($0.title).tag($0) } }
                    Picker("Equipment (optional)", selection: $draft.equipment) { ForEach(ExerciseEquipment.allCases) { Text($0.title).tag($0) } }
                    Picker("Vorgabe", selection: $draft.exerciseType) { Text("Wiederholungen").tag("strength"); Text("Halten / Sekunden").tag("timed") }
                }
                Section("Weitere Muskeln (optional)") {
                    ForEach(MuscleGroup.allCases.filter { $0 != draft.primaryMuscle }) { group in
                        Button {
                            if draft.secondaryMuscles.contains(group) { draft.secondaryMuscles.removeAll { $0 == group } }
                            else { draft.secondaryMuscles.append(group) }
                        } label: {
                            HStack { Text(group.title).foregroundStyle(FYColor.ink); Spacer(); Image(systemName: draft.secondaryMuscles.contains(group) ? "checkmark.circle.fill" : "circle").foregroundStyle(FYColor.lime) }
                        }.accessibilityAddTraits(draft.secondaryMuscles.contains(group) ? .isSelected : [])
                    }
                }
                Section { TextField("Notiz (optional)", text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0.isEmpty ? nil : $0 }), axis: .vertical) }
                if isNew, !duplicates.isEmpty, !duplicateConfirmed {
                    Section {
                        Text("Ähnliche Übung gefunden. Möchtest du sie verwenden?").font(.subheadline)
                        ForEach(Array(duplicates.prefix(3))) { exercise in
                            Button("\(exercise.name) verwenden") { onSaved(exercise); dismiss() }
                        }
                        Button("Trotzdem eigene erstellen") { duplicateConfirmed = true }
                    } header: { Text("Schon in deiner Bibliothek?") }
                }
                if let error = store.workouts.errorMessage { Section { Text(error).foregroundStyle(FYColor.coral) } }
            }.disabled(store.workouts.isBusy).scrollContentBackground(.hidden).background(FYColor.background)
                .navigationTitle(isNew ? "Eigene Übung" : "Übung bearbeiten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(store.workouts.isBusy) } }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 5) {
                        Text("Nur du kannst deine Übung ändern. Geteilte Plankopien bleiben unabhängig.").font(.caption).foregroundStyle(FYColor.muted)
                        Button(isNew ? "Erstellen & hinzufügen" : "Änderungen speichern") {
                            Task {
                                draft.secondaryMuscles.removeAll { $0 == draft.primaryMuscle }
                                if let saved = await store.workouts.saveExercise(draft) { onSaved(saved); dismiss() }
                            }
                        }.buttonStyle(PrimaryButtonStyle()).disabled(!canSave || store.workouts.isBusy).accessibilityIdentifier("save-custom-exercise")
                    }.padding(16).background(.ultraThinMaterial)
                }
                .onChange(of: draft.name) { _, _ in duplicateConfirmed = false }
                .onChange(of: draft.primaryMuscle) { _, value in draft.secondaryMuscles.removeAll { $0 == value } }
        }.tint(FYColor.lime).interactiveDismissDisabled(store.workouts.isBusy)
    }
    private var canSave: Bool { draft.validationMessage == nil && (!isNew || duplicates.isEmpty || duplicateConfirmed) }
    private var duplicates: [GymExercise] {
        guard draft.normalizedName.count >= 3 else { return [] }
        return store.workouts.exercises.filter { $0.id != draft.id && !$0.isArchived && $0.hasSimilarName(to: draft.name) }
    }
}
