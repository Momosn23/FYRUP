import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showsAuth = false
    @State private var createsAccount = false
    var body: some View {
        ZStack {
            Image("SplashHero").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.25), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                FYRUPWordmark(size: 54)
                Text("SAME ENERGY.\nHIGHER STANDARDS.")
                    .font(.caption.weight(.bold)).tracking(1.8).multilineTextAlignment(.center)
                Spacer().frame(height: 48)
                SignInWithAppleButton(.signIn) { store.configureAppleRequest($0) } onCompletion: { result in
                    Task { await store.handleAppleResult(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("Mit E-Mail anmelden") { createsAccount = false; showsAuth = true }.buttonStyle(SecondaryButtonStyle())
                Button("Account erstellen") { createsAccount = true; showsAuth = true }
                    .font(.footnote).foregroundStyle(.white.opacity(0.75)).underline()
                Text("More than training. A stronger you.")
                    .font(.footnote.italic()).foregroundStyle(.white.opacity(0.64)).padding(.top, 18)
            }
            .padding(.horizontal, 28).padding(.bottom, 28)
        }
        .sheet(isPresented: $showsAuth) { AuthView(initiallyCreatesAccount: createsAccount) }
    }
}

struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var createsAccount: Bool
    init(initiallyCreatesAccount: Bool = false) { _createsAccount = State(initialValue: initiallyCreatesAccount) }
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
    @State private var birthYear = ""
    @State private var city = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, username, birthYear, city }
    private var normalizedUsername: String { username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    private var usernameIsValid: Bool { normalizedUsername.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingProgress(step: 1, total: 3) { Task { await store.logout() } }
                Text("Profil erstellen").font(.system(size: 30, weight: .bold))
                Text("Erzähl uns ein paar Infos über dich.").foregroundStyle(FYColor.muted)

                ZStack(alignment: .bottomTrailing) {
                    Image("SplashHero").resizable().scaledToFill().frame(width: 92, height: 92).clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 2))
                    Image(systemName: "camera.fill").font(.caption.bold()).frame(width: 30, height: 30)
                        .background(FYColor.elevated, in: Circle()).overlay(Circle().stroke(.white.opacity(0.45)))
                }.frame(maxWidth: .infinity).padding(.vertical, 4)

                OnboardingField(title: "Anzeigename", placeholder: "z. B. Max", text: $name, symbol: "person", suffix: nil)
                    .textContentType(.name).focused($focusedField, equals: .name)
                OnboardingField(title: "Username", placeholder: "maxfyrup", text: $username, symbol: "at", suffix: usernameIsValid ? "checkmark" : nil)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focusedField, equals: .username)
                Text("So finden dich deine Freunde.").font(.caption).foregroundStyle(FYColor.muted).padding(.top, -12)
                OnboardingField(title: "Geburtsjahr (optional)", placeholder: "z. B. 1998", text: $birthYear, symbol: "calendar", suffix: nil)
                    .keyboardType(.numberPad).focused($focusedField, equals: .birthYear)
                OnboardingField(title: "Stadt (optional)", placeholder: "z. B. Köln", text: $city, symbol: "location", suffix: nil)
                    .textContentType(.addressCity).focused($focusedField, equals: .city)

                Button("Weiter") {
                    focusedField = nil
                    Task { await store.saveProfile(displayName: name, username: normalizedUsername, birthYear: Int(birthYear), city: city) }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !usernameIsValid)
                Text("Keine Sorge, du kannst das später jederzeit in deinem Profil ändern.")
                    .font(.caption2).foregroundStyle(FYColor.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }.padding(22)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(OnboardingBackground())
        .task {
            guard name.isEmpty, username.isEmpty else { return }
            name = store.profile?.displayName ?? store.suggestedDisplayName
            username = store.profile?.username ?? ""
            birthYear = store.profile?.birthYear.map(String.init) ?? ""
            city = store.profile?.city ?? ""
        }
    }
}

struct SportsSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var selected = Set<SportKind>()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingProgress(step: 2, total: 3) { store.route = .profileSetup }
            Text("Welche Sportarten\nmachst du?").font(.system(size: 30, weight: .bold))
            Text("Wähle alles aus, was auf dich zutrifft.\nDu kannst das später jederzeit ändern.").foregroundStyle(FYColor.muted)
            ScrollView { SportGrid(selected: $selected).padding(.vertical, 4) }
            Button("Weiter") { Task { await store.saveProfile(displayName: store.profile?.displayName ?? "", username: store.profile?.username ?? "", sports: Array(selected)) } }
                .buttonStyle(PrimaryButtonStyle()).disabled(selected.isEmpty)
        }
        .padding(22)
        .background(OnboardingBackground())
        .task { if selected.isEmpty { selected = Set(store.profile?.sports ?? []) } }
    }
}

struct SportGrid: View {
    @Binding var selected: Set<SportKind>
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SportKind.allCases) { sport in
                Button { selected.formSymmetricDifference([sport]) } label: {
                    VStack(spacing: 9) {
                        Image(systemName: sport.symbol).font(.title2)
                        Text(sport.title).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .foregroundStyle(.white)
                        .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected.contains(sport) ? FYColor.lime : FYColor.line, lineWidth: selected.contains(sport) ? 2 : 1))
                        .overlay(alignment: .topTrailing) { if selected.contains(sport) { Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime).background(.black, in: Circle()).padding(7) } }
                }.accessibilityLabel(sport.title).accessibilityAddTraits(selected.contains(sport) ? .isSelected : [])
            }
        }
    }
}

struct OnboardingCompleteView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(spacing: 20) {
            OnboardingProgress(step: 3, total: 3) { store.route = .sportsSetup }
            Spacer()
            ZStack {
                Circle().fill(FYColor.lime.opacity(0.12)).frame(width: 132, height: 132)
                Circle().stroke(FYColor.lime.opacity(0.28), lineWidth: 1).frame(width: 132, height: 132)
                Image(systemName: "flame.fill").font(.system(size: 64)).foregroundStyle(FYColor.lime)
            }
            Text("Du bist startklar.").font(.system(size: 32, weight: .bold))
            Text("Deine Crew, deine Trainings, dein Antrieb.\nAb jetzt beginnt FYRUP immer direkt im Heute-Feed.")
                .foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
            Spacer()
            Button("FYRUP STARTEN") { Task { await store.finishOnboarding() } }.buttonStyle(PrimaryButtonStyle())
        }.padding(22).background(OnboardingBackground())
    }
}

private struct OnboardingProgress: View {
    let step: Int
    let total: Int
    let back: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: back) { Image(systemName: "chevron.left").font(.headline).frame(width: 30, height: 30) }
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { index in
                    Capsule().fill(index <= step ? FYColor.lime : FYColor.elevated).frame(height: 4)
                }
            }
            Text("\(step) / \(total)").font(.caption.bold()).foregroundStyle(FYColor.muted).monospacedDigit()
        }.foregroundStyle(.white)
    }
}

private struct OnboardingField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let symbol: String
    let suffix: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.82))
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(FYColor.muted).frame(width: 20)
                TextField(placeholder, text: $text)
                if let suffix { Image(systemName: suffix).foregroundStyle(FYColor.lime).font(.subheadline.bold()) }
            }
            .padding(.horizontal, 14).frame(minHeight: 50)
            .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FYColor.line))
        }
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            FYColor.background
            RadialGradient(colors: [FYColor.lime.opacity(0.12), .clear], center: .top, startRadius: 0, endRadius: 330)
        }.ignoresSafeArea()
    }
}
