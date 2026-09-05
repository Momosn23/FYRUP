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
                .onOpenURL { url in Task { await store.receiveLiveLink(url) } }
                .task {
                    appDelegate.store = store
                    await appDelegate.deliverPendingNotification()
                    await store.bootstrap()
                    await store.deliverPendingNotification()
                    store.deliverPendingRestReminder()
                }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var store: AppStore?
    private var pendingNotification: NotificationTapPayload?
    private var pendingRestReminder: WorkoutRestReminderTap?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let taken = UNNotificationAction(identifier: "FYRUP_SUPPLEMENT_TAKEN", title: "Genommen", options: [.foreground, .authenticationRequired])
        let category = UNNotificationCategory(identifier: "FYRUP_SUPPLEMENT", actions: [taken], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        if let payload = options?[.remoteNotification] as? [AnyHashable: Any] {
            pendingNotification = NotificationTapPayload(userInfo: payload)
        }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await store?.registerDeviceToken(token) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let rest = WorkoutRestReminderTap(requestIdentifier: notification.request.identifier, userInfo: notification.request.content.userInfo) {
            return await canPresentRest(rest) ? [.banner, .sound] : []
        }
        guard let payload = NotificationTapPayload(userInfo: notification.request.content.userInfo), await canPresent(payload) else { return [] }
        return [.banner, .sound, .badge]
    }
    private func canPresent(_ payload: NotificationTapPayload) -> Bool {
        guard let store, let owner = store.session?.userID, store.route == .main else { return false }
        return payload.recipientID == owner
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }
        if let rest = WorkoutRestReminderTap(requestIdentifier: response.notification.request.identifier, userInfo: response.notification.request.content.userInfo) {
            await deliverRestReminder(rest); return
        }
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              var payload = NotificationTapPayload(userInfo: response.notification.request.content.userInfo) else { return }
        payload.marksSupplementTaken = response.actionIdentifier == "FYRUP_SUPPLEMENT_TAKEN" && payload.type == "supplement_reminder"
        await deliverNotification(payload)
    }
    func deliverPendingNotification() async {
        if let store, let pendingRestReminder {
            self.pendingRestReminder = nil
            await store.receiveRestReminder(pendingRestReminder)
        }
        guard let store, let pendingNotification else { return }
        self.pendingNotification = nil
        await store.handleNotificationTap(pendingNotification)
    }
    private func canPresentRest(_ payload: WorkoutRestReminderTap) -> Bool { store?.canPresentRestReminder(payload) == true }
    private func deliverRestReminder(_ payload: WorkoutRestReminderTap) async {
        guard let store else { pendingRestReminder = payload; return }
        await store.receiveRestReminder(payload)
    }
    private func deliverNotification(_ payload: NotificationTapPayload) async {
        guard let store else { pendingNotification = payload; return }
        await store.handleNotificationTap(payload)
    }
}
