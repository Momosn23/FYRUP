import SwiftUI

struct SetupSupplementGrid: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editing: SupplementPlan?
    private let names = ["Kreatin", "Vitamin D3", "Omega 3", "Magnesium", "Protein", "Zink", "Multivitamin", "Eigener Eintrag"]
    private var plans: [SupplementPlan] { store.supplements.snapshot?.plans.filter { !$0.isArchived } ?? [] }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
            ForEach(names, id: \.self) { name in
                let saved = plans.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                Button {
                    guard let owner = store.session?.userID else { return }
                    editing = saved ?? SupplementPlan(ownerID: owner, name: name == "Eigener Eintrag" ? "" : name)
                } label: {
                    HStack(spacing: 10) {
                        Image("SupplementsHero").resizable().scaledToFill().frame(width: 54, height: 58).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(name).font(.footnote.weight(.semibold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Image(systemName: saved == nil ? "circle" : "checkmark.circle.fill").foregroundStyle(saved == nil ? FYColor.line : FYColor.lime)
                        }
                    }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(8)
                        .background(saved == nil ? FYColor.surface : FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(saved == nil ? FYColor.line : FYColor.lime))
                }.buttonStyle(FYPressStyle()).foregroundStyle(FYColor.ink)
                    .accessibilityValue(saved == nil ? "Nicht eingerichtet" : "Eingerichtet")
                    .accessibilityIdentifier("setup-supplement-\(name)")
                    .disabled(store.supplements.snapshot == nil || store.supplements.isSaving)
            }
        }.sheet(item: $editing) { SupplementEditorView(plan: $0) }
    }
}
