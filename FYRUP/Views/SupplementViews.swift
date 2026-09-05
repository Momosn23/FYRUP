import SwiftUI

struct SupplementHomeCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { SupplementsView() } label: {
                HStack {
                    Label("Deine Supplements", systemImage: "pills").font(.headline)
                    Spacer(); Image(systemName: "chevron.right").font(.caption.bold())
                }.foregroundStyle(FYColor.ink)
            }.accessibilityIdentifier("open-supplements")
            if let snapshot = store.supplements.snapshot, !snapshot.plans.isEmpty {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    if store.supplements.isCurrentDay {
                        if snapshot.doses.isEmpty { Text("Heute ist nichts vorgesehen.").font(.subheadline).foregroundStyle(FYColor.muted) }
                        ForEach(Array(snapshot.doses.prefix(3))) { dose in SupplementDoseRow(dose: dose, snapshot: snapshot) }
                        if snapshot.doses.count > 3 {
                            NavigationLink("Alle heutigen Einträge") { SupplementsView() }.font(.subheadline.bold())
                        }
                    } else { Text("Neuer Tag – bitte deine Liste aktualisieren.").font(.caption).foregroundStyle(FYColor.muted) }
                }
            } else {
                Text("Deine persönliche Liste – nur wenn du möchtest.").font(.subheadline).foregroundStyle(FYColor.muted)
            }
            if !store.supplements.pending.isEmpty {
                Text(store.supplements.pending.count == 1 ? "Eine Änderung wartet auf Abgleich." : "\(store.supplements.pending.count) Änderungen warten auf Abgleich.").font(.caption).foregroundStyle(FYColor.muted)
            }
            if store.supplements.errorMessage != nil { Text("Liste gerade nicht aktuell. Zum erneuten Laden öffnen.").font(.caption).foregroundStyle(FYColor.muted) }
        }.fyCard()
    }
}

struct SupplementsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing: SupplementPlan?
    @State private var showsQuietHours = false
    var highlightedDoseID: UUID? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Nur für dich", systemImage: "lock.fill").font(.caption.bold()).foregroundStyle(FYColor.lime)
                    Text("Deine Auswahl. Deine Zeiten.").font(.title2.bold())
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Freiwillige Erinnerungen für deine eigene Auswahl.")
                            .accessibilityIdentifier("supplement-purpose")
                        Text("Keine Produktempfehlung.")
                            .accessibilityIdentifier("supplement-no-recommendation")
                        Text("Ohne Einfluss auf deine Streak.")
                            .accessibilityIdentifier("supplement-no-streak-impact")
                    }.font(.subheadline).foregroundStyle(FYColor.muted)
                        .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SupplementStatusMessages()
                    if store.supplements.isLoading && store.supplements.snapshot == nil { ProgressView("Liste wird geladen …") }
                    if let snapshot = store.supplements.snapshot {
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Heute").font(.headline)
                                Text("Zeiten in \(snapshot.settings.timezone)").font(.caption).foregroundStyle(FYColor.muted)
                                if !store.supplements.isCurrentDay {
                                    Text("Diese Ansicht stammt noch vom Vortag. Lade den aktuellen Tag, bevor du etwas bestätigst.").font(.subheadline)
                                    Button("Heute laden") { Task { await store.supplements.refresh() } }.buttonStyle(OutlineButtonStyle())
                                } else if snapshot.doses.isEmpty {
                                    Text("Heute ist nichts vorgesehen.").foregroundStyle(FYColor.muted)
                                } else {
                                    ForEach(snapshot.doses) { dose in
                                        SupplementDoseRow(dose: dose, snapshot: snapshot, expanded: true)
                                            .padding(12).background(dose.id == highlightedDoseID ? FYColor.limeSoft : FYColor.background, in: RoundedRectangle(cornerRadius: 14))
                                            .id(dose.id)
                                    }
                                }
                            }.fyCard()
                        }
                        HStack {
                            Text("Deine Einträge").font(.headline)
                            Spacer()
                            Text("\(snapshot.plans.count) / \(SupplementLimits.planCount)").font(.caption).foregroundStyle(FYColor.muted)
                        }
                        ForEach(snapshot.plans) { plan in
                            Button { editing = plan } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: plan.isPaused ? "pause.circle" : "pills.fill").foregroundStyle(FYColor.lime)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.name).font(.headline)
                                        Text(plan.isPaused ? "Pausiert" : plan.slots.map(\.clockLabel).joined(separator: " · ")).font(.caption).foregroundStyle(FYColor.muted)
                                        Text(plan.remindersEnabled ? "Erinnerungen eingeschaltet" : "Ohne Erinnerungen").font(.caption2).foregroundStyle(FYColor.muted)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").font(.caption.bold())
                                }.foregroundStyle(FYColor.ink).fyCard()
                            }.buttonStyle(.plain).accessibilityIdentifier("supplement-plan-\(plan.id)")
                        }
                        Button {
                            if let owner = store.session?.userID { editing = SupplementPlan(ownerID: owner, name: "") }
                        } label: { Label("Eigenen Eintrag hinzufügen", systemImage: "plus") }
                            .buttonStyle(PrimaryButtonStyle()).disabled(snapshot.plans.count >= SupplementLimits.planCount)
                            .accessibilityIdentifier("add-supplement")
                        Button("Ruhezeiten") { showsQuietHours = true }.buttonStyle(OutlineButtonStyle())
                        Text("Erinnerungen enden nach der gewählten Anzahl. Ausgelassene Einträge werden nicht auf den nächsten Tag übertragen. Eine Erinnerung ist keine Aufforderung, zusätzlich etwas einzunehmen.")
                            .font(.footnote).foregroundStyle(FYColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if !store.supplements.isLoading {
                        Button("Liste laden") { Task { await store.supplements.refresh() } }.buttonStyle(PrimaryButtonStyle())
                    }
                }.padding(20).padding(.bottom, 76)
            }.background(FYColor.background).navigationTitle("Supplements").navigationBarTitleDisplayMode(.inline)
                .refreshable { await store.supplements.refresh() }
                .task {
                    await store.supplements.refresh()
                    if let highlightedDoseID { proxy.scrollTo(highlightedDoseID, anchor: .center) }
                }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.supplements.refresh() } } }
                .sheet(item: $editing) { plan in SupplementEditorView(plan: plan) }
                .sheet(isPresented: $showsQuietHours) {
                    if let settings = store.supplements.snapshot?.settings { SupplementQuietHoursView(settings: settings) }
                }
        }
    }
}

private struct SupplementDoseRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dose: SupplementDose
    let snapshot: SupplementSnapshot
    var expanded = false
    private var pending: Bool { store.supplements.pending.contains { $0.doseID == dose.id } }
    private var plan: SupplementPlan? { snapshot.plans.first { $0.id == dose.planID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: dose.status == .taken ? "checkmark.circle.fill" : dose.status == .skipped ? "minus.circle" : "circle")
                    .font(.title3).foregroundStyle(dose.status == .taken ? FYColor.lime : FYColor.muted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan?.name ?? "Eigener Eintrag").font(.subheadline.bold())
                    Text("\(plan?.slots.first(where: { $0.id == dose.slotID })?.clockLabel ?? "–") · \(dose.status.title)")
                        .font(.caption).foregroundStyle(FYColor.muted)
                }
                Spacer(minLength: 0)
                if dose.status == .open {
                    Button("Genommen") { Task { await store.supplements.mark(dose.id, as: .taken) } }
                        .font(.caption.bold()).padding(10).background(FYColor.limeSoft, in: Capsule())
                        .accessibilityIdentifier("supplement-taken-\(dose.id)")
                        .disabled(store.supplements.changesDisabled || pending)
                }
            }
            if pending { Label("Vorgemerkt – noch nicht bestätigt", systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(FYColor.muted) }
            if expanded {
                HStack {
                    if let changedAt = dose.changedAt { Text("Bestätigt: \(changedAt.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(FYColor.muted) }
                    Spacer()
                    Button(dose.status == .open ? "Heute überspringen" : "Rückgängig") {
                        Task { await store.supplements.mark(dose.id, as: dose.status == .open ? .skipped : .open) }
                    }.font(.caption.bold()).frame(minHeight: 36)
                        .disabled(store.supplements.changesDisabled || pending)
                        .accessibilityIdentifier("supplement-secondary-\(dose.id)")
                }
            }
        }.animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: dose.status)
    }
}

private struct SupplementStatusMessages: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        if let error = store.supplements.errorMessage {
            WorkoutErrorBanner(message: error) { Task { await store.supplements.refresh() } }
        }
        if let error = store.supplements.pendingError {
            VStack(alignment: .leading, spacing: 10) {
                Text(error).font(.footnote)
                Button("Abgleich erneut versuchen") { Task { await store.supplements.refresh() } }.font(.subheadline.bold())
                ForEach(store.supplements.pending) { change in
                    Button("Vormerkung verwerfen") { store.supplements.discardPending(change.id); Task { await store.supplements.load() } }
                        .font(.caption).disabled(store.supplements.isSyncing)
                        .accessibilityIdentifier("discard-supplement-pending-\(change.id)")
                }
            }.fyCard()
        }
    }
}

private struct SupplementEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var plan: SupplementPlan
    @State private var confirmsArchive = false
    @FocusState private var nameFocused: Bool
    private let dayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Eigener Name", text: $plan.name).textInputAutocapitalization(.sentences)
                        .focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
                        .padding(14).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("supplement-name")
                    Text("Keine Dosierungsvorgabe – trage nur deine eigene Auswahl ein.").font(.caption).foregroundStyle(FYColor.muted)
                    Text("An welchen Tagen?").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(1...7, id: \.self) { day in
                                Button(dayNames[day - 1]) {
                                    if plan.weekdays.contains(day) { plan.weekdays.removeAll { $0 == day } } else { plan.weekdays.append(day) }
                                }.font(.caption.bold()).frame(width: 42, height: 44)
                                    .foregroundStyle(plan.weekdays.contains(day) ? FYColor.lime : FYColor.muted)
                                    .background(plan.weekdays.contains(day) ? FYColor.limeSoft : FYColor.surface, in: RoundedRectangle(cornerRadius: 11))
                                    .accessibilityAddTraits(plan.weekdays.contains(day) ? [.isSelected] : [])
                                    .accessibilityIdentifier("supplement-day-\(day)")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Deine Uhrzeiten").font(.headline)
                        ForEach($plan.slots) { $slot in
                            HStack {
                                SupplementTimePicker(title: "Uhrzeit", minute: $slot.minute)
                                if plan.slots.count > 1 {
                                    Button { plan.slots.removeAll { $0.id == slot.id } } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                                        .accessibilityLabel("Uhrzeit \(slot.clockLabel) entfernen")
                                }
                            }
                        }
                        if plan.slots.count < SupplementLimits.slotCount {
                            Button("Uhrzeit hinzufügen") {
                                let minute = stride(from: 540, to: 1440, by: 60).first { candidate in !plan.slots.contains { $0.minute == candidate } } ?? 0
                                plan.slots.append(SupplementSlot(minute: minute))
                            }.font(.subheadline.bold())
                        }
                    }.fyCard()
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Eintrag pausieren", isOn: $plan.isPaused)
                        Toggle("An offene Einträge erinnern", isOn: $plan.remindersEnabled).accessibilityIdentifier("supplement-reminders")
                        if plan.remindersEnabled {
                            Text("Eine erste Erinnerung zur Uhrzeit, danach nur solange der Eintrag offen ist. Auf dem Sperrbildschirm erscheinen keine Supplement-Namen.").font(.footnote).foregroundStyle(FYColor.muted)
                            Stepper("Zusätzliche Erinnerungen: \(plan.repeatCount)", value: $plan.repeatCount, in: 0...SupplementLimits.maxRepeats)
                            if plan.repeatCount > 0 {
                                Picker("Abstand", selection: $plan.repeatMinutes) {
                                    ForEach(SupplementLimits.intervals, id: \.self) { Text("\($0) Minuten").tag($0) }
                                }
                            }
                            SystemNotificationSettingsRow()
                            if store.notificationPreferences?.reminders == false { Text("Allgemeine Erinnerungen sind in FYRUP ausgeschaltet. Du kannst sie unter Profil → Benachrichtigungen aktivieren.").font(.footnote).foregroundStyle(FYColor.muted) }
                            Text("Die Liste bleibt auch ohne Push-Freigabe nutzbar. Zustellung kann verzögert werden oder ausbleiben.").font(.caption).foregroundStyle(FYColor.muted)
                        }
                    }.fyCard()
                    SupplementStatusMessages()
                    if let message = plan.validationMessage { Text(message).font(.caption).foregroundStyle(FYColor.muted) }
                    if plan.revision > 0 { Button("Eintrag entfernen", role: .destructive) { confirmsArchive = true }.frame(maxWidth: .infinity, minHeight: 44) }
                }.padding(20)
            }.background(FYColor.background).navigationTitle(plan.revision == 0 ? "Eigener Eintrag" : "Eintrag bearbeiten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() }.disabled(store.supplements.isSaving) } }
                .safeAreaInset(edge: .bottom) {
                    Button("Speichern") { Task { if await store.supplements.save(plan) { dismiss() } } }
                        .buttonStyle(PrimaryButtonStyle()).disabled(plan.validationMessage != nil || store.supplements.isSaving || store.supplements.isSyncing)
                        .accessibilityIdentifier("save-supplement").padding(16).background(.ultraThinMaterial)
                }
                .confirmationDialog("Eintrag entfernen?", isPresented: $confirmsArchive) {
                    Button("Entfernen", role: .destructive) { Task { var archived = plan; archived.isArchived = true; if await store.supplements.save(archived) { dismiss() } } }
                    Button("Behalten", role: .cancel) { }
                } message: { Text("Er verschwindet aus deiner Liste. Ausstehende Erinnerungen werden gestoppt; bereits zugestellte Hinweise können noch sichtbar sein.") }
                .interactiveDismissDisabled(store.supplements.isSaving)
        }.tint(FYColor.lime).preferredColorScheme(.light)
    }
}

private struct SupplementQuietHoursView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var settings: SupplementSettings
    var body: some View {
        NavigationStack {
            Form {
                Section("Ruhezeiten") {
                    Toggle("Ruhezeit aktivieren", isOn: $settings.quietEnabled)
                    if settings.quietEnabled {
                        SupplementTimePicker(title: "Von", minute: $settings.quietStart)
                        SupplementTimePicker(title: "Bis", minute: $settings.quietEnd)
                    }
                }
                Section {
                    Text("Deine feste Zeitzone: \(settings.timezone)")
                    Text("Auf Reisen bleiben diese Zeiten erhalten. Während der Ruhezeit wird nichts nachgeholt.").font(.footnote)
                    SupplementStatusMessages()
                    Button("Ruhezeiten speichern") { Task { if await store.supplements.saveSettings(settings) { dismiss() } } }
                        .disabled(!settings.isValid || store.supplements.isSaving)
                }
            }.navigationTitle("Ruhezeiten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() }.disabled(store.supplements.isSaving) } }
                .interactiveDismissDisabled(store.supplements.isSaving)
        }.tint(FYColor.lime)
    }
}

private struct SupplementTimePicker: View {
    let title: String
    @Binding var minute: Int
    private var calendar: Calendar { SupplementDay.calendar(timezone: "UTC")! }
    var body: some View {
        DatePicker(title, selection: Binding(get: {
            calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: minute / 60, minute: minute % 60))!
        }, set: { date in minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date) }), displayedComponents: .hourAndMinute)
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
    }
}
