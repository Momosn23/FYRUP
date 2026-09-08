import CoreLocation
import Foundation
import Observation

@MainActor @Observable final class WeatherCitySearch: NSObject, CLLocationManagerDelegate {
    private let geocoder = CLGeocoder()
    private let manager = CLLocationManager()
    private var generation = UUID()
    private var requestedLocation = false
    private var timeout: Task<Void, Never>?
    private(set) var results: [WeatherPlace] = []
    private(set) var isBusy = false
    var message: String?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyKilometer }
    func find(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...120).contains(query.count) else { message = "Gib mindestens zwei Zeichen für deine Stadt ein."; return }
        cancel(); let epoch = generation; isBusy = true; message = nil
        defer { if epoch == generation { isBusy = false } }
        do {
            var places = try await geocoder.geocodeAddressString(query)
            guard epoch == generation else { return }
            if let first = places.first, first.thoroughfare != nil, let city = first.locality {
                places = try await geocoder.geocodeAddressString([city, first.country].compactMap { $0 }.joined(separator: ", "))
            }
            guard epoch == generation else { return }
            results = places.compactMap(Self.city)
            if results.isEmpty { message = "Keine Stadt gefunden. Versuche einen anderen Namen." }
        } catch { if epoch == generation { message = "Die Stadtsuche ist gerade nicht erreichbar." } }
    }
    func useCurrentLocation() {
        cancel(); isBusy = true; requestedLocation = true; message = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: failLocation()
        }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled, self?.requestedLocation == true else { return }
            self?.failLocation()
        }
    }
    func cancel() {
        generation = UUID(); geocoder.cancelGeocode(); manager.stopUpdatingLocation(); timeout?.cancel(); timeout = nil
        requestedLocation = false; isBusy = false; results = []
    }
    private func failLocation() {
        cancel(); message = "Standort nicht verfügbar. Du kannst deine Stadt manuell auswählen."
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, requestedLocation else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways { self.manager.requestLocation() }
            else if status == .denied || status == .restricted { failLocation() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in guard self?.requestedLocation == true else { return }; self?.failLocation() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              abs(location.timestamp.timeIntervalSinceNow) < 300 else { return }
        // Coarsen before sending to the city resolver or retaining a place.
        let lat = (location.coordinate.latitude * 100).rounded() / 100
        let lon = (location.coordinate.longitude * 100).rounded() / 100
        Task { @MainActor [weak self] in await self?.resolve(latitude: lat, longitude: lon) }
    }
    private func resolve(latitude: Double, longitude: Double) async {
        guard requestedLocation else { return }
        let epoch = generation
        do {
            let found = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
            guard epoch == generation, requestedLocation else { return }
            let name = found.first?.locality ?? "Aktueller Ort"
            results = [.init(name: name, latitude: latitude, longitude: longitude)]
            requestedLocation = false; isBusy = false; timeout?.cancel()
        } catch { if epoch == generation { failLocation() } }
    }
    private static func city(_ value: CLPlacemark) -> WeatherPlace? {
        guard let coordinate = value.location?.coordinate, let name = value.locality ?? value.name else { return nil }
        let place = WeatherPlace(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        return place.isValid ? place : nil
    }
}
