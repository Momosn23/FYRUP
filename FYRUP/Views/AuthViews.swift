import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @State private var showsAuth = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "flame.fill").font(.system(size: 72, weight: .black)).foregroundStyle(FYColor.lime)
            Text("FYRUP").font(.system(size: 58, weight: .black, design: .rounded))
            Text("Your friends make you move.").font(.title2.bold())
            Text("Sieh, wer heute aktiv ist, plane Training mit Freunden und motiviert euch gegenseitig.").font(.body).foregroundStyle(FYColor.muted)
            Spacer()
            Button("LOS GEHT'S") { showsAuth = true }.buttonStyle(PrimaryButtonStyle())
        }.padding(24).sheet(isPresented: $showsAuth) { AuthView() }
    }
}

struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var createsAccount = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(createsAccount ? "Konto erstellen" : "Willkommen zurück").font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    TextField("E-Mail", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).fyField()
                    SecureField("Passwort", text: $password).textContentType(createsAccount ? .newPassword : .password).fyField()
                    Button(createsAccount ? "REGISTRIEREN" : "ANMELDEN") {
                        Task { createsAccount ? await store.signUp(email: email, password: password) : await store.signIn(email: email, password: password) }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(email.isEmpty || password.count < 8)
                    SignInWithAppleButton(.continue) { store.configureAppleRequest($0) } onCompletion: { result in Task { await store.handleAppleResult(result) } }
                        .signInWithAppleButtonStyle(.white).frame(height: 52).clipShape(Capsule())
                    Button(createsAccount ? "Schon dabei? Anmelden" : "Noch kein Konto? Registrieren") { createsAccount.toggle() }.foregroundStyle(.white)
                    if !createsAccount { Button("Passwort vergessen") { Task { await store.resetPassword(email: email) } }.font(.footnote).foregroundStyle(FYColor.muted) }
                }.padding(24)
            }.background(FYColor.background).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.presentationDetents([.large]).preferredColorScheme(.dark)
    }
}

private extension View {
    func fyField() -> some View { self.padding(16).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 16)).autocorrectionDisabled() }
}

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var username = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dein Profil").font(.largeTitle.bold())
            Text("So erkennt dich deine Crew.").foregroundStyle(FYColor.muted)
            TextField("Anzeigename", text: $name).padding(16).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 16))
            TextField("username", text: $username).textInputAutocapitalization(.never).padding(16).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 16))
            Text("3–24 Zeichen: a–z, 0–9 und _").font(.caption).foregroundStyle(FYColor.muted)
            Spacer()
            Button("WEITER") { Task { await store.saveProfile(displayName: name, username: username) } }.buttonStyle(PrimaryButtonStyle()).disabled(name.isEmpty || username.isEmpty)
        }.padding(24)
    }
}

struct SportsSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var selected = Set<SportKind>()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Was bewegt dich?").font(.largeTitle.bold())
            Text("Wähle alles, was zu dir passt.").foregroundStyle(FYColor.muted)
            ScrollView { SportGrid(selected: $selected) }
            Button("FYRUP STARTEN") { Task { await store.saveProfile(displayName: store.profile?.displayName ?? "", username: store.profile?.username ?? "", sports: Array(selected)) } }
                .buttonStyle(PrimaryButtonStyle()).disabled(selected.isEmpty)
        }.padding(24)
    }
}

struct SportGrid: View {
    @Binding var selected: Set<SportKind>
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SportKind.allCases) { sport in
                Button { selected.formSymmetricDifference([sport]) } label: {
                    VStack(spacing: 10) { Image(systemName: sport.symbol).font(.title); Text(sport.title).font(.subheadline.bold()) }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .foregroundStyle(selected.contains(sport) ? .black : .white)
                        .background(selected.contains(sport) ? FYColor.lime : FYColor.surface, in: RoundedRectangle(cornerRadius: 20))
                }.accessibilityLabel(sport.title).accessibilityAddTraits(selected.contains(sport) ? .isSelected : [])
            }
        }
    }
}

