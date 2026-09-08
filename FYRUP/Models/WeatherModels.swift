import Foundation

struct WeatherPlace: Codable, Hashable, Identifiable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var id: String { "\(name)|\(latitude)|\(longitude)" }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120
        && latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

struct CurrentWeatherSnapshot: Sendable {
    let observedAt: Date
    let receivedAt: Date
    let temperatureCelsius: Double
    let condition: String
    let symbol: String
    let attributionMark: URL
    let attributionLink: URL
    func isFresh(at now: Date) -> Bool {
        temperatureCelsius.isFinite && receivedAt <= now && now.timeIntervalSince(receivedAt) < 1800
        && observedAt <= now.addingTimeInterval(60) && now.timeIntervalSince(observedAt) < 3600
    }
    var temperature: String {
        Measurement(value: temperatureCelsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}

enum WeatherFailure: Error, Equatable {
    case offline, configuration, quota, unavailable
    var message: String {
        switch self {
        case .offline: "Wetter momentan nicht verfügbar. Bei der nächsten Verbindung wird es aktualisiert."
        case .configuration: "Wetter ist für diese App-Version noch nicht freigeschaltet."
        case .quota: "Wetter ist vorübergehend nicht verfügbar. Bitte versuche es später erneut."
        case .unavailable: "Wetter momentan nicht verfügbar."
        }
    }
}
