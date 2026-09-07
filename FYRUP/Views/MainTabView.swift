import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

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
            if phase == .active && store.route == .main { store.rest.reloadExternalClock(); Task { await store.prepareNotificationRegistration(); await store.refresh(); await store.supplements.refresh(); await store.steps.refresh(force: true); await store.energy.refresh(force: true); await store.weekly.refresh(force: true); await store.weekly.refreshFriends(); await store.blind.refreshSummaries() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await store.steps.refresh(force: true); await store.energy.refresh(force: true); await store.weekly.refresh(force: true) }
        }
        .onChange(of: store.rest.clock) { _, _ in store.synchronizeLiveSurface() }
        .onChange(of: store.myActivity) { _, _ in store.synchronizeLiveSurface() }
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
