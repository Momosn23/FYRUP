import SwiftUI
import UIKit
import UserNotifications

@main
struct FYRUPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .task {
                    appDelegate.store = store
                    await appDelegate.deliverPendingNotification()
                    await store.bootstrap()
                    await store.deliverPendingNotification()
                }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var store: AppStore?
    private var pendingNotification: NotificationTapPayload?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let payload = options?[.remoteNotification] as? [AnyHashable: Any] {
            pendingNotification = NotificationTapPayload(userInfo: payload)
        }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await store?.repository.registerDeviceToken(token) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let payload = NotificationTapPayload(userInfo: response.notification.request.content.userInfo) else { return }
        await deliverNotification(payload)
    }
    func deliverPendingNotification() async {
        guard let store, let pendingNotification else { return }
        self.pendingNotification = nil
        await store.handleNotificationTap(pendingNotification)
    }
    private func deliverNotification(_ payload: NotificationTapPayload) async {
        guard let store else { pendingNotification = payload; return }
        await store.handleNotificationTap(payload)
    }
}
