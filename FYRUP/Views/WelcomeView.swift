import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAccountChoice = false
    @State private var authMode: AuthMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .bottomLeading) {
                    Image("WelcomeHeroLight").resizable().scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 650).clipped().accessibilityHidden(true)
                    LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 0) {
                        FYRUPWordmark(size: 27).padding(.top, 18)
                        Spacer()
                        Text("Deine bessere Version\nbeginnt heute.")
                            .font(.system(size: 39, weight: .black)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("welcome-heading")
                        Text("Mehr Bewegung. Mehr Energie. Mehr von dir.")
                            .font(.body.weight(.medium)).foregroundStyle(.white.opacity(0.88)).padding(.top, 10)
                        if let message = store.authMessage {
                            Text(message).font(.footnote).foregroundStyle(.white).padding(.top, 10).accessibilityIdentifier("auth-feedback")
                        }
                    }.padding(.horizontal, FYLayout.page).padding(.bottom, 94)
                }
                .frame(minHeight: 650)
            }.background(FYColor.background)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsAccountChoice = true } } label: {
                            Label("Los geht’s", systemImage: "arrow.right")
                        }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("welcome-intro-next")
                    }.padding(.horizontal, FYLayout.page).padding(.vertical, 12).background(.ultraThinMaterial)
                }
                .navigationDestination(isPresented: $showsAccountChoice) { accountChoice }
        }.fullScreenCover(item: $authMode) { mode in AuthView(mode: mode).id(mode.id) }
    }

    private var accountChoice: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            FYRUPWordmark(size: 25)
            VStack(alignment: .leading, spacing: 7) {
                Text("Konto erstellen").font(.largeTitle.weight(.black)).accessibilityIdentifier("account-choice-title")
                Text("Wähle eine Option, um fortzufahren.").foregroundStyle(FYColor.muted)
            }
            SignInWithAppleButton(.continue) { store.configureAppleRequest($0) } onCompletion: { result in
                Task { await store.handleAppleResult(result) }
            }.signInWithAppleButtonStyle(.white).frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FYColor.line))
                .disabled(store.isBusy)
            Button { authMode = .registration } label: { Label("Mit E-Mail fortfahren", systemImage: "envelope") }
                .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("welcome-create-account").disabled(store.isBusy)
            VStack(alignment: .leading, spacing: 18) {
                Label("Deine Daten bleiben unter deiner Kontrolle.", systemImage: "checkmark.shield")
                Label("Deine Ziele und Fortschritte gehören dir.", systemImage: "chart.bar")
                Label("Gemeinsam aktiv – nur wenn du es möchtest.", systemImage: "person.2")
            }.font(.subheadline.weight(.medium)).padding(.vertical, 8)
            // Product scope is Apple and email only; Google sign-in was explicitly removed.
            Button("Ich habe bereits ein Konto") { authMode = .signIn }
                .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("welcome-email-login")
            if let message = store.authMessage { Text(message).font(.footnote).accessibilityIdentifier("auth-feedback") }
            WelcomeLegalLinks()
          }.padding(FYLayout.page)
        }.background(FYColor.background).navigationBarTitleDisplayMode(.inline)
    }
}

private struct WelcomeLegalLinks: View {
    var body: some View {
        // This is the owner's existing website policy, not a published FYRUP policy.
        // The separate FYRUP draft and missing terms remain release blockers.
        Link("Datenschutz der ObjektSignal-Website", destination: URL(string: "https://objektsignal.com/datenschutz")!)
            .font(.footnote).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("welcome-privacy")
    }
}
