import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack { TodayView() }.tabItem { Label("Heute", systemImage: "flame.fill") }.tag(0)
            NavigationStack { FriendsView() }.tabItem { Label("Freunde", systemImage: "person.2.fill") }.tag(1)
            Color.clear.tabItem { Label("Start", systemImage: "plus.circle.fill") }.tag(2)
            NavigationStack { ProfileView() }.tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(3)
        }
        .onChange(of: store.selectedTab) { _, value in if value == 2 { store.selectedTab = 0; store.showsActivityComposer = true } }
        .sheet(isPresented: $store.showsActivityComposer) { ActivityComposerView() }
        .task { await store.refresh() }
    }
}

