import SwiftUI
import UIKit

/// A deliberately small export, independent of the activity/feed visibility.
/// Names, IDs, location, notes, prescriptions and actual measurements never enter it.
struct WorkoutShareSummary: Identifiable, Equatable {
    let id = UUID()
    let ownerID: UUID
    let text: String

    init?(activity: Activity, log: WorkoutLog, ownerID: UUID?) {
        guard let ownerID, activity.userID == ownerID, activity.status == .completed,
              activity.id == log.activityID, log.validationMessage == nil,
              let start = activity.startedAt, let end = activity.endedAt,
              start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, end >= start,
              let duration = activity.duration, duration.isFinite, duration >= 0, duration < Double(Int.max) else { return nil }
        let seconds = Int(duration)
        let time = [seconds / 3600, seconds / 60 % 60, seconds % 60]
            .map { $0 < 10 ? "0\($0)" : String($0) }.joined(separator: ":")
        self.ownerID = ownerID
        let exerciseCount = log.exercises.count == 1 ? "1 Übung" : "\(log.exercises.count) Übungen"
        text = "Workout geschafft mit FYRUP! 💪\n\(activity.sport.title) · \(time) aktive Zeit\n\(log.completedExercises) von \(exerciseCount) abgeschlossen."
    }
}

/// Optional actual measurements. Empty fields stay empty; targets are never copied into them.
struct WorkoutSetEntryInput: Codable, Equatable, Sendable {
    var weight: String = ""
    var reps: String = ""

    init(weight: String = "", reps: String = "") { self.weight = weight; self.reps = reps }
    init(set: WorkoutSetLog) {
        weight = set.weight.map { value in
            let text = String(value)
            return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        } ?? ""
        reps = set.reps.map(String.init) ?? ""
    }

    var validationMessage: String? {
        let weightText = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let repsText = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        if !weightText.isEmpty {
            guard let parsed = Double(weightText.replacingOccurrences(of: ",", with: ".")), WorkoutLimits.accepts(weight: parsed) else { return "Trage ein gültiges Gewicht von 0 bis 2.000 kg ein oder lass das Feld leer." }
        }
        if !repsText.isEmpty {
            guard let parsed = Int(repsText), WorkoutLimits.actualReps.contains(parsed) else { return "Trage eine ganze Zahl von 0 bis 999 ein oder lass das Feld leer." }
        }
        return nil
    }

    func applying(to original: WorkoutSetLog, completed: Bool) throws -> WorkoutSetLog {
        if let validationMessage { throw AppError.validation(validationMessage) }
        var result = original
        result.weight = Double(weight.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
        result.reps = Int(reps.trimmingCharacters(in: .whitespacesAndNewlines))
        result.completed = completed
        return result
    }
}

@MainActor
struct WorkoutTrackingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var activityID: UUID? = nil
    @State private var capturedID: UUID?
    @State private var capturedOwnerID: UUID?
    @State private var activitySnapshot: Activity?
    @State private var confirmed: WorkoutLog?
    @State private var pending: WorkoutLog?
    @State private var completedActivity: Activity?
    @State private var editingSet: TrackingSetSelection?
    @State private var mode = TrackingMode.easy
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: String?
    @State private var confirmsFinish = false
    @State private var confirmsCancel = false
    @State private var confirmsLeave = false
    @State private var shareSummary: WorkoutShareSummary?
    @State private var completionCelebration: UUID?
    @State private var draftConflict = false
    @State private var confirmsDiscardDrafts = false

    private var displayed: WorkoutLog? { pending ?? confirmed }
    private var currentActivity: Activity? {
        if store.myActivity?.id == capturedID { return store.myActivity }
        return completedActivity ?? activitySnapshot
    }
    private var controlsDisabled: Bool { isLoading || isSaving || store.isBusy || store.workouts.isBusy || completedActivity != nil }
    private var hasLocalInputs: Bool { capturedID.map { store.trackingDrafts.hasInput(activityID: $0) } == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let completedActivity, let confirmed {
                    WorkoutResultHeader(activity: completedActivity, log: confirmed)
                    WorkoutFeedbackButton(activityID: completedActivity.id)
                    WorkoutRecordedExercises(log: confirmed)
                } else if let log = displayed, let activity = currentActivity {
                    liveHeader(activity: activity, log: log)
                    WorkoutRestView(activityID: activity.id)
                    if pending != nil { pendingBanner }
                    if hasLocalInputs || draftConflict { localDraftBanner }
                    if let error = store.trackingDrafts.errorMessage { errorBanner(error) }
                    if let message { errorBanner(message) }
                    Picker("Workout-Modus", selection: $mode) {
                        ForEach(TrackingMode.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("tracking-mode").disabled(controlsDisabled)
                    Text(mode == .easy ? "Einfach loslegen und Übungen abhaken. Gewichte und Wiederholungen musst du nicht eintragen." : "Halte deine tatsächlichen Sätze fest. Alle Werte sind freiwillig und bleiben privat.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                    ForEach(Array(log.exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseCard(exercise, index: index)
                    }
                    if let activity = currentActivity, activity.status == .live {
                        Button(activity.pausedAt == nil ? "Workout pausieren" : "Workout fortsetzen") {
                            Task {
                                await store.setPaused(activity.pausedAt == nil)
                                if let error = store.errorMessage { message = error }
                            }
                        }.buttonStyle(OutlineButtonStyle()).disabled(controlsDisabled)
                            .accessibilityIdentifier("pause-plan-workout")
                        Button("Workout abschließen") { confirmsFinish = true }
                            .buttonStyle(PrimaryButtonStyle()).disabled(controlsDisabled || hasLocalInputs || draftConflict)
                            .accessibilityIdentifier("finish-plan-workout")
                        Button("Workout abbrechen") { confirmsCancel = true }
                            .font(.footnote).foregroundStyle(FYColor.coral).frame(maxWidth: .infinity, minHeight: 44).disabled(controlsDisabled)
                    }
                } else if isLoading {
                    ProgressView("Dein Workout wird geladen …").frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    ContentUnavailableView("Workout nicht geladen", systemImage: "arrow.clockwise", description: Text("Dein Workout ist nicht verloren. Lade das Protokoll erneut."))
                    if let message { errorBanner(message) }
                    Button("Erneut laden") { Task { await load() } }.buttonStyle(PrimaryButtonStyle())
                }
            }.padding(20).padding(.bottom, completedActivity == nil ? 72 : 24)
        }
        .safeAreaInset(edge: .bottom) {
            if let completedActivity {
                // Keep both actions in the visible footer. A scroll-content action could
                // otherwise sit behind this footer while iOS still reports it as hittable.
                VStack(spacing: 10) {
                    if let confirmed, let summary = WorkoutShareSummary(activity: completedActivity, log: confirmed, ownerID: store.profile?.id) {
                        Button { shareSummary = summary } label: { Label("Mit Freunden teilen", systemImage: "square.and.arrow.up") }
                            .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("preview-workout-share")
                    }
                    Button("Fertig") { dismiss() }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("finish-workout-summary")
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 44)
                .background(FYColor.background)
            }
        }
        .background(FYColor.background).navigationTitle(completedActivity == nil ? "Dein Workout" : "Geschafft")
        .overlay { TrainingConfetti(trigger: completionCelebration) }
        .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-tracking-screen")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { if pending != nil { confirmsLeave = true } else { dismiss() } } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Zurück").disabled(isSaving)
            }
        }
        .interactiveDismissDisabled(pending != nil || isSaving)
        .task { await load() }
        .onChange(of: store.profile?.id) { _, owner in
            guard owner != capturedOwnerID else { return }
            confirmed = nil; pending = nil; activitySnapshot = nil; completedActivity = nil; editingSet = nil; shareSummary = nil
            dismiss()
        }
        .sheet(item: $editingSet) { selection in
            WorkoutSetEntrySheet(selection: selection) { updated in await saveSet(updated, exerciseID: selection.exerciseID) }
        }
        .sheet(item: $shareSummary) { summary in WorkoutSharePreviewView(summary: summary) }
        .confirmationDialog("Workout abschließen?", isPresented: $confirmsFinish, titleVisibility: .visible) {
            Button("Workout abschließen") { Task { await finish() } }
            Button("Weitermachen", role: .cancel) {}
        } message: {
            Text("\(displayed?.completedExercises ?? 0) von \(displayed?.exercises.count ?? 0) Übungen abgehakt. Deine bestätigten Eingaben bleiben gespeichert. Nicht abgehakte Übungen werden nicht automatisch als erledigt markiert.")
        }
        .confirmationDialog("Workout abbrechen?", isPresented: $confirmsCancel, titleVisibility: .visible) {
            Button("Workout abbrechen", role: .destructive) { Task { await cancel() } }
            Button("Weitermachen", role: .cancel) {}
        } message: { Text("Das ist okay. Ein abgebrochenes Workout zählt nicht zum Wochenziel. Lokale, noch nicht gespeicherte Satzentwürfe werden beim Abbruch verworfen.") }
        .confirmationDialog("Noch nicht gespeicherte Eingaben", isPresented: $confirmsLeave, titleVisibility: .visible) {
            Button("Speichern und schließen") { Task { if let pending, await save(pending) { dismiss() } } }
            Button("Hier bleiben", role: .cancel) {}
        } message: { Text("Deine letzten Eingaben konnten noch nicht bestätigt werden. Bleibe hier und versuche es erneut.") }
        .confirmationDialog("Lokale Eingaben verwerfen?", isPresented: $confirmsDiscardDrafts, titleVisibility: .visible) {
            Button("Lokale Eingaben verwerfen", role: .destructive) {
                if let id = capturedID { store.trackingDrafts.clearActivity(id) }
                pending = nil; draftConflict = false
            }
            Button("Behalten", role: .cancel) {}
        } message: { Text("Nur noch nicht bestätigte Eingaben auf diesem Gerät werden entfernt. Dein gespeichertes Protokoll bleibt unverändert.") }
    }

    private func liveHeader(activity: Activity, log: WorkoutLog) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LiveSessionVisual(activity: activity, title: log.planName)
            HStack {
                Label(activity.pausedAt == nil ? "LIVE" : "PAUSIERT", systemImage: activity.pausedAt == nil ? "circle.fill" : "pause.circle.fill")
                    .font(.caption.bold()).foregroundStyle(activity.pausedAt == nil ? FYColor.live : FYColor.muted)
                Spacer()
                Label("Privates Protokoll", systemImage: "lock.fill").font(.caption2).foregroundStyle(FYColor.muted)
            }
            HStack {
                Text("\(confirmed?.completedExercises ?? 0) / \(confirmed?.exercises.count ?? 0) Übungen").font(.subheadline.bold())
                Spacer()
                if activity.pausedAt != nil { Text("Deine Pause läuft").font(.caption).foregroundStyle(FYColor.muted) }
            }
            ProgressView(value: confirmed?.progress ?? 0).tint(FYColor.lime)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: confirmed?.progress)
                .accessibilityLabel("Gespeicherter Workout-Fortschritt")
            if let next = confirmed?.currentExercise {
                Text("Als Nächstes: \(next.exercise.name)").font(.footnote).foregroundStyle(FYColor.muted)
            }
        }.fyCard()
    }

    private var pendingBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Noch nicht gespeichert", systemImage: "icloud.slash").font(.subheadline.bold())
            Text("Deine Eingaben sind hier noch vorhanden. Der Fortschritt zählt erst nach erfolgreichem Speichern.").font(.caption)
            Button("Speichern erneut versuchen") { Task { if let pending { _ = await save(pending) } } }
                .font(.subheadline.bold()).disabled(controlsDisabled).accessibilityIdentifier("retry-workout-log")
            Button("Lokale Eingaben verwerfen") { confirmsDiscardDrafts = true }.font(.caption).disabled(controlsDisabled)
        }.foregroundStyle(FYColor.ink).padding(16).background(FYColor.planned.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var localDraftBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lokale Eingaben vorhanden", systemImage: "square.and.pencil").font(.subheadline.bold())
            Text(draftConflict ? "Das gespeicherte Protokoll hat sich inzwischen geändert. Dein lokaler Entwurf wird nicht darübergeschrieben. Prüfe den aktuellen Stand oder verwirf den Entwurf." : "Öffne den zugehörigen Satz im Tracking-Modus. Deine noch nicht gespeicherten Texte werden dort wiederhergestellt. Vor dem Abschluss kannst du sie speichern oder verwerfen.")
                .font(.footnote)
            Button("Lokale Eingaben verwerfen") { confirmsDiscardDrafts = true }.font(.caption.bold()).disabled(controlsDisabled)
        }.fyCard().accessibilityIdentifier("restored-tracking-draft")
    }

    private func errorBanner(_ value: String) -> some View {
        Label(value, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(FYColor.coral)
            .accessibilityIdentifier("tracking-error")
    }

    private func exerciseCard(_ exercise: WorkoutExerciseLog, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.headline).foregroundStyle(FYColor.lime)
                    .frame(width: 38, height: 38).background(FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.exercise.name).font(.headline)
                    Text(trackingPrescription(exercise)).font(.subheadline).foregroundStyle(FYColor.muted)
                    Text(exercise.exercise.subtitle).font(.caption).foregroundStyle(FYColor.muted)
                    if let weight = exercise.targetWeight {
                        Text("Zielgewicht: \(weight.formatted(.number.precision(.fractionLength(0...2)))) kg · keine erfasste Leistung")
                            .font(.caption).foregroundStyle(FYColor.muted)
                    }
                    if let value = store.workouts.performance[exercise.exercise.id] {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Dein letzter Stand", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption.bold()).foregroundStyle(FYColor.ink)
                            Text("Zuletzt: \(performanceValue(weight: value.lastWeight, reps: value.lastReps, unit: exercise.exercise.repetitionUnit)) · \(value.lastCompletedAt.formatted(date: .abbreviated, time: .omitted))")
                            Text("Bestwert: \(performanceValue(weight: value.bestWeight, reps: value.bestReps, unit: exercise.exercise.repetitionUnit))")
                        }
                        .font(.caption).foregroundStyle(FYColor.muted).padding(.top, 3)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("exercise-performance-\(exercise.exercise.id.uuidString)")
                    }
                }
                Spacer(minLength: 0)
                if confirmed?.exercises.first(where: { $0.id == exercise.id })?.completed == true {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime).font(.title3)
                        .accessibilityLabel("Gespeichert abgeschlossen")
                }
            }
            if let note = exercise.note, !note.isEmpty { Text(note).font(.footnote).foregroundStyle(FYColor.muted) }
            if mode == .track {
                VStack(spacing: 7) {
                    ForEach(exercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in
                        Button {
                            editingSet = TrackingSetSelection(exerciseID: exercise.id, exerciseName: exercise.exercise.name, unit: exercise.exercise.repetitionUnit, set: set, draftContext: draftContext(exerciseID: exercise.id, setID: set.id))
                        } label: { WorkoutSetRow(set: set, unit: exercise.exercise.repetitionUnit, editable: true) }
                            .buttonStyle(.plain).disabled(controlsDisabled)
                            .accessibilityIdentifier("workout-set-\(index)-\(set.setNumber)")
                    }
                    if exercise.sets.count < WorkoutLimits.targetSets.upperBound {
                        Button { Task { await addSet(exerciseID: exercise.id) } } label: { Label("Satz hinzufügen", systemImage: "plus") }
                            .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44).disabled(controlsDisabled)
                    }
                }
            }
            if let activityID = capturedID {
                ExerciseEffortControl(activityID: activityID, exerciseID: exercise.id).disabled(controlsDisabled)
            }
            Button {
                Task { await setExerciseCompleted(exerciseID: exercise.id, completed: !exercise.completed) }
            } label: {
                Label(exercise.completed ? "Übung wieder öffnen" : "Übung fertig", systemImage: exercise.completed ? "arrow.uturn.backward" : "checkmark.circle")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 46)
                    .background(exercise.completed ? FYColor.elevated : FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).foregroundStyle(FYColor.ink).disabled(controlsDisabled)
                .accessibilityIdentifier("complete-workout-exercise-\(index)")
        }.fyCard().accessibilityElement(children: .contain).accessibilityIdentifier("workout-exercise-\(index)")
    }

    private func performanceValue(weight: Double?, reps: Int?, unit: String) -> String {
        let repetitions = reps.map { "\($0) \(unit)" }
        let load = weight.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) kg" }
        return [load, repetitions].compactMap { $0 }.joined(separator: " × ")
    }

    private func draftContext(exerciseID: UUID, setID: UUID) -> WorkoutSetDraftContext? {
        guard let owner = store.profile?.id, let activity = currentActivity, let log = displayed else { return nil }
        return .workout(ownerID: owner, activity: activity, log: log, exerciseID: exerciseID, setID: setID)
    }

    private func load() async {
        guard confirmed == nil, !isSaving else { return }
        capturedOwnerID = store.profile?.id
        let owner = capturedOwnerID
        let id = capturedID ?? activityID ?? store.myActivity?.id
        capturedID = id
        guard let id else { isLoading = false; message = "Es ist gerade kein Workout geöffnet."; return }
        isLoading = true
        if store.myActivity?.id == id { activitySnapshot = store.myActivity }
        else { activitySnapshot = store.recentActivities.first { $0.id == id } }
        let result = await store.workouts.loadLog(activityID: id)
        guard !Task.isCancelled, owner == store.profile?.id else { return }
        isLoading = false
        if let result {
            confirmed = result; message = nil
            if activitySnapshot?.status == .completed { completedActivity = activitySnapshot }
            if let activity = currentActivity {
                switch store.trackingDrafts.recoverPending(activity: activity, confirmed: result) {
                case .restored(let draft): pending = draft
                case .conflict: draftConflict = true
                case .none, .alreadySaved: break
                }
                if store.trackingDrafts.hasInput(activityID: activity.id) { mode = .track }
            }
        } else { message = store.workouts.errorMessage ?? "Das Protokoll konnte nicht geladen werden." }
    }

    @discardableResult private func save(_ candidate: WorkoutLog, retainOnFailure: Bool = true) async -> Bool {
        guard !isSaving, !store.workouts.isBusy, capturedOwnerID == store.profile?.id else { return false }
        isSaving = true; message = nil
        defer { isSaving = false }
        if retainOnFailure, let baseline = confirmed, let activity = currentActivity {
            _ = store.trackingDrafts.savePending(candidate, baseline: baseline, activity: activity)
        }
        guard let saved = await store.workouts.saveLog(candidate), capturedOwnerID == store.profile?.id else {
            if retainOnFailure && capturedOwnerID == store.profile?.id { pending = candidate }
            message = store.workouts.errorMessage ?? "Nicht gespeichert. Deine Eingaben bleiben erhalten."
            return false
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { confirmed = saved; pending = nil }
        store.trackingDrafts.removePending(activityID: saved.activityID)
        draftConflict = false
        Haptics.impact(.light)
        return true
    }

    private func setExerciseCompleted(exerciseID: UUID, completed: Bool) async {
        guard var candidate = displayed, let index = candidate.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        candidate.exercises[index].completed = completed
        _ = await save(candidate)
    }

    private func saveSet(_ updated: WorkoutSetLog, exerciseID: UUID) async -> Bool {
        guard var candidate = displayed, let exerciseIndex = candidate.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = candidate.exercises[exerciseIndex].sets.firstIndex(where: { $0.setNumber == updated.setNumber }) else { return false }
        candidate.exercises[exerciseIndex].sets[setIndex] = updated
        // The sheet retains unsaved text. Discarding that sheet must not leave a hidden pending edit.
        return await save(candidate, retainOnFailure: false)
    }

    private func addSet(exerciseID: UUID) async {
        guard var candidate = displayed, let index = candidate.exercises.firstIndex(where: { $0.id == exerciseID }), candidate.exercises[index].sets.count < 30 else { return }
        let taken = Set(candidate.exercises[index].sets.map(\.setNumber))
        guard let next = (1...30).first(where: { !taken.contains($0) }) else { return }
        candidate.exercises[index].sets.append(WorkoutSetLog(setNumber: next))
        _ = await save(candidate)
    }

    private func finish() async {
        guard let id = capturedID, let candidate = displayed, !controlsDisabled, !hasLocalInputs, !draftConflict, store.myActivity?.id == id else { return }
        // Saving is deliberately awaited even without changes: completion never outruns persistence.
        guard await save(candidate), capturedOwnerID == store.profile?.id else { return }
        let finished = await store.finish(distanceMeters: nil)
        guard capturedOwnerID == store.profile?.id else { return }
        if let finished {
            store.trackingDrafts.clearActivity(finished.id)
            completedActivity = finished; activitySnapshot = finished; message = nil; completionCelebration = UUID()
            await store.weekly.prepareCelebration()
        } else { message = store.errorMessage ?? "Der Abschluss wurde noch nicht bestätigt. Versuche es erneut." }
    }

    private func cancel() async {
        guard store.myActivity?.id == capturedID, !controlsDisabled else { return }
        if let pending, !(await save(pending)) { return }
        await store.cancelCurrent()
        if store.errorMessage == nil, store.myActivity?.id != capturedID {
            if let id = capturedID { store.trackingDrafts.clearActivity(id) }
            dismiss()
        }
        else { message = store.errorMessage ?? "Der Abbruch wurde noch nicht bestätigt." }
    }
}

enum TrackingMode: String, CaseIterable, Identifiable {
    case easy, track
    var id: String { rawValue }
    var title: String { self == .easy ? "Einfach" : "Tracken" }
}

struct TrackingSetSelection: Identifiable {
    let exerciseID: UUID
    let exerciseName: String
    let unit: String
    let set: WorkoutSetLog
    var isBlind = false
    var draftContext: WorkoutSetDraftContext? = nil
    var id: UUID { self.set.id }
}

@MainActor
struct WorkoutSetEntrySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let selection: TrackingSetSelection
    let onSave: (WorkoutSetLog) async -> Bool
    @State private var input: WorkoutSetEntryInput
    @State private var isSaving = false
    @State private var error: String?
    @State private var confirmsDiscard = false
    @State private var didRestore = false
    @State private var restored = false
    @State private var conflictingInput: WorkoutSetEntryInput?

    init(selection: TrackingSetSelection, onSave: @escaping (WorkoutSetLog) async -> Bool) {
        self.selection = selection; self.onSave = onSave
        _input = State(initialValue: WorkoutSetEntryInput(set: selection.set))
    }

    private var hasChanges: Bool {
        let original = WorkoutSetEntryInput(set: selection.set)
        return original.weight != input.weight || original.reps != input.reps
    }

    private var isAuthorized: Bool {
        guard let context = selection.draftContext, store.profile?.id == context.key.ownerID,
              store.trackingDrafts.userID == context.key.ownerID else { return false }
        if let blindID = context.key.blindWorkoutID {
            guard let state = store.blind.state(id: blindID) else { return false }
            return WorkoutSetDraftContext.blind(ownerID: context.key.ownerID, state: state, exerciseID: context.key.exerciseID, setID: context.key.setID) != nil
        }
        return store.myActivity?.id == context.key.activityID && store.myActivity?.status == .live
    }

    private var validationMessage: String? {
        if let message = input.validationMessage { return message }
        guard selection.isBlind else { return nil }
        if let weight = Double(input.weight.replacingOccurrences(of: ",", with: ".")), weight > 500 { return "Prüfe das Gewicht. Für Blind Workouts sind höchstens 500 kg erfassbar." }
        let limit = selection.unit == "Sek." ? 300 : 30
        if let reps = Int(input.reps), reps > limit { return "Für dieses Blind Workout sind höchstens \(limit) \(selection.unit) pro Satz erfassbar." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if restored { Label("Lokaler Satzentwurf wiederhergestellt", systemImage: "arrow.counterclockwise").font(.footnote).accessibilityIdentifier("restored-set-draft") }
                if let conflictingInput {
                    Section {
                        Text("Dieser Satz wurde inzwischen geändert. Deine alten Eingaben sind noch lokal vorhanden und werden nicht automatisch übernommen.").font(.footnote)
                        Button("Lokale Eingaben prüfen") { input = conflictingInput; self.conflictingInput = nil; restored = true }
                        Button("Alten Entwurf verwerfen", role: .destructive) { removeDraft(); self.conflictingInput = nil }
                    }
                }
                Section {
                    Text(selection.exerciseName).font(.headline)
                    Text("Trage nur ein, was du wirklich gemacht hast. Beide Felder dürfen leer bleiben.").font(.footnote).foregroundStyle(FYColor.muted)
                }
                Section("Deine tatsächlichen Werte") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gewicht (kg)").font(.subheadline.bold())
                            .accessibilityIdentifier("set-weight-label")
                        TextField("Optional", text: $input.weight).keyboardType(.decimalPad)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Gewicht in kg").accessibilityIdentifier("set-weight")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selection.unit == "Sek." ? "Zeit (Sekunden)" : "Wiederholungen")
                            .font(.subheadline.bold()).accessibilityIdentifier("set-reps-label")
                        TextField("Optional", text: $input.reps).keyboardType(.numberPad)
                            .frame(minHeight: 44)
                            .accessibilityLabel(selection.unit == "Sek." ? "Sekunden" : "Wiederholungen").accessibilityIdentifier("set-reps")
                    }
                }
                if let validation = validationMessage { Text(validation).font(.footnote).foregroundStyle(FYColor.coral) }
                if let error { Text(error).font(.footnote).foregroundStyle(FYColor.coral).accessibilityIdentifier("set-save-error") }
                if let error = store.trackingDrafts.errorMessage { Text(error).font(.footnote).foregroundStyle(FYColor.coral) }
                Section {
                    Button(selection.set.completed ? "Abgeschlossenen Satz speichern" : "Satz abschließen") { Task { await save(completed: true) } }
                        .accessibilityIdentifier("save-workout-set")
                    Button("Nur Werte speichern") { Task { await save(completed: selection.set.completed) } }
                    if selection.set.completed {
                        Button("Satz wieder öffnen") { Task { await save(completed: false) } }
                    }
                }.disabled(isSaving || validationMessage != nil || conflictingInput != nil)
            }.disabled(isSaving || !isAuthorized)
                .scrollContentBackground(.hidden).background(FYColor.background)
                .navigationTitle("Satz \(selection.set.setNumber)").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { if hasChanges || conflictingInput != nil { confirmsDiscard = true } else { removeDraft(); dismiss() } }.disabled(isSaving)
                    }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Tastatur schließen") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
                }
                .confirmationDialog("Eingaben verwerfen?", isPresented: $confirmsDiscard) {
                    Button("Eingaben verwerfen", role: .destructive) { removeDraft(); dismiss() }
                    Button("Weiter bearbeiten", role: .cancel) {}
                }
                .interactiveDismissDisabled(hasChanges || isSaving || error != nil)
                .task { restoreDraft() }
                .onChange(of: input) { _, input in
                    guard didRestore, isAuthorized, conflictingInput == nil, let context = selection.draftContext else { return }
                    _ = store.trackingDrafts.saveInput(input, context: context)
                }
                .onChange(of: isAuthorized) { _, authorized in if !authorized { dismiss() } }
        }.tint(FYColor.lime)
    }

    private func save(completed: Bool) async {
        guard !isSaving, isAuthorized, validationMessage == nil, conflictingInput == nil else { return }
        isSaving = true; error = nil
        defer { isSaving = false }
        do {
            let updated = try input.applying(to: selection.set, completed: completed)
            if let context = selection.draftContext { _ = store.trackingDrafts.saveInput(input, context: context) }
            let saved = await onSave(updated)
            guard isAuthorized else { return }
            if saved { removeDraft(); dismiss() }
            else { error = "Nicht gespeichert. Deine Eingaben bleiben hier erhalten. Versuche es erneut." }
        } catch { self.error = error.localizedDescription }
    }

    private func restoreDraft() {
        guard !didRestore, isAuthorized, let context = selection.draftContext else { return }
        switch store.trackingDrafts.input(for: context) {
        case .none: break
        case .restored(let value): input = value; restored = true
        case .conflict(let value): conflictingInput = value
        }
        didRestore = true
    }
    private func removeDraft() {
        if let context = selection.draftContext { store.trackingDrafts.removeInput(context: context) }
    }
}

@MainActor
struct WorkoutHistoryView: View {
    @Environment(AppStore.self) private var store
    let activityID: UUID
    @State private var log: WorkoutLog?
    @State private var isLoading = true
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let log {
                    Text(log.planName).font(.title.bold())
                    Label("Dein privates Workout-Protokoll", systemImage: "lock.fill").font(.footnote).foregroundStyle(FYColor.muted)
                    WorkoutFeedbackButton(activityID: activityID)
                    HStack { WorkoutSummaryMetric(value: "\(log.completedExercises)/\(log.exercises.count)", title: "Übungen"); WorkoutSummaryMetric(value: "\(log.completedSets)", title: "Erfasste Sätze") }.fyCard()
                    WorkoutRecordedExercises(log: log)
                } else if isLoading { ProgressView("Protokoll wird geladen …").frame(maxWidth: .infinity, minHeight: 160) }
                if let message {
                    Text(message).foregroundStyle(FYColor.coral).font(.footnote)
                    Button("Erneut laden") { Task { await load() } }.buttonStyle(OutlineButtonStyle())
                }
            }.padding(20).padding(.bottom, 72)
        }.background(FYColor.background).navigationTitle("Workout-Protokoll").navigationBarTitleDisplayMode(.inline)
            .task(id: activityID) { await load() }
            .onChange(of: store.profile?.id) { _, _ in log = nil; message = nil }
    }
    private func load() async {
        isLoading = true; message = nil
        let owner = store.profile?.id
        let loaded = await store.workouts.loadLog(activityID: activityID)
        guard !Task.isCancelled, owner == store.profile?.id else { return }
        log = loaded; isLoading = false
        if loaded == nil { message = store.workouts.errorMessage ?? "Dein Protokoll konnte nicht geladen werden." }
    }
}

private struct WorkoutSharePreviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutShareSummary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.profile?.id == summary.ownerID {
                        Label("Dein Moment. Deine Entscheidung.", systemImage: "square.and.arrow.up")
                            .font(.title3.bold()).foregroundStyle(FYColor.ink)
                        Text("Nur dieser Text wird zum Teilen vorbereitet:").font(.subheadline).foregroundStyle(FYColor.muted)
                        Text(summary.text).font(.body).frame(maxWidth: .infinity, alignment: .leading).fyCard()
                            .accessibilityIdentifier("workout-share-text")
                        Text("Keine Übungsnamen, Gewichte, Wiederholungen, Notizen oder Orte. Dein privater Plan und deine Satzdaten bleiben in FYRUP. Die Sichtbarkeit deiner Aktivität wird nicht geändert.")
                            .font(.footnote).foregroundStyle(FYColor.muted)
                        ShareLink(item: summary.text) { Label("Zusammenfassung teilen", systemImage: "square.and.arrow.up") }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("confirm-workout-share")
                        Text("Du wählst anschließend die App und die Empfänger. Ohne deine Auswahl wird nichts versendet.")
                            .font(.caption).foregroundStyle(FYColor.muted)
                    }
                }.padding(24)
            }.background(FYColor.background).navigationTitle("Mit Freunden teilen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.accessibilityIdentifier("cancel-workout-share") } }
        }.tint(FYColor.lime).preferredColorScheme(.light)
            .onChange(of: store.profile?.id) { _, owner in if owner != summary.ownerID { dismiss() } }
    }
}

private struct WorkoutResultHeader: View {
    let activity: Activity
    let log: WorkoutLog
    var body: some View {
        VStack(spacing: 17) {
            Image(systemName: "trophy.fill").font(.system(size: 58)).foregroundStyle(FYColor.planned)
                .padding(22).background(FYColor.planned.opacity(0.10), in: Circle())
            Text("Workout geschafft!").font(.title.bold())
            Text("Gym · \(log.planName)").foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                WorkoutSummaryMetric(value: LiveTimer.format(activity.duration ?? 0), title: "Aktive Zeit")
                WorkoutSummaryMetric(value: "\(log.completedExercises)/\(log.exercises.count)", title: "Übungen")
                if log.completedSets > 0 { WorkoutSummaryMetric(value: "\(log.completedSets)", title: "Erfasste Sätze") }
            }.fyCard()
            Label("Protokoll gespeichert", systemImage: "checkmark.shield.fill").font(.subheadline.bold()).foregroundStyle(FYColor.lime)
            Text("Deine Satzwerte bleiben privat. Ob Freunde die Workout-Zusammenfassung sehen, richtet sich nach deiner Aktivitätssichtbarkeit.")
                .font(.footnote).foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 10).accessibilityIdentifier("workout-completed-summary")
    }
}

private struct WorkoutRecordedExercises: View {
    let log: WorkoutLog
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deine Übungen").font(.title3.bold())
            ForEach(log.exercises.sorted { $0.sortOrder < $1.sortOrder }) { exercise in
                VStack(alignment: .leading, spacing: 10) {
                    Label(exercise.exercise.name, systemImage: exercise.completed ? "checkmark.circle.fill" : "circle")
                        .font(.headline).foregroundStyle(exercise.completed ? FYColor.ink : FYColor.muted)
                    Text(exercise.completed ? "Übung abgeschlossen" : "Nicht als abgeschlossen markiert").font(.caption).foregroundStyle(FYColor.muted)
                    let actualSets = exercise.sets.filter { $0.completed || $0.weight != nil || $0.reps != nil }
                    if actualSets.isEmpty { Text("Keine Satzwerte erfasst – das ist im einfachen Modus völlig okay.").font(.footnote).foregroundStyle(FYColor.muted) }
                    else {
                        ForEach(actualSets.sorted { $0.setNumber < $1.setNumber }) { set in
                            WorkoutSetRow(set: set, unit: exercise.exercise.repetitionUnit, editable: false)
                        }
                    }
                    ExerciseEffortControl(activityID: log.activityID, exerciseID: exercise.id, editable: false)
                }.fyCard()
            }
        }
    }
}

private struct WorkoutSummaryMetric: View {
    let value: String
    let title: String
    var body: some View {
        VStack(spacing: 5) {
            Text(value).font(.headline).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(FYColor.muted)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

struct WorkoutSetRow: View {
    let set: WorkoutSetLog
    let unit: String
    let editable: Bool
    var body: some View {
        HStack(spacing: 10) {
            Text("Satz \(set.setNumber)").font(.subheadline.bold())
            Spacer(minLength: 6)
            Text(set.weight.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) kg" } ?? "— kg")
            Text("·")
            Text(set.reps.map { "\($0) \(unit)" } ?? "— \(unit)")
            Image(systemName: set.completed ? "checkmark.circle.fill" : editable ? "pencil.circle" : "circle")
                .foregroundStyle(set.completed ? FYColor.lime : FYColor.muted)
        }.font(.caption).foregroundStyle(FYColor.ink).padding(12)
            .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Satz \(set.setNumber), \(set.weight.map { "\($0) Kilogramm" } ?? "kein Gewicht erfasst"), \(set.reps.map { "\($0) \(unit)" } ?? "kein Wert erfasst"), \(set.completed ? "abgeschlossen" : "offen")")
    }
}

private func trackingPrescription(_ exercise: WorkoutExerciseLog) -> String {
    let range = exercise.targetRepsMin == exercise.targetRepsMax ? "\(exercise.targetRepsMin)" : "\(exercise.targetRepsMin)–\(exercise.targetRepsMax)"
    return "Ziel: \(exercise.targetSets) × \(range) \(exercise.exercise.repetitionUnit)"
}
