import SwiftUI

struct PersonalSetupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isOnboarding = false
    @State private var page = 0
    @State private var stepGoal = ""
    @State private var fieldError: String?
    @State private var bodyDraft = BodyMeasurementsDraft()
    @State private var restoredPage = false
    @State private var restoredOwnerID: UUID?
    @FocusState private var stepGoalFocused: Bool
    private let titles = ["Apple Health verbinden", "Körperdaten", "Berechtigungen", "Dein FYRUP"]
    private var ready: Bool { store.setup.value != nil && store.steps.userID == store.session?.userID }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FYSetupHeading(title: titles[page], subtitle: "", step: page + 1, total: 4, showsBack: page > 0 || !isOnboarding) {
                        if page > 0 { changePage(page - 1, proxy: proxy) } else { dismiss() }
                    }.id("setup-top")
                    Group {
                        switch page {
                        case 0: stepsPage
                        case 1:
                            Text("Diese Angaben sind freiwillig. Du kannst FYRUP auch ohne sie für Sport und Freunde nutzen.").foregroundStyle(FYColor.muted)
                            BodyMeasurementsView(draft: $bodyDraft)
                        case 2: permissionsPage
                        default: overviewPage
                        }
                    }.id(page).transition(.opacity.combined(with: .move(edge: .trailing)))
                    if let error = fieldError ?? store.setup.errorMessage { Text(error).font(.footnote).foregroundStyle(FYColor.coral) }
                    if store.setup.value == nil {
                        Button("Einstellungen erneut laden") { store.setup.activate(userID: store.session?.userID) }.buttonStyle(OutlineButtonStyle())
                    }
                }.padding(FYLayout.page)
            }.scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(page == 3 ? "Einrichtung abschließen" : "Weiter") {
                        fieldError = nil
                        if page == 0 {
                            let raw = stepGoal.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "")
                            if !raw.isEmpty, Int(raw).map({ !(1000...100000).contains($0) }) ?? true {
                                fieldError = "Wähle 1.000–100.000 Schritte oder lass das Ziel leer."; return
                            }
                            store.steps.setGoal(Int(raw))
                            if !store.steps.healthDecisionMade { store.steps.continueWithoutHealth() }
                        }
                        if page == 1 {
                            fieldError = bodyDraft.validationMessage
                            guard fieldError == nil, store.setup.update({ bodyDraft.apply(to: &$0) }) else { return }
                        }
                        if page < 3 { changePage(page + 1, proxy: proxy) }
                        else if store.setup.finishSetup() {
                            Haptics.success()
                            if isOnboarding { store.route = .onboardingComplete }
                            else { dismiss() }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!ready || store.steps.isBusy)
                        .accessibilityIdentifier("personal-setup-next")
                    Text("Du entscheidest. Optionale Freigaben dürfen aus bleiben und lassen sich später ändern.")
                        .font(.caption).foregroundStyle(FYColor.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }.padding(FYLayout.page).background(FYColor.background)
            }
        }.background(FYColor.background).toolbar(.hidden, for: .navigationBar)
            .task(id: store.session?.userID) {
                guard let owner = store.session?.userID else { return }
                restorePageIfNeeded()
                await store.steps.activate(userID: owner)
                guard store.session?.userID == owner else { return }
                stepGoal = store.steps.goal.map(String.init) ?? ""
            }
            .onChange(of: store.setup.value == nil) { _, isMissing in if !isMissing { restorePageIfNeeded() } }
            .toolbar {
                if page == 0 {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Fertig") { stepGoalFocused = false }
                    }
                }
            }
    }

    private func changePage(_ target: Int, proxy: ScrollViewProxy) {
        guard store.setup.move(to: target) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { page = target; proxy.scrollTo("setup-top", anchor: .top) }
    }
    private func restorePageIfNeeded() {
        guard (!restoredPage || restoredOwnerID != store.setup.userID), store.setup.value != nil else { return }
        page = store.setup.resumePage; restoredPage = true; restoredOwnerID = store.setup.userID
        fieldError = nil; bodyDraft = .init(store.setup.value)
    }
    private var stepsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Verbinde Apple Health und sieh deine Schritte direkt auf Heute. FYRUP fragt hier nur nach dem Lesen deiner Schritte – nichts wird in Health geschrieben.")
                .font(.subheadline).foregroundStyle(FYColor.muted)
            Button(store.steps.healthRequested ? "Apple Health prüfen" : "Ja, Apple Health verbinden") {
                Task { await store.steps.connect() }
            }.buttonStyle(PrimaryButtonStyle()).disabled(!ready || store.steps.isAuthorizing || !store.steps.isAvailable)
                .accessibilityIdentifier("setup-connect-health")
            if isOnboarding && !store.steps.healthRequested {
                Button("Jetzt ohne Apple Health") { store.steps.continueWithoutHealth() }
                    .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("setup-skip-health")
            }
            Label(store.steps.healthStatusText, systemImage: "heart.text.clipboard").font(.caption).foregroundStyle(FYColor.muted)
            VStack(alignment: .leading, spacing: 12) {
                Text("Dein Schrittziel pro Tag").font(.headline)
                TextField("Optional, z. B. 8.000", text: $stepGoal).keyboardType(.numberPad)
                    .focused($stepGoalFocused)
                    .padding(13).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("setup-step-goal")
                HStack {
                    ForEach([5000, 7500, 10000], id: \.self) { value in
                        Button(StepCountFormat.string(value)) { stepGoal = String(value) }
                            .font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                            .background(FYColor.limeSoft, in: Capsule()).buttonStyle(FYPressStyle())
                    }
                }
                Text("Dein Ziel bleibt privat und ist keine Vorgabe. Schritte zählen nicht als Streak-Einheiten.").font(.caption).foregroundStyle(FYColor.muted)
            }.fyCard()
            VStack(alignment: .leading, spacing: 10) {
                Text("Mit deiner Crew teilen?").font(.headline)
                Text("Nur bestätigte Freunde sehen deine heutige Schrittzahl. Nicht deine Health-Rohdaten, Körperdaten oder dein Schrittziel.").font(.caption).foregroundStyle(FYColor.muted)
                if store.steps.isSharingPreferenceCurrent {
                    Toggle("Schritte mit Freunden teilen", isOn: Binding(get: { store.steps.sharingEnabled == true }, set: { enabled in Task { await store.steps.setSharing(enabled) } }))
                        .disabled(store.steps.isChangingSharing).accessibilityIdentifier("setup-share-steps")
                } else {
                    Text("Gespeicherte Freigabe noch nicht bestätigt.").font(.caption)
                    Button("Freigabe laden") { Task { await store.steps.refresh(force: true) } }.disabled(store.steps.isBusy)
                }
                Text("Health-Zugriff und Teilen sind zwei getrennte Entscheidungen. Teilen ist nicht vorausgewählt.").font(.caption).foregroundStyle(FYColor.muted)
            }.fyCard()
            if let message = store.steps.message { Text(message).font(.caption).foregroundStyle(FYColor.coral) }
        }
    }
    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            NavigationLink { WeatherPlaceView() } label: { setupLink("Ort für Wetter", subtitle: "Stadt auswählen oder Standort einmal verwenden", symbol: "mappin") }.buttonStyle(.plain)
            NavigationLink { LiveAndRestSettingsView() } label: { setupLink("LIVE auf dem Sperrbildschirm", subtitle: "Optionale Anzeige und eigene Satzpausen", symbol: "iphone") }.buttonStyle(.plain)
            Text("Entscheide jetzt, was dich begleiten darf. Jede Systemfreigabe erklärst und bestätigst du separat.").foregroundStyle(FYColor.muted)
            VStack(alignment: .leading, spacing: 8) {
                Label("Einladungen & Erinnerungen", systemImage: "bell.badge.fill").font(.headline)
                Text("Für Session-Einladungen und die von dir gewählten Erinnerungen. Ohne Erlaubnis bleiben Hinweise in FYRUP sichtbar, erscheinen aber nicht als Push.").font(.subheadline).foregroundStyle(FYColor.muted)
                SystemNotificationSettingsRow()
            }.fyCard()
            VStack(alignment: .leading, spacing: 10) {
                Label("Nur, was du wirklich nutzt", systemImage: "hand.raised.fill").font(.headline)
                Text("Beim Profilbild wählst du einzelne Fotos aus. FYRUP braucht keinen Zugriff auf deine gesamte Fotomediathek. Kontakte und Standort werden hier nicht vorsorglich freigegeben.")
                    .font(.subheadline).foregroundStyle(FYColor.muted)
            }.fyCard()
        }
    }
    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ziele, Erinnerungen und Privatsphäre sind jederzeit erreichbar – nichts ist in einem versteckten Menü verschwunden.").foregroundStyle(FYColor.muted)
            NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { setupLink("Mein Wochenplan", subtitle: "Sportarten, Dauer und freie Wochentage", symbol: "calendar") }.buttonStyle(FYPressStyle())
            NavigationLink { FavoriteGymView() } label: { setupLink("Dein Stammgym", subtitle: "Privat speichern, beim Planen vorausfüllen", symbol: "mappin.and.ellipse") }.buttonStyle(FYPressStyle()).accessibilityIdentifier("open-favorite-gym")
            NavigationLink { SupplementsView() } label: { setupLink("Deine Supplements", subtitle: "Eigene Liste und freiwillige Erinnerungen", symbol: "pills.fill") }.buttonStyle(FYPressStyle())
            NavigationLink { NutritionView() } label: { setupLink("Ernährung", subtitle: "Eigene Ziele und Mahlzeiten · optional", symbol: "fork.knife") }.buttonStyle(FYPressStyle())
            NavigationLink { PrivacyView() } label: { setupLink("Deine Privatsphäre", subtitle: "Wer sieht deine Aktivitäten?", symbol: "lock.shield.fill") }.buttonStyle(FYPressStyle())
            Label("Health-Freigaben kannst du zusätzlich jederzeit in Apple Health ändern.", systemImage: "heart.fill").font(.caption).foregroundStyle(FYColor.muted)
        }
    }
    private func setupLink(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.title2).foregroundStyle(FYColor.lime)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(FYColor.muted) }
            Spacer(); Image(systemName: "chevron.right").font(.caption)
        }.foregroundStyle(FYColor.ink).fyCard()
    }
}

struct PersonalSetupHomeCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        NavigationLink { PersonalSetupView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(FYColor.lime)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.setup.value?.completed == true ? "Dein FYRUP" : "Mach FYRUP zu deinem").font(.subheadline.bold())
                    Text("Schritte · Körperdaten · Erinnerungen · LIVE").font(.caption).foregroundStyle(FYColor.muted)
                }
                Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.caption.bold())
            }.foregroundStyle(FYColor.ink).fyCard()
        }.buttonStyle(FYPressStyle()).accessibilityIdentifier("open-personal-setup")
    }
}
