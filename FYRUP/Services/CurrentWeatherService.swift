import CoreLocation
import Foundation
import WeatherKit
import OSLog
import Observation

@MainActor protocol CurrentWeatherReading {
    func current(for place: WeatherPlace) async throws -> CurrentWeatherSnapshot
}

@MainActor struct AppleCurrentWeatherReader: CurrentWeatherReading {
    func current(for place: WeatherPlace) async throws -> CurrentWeatherSnapshot {
        do {
            let service = WeatherService.shared
            let current = try await service.weather(for: CLLocation(latitude: place.latitude, longitude: place.longitude), including: .current)
            let attribution = try await service.attribution
            return .init(observedAt: current.date, receivedAt: .now, temperatureCelsius: current.temperature.converted(to: .celsius).value,
                         condition: current.condition.description, symbol: current.symbolName,
                         // The weather surfaces use a white card. Apple's dark
                         // mark is white and therefore disappeared in review.
                         attributionMark: attribution.combinedMarkLightURL, attributionLink: attribution.legalPageURL)
        } catch WeatherError.permissionDenied { throw WeatherFailure.configuration }
        catch {
            let ns = error as NSError
            let underlying = (ns.userInfo[NSUnderlyingErrorKey] as? NSError) ?? ns
            if underlying.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost].contains(underlying.code) { throw WeatherFailure.offline }
            if ns.code == 429 || underlying.code == 429 { throw WeatherFailure.quota }
            if ns.code == 401 || ns.code == 403 { throw WeatherFailure.configuration }
            throw WeatherFailure.unavailable
        }
    }
}

@MainActor @Observable final class CurrentWeatherStore {
    private let reader: any CurrentWeatherReading
    private let now: () -> Date
    private var cache: [WeatherPlace: CurrentWeatherSnapshot] = [:]
    private var pending: [WeatherPlace: Task<CurrentWeatherSnapshot, Error>] = [:]
    private var retryAfter: [WeatherPlace: Date] = [:]
    private var generation = UUID()
    private let log = Logger(subsystem: "app.fyrup.ios", category: "Weather")
    private(set) var place: WeatherPlace?
    private(set) var value: CurrentWeatherSnapshot?
    private(set) var failure: WeatherFailure?
    private(set) var isLoading = false
    init(reader: any CurrentWeatherReading = AppleCurrentWeatherReader(), now: @escaping () -> Date = { .now }) { self.reader = reader; self.now = now }
    func reset() {
        generation = UUID(); pending.values.forEach { $0.cancel() }; pending = [:]; cache = [:]; retryAfter = [:]
        place = nil; value = nil; failure = nil; isLoading = false
    }
    func select(_ place: WeatherPlace?) async {
        guard place?.isValid ?? true else { return }
        if self.place != place { self.place = place; value = nil; failure = nil; isLoading = false }
        await refresh()
    }
    func refresh() async {
        guard let place else { return }
        let epoch = generation
        if let cached = cache[place], cached.isFresh(at: now()) { value = cached; failure = nil; return }
        value = nil // Never carry stale data or a previous city's temperature into the card.
        if let retry = retryAfter[place], retry > now() { return }
        let task: Task<CurrentWeatherSnapshot, Error>
        if let existing = pending[place] { task = existing }
        else {
            task = Task { try await reader.current(for: place) }; pending[place] = task
            log.info("weather request started") // No city, coordinates, IDs or data values.
        }
        isLoading = true
        do {
            let result = try await task.value
            guard epoch == generation else { return }
            guard result.isFresh(at: now()) else { throw WeatherFailure.unavailable }
            cache[place] = result; pending[place] = nil; retryAfter[place] = nil
            if self.place == place { value = result; failure = nil; isLoading = false }
            log.info("weather request succeeded")
        } catch {
            guard epoch == generation else { return }
            let failure = error as? WeatherFailure ?? .unavailable
            pending[place] = nil
            retryAfter[place] = now().addingTimeInterval(failure == .quota || failure == .configuration ? 1800 : 60)
            if self.place == place { self.failure = failure; isLoading = false }
            let code = String(describing: failure)
            log.info("weather request failed category=\(code, privacy: .public)")
        }
    }
}
