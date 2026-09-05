import UserNotifications

enum SystemNotificationAuthorization {
    /// Older Apple SDKs do not mark UNNotificationSettings as Sendable. Read it
    /// inside Apple's callback and transfer only the immutable integer value.
    /// This reads the current setting; it never requests notification permission.
    nonisolated static func rawStatus() async -> Int {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.rawValue)
            }
        }
    }
}
