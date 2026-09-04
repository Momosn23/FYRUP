import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .bottom) {
            TabView(selection: $store.selectedTab) {
                NavigationStack {
                    TodayView().navigationDestination(isPresented: $store.opensNotifications) { NotificationCenterView() }
                }
                .tabItem { Label("Heute", systemImage: "house.fill") }.tag(0)

                NavigationStack { FriendsView() }
                    .tabItem { Label("Freunde", systemImage: "person.2.fill") }.tag(1)

                Color.clear.tabItem { Text("") }.tag(2)

                NavigationStack { DiscoverView() }
                    .tabItem { Label("Entdecken", systemImage: "figure.run") }.tag(3)

                NavigationStack { ProfileView() }
                    .tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(4)
            }
            .tint(FYColor.lime)
            .onChange(of: store.selectedTab) { oldValue, value in
                if value == 2 {
                    store.selectedTab = oldValue == 2 ? 0 : oldValue
                    store.activityComposerMode = 0
                    store.showsActivityComposer = true
                }
            }

            Button {
                store.activityComposerMode = 0
                store.showsActivityComposer = true
            } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(FYColor.lime, in: Circle())
                    .shadow(color: FYColor.lime.opacity(0.30), radius: 9, y: 4)
            }
            .accessibilityLabel("Planen")
            .padding(.bottom, 9)
        }
        .fullScreenCover(isPresented: $store.showsActivityComposer) { ActivityComposerView(initialMode: store.activityComposerMode) }
        .task { await store.refresh() }
    }
}

private struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Entdecken").font(.largeTitle.weight(.black))
                Text("Was möchtest du heute machen?").foregroundStyle(FYColor.muted)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SportKind.allCases) { sport in
                        Button {
                            store.activityComposerMode = 0
                            store.showsActivityComposer = true
                        } label: {
                            VStack(alignment: .leading, spacing: 20) {
                                Image(systemName: sport.symbol).font(.title).foregroundStyle(sport.accentColor)
                                Text(sport.title).font(.headline).foregroundStyle(FYColor.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading).fyCard()
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(18)
        }.background(FYColor.background).navigationBarHidden(true)
    }
}
