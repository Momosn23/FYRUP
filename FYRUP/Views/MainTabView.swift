import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
        VStack(spacing: 0) {
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
        .clipped()
        FYMainNavigation()
        }
        // UIKit's TabView scroll surfaces otherwise extend to the full window.
        // Real sibling navigation + explicit safe-area bounds keep both the
        // rendered content and tappable area out of the system/navigation bars.
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
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
                .accessibilityShowsLargeContentViewer { Label("Neue Aktivität", systemImage: "plus") }
            tab("Entdecken", symbol: "safari", index: 3, id: "discover")
            tab("Profil", symbol: "person.crop.circle", index: 4, id: "profile")
        }.padding(.horizontal, 8).padding(.vertical, 6)
            .background(.white, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(FYColor.line, lineWidth: 0.5))
            .padding(.horizontal, 12).padding(.bottom, 4)
            .background(FYColor.background.opacity(0.96))
            // Navigation has a fixed spatial budget; only this bar is capped.
            // Apple's large-content viewer provides the full enlarged label.
            // Main content keeps the user's unrestricted Dynamic Type size.
            .dynamicTypeSize(...DynamicTypeSize.large)
            // A parent identifier overrides the individual buttons on iOS 26.
            // Keep identifiers on the five actual controls only.
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
            .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
    }
}
