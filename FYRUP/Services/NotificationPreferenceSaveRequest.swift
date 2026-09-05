import Foundation

/// Both complete snapshots are mandatory. A missing baseline must never select
/// the deprecated unconditional RPC or silently assume default opt-ins.
struct NotificationPreferenceSaveRequest: Encodable, Sendable {
    let expected: NotificationPreferences
    let desired: NotificationPreferences
    enum CodingKeys: String, CodingKey { case expected = "p_expected", desired = "p_desired" }
}
