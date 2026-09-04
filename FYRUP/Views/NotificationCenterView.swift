import SwiftUI

struct NotificationCenterView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Group {
            if store.notifications.isEmpty { ContentUnavailableView("Noch keine Mitteilungen", systemImage: "bell", description: Text("Social Signals aus deiner Crew erscheinen hier.")) }
            else { List(store.notifications) { item in VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.headline); Text(item.body).foregroundStyle(FYColor.muted); Text(item.createdAt, style: .relative).font(.caption).foregroundStyle(FYColor.muted) }.listRowBackground(FYColor.surface) } }
        }.scrollContentBackground(.hidden).background(FYColor.background).navigationTitle("Mitteilungen").task { await store.markNotificationsRead() }
    }
}
