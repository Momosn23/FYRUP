import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                TodayView()
                    .navigationDestination(isPresented: $store.opensNotifications) { NotificationCenterView() }
            }.tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            Color.clear.tabItem { Label("Planen", systemImage: "clock") }.tag(1)
            NavigationStack { FriendsView() }.tabItem { Label("Entdecken", systemImage: "safari") }.tag(2)
            NavigationStack { ProfileView() }.tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(3)
        }
        .onChange(of: store.selectedTab) { _, value in if value == 1 { store.activityComposerMode = 1; store.selectedTab = 0; store.showsActivityComposer = true } }
        .fullScreenCover(isPresented: $store.showsActivityComposer) { ActivityComposerView(initialMode: store.activityComposerMode) }
        .task { await store.refresh() }
    }
}
