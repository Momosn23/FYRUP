import AuthenticationServices
import SwiftUI

enum AuthMode: String, Identifiable {
    case signIn, registration
    var id: String { rawValue }
}


struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showsPassword = false
    @State private var mode: AuthMode
    private var createsAccount: Bool { mode == .registration }

    init(mode: AuthMode = .signIn) { _mode = State(initialValue: mode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(createsAccount ? "E-Mail & Passwort" : "Willkommen zurück")
                        .font(.system(size: 29, weight: .black)).foregroundStyle(FYColor.ink)
                        .accessibilityIdentifier("auth-title")
                    if createsAccount { Text("Erstelle ein Konto mit deiner E-Mail-Adresse.").font(.subheadline).foregroundStyle(FYColor.muted) }
                    Text("E-Mail-Adresse").onboardingLabel()
                    TextField("max@example.com", text: $email)
                        .textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).fyField()
                        .accessibilityIdentifier("auth-email")
                    Text("Passwort").onboardingLabel()
                    HStack(spacing: 8) {
                        Group {
                            if showsPassword { TextField("Dein Passwort", text: $password) }
                            else { SecureField(createsAccount ? "Mindestens 6 Zeichen" : "Dein Passwort", text: $password) }
                        }.textContentType(createsAccount ? .newPassword : .password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("auth-password")
                        Button { showsPassword.toggle() } label: {
                            Image(systemName: showsPassword ? "eye.slash" : "eye").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(showsPassword ? "Passwort verbergen" : "Passwort anzeigen")
                            .accessibilityIdentifier("auth-toggle-password")
                    }.fyField()
                    if createsAccount {
                        PasswordRule(text: "Mindestens 6 Zeichen", valid: password.count >= PendingEmailAuth.minimumPasswordLength)
                        Text("Tipp: Verwende ein längeres, einzigartiges Passwort.").font(.footnote).foregroundStyle(FYColor.muted)
                    }
                    if let message = store.authMessage { Text(message).font(.footnote).foregroundStyle(FYColor.coral).accessibilityIdentifier("auth-feedback") }
                    Button(createsAccount ? "Konto erstellen" : "Anmelden") {
                        let submittedMode = mode; let submittedEmail = email; let submittedPassword = password
                        Task {
                            if submittedMode == .registration { await store.signUp(email: submittedEmail, password: submittedPassword) }
                            else { await store.signIn(email: submittedEmail, password: submittedPassword) }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (createsAccount ? password.count < PendingEmailAuth.minimumPasswordLength : password.isEmpty) || store.isBusy)
                        .accessibilityIdentifier("auth-submit")
                    SignInWithAppleButton(.continue) { store.configureAppleRequest($0) } onCompletion: { result in Task { await store.handleAppleResult(result) } }
                        .signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).disabled(store.isBusy)
                    Button(createsAccount ? "Schon dabei? Anmelden" : "Noch kein Konto? Registrieren") {
                        showsPassword = false
                        store.authMessage = nil
                        mode = createsAccount ? .signIn : .registration
                    }
                        .foregroundStyle(FYColor.ink).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("auth-switch-mode").disabled(store.isBusy)
                    if !createsAccount {
                        Button("Passwort vergessen") { Task { await store.resetPassword(email: email) } }
                            .font(.footnote).foregroundStyle(FYColor.muted).frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isBusy)
                    }
                }.padding(24)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Zurück zur Anmeldung").accessibilityIdentifier("auth-close")
                        .disabled(store.isBusy)
                }
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(store.isBusy)
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { password = ""; showsPassword = false }
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
    @State private var fieldError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, username, birthYear, city }
    private var normalizedUsername: String { username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    private var usernameIsValid: Bool { normalizedUsername.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                FYSetupHeading(title: "Dein Profil", subtitle: "So finden dich deine Freunde in FYRUP.", step: 1, total: 1, showsProgress: false) { Task { await store.logout() } }
                    .accessibilityElement(children: .contain).accessibilityIdentifier("onboarding-progress")
                AvatarPicker(profile: store.profile, jpegData: $avatarJPEG).frame(maxWidth: .infinity).padding(.vertical, 2)
                FYInputField(title: "Anzeigename", placeholder: "Dein Name", text: $name, identifier: "profile-setup-name")
                    .textContentType(.name).focused($focusedField, equals: .name)
                FYInputField(title: "Benutzername", placeholder: "Dein eindeutiger Benutzername", text: $username, identifier: "profile-setup-username")
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focusedField, equals: .username)
                Text("3–24 Buchstaben, Zahlen oder _. Die Verfügbarkeit wird beim Speichern geprüft.").font(.footnote).foregroundStyle(FYColor.muted)
                FYInputField(title: "Geburtsjahr · optional", placeholder: "Keine Angabe", text: $birthYear, identifier: "profile-setup-birth-year")
                    .keyboardType(.numberPad).focused($focusedField, equals: .birthYear)
                Text("Das Geburtsjahr bleibt privat. Es erscheint nicht in der Suche oder auf Freundesprofilen.").font(.footnote).foregroundStyle(FYColor.muted)
                if let fieldError { Text(fieldError).font(.footnote).foregroundStyle(FYColor.coral) }
            }.padding(FYLayout.page)
        }
        .scrollDismissesKeyboard(.interactively).clipped().background(FYColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button("Weiter") {
                    focusedField = nil
                    fieldError = nil
                    let year = birthYear.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Match the existing database field constraint, not a new age policy.
                    guard year.isEmpty || Int(year).map({ (1900...(Calendar.current.component(.year, from: .now) - 13)).contains($0) }) == true else {
                        fieldError = "Prüfe dein Geburtsjahr oder lass die Angabe leer."; return
                    }
                    Task { await store.saveProfile(displayName: name, username: normalizedUsername, birthYear: Int(year), city: city, avatarJPEG: avatarJPEG) }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !usernameIsValid || store.isBusy)
                .padding(FYLayout.page).background(FYColor.background).accessibilityIdentifier("profile-setup-save")
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focusedField = nil } } }
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
    @Environment(\.dismiss) private var dismiss
    var isEditing = false
    @State private var selected = Set<SportKind>()
    @State private var restored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FYSetupHeading(title: "Deine Sportarten", subtitle: "Wähle, was dir Spaß macht. Du kannst das später ändern.", step: 1, total: 1, showsProgress: false) {
                if isEditing { dismiss() } else { store.route = .profileSetup }
            }
            ScrollView { SportGrid(selected: $selected).padding(.vertical, 4) }
            Button(isEditing ? "Speichern" : "Weiter") {
                Task {
                    if isEditing { if await store.saveSportsPreferences(Array(selected)) { dismiss() } }
                    else { await store.saveOnboardingSports(Array(selected)) }
                }
            }.buttonStyle(PrimaryButtonStyle()).disabled(store.isBusy)
            if !isEditing {
                Button("Später auswählen") { Task { await store.saveOnboardingSports([]) } }.frame(minHeight: 44).disabled(store.isBusy)
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
        .background(OnboardingBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task { if !restored { selected = Set(store.profile?.sports ?? []); restored = true } }
    }
}

struct SportGrid: View {
    @Binding var selected: Set<SportKind>
    @Environment(\.dynamicTypeSize) private var typeSize
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2) }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(SportKind.allCases) { sport in
                Button { selected.formSymmetricDifference([sport]) } label: {
                    ZStack(alignment: .bottomLeading) {
                        SportPhoto(sport: sport)
                        LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                        HStack(alignment: .bottom) {
                            Text(sport.title).font(.headline.weight(.black)).lineLimit(2)
                            Spacer(minLength: 4)
                            Image(systemName: selected.contains(sport) ? "checkmark.circle.fill" : "circle")
                                .font(.title3).symbolRenderingMode(.palette)
                                .foregroundStyle(selected.contains(sport) ? FYColor.lime : .white, .white)
                        }.padding(12)
                    }
                    .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 168 : 138)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(selected.contains(sport) ? FYColor.lime : FYColor.line, lineWidth: selected.contains(sport) ? 2.5 : 0.7))
                }.buttonStyle(FYPressStyle()).accessibilityLabel(sport.title).accessibilityAddTraits(selected.contains(sport) ? .isSelected : [])
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
        Color.white.ignoresSafeArea()
    }
}
