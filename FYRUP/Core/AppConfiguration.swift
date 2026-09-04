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
        let rawURL = (values["SUPABASE_URL"] as? String)
            ?? (fallbackValues["SUPABASE_URL"] as? String)
        let key = (values["SUPABASE_PUBLISHABLE_KEY"] as? String)
            ?? (fallbackValues["SUPABASE_PUBLISHABLE_KEY"] as? String)
        let environment = (values["APP_ENVIRONMENT"] as? String)
            ?? (fallbackValues["APP_ENVIRONMENT"] as? String)
            ?? "development"

        guard
            let rawURL,
            let url = URL(string: rawURL),
            url.scheme == "https",
            url.host != nil,
            let key,
            !key.isEmpty,
            !rawURL.contains("YOUR_PROJECT"),
            !key.contains("YOUR_PUBLISHABLE_KEY")
        else { return nil }
        return AppConfiguration(
            supabaseURL: url,
            publishableKey: key,
            environment: environment
        )
    }
}

enum AppError: LocalizedError, Equatable {
    case configuration
    case authentication
    case validation(String)
    case conflict(String)
    case network
    case server

    var errorDescription: String? {
        switch self {
        case .configuration: "Die App ist noch nicht mit dem Backend verbunden."
        case .authentication: "Bitte melde dich erneut an."
        case .validation(let message), .conflict(let message): message
        case .network: "Du scheinst offline zu sein. Versuche es gleich noch einmal."
        case .server: "Das hat gerade nicht geklappt. Versuche es erneut."
        }
    }
}
