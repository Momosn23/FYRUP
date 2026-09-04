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
                .preferredColorScheme(.dark)
                .task {
                    appDelegate.store = store
                    await store.bootstrap()
                    await appDelegate.deliverPendingNotification()
                }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var store: AppStore?
    private var pendingNotificationType: String?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let payload = options?[.remoteNotification] as? [AnyHashable: Any] {
            pendingNotificationType = payload["fyrup_type"] as? String
        }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await store?.repository.registerDeviceToken(token) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let type = response.notification.request.content.userInfo["fyrup_type"] as? String
        await deliverNotification(type)
    }
    func deliverPendingNotification() async {
        guard let pendingNotificationType else { return }
        self.pendingNotificationType = nil
        await store?.handleNotificationTap(type: pendingNotificationType)
    }
    private func deliverNotification(_ type: String?) async {
        await store?.handleNotificationTap(type: type)
    }
}
