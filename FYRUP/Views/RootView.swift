import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ZStack {
            FYColor.background.ignoresSafeArea()
            switch store.route {
            case .loading: ProgressView().tint(FYColor.lime).controlSize(.large)
            case .configuration: ConfigurationView()
            case .signedOut: WelcomeView()
            case .profileSetup: ProfileSetupView()
            case .sportsSetup: SportsSetupView()
            case .onboardingComplete: OnboardingCompleteView()
            case .main: MainTabView()
            }
            if store.isBusy { Color.black.opacity(0.28).ignoresSafeArea(); ProgressView().tint(FYColor.lime).controlSize(.large) }
        }
        .tint(FYColor.lime)
        .alert("Hinweis", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

private struct ConfigurationView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "flame.fill").font(.system(size: 58)).foregroundStyle(FYColor.lime)
            Text("Backend verbinden").font(.largeTitle.bold())
            Text("Kopiere Config/Shared.xcconfig nach Config/Secrets.xcconfig und trage SUPABASE_URL sowie SUPABASE_PUBLISHABLE_KEY ein.")
                .foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
            Text("Für die lokale UI-Demo: Scheme → Arguments → --demo")
                .font(.footnote).foregroundStyle(FYColor.muted)
        }.padding(28)
    }
}
