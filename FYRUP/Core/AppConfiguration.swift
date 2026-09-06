import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let publishableKey: String
    let environment: String

    static func load(bundle: Bundle = .main) -> AppConfiguration? {
        let resourceValues: [String: Any]
        if
            let fileURL = bundle.url(forResource: "BackendConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: fileURL),
            let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = propertyList as? [String: Any]
        {
            resourceValues = dictionary
        } else {
            resourceValues = [:]
        }

        return load(
            values: resourceValues,
            fallbackValues: bundle.infoDictionary ?? [:]
        )
    }

    static func load(
        values: [String: Any],
        fallbackValues: [String: Any] = [:]
    ) -> AppConfiguration? {
        // A checked-in template resource must not mask valid xcconfig values in
        // the generated Info.plist. Release CI still replaces the resource and
        // independently verifies the final IPA.
        for candidate in [values, fallbackValues] {
            guard let rawURL = candidate["SUPABASE_URL"] as? String,
                  let key = candidate["SUPABASE_PUBLISHABLE_KEY"] as? String,
                  let url = URL(string: rawURL), url.scheme == "https", url.host != nil,
                  !key.isEmpty, !rawURL.contains("YOUR_PROJECT"),
                  !key.contains("YOUR_PUBLISHABLE_KEY") else { continue }
            let environment = (candidate["APP_ENVIRONMENT"] as? String)
                ?? (fallbackValues["APP_ENVIRONMENT"] as? String)
                ?? "development"
            return AppConfiguration(supabaseURL: url, publishableKey: key, environment: environment)
        }
        return nil
    }
}

enum AppError: LocalizedError, Equatable {
    case configuration
    case authentication
    case accessDenied
    case validation(String)
    case conflict(String)
    case offline
    case serverUnavailable
    case network
    case server

    var errorDescription: String? {
        switch self {
        case .configuration: "Die App ist noch nicht mit dem Backend verbunden."
        case .authentication: "Bitte melde dich erneut an."
        case .accessDenied: "Du hast auf diesen Inhalt keinen Zugriff mehr."
        case .validation(let message), .conflict(let message): message
        case .offline, .network: "Kein Internet. Sobald du wieder online bist, lädt FYRUP automatisch neu."
        case .serverUnavailable: "Der Server ist vorübergehend nicht erreichbar. FYRUP versucht es erneut."
        case .server: "Die Daten konnten nicht geladen werden. Versuche es erneut."
        }
    }

    var isAccessDenied: Bool {
        self == .authentication || self == .accessDenied
            || self == .conflict("Du hast auf diesen Inhalt keinen Zugriff mehr.")
    }
}
