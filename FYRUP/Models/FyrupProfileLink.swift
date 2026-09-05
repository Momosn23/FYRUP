import Foundation

struct FyrupProfileLink: Equatable, Sendable {
    let username: String

    init?(url: URL) {
        guard url.scheme?.lowercased() == "fyrup", url.host?.lowercased() == "profile",
              url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1 else { return nil }
        let value = parts[0].lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        guard (3...24).contains(value.count), value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        username = value
    }

    init?(username: String) {
        guard let url = URL(string: "fyrup://profile/\(username.lowercased())"), let parsed = FyrupProfileLink(url: url) else { return nil }
        self = parsed
    }

    var url: URL { URL(string: "fyrup://profile/\(username)")! }
}
