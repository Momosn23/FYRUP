import SwiftUI

/// One production flow. Entering a page never requests a system permission.
struct PersonalSetupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isOnboarding = false
    @State private var page: SetupJourneyStep = .body
    @State private var bodyDraft = BodyMeasurementsDraft()
    @State private var stepGoal = ""
    @State private var weeklyGoal: Int?
    @State private var fieldError: String?
    @State private var restoredOwnerID: UUID?
    @State private var healthLoadedOwnerID: UUID?
    @State private var editingSummary = false
    @State private var showsSummaryDetails = false
    @State private var isAdvancing = false
    @State private var showsNutritionGoal = false
    @State private var showsContacts = false
    @FocusState private var stepGoalFocused: Bool
    private var ready: Bool { store.setup.value != nil && store.setup.userID == store.session?.userID }
    private var choices: SetupChoices { store.setup.value?.setupChoices ?? .init() }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FYSetupHeading(title: page.title, subtitle: page.subtitle, step: page.position,
                                   total: SetupJourneyStep.allCases.count) {
                        if editingSummary { editingSummary = false; move(to: .summary, proxy: proxy) }
                        else if let previous = page.previous { move(to: previous, proxy: proxy) }
                        else if isOnboarding { store.route = .sportsSetup }
                        else { dismiss() }
                    }.id("setup-top")
                    pageContent.id(page).transition(.opacity)
                    if let message = fieldError ?? store.setup.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(FYColor.coral).accessibilityIdentifier("setup-error")
                    }
                    if !ready {
                        Button("Private Einstellungen erneut laden") { store.setup.activate(userID: store.session?.userID); restore() }.buttonStyle(OutlineButtonStyle())
                    }
                }.padding(FYLayout.page)
            }.scrollDismissesKeyboard(.interactively).clipped()
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 4) {
                        Button(page == .summary ? (isOnboarding ? "Zu FYRUP" : "Einrichtung abschließen") : "Weiter") {
                            Task { await advance(proxy: proxy, skipping: false) }
                        }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("personal-setup-next")
                        if page != .summary {
                            Button("Später einrichten") { Task { await advance(proxy: proxy, skipping: true) } }
                                .font(.footnote).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("personal-setup-skip")
                        }
                    }.disabled(!ready || isAdvancing || store.isBusy)
                        .padding(.horizontal, FYLayout.page).padding(.vertical, 12).background(FYColor.background)
                }
                .onChange(of: page) { _, _ in proxy.scrollTo("setup-top", anchor: .top) }
                .onChange(of: showsSummaryDetails) { _, isExpanded in
                    guard isExpanded else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                        proxy.scrollTo("setup-summary-more-anchor", anchor: .top)
                    }
                }
        }.background(FYColor.background).toolbar(.hidden, for: .navigationBar)
            .task(id: store.session?.userID) { restore() }
            .onChange(of: store.setup.value == nil) { _, missing in if !missing { restore() } }
            .task(id: "\(store.session?.userID.uuidString ?? "none"):\(page.rawValue)") { await loadPage() }
            .sheet(isPresented: $showsNutritionGoal) { NutritionGoalView() }
            .sheet(isPresented: $showsContacts) { ContactInviteFlowView() }
            .toolbar { if page == .health { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { stepGoalFocused = false } } } }
    }

    @ViewBuilder private var pageContent: some View {
        switch page {
        case .body: BodyMeasurementsView(draft: $bodyDraft)
        case .primaryGoal:
            VStack(spacing: 10) {
                ForEach(SetupPrimaryGoal.allCases, id: \.self) { goal in
                    FYSelectionCard(title: goal.title, subtitle: goal.detail, symbol: goal.symbol, selected: choices.primaryGoal == goal) {
                        updateChoices { $0.primaryGoal = $0.primaryGoal == goal ? nil : goal }
                    }.accessibilityIdentifier("setup-primary-\(goal.rawValue)")
                }
            }
        case .additionalGoals:
            VStack(spacing: 10) {
                ForEach(SetupAdditionalGoal.allCases, id: \.self) { goal in
                    FYSelectionCard(title: goal.title, subtitle: goal.detail, symbol: goal.symbol, selected: choices.additionalGoals.contains(goal)) {
                        updateChoices { $0.additionalGoals.formSymmetricDifference([goal]) }
                    }.accessibilityIdentifier("setup-additional-\(goal.rawValue)")
                }
            }
            hint("Eine Auswahl aktiviert keine Freigabe und keine Erinnerung.")
        case .weeklyGoal: weeklyPage
        case .days:
            SetupDayChoices(selection: choices.preferredDays) { day in updateChoices { $0.preferredDays.formSymmetricDifference([day]) } }
            Button("Unterschiedlich") { updateChoices { $0.preferredDays = [] } }.buttonStyle(OutlineButtonStyle())
            hint("Dein Wochenziel ist unabhängig von diesen Tagen. Es entstehen noch keine Termine.")
        case .time:
            VStack(spacing: 10) {
                ForEach(SetupTimePreference.allCases, id: \.self) { time in
                    FYSelectionCard(title: time.title, subtitle: time.detail, symbol: time.symbol, selected: choices.preferredTime == time) {
                        updateChoices { $0.preferredTime = time }
                    }.accessibilityIdentifier("setup-time-\(time.rawValue)")
                }
            }
            hint("Eine Vorliebe ist keine Erlaubnis für Mitteilungen.")
        case .supplements: supplementsPage
        case .nutrition: nutritionPage
        case .health: healthPage
        case .permissions: permissionsPage
        case .privacy: privacyPage
        case .friends: friendsPage
        case .firstActivity:
            Image("SportGymHero").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 170).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).accessibilityHidden(true)
            ForEach(SetupFirstAction.allCases, id: \.self) { action in
                FYSelectionCard(title: action.title, subtitle: action.detail, symbol: action.symbol,
                                selected: store.setup.value?.setupJourney?.firstAction == action) {
                    _ = store.setup.update { $0.setupJourney?.firstAction = action }
                }.accessibilityIdentifier("setup-first-\(action.rawValue)")
            }
            hint("Die Auswahl startet noch keine Aktivität. Auch beim Abbrechen bleibt deine Einrichtung erhalten.")
        case .summary: summaryPage
        }
    }
    private var weeklyPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            SetupWeeklyChoices(selection: $weeklyGoal).disabled(store.weekly.isSavingGoal)
            hint("Wähle ein realistisches Ziel. Änderungen gelten ab nächster Woche.")
            if store.weekly.state?.goalConfirmed == true, let current = store.weekly.currentWeek {
                Label("Diese Woche: \(current.weeklyGoal) Einheiten", systemImage: "calendar").font(.subheadline)
            }
            if let message = store.weekly.errorMessage { hint(message) }
            if !store.weekly.isStateConfirmed { Button("Wochenziel erneut laden") { Task { await loadPage() } }.buttonStyle(OutlineButtonStyle()) }
        }
    }
    private var supplementsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("SupplementsHero").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 150).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).accessibilityHidden(true)
            let plans = store.supplements.snapshot?.plans.filter { !$0.isArchived } ?? []
            if plans.isEmpty { hint("Wenn du keine Supplements nutzt, gehe einfach weiter. Es wird kein Einnahmeplan angelegt.") }
            SetupSupplementGrid()
            ForEach(plans) { plan in
                HStack { Label(plan.name, systemImage: "pills"); Spacer(); Text(plan.isPaused ? "Pausiert" : "Eingerichtet").font(.caption).foregroundStyle(FYColor.muted) }.fyCard()
            }
            NavigationLink { SupplementsView() } label: { setupLink("Eigene Liste bearbeiten", detail: "Einträge und Erinnerungen selbst festlegen", symbol: "plus.circle") }.buttonStyle(.plain)
            hint("Keine Einnahmeempfehlung. Es werden keine Mengen für dich vorausgefüllt.")
        }
    }
    private var nutritionPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("NutritionMealHero").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 180).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).accessibilityHidden(true)
            Label("Mahlzeiten erfassen", systemImage: "checkmark.circle").font(.body)
            Label("Eigene Kalorien- und Makroziele", systemImage: "checkmark.circle").font(.body)
            if let goal = store.nutrition.diary?.goal { Text("Dein Tagesziel: \(goal.kcal.formatted()) kcal").font(.headline) }
            Button(store.nutrition.diary?.goal == nil ? "Jetzt einrichten" : "Ziele bearbeiten") { showsNutritionGoal = true }
                .buttonStyle(OutlineButtonStyle()).disabled(store.nutrition.diary == nil).accessibilityIdentifier("setup-nutrition-goal")
            hint("Das Ernährungstagebuch bleibt derzeit auf diesem iPhone. Die Kalorien deiner Mahlzeiten sind von aktiver Energie getrennt.")
        }
    }
    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Schritte aus Apple Health", systemImage: "heart.fill").font(.headline).foregroundStyle(FYColor.lime)
            hint("FYRUP fragt hier nur nach dem Lesen deiner Schritte. Es werden keine Daten in Apple Health geschrieben.")
            Button(store.steps.healthRequested ? "Apple Health prüfen" : "Mit Apple Health verbinden") { Task { await store.steps.connect() } }
                .buttonStyle(OutlineButtonStyle()).disabled(store.steps.isBusy || !store.steps.isAvailable || store.steps.userID != store.session?.userID)
                .accessibilityIdentifier("setup-connect-health")
            Text(store.steps.healthStatusText).font(.footnote).foregroundStyle(FYColor.muted).accessibilityIdentifier("setup-health-status")
            FYInputField(title: "Schrittziel pro Tag · optional", placeholder: "Dein eigenes Ziel", text: $stepGoal, unit: "Schritte", identifier: "setup-step-goal")
                .keyboardType(.numberPad).focused($stepGoalFocused).disabled(healthLoadedOwnerID != store.session?.userID)
            hint("Schritte zählen nicht als Streak-Einheiten. Die Freigabe für Freunde wählst du separat unter Privatsphäre.")
            if let message = store.steps.message { hint(message) }
        }
    }
    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink { WeatherPlaceView() } label: { setupLink("Ort für Wetter", detail: "Stadt manuell wählen – auch ohne GPS", symbol: "mappin") }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 8) {
                Label("Einladungen & Erinnerungen", systemImage: "bell").font(.headline)
                hint("Für Session-Einladungen und selbst gewählte Erinnerungen. Ohne Push-Erlaubnis bleiben Einladungen in FYRUP erreichbar.")
                SystemNotificationSettingsRow()
            }.fyCard()
            NavigationLink { LiveAndRestSettingsView() } label: { setupLink("LIVE auf dem Sperrbildschirm", detail: "Optionale Anzeige und eigene Satzpausen", symbol: "iphone") }.buttonStyle(.plain)
            hint("Kamera und Kontakte fragt FYRUP erst bei der jeweiligen Aktion an. Für einen Avatar wählst du einzelne Fotos, nicht deine gesamte Mediathek.")
        }
    }
    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wer sieht deine Aktivitäten?").font(.headline)
            ForEach([ActivityVisibility.nobody, .friends], id: \.self) { visibility in
                FYSelectionCard(title: visibility.title, subtitle: "", symbol: visibility.rawValue == "nobody" ? "lock" : "person.2",
                                selected: store.activityPrivacy.isConfirmed && store.activityPrivacy.value == visibility) {
                    Task { await store.saveActivityPrivacy(visibility) }
                }.disabled(!store.activityPrivacy.isConfirmed || store.activityPrivacy.isBusy).accessibilityIdentifier("activity-visibility-\(visibility.rawValue)")
            }
            if !store.activityPrivacy.isConfirmed { Button("Sichtbarkeit laden") { Task { await store.refreshActivityPrivacy() } }.buttonStyle(OutlineButtonStyle()) }
            if let message = store.activityPrivacy.errorMessage { hint(message) }
            if store.steps.isSharingPreferenceCurrent {
                Toggle("Schritte mit Freunden teilen", isOn: Binding(get: { store.steps.sharingEnabled == true }, set: { enabled in Task { await store.steps.setSharing(enabled) } }))
                    .disabled(store.steps.isChangingSharing).accessibilityIdentifier("setup-share-steps").fyCard()
            } else { Button("Schritte-Freigabe laden") { Task { await store.steps.refresh(force: true) } }.buttonStyle(OutlineButtonStyle()) }
            hint("Bei aktivierter Schritte-Freigabe werden Tageswerte an Supabase übertragen. Nur bestätigte Freunde erhalten Zugriff, keine Health-Rohdaten.")
            Label("Ernährungskalorien: privat", systemImage: "lock").font(.subheadline)
            Label("Wetterort: nicht mit Freunden geteilt", systemImage: "lock").font(.subheadline)
            hint("Körperdaten, Supplement-Protokolle und Satzgewichte bleiben privat. Weitere Datenfreigaben werden nicht automatisch aktiviert.")
        }
    }
    private var friendsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("OnboardingCrewCollage").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 180).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).accessibilityHidden(true)
            NavigationLink { SetupFriendSearchView() } label: { setupLink("Benutzernamen suchen", detail: "Finde deine Freunde in FYRUP", symbol: "magnifyingglass") }.buttonStyle(.plain).accessibilityIdentifier("setup-find-username")
            Button { showsContacts = true } label: { setupLink("Aus Kontakten einladen", detail: "Du wählst einen Kontakt selbst aus", symbol: "person.crop.circle.badge.plus") }.buttonStyle(.plain)
            if let username = store.profile?.username, let link = FyrupProfileLink(username: username) {
                ShareLink(item: link.url, message: Text("Öffne mein Profil in FYRUP. Die App muss bereits installiert sein.")) {
                    setupLink("Profil-Link teilen", detail: "App und Empfänger selbst auswählen", symbol: "square.and.arrow.up")
                }.buttonStyle(.plain)
            }
            hint("Kein automatischer Adressbuchupload. Anfragen und Einladungen sendest du bewusst selbst.")
        }
    }
    private var summaryPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                summaryRow(.weeklyGoal, detail: weeklySummary, symbol: "flame")
                Divider()
                summaryRow(.primaryGoal, detail: choices.primaryGoal?.title ?? "Noch nicht gewählt", symbol: "target")
                Divider()
                summaryRow(.health, detail: store.steps.userID == store.session?.userID ? store.steps.healthStatusText : "Noch nicht geladen", symbol: "heart")
                Divider()
                summaryRow(.supplements, detail: store.supplements.snapshot.map { "\($0.plans.filter { !$0.isArchived && !$0.isPaused }.count) aktive Einträge" } ?? "Noch nicht geladen", symbol: "pills")
                Divider()
                summaryRow(.nutrition, detail: store.nutrition.diary?.goal.map { "\($0.kcal.formatted()) kcal pro Tag" } ?? "Nicht eingerichtet", symbol: "fork.knife")
                Divider()
                summaryRow(.privacy, detail: store.activityPrivacy.isConfirmed ? store.activityPrivacy.value?.title ?? "Noch nicht bestätigt" : "Noch nicht bestätigt", symbol: "lock")
            }.fyCard(padding: 12)
            VStack(spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsSummaryDetails.toggle() }
                } label: {
                    HStack {
                        Label("Weitere Einstellungen", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: showsSummaryDetails ? "chevron.up" : "chevron.down").font(.caption)
                    }.foregroundStyle(FYColor.ink).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("setup-summary-more")
                    .accessibilityValue(showsSummaryDetails ? "Ausgeklappt" : "Eingeklappt")
                if showsSummaryDetails { summaryDetails }
            }.fyCard(padding: 12).id("setup-summary-more-anchor")
            Image("OnboardingCrewCollage").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 170).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).accessibilityHidden(true)
        }
    }
    private var summaryDetails: some View {
        VStack(spacing: 0) {
            summaryRow(.additionalGoals, detail: choices.additionalGoals.isEmpty ? "Keine ausgewählt" : choices.additionalGoals.map(\.title).sorted().joined(separator: ", "), symbol: "sparkles")
            Divider()
            summaryRow(.days, detail: choices.preferredDays.isEmpty ? "Unterschiedlich" : choices.preferredDays.sorted { $0.rawValue < $1.rawValue }.map(\.shortTitle).joined(separator: ", "), symbol: "calendar")
            Divider()
            summaryRow(.time, detail: choices.preferredTime?.title ?? "Noch nicht gewählt", symbol: "clock")
            Divider()
            summaryRow(.body, detail: store.setup.value?.heightCM != nil || store.setup.value?.weightKG != nil ? "Private Angaben hinterlegt" : "Keine Angaben", symbol: "figure.stand")
            Divider()
            summaryRow(.permissions, detail: store.setup.value?.weatherPlace?.name ?? "Noch kein Wetterort", symbol: "mappin")
            Divider()
            summaryRow(.friends, detail: "Suchen oder einladen", symbol: "person.2")
            Divider()
            summaryRow(.firstActivity, detail: store.setup.value?.setupJourney?.firstAction?.title ?? "Später", symbol: "play")
            Divider()
            NavigationLink { SportsSetupView(isEditing: true) } label: {
                let sports = store.profile?.sports.map(\.title).joined(separator: ", ") ?? ""
                summaryLabel("Sportarten", detail: sports.isEmpty ? "Noch nicht gewählt" : sports, symbol: "figure.run")
            }.buttonStyle(.plain)
        }
    }
    private var weeklySummary: String {
        guard store.weekly.isStateConfirmed else { return "Noch nicht geladen" }
        guard store.weekly.state?.goalConfirmed == true, let current = store.weekly.currentWeek else { return "Noch nicht festgelegt" }
        let currentText = "Diese Woche: \(current.weeklyGoal) Einheiten"
        guard let next = store.weekly.state?.nextWeeklyGoal else { return currentText }
        return "\(currentText) · Ab nächster Woche: \(next)"
    }
    private func summaryRow(_ target: SetupJourneyStep, detail: String, symbol: String) -> some View {
        Button {
            guard store.setup.moveJourney(to: target) else { return }
            editingSummary = true; page = target
            if target == .body { bodyDraft = .init(store.setup.value) }
        } label: { summaryLabel(target.title, detail: detail, symbol: symbol) }.buttonStyle(.plain).accessibilityIdentifier("setup-summary-\(target.rawValue)")
    }
    private func summaryLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.body).frame(width: 24).foregroundStyle(FYColor.lime)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(FYColor.muted)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted)
        }.foregroundStyle(FYColor.ink).frame(minHeight: 44).padding(.vertical, 6).contentShape(Rectangle())
    }
    private func setupLink(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).frame(width: 26).foregroundStyle(FYColor.lime)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.footnote).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption)
        }.foregroundStyle(FYColor.ink).fyCard()
    }
    private func hint(_ text: String) -> some View { Text(text).font(.footnote).foregroundStyle(FYColor.muted).fixedSize(horizontal: false, vertical: true) }
    private func updateChoices(_ change: (inout SetupChoices) -> Void) {
        _ = store.setup.update { value in var choices = value.setupChoices ?? .init(); change(&choices); value.setupChoices = choices }
    }
    private func restore() {
        guard let owner = store.session?.userID, ready, restoredOwnerID != owner else { return }
        let start = isOnboarding ? store.setup.journeyStep : .body
        guard store.setup.beginJourney(at: start) else { return }
        page = start; bodyDraft = .init(store.setup.value); restoredOwnerID = owner
        weeklyGoal = nil; stepGoal = ""; fieldError = nil; editingSummary = false
        healthLoadedOwnerID = nil
        showsNutritionGoal = false; showsContacts = false
    }
    private func loadPage() async {
        guard let owner = store.session?.userID else { return }
        switch page {
        case .weeklyGoal:
            await store.weekly.activate(userID: owner)
            guard store.session?.userID == owner, !Task.isCancelled else { return }
            if let state = store.weekly.state, state.goalConfirmed { weeklyGoal = state.nextWeeklyGoal ?? state.currentWeek?.weeklyGoal }
        case .health, .privacy:
            healthLoadedOwnerID = nil
            await store.steps.activate(userID: owner)
            guard store.session?.userID == owner, !Task.isCancelled else { return }
            stepGoal = store.steps.goal.map(String.init) ?? ""
            healthLoadedOwnerID = owner
            if page == .privacy { await store.refreshActivityPrivacy() }
        case .supplements: await store.supplements.refresh()
        case .summary: await store.refreshActivityPrivacy()
        default: break
        }
    }
    private func move(to target: SetupJourneyStep, proxy: ScrollViewProxy) {
        guard store.setup.moveJourney(to: target) else { return }
        fieldError = nil; stepGoalFocused = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { page = target; proxy.scrollTo("setup-top", anchor: .top) }
    }
    private func advance(proxy: ScrollViewProxy, skipping: Bool) async {
        guard !isAdvancing, ready, let owner = store.session?.userID else { return }
        isAdvancing = true; defer { isAdvancing = false }; fieldError = nil
        if !skipping {
            if page == .body {
                fieldError = bodyDraft.validationMessage
                guard fieldError == nil, store.setup.update({ bodyDraft.apply(to: &$0) }) else { return }
            }
            if page == .weeklyGoal, let goal = weeklyGoal {
                guard store.weekly.isStateConfirmed else { fieldError = "Lade dein Wochenziel erneut oder richte es später ein."; return }
                if store.weekly.state?.goalConfirmed == true {
                    if goal != (store.weekly.state?.nextWeeklyGoal ?? store.weekly.currentWeek?.weeklyGoal) { guard await store.weekly.scheduleGoal(goal) else { return } }
                } else { guard await store.weekly.confirmGoal(goal) else { return } }
            }
            if page == .health {
                guard healthLoadedOwnerID == owner, store.steps.userID == owner else {
                    fieldError = "Dein gespeichertes Schrittziel wird noch geladen. Du kannst diesen Schritt auch später einrichten."; return
                }
                let input = stepGoal.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "")
                guard input.isEmpty || Int(input).map({ (1000...100000).contains($0) }) == true else { fieldError = "Wähle 1.000–100.000 Schritte oder lass das Ziel leer."; return }
                store.steps.setGoal(Int(input))
            }
        }
        guard store.session?.userID == owner else { return }
        if page == .health && store.steps.userID == owner && !store.steps.healthDecisionMade { store.steps.continueWithoutHealth() }
        if page == .summary {
            let firstAction = store.setup.value?.setupJourney?.firstAction
            if isOnboarding {
                guard await store.finishOnboarding(), store.session?.userID == owner else { return }
                if firstAction == .now || firstAction == .plan { store.activityComposerMode = firstAction == .plan ? 1 : 0; store.showsActivityComposer = true }
            } else if store.setup.finishSetup() { dismiss() }
        } else if editingSummary { editingSummary = false; move(to: .summary, proxy: proxy) }
        else if let next = page.next { move(to: next, proxy: proxy) }
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
                    Text("Ziele · Schritte · Ernährung · Freigaben").font(.caption).foregroundStyle(FYColor.muted)
                }
                Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.caption.bold())
            }.foregroundStyle(FYColor.ink).fyCard()
        }.buttonStyle(FYPressStyle()).accessibilityIdentifier("open-personal-setup")
    }
}
