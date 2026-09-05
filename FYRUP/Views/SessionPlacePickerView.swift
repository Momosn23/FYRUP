import SwiftUI

struct SessionPlacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var search = SessionPlaceSearch()
    let onSelect: (SessionPlace) -> Void

    init(initialQuery: String, onSelect: @escaping (SessionPlace) -> Void) {
        _query = State(initialValue: initialQuery); self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted)
                    TextField("Gym, Adresse oder Ort", text: $query).textInputAutocapitalization(.words)
                        .submitLabel(.search).onSubmit { Task { await search.find(query) } }
                    if !query.isEmpty { Button { query = ""; search.clear() } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Suche löschen") }
                }.padding(14).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))

                Button("ORT SUCHEN") { Task { await search.find(query) } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(search.isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    .accessibilityIdentifier("search-session-place")
                Text("Die Suche wird von Apple Karten verarbeitet. FYRUP speichert die gewählte Koordinate nur auf diesem iPhone und sendet sie weder an Freunde noch an den FYRUP-Server.")
                    .font(.caption2).foregroundStyle(FYColor.muted).frame(maxWidth: .infinity, alignment: .leading)

                if search.isSearching { ProgressView("Orte werden gesucht …").frame(maxWidth: .infinity, alignment: .leading) }
                if let message = search.errorMessage { Text(message).font(.caption).foregroundStyle(FYColor.coral).frame(maxWidth: .infinity, alignment: .leading) }

                List(search.results) { place in
                    Button {
                        onSelect(place); dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(FYColor.lime)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name).font(.headline).foregroundStyle(FYColor.ink)
                                if let detail = place.detail { Text(detail).font(.caption).foregroundStyle(FYColor.muted) }
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(FYColor.muted)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("session-place-result")
                }.listStyle(.plain).scrollContentBackground(.hidden)

                if search.results.isEmpty && !search.isSearching && search.errorMessage == nil {
                    ContentUnavailableView("Ort auswählen", systemImage: "map",
                                           description: Text("Suche einen konkreten Ort, wenn du bei der Ankunft erinnert werden möchtest."))
                }
            }.padding(.horizontal, 18).padding(.top, 12).background(FYColor.background)
                .navigationTitle("Ort suchen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.preferredColorScheme(.light)
    }
}
