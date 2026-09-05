import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class SessionPlaceSearch {
    private(set) var results: [SessionPlace] = []
    private(set) var isSearching = false
    var errorMessage: String?
    private var search: MKLocalSearch?

    func find(_ query: String) async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2, value.count <= 120 else {
            results = []; errorMessage = value.isEmpty ? nil : "Gib mindestens zwei Zeichen ein."
            return
        }
        search?.cancel(); errorMessage = nil; isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = value
        request.resultTypes = [.address, .pointOfInterest]
        let current = MKLocalSearch(request: request); search = current
        do {
            let response = try await current.start()
            guard search === current else { return }
            results = Array(response.mapItems.prefix(8)).compactMap { item in
                let coordinate = item.placemark.coordinate
                let title = (item.name ?? value).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, title.count <= 120 else { return nil }
                let detail = [item.placemark.thoroughfare, item.placemark.locality]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0 != title }.joined(separator: ", ")
                return SessionPlace(name: title, detail: detail.isEmpty ? nil : detail,
                                    latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        } catch is CancellationError {
            return
        } catch {
            guard search === current else { return }
            results = []; errorMessage = "Die Ortssuche ist gerade nicht erreichbar. Versuche es erneut."
        }
        if search === current { isSearching = false }
    }

    func clear() { search?.cancel(); search = nil; results = []; errorMessage = nil; isSearching = false }
}
