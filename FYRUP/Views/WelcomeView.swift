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
                VStack(alignment: .leading, spacing: 24) {
                    FYRUPWordmark(size: 38).frame(maxWidth: .infinity).padding(.top, 16)
                    Text("Deine bessere Version beginnt heute.")
                        .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("welcome-heading")
                    Text("Mehr Energie. Mehr Gesundheit. Mehr von dir.")
                        .font(.body).foregroundStyle(FYColor.muted)
                    // Existing project artwork. Exact mountain original and license evidence remain outstanding.
                    Image("WelcomeHeroLight").resizable().scaledToFill()
                        .frame(height: 260).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    if let message = store.authMessage { Text(message).font(.footnote).accessibilityIdentifier("auth-feedback") }
                }.padding(FYLayout.page)
            }.background(FYColor.background)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 4) {
                        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsAccountChoice = true } } label: {
                            Label("Los geht’s", systemImage: "arrow.right")
                        }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("welcome-intro-next")
                        Button("Ich habe bereits ein Konto") { authMode = .signIn }
                            .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("welcome-email-login")
                        WelcomeLegalLinks()
                    }.padding(.horizontal, FYLayout.page).padding(.vertical, 8).background(FYColor.background)
                }
                .navigationDestination(isPresented: $showsAccountChoice) { accountChoice }
        }.fullScreenCover(item: $authMode) { mode in AuthView(mode: mode).id(mode.id) }
    }

    private var accountChoice: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Text("Konto erstellen").font(.largeTitle.bold()).accessibilityIdentifier("account-choice-title")
            Text("Wähle eine Option, um fortzufahren.").foregroundStyle(FYColor.muted)
            SignInWithAppleButton(.continue) { store.configureAppleRequest($0) } onCompletion: { result in
                Task { await store.handleAppleResult(result) }
            }.signInWithAppleButtonStyle(.white).frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FYColor.line))
                .disabled(store.isBusy)
            Button { authMode = .registration } label: { Label("Mit E-Mail fortfahren", systemImage: "envelope") }
                .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("welcome-create-account").disabled(store.isBusy)
            // Google is disabled in the production project. No nonfunctional sign-in option.
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
