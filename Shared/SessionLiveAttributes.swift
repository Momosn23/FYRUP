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
        var currentExerciseName: String?
        var completedSets: Int?
        var totalSets: Int?
        var canTrackSets: Bool?
    }
    var sessionID: UUID
    var ownerID: UUID
}

enum SessionLiveAction: String, Equatable, Sendable {
    case open
    case rest
    case setEntry = "set"
}

struct SessionLiveLink: Equatable {
    let sessionID: UUID
    let action: SessionLiveAction
    var opensRest: Bool { action == .rest }
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "fyrup", components.host == "live", components.user == nil,
              components.password == nil, components.port == nil, components.fragment == nil else { return nil }
        let pieces = components.path.split(separator: "/")
        guard pieces.count == 1, let id = UUID(uuidString: String(pieces[0])) else { return nil }
        let query = components.queryItems ?? []
        let parsedAction: SessionLiveAction
        if query.isEmpty { parsedAction = .open }
        else if query.count == 1, query[0].name == "action", let value = query[0].value,
                let valueAction = SessionLiveAction(rawValue: value), valueAction != .open { parsedAction = valueAction }
        else { return nil }
        sessionID = id; action = parsedAction
    }
    static func url(sessionID: UUID, action: SessionLiveAction = .open) -> URL {
        // Only an existing live session can be opened. The link grants no access.
        let query = action == .open ? "" : "?action=\(action.rawValue)"
        return URL(string: "fyrup://live/\(sessionID.uuidString)\(query)")!
    }
    static func url(sessionID: UUID, opensRest: Bool) -> URL {
        url(sessionID: sessionID, action: opensRest ? .rest : .open)
    }
}
