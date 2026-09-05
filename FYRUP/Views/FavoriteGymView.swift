import SwiftUI

struct FavoriteGymView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var baseline = ""
    @State private var baselinePlace: SessionPlace?
    @State private var saved = false
    @State private var loadedUserID: UUID?
    @State private var hasLoadedName = false
    @State private var selectedPlace: SessionPlace?
    @State private var showsPlacePicker = false
    @FocusState private var isEditing: Bool
    private var hasChanges: Bool { name != baseline || selectedPlace != baselinePlace }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SportPhoto(sport: .gym).frame(height: 180)
                    .overlay { LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom) }
                    .overlay(alignment: .bottomLeading) {
                        Text("Dein Ort.\nDein Rhythmus.").font(.title.bold()).foregroundStyle(.white).padding(20)
                    }.clipShape(RoundedRectangle(cornerRadius: 24))
                Text("Dein Stammgym").font(.title2.bold())
                Text("Einmal eintragen. Bei einer neuen Gym-Session steht es im Planungsformular schon bereit.").foregroundStyle(FYColor.muted)
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(FYColor.lime)
                    TextField("z. B. Fitness First Köln", text: $name).focused($isEditing).submitLabel(.done)
                        .onChange(of: name) { _, value in if value != selectedPlace?.name { selectedPlace = nil } }
                        .accessibilityLabel("Name deines Stammgyms").accessibilityIdentifier("favorite-gym-name")
                }.padding(16).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                Button { showsPlacePicker = true } label: {
                    Label(selectedPlace == nil ? "Stammgym auf der Karte wählen" : "Kartenort ändern", systemImage: "map.fill")
                }.buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("choose-favorite-gym-place")
                if let selectedPlace {
                    Label(selectedPlace.detail ?? "Kartenort ausgewählt", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(FYColor.lime)
                }
                Text("Privat auf diesem iPhone gespeichert. Keine Standortfreigabe und kein GPS-Zugriff. Wenn du den Ort beim Planen stehen lässt, wird er zum Treffpunkt dieser Session und ist für deren berechtigte Teilnehmer sichtbar.")
                    .font(.caption).foregroundStyle(FYColor.muted)
                Button("Stammgym speichern") {
                    guard loadedUserID == store.setup.userID else { return }
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.setup.update({ value in
                        value.favoriteGymName = trimmed.isEmpty ? nil : trimmed
                        value.favoriteGymPlace = trimmed.isEmpty ? nil : selectedPlace
                    }) {
                        name = trimmed; baseline = trimmed; baselinePlace = selectedPlace; saved = true; isEditing = false; Haptics.success()
                    }
                }.buttonStyle(PrimaryButtonStyle()).disabled(store.setup.value == nil || loadedUserID != store.setup.userID).accessibilityIdentifier("save-favorite-gym")
                if hasChanges { Button("Änderungen verwerfen") { name = baseline; selectedPlace = baselinePlace; isEditing = false }.frame(minHeight: 44) }
                if store.setup.value?.favoriteGymName != nil {
                    Button("Stammgym entfernen", role: .destructive) {
                        guard loadedUserID == store.setup.userID else { return }
                        if store.setup.update({ $0.favoriteGymName = nil; $0.favoriteGymPlace = nil }) { name = ""; baseline = ""; selectedPlace = nil; baselinePlace = nil; saved = false }
                    }.frame(minHeight: 44).accessibilityIdentifier("remove-favorite-gym")
                }
                if saved { Label("Stammgym gespeichert", systemImage: "checkmark.circle.fill").foregroundStyle(FYColor.lime).accessibilityIdentifier("favorite-gym-saved") }
                if let message = store.setup.errorMessage { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
                Text("Du kannst den Treffpunkt vor jedem geplanten Termin ändern oder leer lassen. Das verändert dein Stammgym nicht.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
            }.padding(22).padding(.bottom, 80)
        }.background(FYColor.background).navigationTitle("Stammgym").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(hasChanges).interactiveDismissDisabled(hasChanges)
            .onAppear { if !hasLoadedName || loadedUserID != store.setup.userID { loadSavedName() } }
            .onChange(of: store.setup.userID) { _, _ in loadSavedName() }
            .onChange(of: name) { _, value in if value != baseline { saved = false } }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { isEditing = false } } }
            .sheet(isPresented: $showsPlacePicker) {
                SessionPlacePickerView(initialQuery: name) { place in name = place.name; selectedPlace = place }
            }
    }

    private func loadSavedName() {
        loadedUserID = store.setup.userID; hasLoadedName = true
        name = store.setup.value?.favoriteGymName ?? ""; baseline = name
        selectedPlace = store.setup.value?.favoriteGymPlace; baselinePlace = selectedPlace; saved = false
    }
}
