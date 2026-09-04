import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let publishableKey: String
    let environment: String

    static func load(bundle: Bundle = .main) -> AppConfiguration? {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: rawURL),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !rawURL.contains("YOUR_PROJECT"), !key.contains("YOUR_PUBLISHABLE_KEY")
        else { return nil }
        return AppConfiguration(
            supabaseURL: url,
            publishableKey: key,
            environment: bundle.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String ?? "development"
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

