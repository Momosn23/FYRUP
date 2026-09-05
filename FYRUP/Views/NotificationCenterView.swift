import SwiftUI

struct NotificationCenterView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = 0

    var body: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $filter) { Text("Alle").tag(0); Text("Einladungen").tag(1); Text("Reaktionen").tag(2) }
                .pickerStyle(.segmented).padding(.horizontal, 16)
            if filteredNotifications.isEmpty {
                ContentUnavailableView("Noch keine Mitteilungen", systemImage: "bell", description: Text("Social Signals aus deiner Crew erscheinen hier."))
            } else {
                List(filteredNotifications) { item in
                    Group {
                        if item.type == "workout_plan_shared", let value = item.data?["plan_id"], let planID = UUID(uuidString: value) {
                            NavigationLink { WorkoutPlanDetailView(planID: planID) } label: { notificationRow(item) }
                        } else if item.type == "weekly_goal" || item.type == "flame_reaction" {
                            NavigationLink { WeeklyFlameDetailView() } label: { notificationRow(item) }
                        } else if let value = item.data?["session_id"], let sessionID = UUID(uuidString: value), let invitation = store.invitations.first(where: { $0.sessionID == sessionID }) {
                            NavigationLink { InvitationDetailView(invitation: invitation) } label: { notificationRow(item) }
                        } else {
                            notificationRow(item)
                        }
                    }
                    .padding(.vertical, 4).listRowBackground(FYColor.background).listRowSeparatorTint(FYColor.line)
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .background(FYColor.background)
        .navigationTitle("Mitteilungen")
        .task { await store.markNotificationsRead() }
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(iconColor(item).opacity(0.16)); Image(systemName: icon(item)).foregroundStyle(iconColor(item)) }.frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.bold()).foregroundStyle(FYColor.ink)
                Text(item.body).font(.caption).foregroundStyle(FYColor.muted).lineLimit(2)
                Text(item.createdAt, style: .relative).font(.caption2).foregroundStyle(FYColor.muted)
            }
            Spacer()
        }
    }

    private var filteredNotifications: [AppNotification] {
        switch filter {
        case 1: store.notifications.filter { $0.type.localizedCaseInsensitiveContains("invite") || $0.type.localizedCaseInsensitiveContains("session") || $0.type == "workout_plan_shared" }
        case 2: store.notifications.filter { $0.type.localizedCaseInsensitiveContains("reaction") || $0.type.localizedCaseInsensitiveContains("fyrup") }
        default: store.notifications
        }
    }
    private func icon(_ item: AppNotification) -> String { item.type.contains("invite") ? "envelope.fill" : item.type.contains("reaction") ? "flame.fill" : "bell.fill" }
    private func iconColor(_ item: AppNotification) -> Color { item.type.contains("invite") ? FYColor.violet : item.type.contains("reaction") ? FYColor.coral : FYColor.cyan }
}
