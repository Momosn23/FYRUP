import AuthenticationServices
import SwiftUI

enum AuthMode: String, Identifiable {
    case signIn, registration
    var id: String { rawValue }
}

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var settledPage = -1
    @State private var authMode: AuthMode?

    var body: some View {
        ZStack {
            switch page {
            case 0: splash
            case 1: introOne
            case 2: introTwo
            default: loginChoice
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: page)
        .fullScreenCover(item: $authMode) { mode in AuthView(mode: mode).id(mode.id) }
        .task(id: page) {
            let displayedPage = page
            if displayedPage == 0 {
                do { try await Task.sleep(for: .seconds(1.4)) } catch { return }
                guard !Task.isCancelled, page == 0 else { return }
                page = 1
            } else {
                // A page is interactable only once its crossfade is finished. Snapshot tests
                // wait for this enabled state instead of photographing a mid-transition overlay.
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                }
                guard !Task.isCancelled, page == displayedPage else { return }
                settledPage = displayedPage
            }
        }
    }

    private var splash: some View {
        ZStack {
            Image("SplashRunnerLight").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.04), .black.opacity(0.52)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 12) {
                Spacer()
                FYRUPWordmark(size: 57, color: .white)
                Text("Your friends\nmake you move.")
                    .font(.title3.weight(.bold)).multilineTextAlignment(.center).foregroundStyle(.white)
                Spacer().frame(height: 54)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FYRUP. Your friends make you move.")
        .onTapGesture { page = 1 }
    }

    private var introOne: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Gemeinsam\nmehr erreichen.")
                .font(.system(size: 34, weight: .black)).foregroundStyle(FYColor.ink)
            Text("Sieh, wer heute aktiv ist, plane Sessions mit Freunden und motiviert euch gegenseitig.")
                .font(.body).foregroundStyle(FYColor.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image("OnboardingCrewCollage").resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            PageDots(current: 0)
            Button("Los geht's") { page = 2 }.buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("welcome-intro-next").disabled(settledPage != 1)
        }
        .padding(.horizontal, 24).padding(.top, 54).padding(.bottom, 18)
        .background(Color.white.ignoresSafeArea())
    }

    private var introTwo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("OnboardingCrewCollage").resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Gemeinsam aktiv.\nEine stärkere Crew.")
                .font(.system(size: 31, weight: .black)).foregroundStyle(FYColor.ink)
            Text("Gym, Laufen, Fußball und mehr – alles in einer App.")
                .font(.body).foregroundStyle(FYColor.muted)
            Spacer(minLength: 4)
            PageDots(current: 1)
            Button("Weiter") { page = 3 }.buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("welcome-crew-next").disabled(settledPage != 2)
        }
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 18)
        .background(Color.white.ignoresSafeArea())
    }

    private var loginChoice: some View {
        ZStack {
            Image("WelcomeHeroLight").resizable().scaledToFill()
                .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            LinearGradient(stops: [
                .init(color: .white.opacity(0.10), location: 0),
                .init(color: .white.opacity(0.02), location: 0.38),
                .init(color: .black.opacity(0.16), location: 0.58),
                .init(color: .black.opacity(0.72), location: 1)
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 14) {
                Spacer().frame(height: 82)
                Text("Willkommen bei").font(.title3.weight(.bold)).foregroundStyle(FYColor.ink)
                    .shadow(color: .white.opacity(0.8), radius: 8)
                FYRUPWordmark(size: 50)
                    .shadow(color: .white.opacity(0.75), radius: 10)
                Text("Your friends make you move.").font(.subheadline.weight(.medium)).foregroundStyle(FYColor.ink.opacity(0.76))
                    .shadow(color: .white, radius: 7)
                // Keep the actions inside the visible safe area on compact iPhones.
                // A flexible spacer preserves the photo-first composition without
                // pushing login controls out of the accessibility hierarchy.
                Spacer(minLength: 24)
                SignInWithAppleButton(.signIn) { store.configureAppleRequest($0) } onCompletion: { result in
                    Task { await store.handleAppleResult(result) }
                }
                .signInWithAppleButtonStyle(.white).frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                .disabled(settledPage != 3 || store.isBusy)
                Button("Mit E-Mail anmelden") { authMode = .signIn }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.62)))
                    .buttonStyle(FYPressStyle())
                    .accessibilityIdentifier("welcome-email-login").disabled(settledPage != 3 || store.isBusy)
                Button("Account erstellen") { authMode = .registration }
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white).underline()
                    .accessibilityIdentifier("welcome-create-account").disabled(settledPage != 3 || store.isBusy)
                Text("Mit der Anmeldung stimmst du unseren AGB und der Datenschutzerklärung zu.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.78)).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26).padding(.bottom, 18)
        }
        .accessibilityIdentifier("welcome-login-full-hero")
    }
}

private struct PageDots: View {
    let current: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(index == current ? FYColor.ink : FYColor.line).frame(width: 6, height: 6)
            }
        }.frame(maxWidth: .infinity)
    }
}

struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AuthMode
    private var createsAccount: Bool { mode == .registration }

    init(mode: AuthMode = .signIn) { _mode = State(initialValue: mode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(createsAccount ? "Account erstellen" : "Willkommen zurück")
                        .font(.system(size: 29, weight: .black)).foregroundStyle(FYColor.ink)
                        .accessibilityIdentifier("auth-title")
                    if createsAccount { Text("Erstelle dein FYRUP-Profil in wenigen Schritten.").font(.subheadline).foregroundStyle(FYColor.muted) }
                    Text("E-Mail-Adresse").onboardingLabel()
                    TextField("max@example.com", text: $email)
                        .textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).fyField()
                        .accessibilityIdentifier("auth-email")
                    Text("Passwort").onboardingLabel()
                    SecureField("Mindestens 8 Zeichen", text: $password)
                        .textContentType(createsAccount ? .newPassword : .password).fyField()
                        .accessibilityIdentifier("auth-password")
                    if createsAccount {
                        PasswordRule(text: "Mindestens 8 Zeichen", valid: password.count >= 8)
                        PasswordRule(text: "Ein Großbuchstabe", valid: password.contains(where: \.isUppercase))
                        PasswordRule(text: "Eine Zahl", valid: password.contains(where: \.isNumber))
                    }
                    Button(createsAccount ? "Weiter" : "Anmelden") {
                        let submittedMode = mode; let submittedEmail = email; let submittedPassword = password
                        Task {
                            if submittedMode == .registration { await store.signUp(email: submittedEmail, password: submittedPassword) }
                            else { await store.signIn(email: submittedEmail, password: submittedPassword) }
                        }
                    }.buttonStyle(SecondaryButtonStyle()).disabled(email.isEmpty || password.count < 8 || store.isBusy)
                        .accessibilityIdentifier("auth-submit")
                    SignInWithAppleButton(.continue) { store.configureAppleRequest($0) } onCompletion: { result in Task { await store.handleAppleResult(result) } }
                        .signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12))
                    Button(createsAccount ? "Schon dabei? Anmelden" : "Noch kein Konto? Registrieren") {
                        mode = createsAccount ? .signIn : .registration
                    }
                        .foregroundStyle(FYColor.ink).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("auth-switch-mode").disabled(store.isBusy)
                    if !createsAccount {
                        Button("Passwort vergessen") { Task { await store.resetPassword(email: email) } }
                            .font(.footnote).foregroundStyle(FYColor.muted).frame(maxWidth: .infinity)
                    }
                }.padding(24)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Zurück zur Anmeldung").accessibilityIdentifier("auth-close")
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct PasswordRule: View {
    let text: String
    let valid: Bool
    var body: some View {
        Label(text, systemImage: valid ? "checkmark.circle.fill" : "circle")
            .font(.caption).foregroundStyle(valid ? FYColor.lime : FYColor.muted)
    }
}

private extension View {
    func fyField() -> some View {
        self.padding(.horizontal, 14).frame(minHeight: 50)
            .foregroundStyle(FYColor.ink).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 11)).autocorrectionDisabled()
    }
}

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var username = ""
    @State private var birthYear = ""
    @State private var city = ""
    @State private var avatarJPEG: Data?
    @FocusState private var focusedField: Field?

    private enum Field { case name, username, birthYear, city }
    private var normalizedUsername: String { username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    private var usernameIsValid: Bool { normalizedUsername.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                OnboardingProgress(step: 1, total: 3) { Task { await store.logout() } }
                    .accessibilityElement(children: .contain).accessibilityIdentifier("onboarding-progress")
                Text("Erzähl uns von dir").font(.system(size: 30, weight: .black)).foregroundStyle(FYColor.ink)
                AvatarPicker(profile: store.profile, jpegData: $avatarJPEG).frame(maxWidth: .infinity).padding(.vertical, 2)
                OnboardingField(title: "Vorname", placeholder: "Max", text: $name, symbol: nil, suffix: nil)
                    .textContentType(.name).focused($focusedField, equals: .name)
                OnboardingField(title: "Username", placeholder: "maxfyrup", text: $username, symbol: "at", suffix: usernameIsValid ? "checkmark.circle.fill" : nil)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focusedField, equals: .username)
                OnboardingField(title: "Geburtsjahr (optional)", placeholder: "2003", text: $birthYear, symbol: nil, suffix: nil)
                    .keyboardType(.numberPad).focused($focusedField, equals: .birthYear)
                OnboardingField(title: "Stadt (optional)", placeholder: "Köln", text: $city, symbol: nil, suffix: nil)
                    .textContentType(.addressCity).focused($focusedField, equals: .city).submitLabel(.done)
                    .onSubmit { focusedField = nil }
                Button("Weiter") {
                    focusedField = nil
                    Task { await store.saveProfile(displayName: name, username: normalizedUsername, birthYear: Int(birthYear), city: city, avatarJPEG: avatarJPEG) }
                }
                .buttonStyle(SecondaryButtonStyle()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !usernameIsValid)
            }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively).background(OnboardingBackground())
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
        VStack(alignment: .leading, spacing: 14) {
            OnboardingProgress(step: 2, total: 3) { store.route = .profileSetup }
            Text("Was machst du gerne?").font(.system(size: 28, weight: .black)).foregroundStyle(FYColor.ink)
            Text("Wähle eine oder mehrere Sportarten aus.").font(.subheadline).foregroundStyle(FYColor.muted)
            ScrollView { SportGrid(selected: $selected).padding(.vertical, 4) }
            Button("Weiter") { Task { await store.saveOnboardingSports(Array(selected)) } }
                .buttonStyle(SecondaryButtonStyle()).disabled(selected.isEmpty)
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
        .background(OnboardingBackground())
        .task { if selected.isEmpty { selected = Set(store.profile?.sports ?? []) } }
    }
}

struct SportGrid: View {
    @Binding var selected: Set<SportKind>
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SportKind.allCases) { sport in
                Button { selected.formSymmetricDifference([sport]) } label: {
                    VStack(spacing: 8) {
                        Image(systemName: sport.symbol).font(.title2).foregroundStyle(sport.accentColor)
                        Text(sport.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.68)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84).foregroundStyle(FYColor.ink)
                    .background(selected.contains(sport) ? FYColor.limeSoft : FYColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected.contains(sport) ? FYColor.lime : FYColor.line, lineWidth: selected.contains(sport) ? 1.5 : 0.8))
                    .overlay(alignment: .topTrailing) {
                        if selected.contains(sport) { Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime).background(.white, in: Circle()).padding(6) }
                    }
                }.accessibilityLabel(sport.title).accessibilityAddTraits(selected.contains(sport) ? .isSelected : [])
            }
        }
    }
}

struct GymSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var selected = Set<String>(["Push"])

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Button { store.route = .sportsSetup } label: { Image(systemName: "chevron.left") }; Spacer() }
            Text("Was ist dein Fokus?").font(.system(size: 28, weight: .black))
            Label("Gym", systemImage: SportKind.gym.symbol).font(.headline)
            ScrollView {
                VStack(spacing: 9) {
                    ForEach(SportCatalog.subtypes[.gym] ?? [], id: \.self) { item in
                        Button { selected.formSymmetricDifference([item]) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: gymSymbol(item)).frame(width: 28).foregroundStyle(selected.contains(item) ? FYColor.ink : FYColor.muted)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(FyrupLanguage.subtype(item, sport: .gym) ?? item).font(.subheadline.bold())
                                    Text(gymSubtitle(item)).font(.caption2).foregroundStyle(FYColor.muted)
                                }
                                Spacer()
                                Image(systemName: selected.contains(item) ? "checkmark.circle.fill" : "circle").foregroundStyle(selected.contains(item) ? FYColor.lime : FYColor.line)
                            }
                            .padding(.horizontal, 14).frame(minHeight: 51).foregroundStyle(FYColor.ink)
                            .background(selected.contains(item) ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected.contains(item) ? FYColor.lime : FYColor.line))
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Überspringen") { Task { await store.saveOnboardingStep("weekly_goal", gymFocus: []) } }.buttonStyle(OutlineButtonStyle())
                Button("Weiter") { Task { await store.saveOnboardingStep("weekly_goal", gymFocus: selected.sorted()) } }.buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(22).background(OnboardingBackground()).foregroundStyle(FYColor.ink)
        .onAppear { if let saved = store.profile?.gymFocus { selected = Set(saved) } }
    }

    private func gymSymbol(_ item: String) -> String {
        switch item { case "Cardio": "figure.run"; case "Legs", "Lower Body": "figure.strengthtraining.traditional"; default: "dumbbell.fill" }
    }
    private func gymSubtitle(_ item: String) -> String {
        switch item {
        case "Push": "Brust, Schultern, Trizeps"
        case "Pull": "Rücken, Bizeps"
        case "Legs": "Beine, Gesäß"
        default: item == "Freies Training" ? "Eigener Fokus" : ""
        }
    }
}

struct FriendsSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Button { store.route = .weeklyGoalSetup } label: { Image(systemName: "chevron.left") }; Spacer() }
            Text("Freunde hinzufügen").font(.system(size: 28, weight: .black))
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted); TextField("Username suchen …", text: $query).textInputAutocapitalization(.never).onSubmit { Task { await store.searchUsers(query) } } }
                .padding(.horizontal, 13).frame(height: 45).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
            ScrollView {
                VStack(spacing: 9) {
                    ForEach(store.userSearchResults) { profile in
                        HStack(spacing: 12) {
                            AvatarView(profile: profile)
                            VStack(alignment: .leading) { Text(profile.displayName).bold(); Text("@\(profile.username)").font(.caption).foregroundStyle(FYColor.muted) }
                            Spacer()
                            Button("Hinzufügen") { Task { await store.sendFriendRequest(to: profile) } }
                                .font(.caption.bold()).foregroundStyle(FYColor.lime).padding(.horizontal, 12).padding(.vertical, 8).background(FYColor.limeSoft, in: Capsule())
                        }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if store.userSearchResults.isEmpty {
                        ContentUnavailableView("Finde deine Crew", systemImage: "person.2.fill", description: Text("Suche nach dem Username deiner Freunde."))
                            .foregroundStyle(FYColor.muted).padding(.top, 70)
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Später") { Task { await store.saveOnboardingStep("complete") } }.buttonStyle(OutlineButtonStyle())
                Button("Fertig") { Task { await store.saveOnboardingStep("complete") } }.buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(22).background(OnboardingBackground()).foregroundStyle(FYColor.ink)
    }
}

struct OnboardingCompleteView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(spacing: 20) {
            OnboardingProgress(step: 3, total: 3) { store.route = .friendsSetup }
            Spacer()
            ZStack {
                Circle().fill(FYColor.limeSoft).frame(width: 132, height: 132)
                Image(systemName: "flame.fill").font(.system(size: 64)).foregroundStyle(FYColor.lime)
            }
            Text("Du bist startklar.").font(.system(size: 32, weight: .black)).foregroundStyle(FYColor.ink)
            Text("Deine Crew, deine Aktivitäten, dein Antrieb.\nAb jetzt beginnt FYRUP direkt im Heute-Feed.")
                .foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
            Spacer()
            Button("FYRUP STARTEN") { Task { await store.finishOnboarding() } }.buttonStyle(SecondaryButtonStyle())
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
                    Capsule().fill(index <= step ? FYColor.lime : FYColor.line).frame(height: 5)
                }
            }
            Text("\(step) / \(total)").font(.caption.bold()).foregroundStyle(FYColor.muted).monospacedDigit()
        }.foregroundStyle(FYColor.ink)
    }
}

private struct OnboardingField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let symbol: String?
    let suffix: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).onboardingLabel()
            HStack(spacing: 9) {
                if let symbol { Image(systemName: symbol).foregroundStyle(FYColor.ink).frame(width: 18) }
                TextField(placeholder, text: $text).foregroundStyle(FYColor.ink)
                if let suffix { Image(systemName: suffix).foregroundStyle(FYColor.lime) }
            }
            .padding(.horizontal, 13).frame(minHeight: 48).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 11))
        }
    }
}

private extension Text {
    func onboardingLabel() -> some View { self.font(.caption.weight(.semibold)).foregroundStyle(FYColor.muted) }
}

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            Color.white
            RadialGradient(colors: [FYColor.lime.opacity(0.08), .clear], center: .topTrailing, startRadius: 0, endRadius: 380)
        }.ignoresSafeArea()
    }
}
