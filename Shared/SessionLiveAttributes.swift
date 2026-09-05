import ActivityKit
import Foundation

struct SessionLiveAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var sport: String
        var symbol: String
        var timerReference: Date
        var pausedSeconds: Int?
        var restStartedAt: Date?
        var restEndsAt: Date?
        var isGym: Bool
    }
    var sessionID: UUID
}

struct SessionLiveLink: Equatable {
    let sessionID: UUID
    let opensRest: Bool
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "fyrup", components.host == "live", components.user == nil,
              components.password == nil, components.port == nil, components.fragment == nil else { return nil }
        let pieces = components.path.split(separator: "/")
        guard pieces.count == 1, let id = UUID(uuidString: String(pieces[0])) else { return nil }
        let query = components.queryItems ?? []
        guard query.isEmpty || (query.count == 1 && query[0].name == "action" && query[0].value == "rest") else { return nil }
        sessionID = id; opensRest = !query.isEmpty
    }
    static func url(sessionID: UUID, opensRest: Bool = false) -> URL {
        // Only an existing live session can be opened. The link grants no access.
        URL(string: "fyrup://live/\(sessionID.uuidString)\(opensRest ? "?action=rest" : "")")!
    }
}
