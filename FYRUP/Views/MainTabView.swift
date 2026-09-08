import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
                NavigationStack {
                    TodayView().navigationDestination(isPresented: $store.opensNotifications) { NotificationCenterView() }
                        .toolbar(.hidden, for: .tabBar)
                }
                .tabItem { Label("Heute", systemImage: "house.fill") }.tag(0)

                NavigationStack { WeeklyScheduleView().toolbar(.hidden, for: .tabBar) }
                    .tabItem { Label("Wochenplan", systemImage: "calendar") }.tag(1)

                NavigationStack { DiscoverView().toolbar(.hidden, for: .tabBar) }
                    .tabItem { Label("Entdecken", systemImage: "figure.run") }.tag(3)

                NavigationStack { ProfileView().toolbar(.hidden, for: .tabBar) }
                    .tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(FYColor.lime)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { FYMainNavigation() }
        .fullScreenCover(isPresented: $store.showsActivityComposer) { ActivityComposerView(initialMode: store.activityComposerMode) }
        .fullScreenCover(isPresented: $store.showsLiveSession) {
            NavigationStack {
                LiveActivityView(opensCurrentSet: store.opensLiveSetEntry).toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { store.opensLiveSetEntry = false; store.showsLiveSession = false }
                    }
                }
            }
        }.onChange(of: store.showsLiveSession) { _, visible in if !visible { store.opensLiveSetEntry = false } }
        .sheet(item: Binding(get: { store.notificationRouting.presentation }, set: { if $0 == nil { store.notificationRouting.dismiss() } })) { presentation in
            NotificationDestinationView(presentation: presentation).id(presentation.id)
        }
        .sheet(item: $store.arrivalDestination) { hosted in
            NavigationStack { HostedSessionView(hosted: hosted) }
        }
        .sheet(item: $store.sharedProfileDestination) { profile in SharedProfileDestinationView(profile: profile) }
        .task {
            await store.deliverPendingNotification()
            await store.refresh()
            store.deliverPendingLiveLink()
            store.deliverPendingRestReminder()
            await store.deliverPendingArrivalReminder()
            await store.deliverPendingProfileLink()
            store.synchronizeLiveSurface()
            guard !Task.isCancelled, store.route == .main, let userID = store.session?.userID, store.profile?.id == userID else { return }
            await store.steps.activate(userID: userID)
            await store.energy.refresh()
            guard store.session?.userID == userID, store.route == .main else { return }
            await store.weekly.activate(userID: userID)
            guard store.session?.userID == userID else { return }
            store.blind.activate(userID: userID)
            store.shot.activate(userID: userID)
            await store.blind.refreshSummaries()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && store.route == .main {
                store.rest.reloadExternalClock()
                Task { await store.weather.refresh() }
                Task { await store.prepareNotificationRegistration(); await store.refresh(); await store.supplements.refresh(); await store.steps.refresh(force: true); await store.energy.refresh(force: true); await store.weekly.refresh(force: true); await store.weekly.refreshFriends(); await store.blind.refreshSummaries() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await store.steps.refresh(force: true); await store.energy.refresh(force: true); await store.weekly.refresh(force: true) }
        }
        .onChange(of: store.rest.clock) { _, _ in store.synchronizeLiveSurface() }
        .onChange(of: store.myActivity) { _, _ in store.synchronizeLiveSurface() }
    }
}

private struct FYMainNavigation: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        HStack(spacing: 2) {
            tab("Heute", symbol: "house", index: 0, id: "today")
            tab("Wochenplan", symbol: "calendar", index: 1, id: "week")
            Button { store.activityComposerMode = 0; store.showsActivityComposer = true } label: {
                Image(systemName: "plus").font(.title.bold()).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(FYColor.lime, in: Circle())
                    .shadow(color: FYColor.lime.opacity(0.18), radius: 6, y: 3)
            }.buttonStyle(FYPressStyle()).frame(maxWidth: .infinity)
                .accessibilityLabel("Neue Aktivität").accessibilityIdentifier("activity-composer")
            tab("Entdecken", symbol: "safari", index: 3, id: "discover")
            tab("Profil", symbol: "person.crop.circle", index: 4, id: "profile")
        }.padding(.horizontal, 8).padding(.vertical, 6)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(FYColor.line, lineWidth: 0.5))
            .padding(.horizontal, 12).padding(.bottom, 4)
            .background(FYColor.background.opacity(0.96))
            .accessibilityIdentifier("main-navigation")
    }
    private func tab(_ title: String, symbol: String, index: Int, id: String) -> some View {
        Button { store.selectedTab = index } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 21, weight: .medium))
                Text(title).font(.caption2).lineLimit(1)
            }.foregroundStyle(store.selectedTab == index ? FYColor.lime : FYColor.ink)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(store.selectedTab == index ? FYColor.limeSoft : .clear, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier("tab-\(id)")
            .accessibilityAddTraits(store.selectedTab == index ? [.isSelected] : [])
    }
}

private struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedSport: SportKind?
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Entdecken").font(.largeTitle.weight(.black))
                Text("Was hast du vor?").foregroundStyle(FYColor.muted)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SportKind.allCases) { sport in
                        Button {
                            selectedSport = sport
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
            .fullScreenCover(item: $selectedSport) { sport in ActivityComposerView(initialSport: sport) }
    }
}
