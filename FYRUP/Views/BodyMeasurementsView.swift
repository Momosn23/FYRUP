import SwiftUI

/// A draft never changes persisted measurements until the user continues.
struct BodyMeasurementsDraft: Equatable {
    var height = ""
    var weight = ""
    var targetWeight = ""
    init(_ value: PersonalSetupPreferences? = nil) {
        height = value?.heightCM.map { String($0) } ?? ""
        weight = value?.weightKG.map { String($0) } ?? ""
        targetWeight = value?.targetWeightKG.map { String($0) } ?? ""
    }
    var validationMessage: String? {
        let inputs = [height, weight, targetWeight].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard inputs.allSatisfy({ $0.isEmpty || NutritionNumber.parse($0) != nil }) else { return "Prüfe deine Angaben und Einheiten." }
        var value = PersonalSetupPreferences()
        apply(to: &value)
        return value.validationMessage
    }
    func apply(to value: inout PersonalSetupPreferences) {
        value.heightCM = NutritionNumber.parse(height)
        value.weightKG = NutritionNumber.parse(weight)
        value.targetWeightKG = NutritionNumber.parse(targetWeight)
        value.measurementsUpdatedAt = value.heightCM == nil && value.weightKG == nil && value.targetWeightKG == nil ? nil : .now
    }
}

/// R05 fields, shared by the production setup flow and the profile editor.
struct BodyMeasurementsView: View {
    @Binding var draft: BodyMeasurementsDraft
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: FYLayout.section) {
            FYInputField(title: "Größe · optional", placeholder: "Deine Größe", text: $draft.height, unit: "cm", identifier: "setup-height")
                .keyboardType(.decimalPad).focused($focused)
            FYInputField(title: "Gewicht · optional", placeholder: "Dein Gewicht", text: $draft.weight, unit: "kg", identifier: "setup-weight")
                .keyboardType(.decimalPad).focused($focused)
            FYInputField(title: "Zielgewicht · optional", placeholder: "Dein Ziel", text: $draft.targetWeight, unit: "kg", identifier: "setup-target-weight")
                .keyboardType(.decimalPad).focused($focused)
            Label("Privat auf diesem iPhone. Getrennt von den Kalorien deiner Mahlzeiten.", systemImage: "lock")
                .font(.footnote).foregroundStyle(FYColor.muted)
        }.toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focused = false } }
        }
    }
}

struct BodyMeasurementsEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BodyMeasurementsDraft()
    @State private var message: String?
    @State private var restored = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FYLayout.section) {
                Text("Körperdaten").font(.title.bold())
                Text("Freiwillige Angaben für deine persönlichen Ziele.").foregroundStyle(FYColor.muted)
                BodyMeasurementsView(draft: $draft)
                if let message = message ?? store.setup.errorMessage { Text(message).font(.footnote).foregroundStyle(FYColor.coral) }
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Speichern") {
                    message = draft.validationMessage
                    guard message == nil else { return }
                    if store.setup.update({ draft.apply(to: &$0) }) { dismiss() }
                }.buttonStyle(PrimaryButtonStyle()).disabled(store.setup.value == nil)
                    .padding(FYLayout.page).background(FYColor.background).accessibilityIdentifier("save-body-measurements")
            }
            .onAppear { guard !restored, store.setup.value != nil else { return }; draft = .init(store.setup.value); restored = true }
    }
}
