import SwiftUI

struct ExerciseEffortControl: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let activityID: UUID
    let exerciseID: UUID
    var editable = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wie anstrengend war die Übung?").font(.caption.weight(.semibold)).foregroundStyle(FYColor.muted)
            if let feedback = store.personal.feedback[activityID] {
                HStack(spacing: 8) {
                    ForEach(ExerciseEffort.allCases) { effort in
                        let chosen = feedback.effort(for: exerciseID) == effort
                        Button {
                            var next = feedback; next.setEffort(chosen ? nil : effort, for: exerciseID)
                            Task { if await store.personal.saveFeedback(next) { Haptics.impact(.light) } }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: effort.symbol).font(.subheadline)
                                Text(effort.title).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)
                            }.frame(maxWidth: .infinity, minHeight: 57)
                                .foregroundStyle(chosen ? Color.white : FYColor.ink)
                                .background(chosen ? tint(effort) : FYColor.elevated, in: RoundedRectangle(cornerRadius: 11))
                        }.buttonStyle(.plain).disabled(!editable || store.personal.savingFeedback.contains(activityID))
                            .accessibilityAddTraits(chosen ? .isSelected : [])
                            .accessibilityIdentifier("effort-\(exerciseID.uuidString)-\(effort.rawValue)")
                    }
                }.animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: feedback.effort(for: exerciseID))
                Text(editable ? "Freiwillig · nur für dich · erneut tippen zum Entfernen" : "Deine private Übungsbewertung").font(.system(size: 10)).foregroundStyle(FYColor.muted)
            } else if store.personal.loadingFeedback.contains(activityID) { ProgressView().controlSize(.small) }
            if let error = store.personal.feedbackErrors[activityID] {
                Text(error).font(.caption).foregroundStyle(FYColor.coral)
                Button("Bewertung neu laden") { Task { await store.personal.loadFeedback(activityID: activityID, force: true) } }.font(.caption.bold())
            }
        }.task(id: activityID) { await store.personal.loadFeedback(activityID: activityID) }
    }
    private func tint(_ effort: ExerciseEffort) -> Color { switch effort { case .easy: FYColor.lime; case .medium: FYColor.cyan; case .hardcore: FYColor.coral } }
}

struct WorkoutFeedbackButton: View {
    @Environment(AppStore.self) private var store
    let activityID: UUID
    @State private var showsReview = false
    var body: some View {
        VStack(spacing: 14) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showsReview = true } } label: {
                Label(store.personal.feedback[activityID]?.feeling.map { "\($0.emoji) \($0.title) · Bewertung ändern" } ?? "Wie war deine Aktivität?", systemImage: "bubble.left")
            }.buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("review-completed-workout")
            if showsReview {
                WorkoutFeedbackEditor(activityID: activityID) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsReview = false }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task(id: activityID) { await store.personal.loadFeedback(activityID: activityID) }
    }
}

private struct WorkoutFeedbackEditor: View {
    @Environment(AppStore.self) private var store
    let activityID: UUID
    let close: () -> Void
    @State private var feeling: TrainingFeeling?
    @State private var note = ""
    @State private var loaded = false
    @State private var baselineRevision: Int?
    @FocusState private var noteFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dein Rückblick").font(.headline)
                    Text("Privat · nur für dich").font(.caption).foregroundStyle(FYColor.muted)
                }
                Spacer()
                Button("Schließen") { close() }.font(.subheadline.weight(.semibold))
            }
            Text("Wie war deine Aktivität?").font(.title3.bold())
            HStack(spacing: 8) {
                ForEach(TrainingFeeling.allCases) { item in
                    Button { feeling = feeling == item ? nil : item; Haptics.impact(.light) } label: {
                        VStack(spacing: 8) { Text(item.emoji).font(.title); Text(item.title).font(.caption.bold()) }
                            .frame(maxWidth: .infinity, minHeight: 87)
                            .background(feeling == item ? FYColor.limeSoft : FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(feeling == item ? FYColor.lime : .clear))
                    }.buttonStyle(.plain).accessibilityAddTraits(feeling == item ? .isSelected : [])
                        .accessibilityIdentifier("workout-feeling-\(item.rawValue)")
                }
            }.disabled(!loaded || store.personal.savingFeedback.contains(activityID))
            TextField("Was lief gut? Was war schwierig? (optional)", text: $note, axis: .vertical)
                .lineLimit(3...6).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14))
                .focused($noteFocused).accessibilityIdentifier("workout-review-note")
                .disabled(!loaded || store.personal.savingFeedback.contains(activityID))
            Text("\(note.unicodeScalars.count) / 500 · privat").font(.caption).foregroundStyle(note.unicodeScalars.count > 500 ? FYColor.coral : FYColor.muted)
            if let error = store.personal.feedbackErrors[activityID] {
                Text(error).font(.footnote).foregroundStyle(FYColor.coral)
                Button("Gespeicherten Stand neu laden") { Task { await store.personal.loadFeedback(activityID: activityID, force: true); applyLoaded() } }
            }
            Button("Bewertung speichern") {
                guard var value = store.personal.feedback[activityID] else { return }
                value.feeling = feeling; value.note = note
                if let baselineRevision { value.revision = baselineRevision }
                Task { if await store.personal.saveFeedback(value) { close() } }
            }.buttonStyle(PrimaryButtonStyle()).disabled(!loaded || note.unicodeScalars.count > 500 || store.personal.savingFeedback.contains(activityID))
                .accessibilityIdentifier("save-workout-review")
            Button("Ohne Änderung schließen") { close() }.frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(FYColor.line))
        .tint(FYColor.lime).preferredColorScheme(.light)
            .task { await store.personal.loadFeedback(activityID: activityID); applyLoaded() }
            .onChange(of: store.personal.feedback[activityID]?.revision) { _, _ in applyLoaded() }
            .onChange(of: store.profile?.id) { _, _ in feeling = nil; note = ""; close() }
    }
    private func applyLoaded() {
        guard let value = store.personal.feedback[activityID] else { return }
        if !loaded { feeling = value.feeling; note = value.note ?? "" }
        baselineRevision = value.revision
        loaded = true
    }
}
