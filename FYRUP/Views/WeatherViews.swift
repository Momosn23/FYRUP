import SwiftUI

struct WeatherDateCard: View {
    @Environment(AppStore.self) private var store
    let date: Date
    @State private var showsPlace = false
    var body: some View {
        VStack(spacing: 8) {
            Button { showsPlace = true } label: {
                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))).font(.caption)
                    if let value = store.weather.value, value.isFresh(at: date) {
                        Label(value.temperature, systemImage: value.symbol).font(.subheadline.weight(.medium)).foregroundStyle(FYColor.ink)
                        Text(store.weather.place?.name ?? "").font(.caption).lineLimit(2)
                    } else if store.setup.value?.weatherPlace != nil {
                        Image(systemName: "cloud").foregroundStyle(FYColor.muted)
                        Text(store.weather.isLoading ? "Wetter laden …" : "Wetter nicht verfügbar").font(.caption)
                    } else { Label("Ort wählen", systemImage: "mappin").font(.caption) }
                }.foregroundStyle(FYColor.muted).frame(minHeight: 54)
            }.buttonStyle(.plain).accessibilityIdentifier("home-weather")
            if let value = store.weather.value, value.isFresh(at: date) {
                Link(destination: value.attributionLink) {
                    AsyncImage(url: value.attributionMark) { image in image.resizable().scaledToFit() }
                        placeholder: { Text("Apple Weather").font(.caption2) }
                        .frame(width: 86, height: 16)
                }.accessibilityLabel("Apple Weather · Datenquellen").accessibilityIdentifier("weather-attribution")
            }
        }.padding(10).frame(maxWidth: 142).background(.white, in: RoundedRectangle(cornerRadius: 12))
            .sheet(isPresented: $showsPlace) { NavigationStack { WeatherPlaceView() } }
            .task(id: store.setup.value?.weatherPlace) { await store.weather.select(store.setup.value?.weatherPlace) }
    }
}

struct WeatherPlaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = WeatherCitySearch()
    @State private var query = ""
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FYLayout.section) {
                Text("Wetter & Ort").font(.title.bold())
                Text("Wähle deine Stadt. Dafür brauchst du keine Standortfreigabe. Die Ortssuche und Wetterabfrage werden von Apple verarbeitet.").foregroundStyle(FYColor.muted)
                if let place = store.setup.value?.weatherPlace {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(place.name, systemImage: "mappin").font(.headline)
                        if let value = store.weather.value, value.isFresh(at: .now) {
                            Label("\(value.temperature) · \(value.condition)", systemImage: value.symbol)
                            Text("Aktualisiert: \(value.receivedAt.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(FYColor.muted)
                            Link("Apple Weather · Datenquellen", destination: value.attributionLink).font(.footnote)
                        } else if let failure = store.weather.failure { Text(failure.message).font(.footnote).foregroundStyle(FYColor.muted) }
                        Button("Wetter aktualisieren") { Task { await store.weather.refresh() } }.disabled(store.weather.isLoading)
                        Button("Wetterort entfernen") {
                            if store.setup.update({ $0.weatherPlace = nil }) { Task { await store.weather.select(nil) } }
                        }
                    }.fyCard()
                }
                FYInputField(title: "Stadt", placeholder: "Zum Beispiel Köln", text: $query).focused($focused)
                    .textContentType(.addressCity).submitLabel(.search).onSubmit { find() }.accessibilityIdentifier("weather-city-query")
                Button("Stadt suchen") { find() }.buttonStyle(PrimaryButtonStyle()).disabled(search.isBusy)
                if search.isBusy { ProgressView("Ort suchen …") }
                ForEach(search.results) { place in
                    Button {
                        guard store.setup.update({ $0.weatherPlace = place }) else { return }
                        Task { await store.weather.select(place) }; dismiss()
                    } label: { HStack { Text(place.name); Spacer(); Image(systemName: "chevron.right") }.frame(minHeight: 52) }
                }
                if let message = search.message ?? store.setup.errorMessage { Text(message).font(.footnote).foregroundStyle(FYColor.muted) }
                Button("Aktuellen Standort verwenden") { focused = false; search.useCurrentLocation() }
                    .buttonStyle(OutlineButtonStyle()).disabled(search.isBusy).accessibilityIdentifier("weather-use-location")
                Text("Nur bei dieser Aktion wird der ungefähre Ort einmal abgefragt. Kein dauerhafter Hintergrundzugriff. Dein Wetterort wird nicht mit Freunden geteilt.")
                    .font(.footnote).foregroundStyle(FYColor.muted)
                Button("Nicht jetzt") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .onDisappear { search.cancel() }
            .task { await store.weather.select(store.setup.value?.weatherPlace) }
    }
    private func find() { focused = false; Task { await search.find(query) } }
}
