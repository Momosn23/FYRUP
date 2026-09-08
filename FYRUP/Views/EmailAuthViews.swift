import SwiftUI

struct EmailConfirmationView: View {
    @Environment(AppStore.self) private var store
    private var isRecovery: Bool { store.pendingEmailAuth?.kind == .recovery }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "envelope.badge.shield.half.filled").font(.system(size: 48)).foregroundStyle(FYColor.lime).accessibilityHidden(true)
                    Text(isRecovery ? "Prüfe dein Postfach" : "E-Mail bestätigen").font(.largeTitle.bold())
                    Text(isRecovery
                         ? "Wenn ein Konto mit dieser Adresse besteht, erhältst du einen Link zum Zurücksetzen."
                         : "Öffne den Bestätigungslink in deiner E-Mail, um mit deinem Konto weiterzumachen.")
                        .foregroundStyle(FYColor.muted)
                    Text(store.pendingEmailAuth?.maskedEmail ?? "Deine E-Mail-Adresse").font(.headline)
                        .accessibilityIdentifier("auth-masked-email")
                    Text("Öffne den Link auf diesem iPhone. Prüfe auch deinen Spam-Ordner. Nach der Bestätigung geht es hier weiter.")
                        .font(.footnote).foregroundStyle(FYColor.muted)
                    if let message = store.authMessage { Text(message).font(.footnote).accessibilityIdentifier("auth-feedback") }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Button("Link erneut senden") { Task { await store.resendEmailAuth() } }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(store.isBusy || !(store.pendingEmailAuth?.canResend(at: context.date) ?? false))
                            .accessibilityIdentifier("auth-resend")
                    }
                    Button("Andere Adresse oder Anmeldung verwenden") { Task { await store.cancelEmailAuth() } }
                        .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("auth-change-email").disabled(store.isBusy)
                }.padding(FYLayout.page)
            }.background(FYColor.background).navigationTitle("Dein Konto").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PasswordRecoveryView: View {
    @Environment(AppStore.self) private var store
    @State private var password = ""
    @State private var confirmation = ""
    @State private var visible = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Neues Passwort").font(.largeTitle.bold())
                    Text("Lege ein neues Passwort fest. Danach meldest du dich damit an.").foregroundStyle(FYColor.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Neues Passwort").font(.footnote)
                        HStack {
                            Group {
                                if visible { TextField("Mindestens 6 Zeichen", text: $password) }
                                else { SecureField("Mindestens 6 Zeichen", text: $password) }
                            }.textContentType(.newPassword).accessibilityIdentifier("recovery-password")
                            Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye").frame(width: 44, height: 44) }
                                .accessibilityLabel(visible ? "Passwort verbergen" : "Passwort anzeigen")
                        }.padding(.horizontal, 12).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passwort wiederholen").font(.footnote)
                        SecureField("Noch einmal eingeben", text: $confirmation).textContentType(.newPassword)
                            .padding(14).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("recovery-confirmation")
                    }
                    Text("Mindestens 6 Zeichen. Ein längeres, einzigartiges Passwort schützt dein Konto besser.").font(.footnote).foregroundStyle(FYColor.muted)
                    if !confirmation.isEmpty && confirmation != password { Text("Die Passwörter stimmen noch nicht überein.").font(.footnote).foregroundStyle(FYColor.coral) }
                    if let message = store.authMessage { Text(message).font(.footnote).accessibilityIdentifier("auth-feedback") }
                    Button("Passwort speichern") {
                        let submitted = password
                        Task { await store.updateRecoveredPassword(submitted) }
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("recovery-save")
                        .disabled(store.isBusy || password.count < PendingEmailAuth.minimumPasswordLength || confirmation != password)
                    Button("Neuen Link anfordern oder zurück") { Task { await store.cancelEmailAuth() } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(store.isBusy)
                }.textInputAutocapitalization(.never).autocorrectionDisabled().padding(FYLayout.page)
            }.scrollDismissesKeyboard(.interactively).background(FYColor.background)
                .navigationTitle("Passwort zurücksetzen").navigationBarTitleDisplayMode(.inline)
        }.onDisappear { password = ""; confirmation = ""; visible = false }
    }
}
