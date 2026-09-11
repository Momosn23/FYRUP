import SwiftUI

struct ActivityComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let linkedActivityID: UUID?
    @State private var sport: SportKind?
    @State private var subtype: String?
    @State private var gymAreas = Set<GymBodyArea>()
    @State private var mode: Int
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var duration = 60
    @State private var note = ""
    @State private var placeDraft = GymPlaceDraft()
    @State private var arrivalPlace: SessionPlace?
    @State private var arrivalReminderEnabled = false
    @State private var showsPlacePicker = false
    @State private var arrivalPermissions = ArrivalPermissionStore()
    @State private var friendsCanJoin = true
    @State private var invitesEnabled = true
    @State private var invitees = Set<UUID>()
    @State private var sportSearch = ""
    @State private var friendSearch = ""
    @State private var showsGroupCreator = false
    @State private var workoutPlan: WorkoutPlan?
    @State private var showsWorkoutPlans = false
    @State private var creatingPlan: WorkoutPlan?

    init(linkedActivityID: UUID? = nil, initialMode: Int = 0, selectedWorkoutPlan: WorkoutPlan? = nil, initialSport: SportKind? = nil) {
        self.linkedActivityID = linkedActivityID
        _mode = State(initialValue: initialMode)
        _workoutPlan = State(initialValue: selectedWorkoutPlan)
        _sport = State(initialValue: selectedWorkoutPlan == nil ? initialSport : .gym)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(sport == nil ? "Womit legst du los?" : mode == 0 ? "Loslegen" : "Session planen").font(.largeTitle.weight(.black)).accessibilityIdentifier("activity-composer-title")
                        Text(sport == nil ? "Wähle deine Aktivität. Details kommen im nächsten Schritt." : mode == 0 ? "Wähle deinen Fokus und leg los." : "Alles auf einen Blick – dann Crew einladen.")
                            .font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                    if sport == nil { sportChooser }
                    else { details }
                }.padding(20)
            }
            .background(FYColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.body.bold()).frame(width: 44, height: 44) }
                        .accessibilityLabel("Schließen")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let sport {
                    Button(mode == 0 ? (sport == .gym ? "WORKOUT STARTEN" : "JETZT LOS") : "SESSION PLANEN") {
                        Task {
                            if mode == 0 { await store.start(sport: sport, subtype: storedSubtype, linked: linkedActivityID, workoutPlanID: workoutPlan?.id, placeName: placeDraft.value.trimmedNil) }
                            else {
                                let planned = await store.plan(sport: sport, subtype: storedSubtype, startsAt: startsAt, duration: duration, note: note.trimmedNil, placeName: placeDraft.value.trimmedNil, friendsCanJoin: friendsCanJoin, invitees: invitesEnabled ? Array(invitees) : [], workoutPlanID: workoutPlan?.id, arrivalPlace: arrivalReminderEnabled ? arrivalPlace : nil)
                                if planned { dismiss() }
                            }
                            if mode == 0, store.errorMessage == nil { dismiss() }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isBusy || placeDraft.value.trimmingCharacters(in: .whitespacesAndNewlines).count > 120)
                    .accessibilityIdentifier("confirm-activity")
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showsGroupCreator) { TrainingGroupEditorView() }
        .fullScreenCover(isPresented: $showsWorkoutPlans) {
            NavigationStack {
                WorkoutPlansView { selected in workoutPlan = selected; showsWorkoutPlans = false }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { showsWorkoutPlans = false } } }
            }
        }
        .fullScreenCover(item: $creatingPlan) { draft in WorkoutPlanEditorView(plan: draft) { workoutPlan = $0 } }
        .sheet(isPresented: $showsPlacePicker) {
            SessionPlacePickerView(initialQuery: placeDraft.value) { place in
                arrivalPlace = place; placeDraft.edit(place.name); arrivalReminderEnabled = false
            }
        }
        .onAppear { synchronizeFavoritePlace() }
        .task { await arrivalPermissions.refresh() }
        .onChange(of: sport) { _, _ in synchronizeFavoritePlace() }
        .onChange(of: store.setup.value?.favoriteGymName) { _, _ in synchronizeFavoritePlace() }
    }
    private var sportChooser: some View {
        VStack(spacing: 16) {
            Picker("Startart", selection: $mode) {
                Text("JETZT LOS").tag(0)
                Text("SESSION PLANEN").tag(1)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("activity-start-mode")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted)
                TextField("Aktivität suchen", text: $sportSearch)
            }
            .padding(.horizontal, 14).frame(minHeight: 48)
            .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: FYLayout.controlRadius, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(SportKind.allCases.filter { sportSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(sportSearch) }) { item in
                    Button { sport = item; subtype = nil; gymAreas = []; workoutPlan = nil } label: {
                        ZStack(alignment: .bottomLeading) {
                            SportPhoto(sport: item)
                            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Image(systemName: item.symbol).font(.headline)
                                    Text(item.title).font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right").font(.caption.bold())
                            }
                            .foregroundStyle(.white).padding(12)
                        }
                        .frame(maxWidth: .infinity, minHeight: 146)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(FYColor.line, lineWidth: 0.7))
                    }
                    .buttonStyle(FYPressStyle()).accessibilityLabel(item.title)
                }
            }
        }
    }
    @ViewBuilder private var details: some View {
        if let sport {
            Button { self.sport = nil; subtype = nil; gymAreas = []; workoutPlan = nil } label: {
                SportHeroCard(sport: sport, title: sport.title, subtitle: FyrupLanguage.subtype(storedSubtype, sport: sport, workoutPlanID: workoutPlan?.id) ?? "Fokus auswählen")
            }.buttonStyle(.plain)

            if sport == .gym {
                gymPlanChoices
                if workoutPlan == nil { gymFocus }
            }
            else if let choices = SportCatalog.subtypes[sport] {
                Text("WAS GENAU?").composerSectionTitle()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { Button("Frei") { subtype = nil }.chip(selected: subtype == nil); ForEach(choices, id: \.self) { item in Button(FyrupLanguage.subtype(item, sport: sport) ?? item) { subtype = item }.chip(selected: subtype == item) } }
                }
            }

            Picker("Startart", selection: $mode) { Text("JETZT LOS").tag(0); Text("SESSION PLANEN").tag(1) }
                .pickerStyle(.segmented)
            if mode == 1 {
                planningDetails
                invitationPicker
            } else {
                immediatePlaceDetails
            }
        }
    }

    private var immediatePlaceDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").frame(width: 22).foregroundStyle(FYColor.muted)
                TextField("Ort (optional)", text: Binding(get: { placeDraft.value }, set: { value in
                    placeDraft.edit(value)
                    if value != arrivalPlace?.name { arrivalPlace = nil }
                })).accessibilityIdentifier("activity-place")
                if !placeDraft.value.isEmpty {
                    Button {
                        placeDraft.edit(""); arrivalPlace = nil
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(FYColor.muted) }
                        .accessibilityLabel("Ort leeren").accessibilityIdentifier("clear-activity-place")
                }
            }
            if placeDraft.usesFavorite {
                Label("Aus deinem Stammgym vorausgefüllt", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(FYColor.lime)
            } else if sport == .gym, let favorite = store.setup.value?.favoriteGymName {
                Button("Stammgym übernehmen") { placeDraft.useFavorite(favorite); arrivalPlace = store.setup.value?.favoriteGymPlace }
                    .font(.caption.bold()).frame(minHeight: 44)
            }
            Button { showsPlacePicker = true } label: {
                Label("Ort auswählen", systemImage: "map.fill").font(.caption.bold()).frame(minHeight: 44)
            }.accessibilityIdentifier("choose-activity-place")
            Text("Optional für diese Aktivität. Die Kartenkoordinate wird dabei nicht hochgeladen.")
                .font(.caption2).foregroundStyle(FYColor.muted)
            if placeDraft.value.trimmingCharacters(in: .whitespacesAndNewlines).count > 120 {
                Text("Bitte kürze den Ort auf höchstens 120 Zeichen.").font(.caption).foregroundStyle(FYColor.coral)
            }
        }
        .padding(14)
        .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FYColor.line))
    }

    private var gymPlanChoices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WIE WILLST DU LOSLEGEN?").composerSectionTitle()
            VStack(spacing: 10) {
                Button { showsWorkoutPlans = true } label: { Label("Workout-Plan wählen", systemImage: "list.clipboard") }
                    .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("choose-workout-plan")
                Button { if let id = store.profile?.id { creatingPlan = WorkoutPlan(ownerID: id) } } label: { Label("Neuer Workout-Plan", systemImage: "plus") }
                    .buttonStyle(OutlineButtonStyle())
            }
            if let workoutPlan { WorkoutPlanCard(plan: workoutPlan) }
            Button { workoutPlan = nil } label: {
                HStack {
                    Label("Freies Workout", systemImage: "figure.strengthtraining.traditional")
                    Spacer(); Image(systemName: workoutPlan == nil ? "checkmark.circle.fill" : "circle")
                }.font(.subheadline.bold()).foregroundStyle(FYColor.lime).padding(14).background(FYColor.limeSoft, in: RoundedRectangle(cornerRadius: 13))
            }.buttonStyle(.plain)
            Button { mode = 1 } label: { Label("Session für später planen", systemImage: "calendar.badge.plus") }
                .buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("gym-plan-for-later")
        }
    }

    private var gymFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GYM – WAS GENAU?").composerSectionTitle()
            ForEach(GymProgram.allCases) { program in
                Button {
                    subtype = program.rawValue
                    gymAreas = Set(program.areas)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: program.symbol).font(.headline).frame(width: 26).foregroundStyle(FYColor.lime)
                        VStack(alignment: .leading, spacing: 3) { Text(program.rawValue).font(.subheadline.bold()); Text(program.subtitle).font(.caption).foregroundStyle(FYColor.muted) }
                        Spacer()
                        Image(systemName: subtype == program.rawValue ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(subtype == program.rawValue ? FYColor.lime : FYColor.muted)
                    }.padding(14).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(subtype == program.rawValue ? FYColor.lime.opacity(0.8) : FYColor.line))
                }.buttonStyle(.plain).foregroundStyle(FYColor.ink).accessibilityLabel(program.rawValue).accessibilityHint(program.subtitle)
            }

            Text("KÖRPERGRUPPEN AUSWÄHLEN").composerSectionTitle()
            MuscleBodyPicker(selection: Binding(get: { MuscleSelection.groups(for: gymAreas) }, set: { groups in
                gymAreas = MuscleSelection.areas(for: groups)
                // A changed focus must not keep claiming that the original Push/Pull preset is selected.
                subtype = GymProgram.allCases.first { Set($0.areas) == gymAreas }?.rawValue ?? (gymAreas.isEmpty ? nil : "Individuell")
            }), available: MuscleSelection.gymGroups, identifierPrefix: "gym-area")
        }
    }

    private var planningDetails: some View {
        VStack(spacing: 0) {
            SessionDateRow(selection: $startsAt)
            Divider().overlay(FYColor.line).padding(.leading, 44)
            DatePicker(selection: $startsAt, in: Date()..., displayedComponents: .hourAndMinute) {
                HStack(spacing: 12) { Image(systemName: "clock").frame(width: 22).foregroundStyle(FYColor.muted); Text("Uhrzeit") }
            }.datePickerStyle(.compact).padding(14).accessibilityIdentifier("session-time")
            Divider().overlay(FYColor.line).padding(.leading, 44)
            ComposerRow(symbol: "timer", title: "Dauer") { Stepper("\(duration) Minuten", value: $duration, in: 15...240, step: 15).fixedSize() }
            Divider().overlay(FYColor.line).padding(.leading, 44)
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").frame(width: 22).foregroundStyle(FYColor.muted)
                TextField("Ort (optional)", text: Binding(get: { placeDraft.value }, set: { value in
                    placeDraft.edit(value)
                    if value != arrivalPlace?.name { arrivalPlace = nil; arrivalReminderEnabled = false }
                })).multilineTextAlignment(.trailing).accessibilityIdentifier("session-place")
                if !placeDraft.value.isEmpty {
                    Button {
                        placeDraft.edit(""); arrivalPlace = nil; arrivalReminderEnabled = false
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(FYColor.muted) }
                        .accessibilityLabel("Ort leeren").accessibilityIdentifier("clear-session-place")
                }
            }.padding(14)
            VStack(alignment: .leading, spacing: 8) {
                if placeDraft.usesFavorite { Label("Aus deinem Stammgym vorausgefüllt", systemImage: "checkmark.circle").font(.caption).foregroundStyle(FYColor.lime) }
                if sport == .gym, let favorite = store.setup.value?.favoriteGymName, !placeDraft.usesFavorite {
                    Button("Stammgym übernehmen") { placeDraft.useFavorite(favorite); arrivalPlace = nil; arrivalReminderEnabled = false }.font(.caption.bold()).frame(minHeight: 44)
                }
                Button { showsPlacePicker = true } label: { Label("Ort auf der Karte auswählen", systemImage: "map.fill").font(.caption.bold()).frame(minHeight: 44) }
                    .accessibilityIdentifier("choose-session-place")
                Text("Der Treffpunkt ist für berechtigte Teilnehmer dieser Session sichtbar. Leer lassen, wenn du keinen Ort teilen möchtest.").font(.caption2).foregroundStyle(FYColor.muted)
                if placeDraft.value.trimmingCharacters(in: .whitespacesAndNewlines).count > 120 { Text("Bitte kürze den Ort auf höchstens 120 Zeichen.").font(.caption).foregroundStyle(FYColor.coral) }
                if let arrivalPlace {
                    Divider().overlay(FYColor.line)
                    Toggle(isOn: Binding(get: { arrivalReminderEnabled }, set: { value in
                        arrivalReminderEnabled = value && arrivalPermissions.isReady
                    })) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bei Ankunft erinnern").font(.subheadline.bold())
                            Text("Einmalig in etwa 180 m Umkreis · genaue Koordinate bleibt auf diesem iPhone").font(.caption2).foregroundStyle(FYColor.muted)
                        }
                    }.tint(FYColor.lime).accessibilityIdentifier("arrival-reminder-toggle")
                    if !arrivalPermissions.isReady {
                        Text("Dafür braucht FYRUP Mitteilungen und Standortzugriff während der Nutzung. Ohne Freigabe bleibt die übrige App vollständig nutzbar.")
                            .font(.caption2).foregroundStyle(FYColor.muted)
                        Button("FREIGABEN AKTIVIEREN") { Task { await arrivalPermissions.request() } }
                            .font(.caption.bold()).frame(minHeight: 44).accessibilityIdentifier("enable-arrival-permissions")
                    } else {
                        Label(arrivalReminderEnabled ? "Erinnerung wird mit der Session gespeichert" : "Freigaben erteilt", systemImage: arrivalReminderEnabled ? "bell.badge.fill" : "checkmark.shield.fill")
                            .font(.caption).foregroundStyle(FYColor.lime)
                    }
                    Text("Ausgewählt: \(arrivalPlace.name)").font(.caption2).foregroundStyle(FYColor.muted)
                }
            }.padding(.horizontal, 14).padding(.bottom, 14).frame(maxWidth: .infinity, alignment: .leading)
        }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(FYColor.line))
    }

    private var invitationPicker: some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(isOn: $invitesEnabled) {
                VStack(alignment: .leading, spacing: 3) { Text("Freunde einladen").font(.headline); Text(invitees.isEmpty ? "Wähle deine Crew" : "\(invitees.count) ausgewählt").font(.caption).foregroundStyle(FYColor.muted) }
            }.tint(FYColor.lime)

            if invitesEnabled {
                if !store.trainingGroups.isEmpty {
                    HStack { Text("DEINE GRUPPEN").composerSectionTitle(); Spacer(); Button("Neue Gruppe") { showsGroupCreator = true }.font(.caption.bold()).foregroundStyle(FYColor.lime) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) { ForEach(store.trainingGroups) { group in groupInviteButton(group) } }
                    }
                } else {
                    Button { showsGroupCreator = true } label: { Label("Crew erstellen", systemImage: "person.3.fill").font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 46) }
                        .buttonStyle(.plain).foregroundStyle(FYColor.lime).background(FYColor.lime.opacity(0.09), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(FYColor.lime.opacity(0.25)))
                }

                HStack { Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted); TextField("Freunde suchen …", text: $friendSearch) }
                    .padding(12).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))

                ForEach(filteredCrew) { member in
                    Button { invitees.formSymmetricDifference([member.id]) } label: {
                        HStack(spacing: 12) { AvatarView(profile: member.profile); VStack(alignment: .leading, spacing: 2) { Text(member.profile.displayName).bold(); Text("@\(member.profile.username)").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); Image(systemName: invitees.contains(member.id) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(invitees.contains(member.id) ? FYColor.lime : FYColor.muted) }
                    }.buttonStyle(.plain).foregroundStyle(FYColor.ink)
                }
            }

            Divider().overlay(FYColor.line)
            Toggle("Weitere Freunde dürfen beitreten", isOn: $friendsCanJoin).tint(FYColor.lime).accessibilityLabel("Freunde dürfen sich anschließen")
            TextField("Nachricht (optional)", text: $note, axis: .vertical).lineLimit(2...4).padding(13).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 13))
        }.padding(15).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(FYColor.line))
    }

    private func groupInviteButton(_ group: TrainingGroup) -> some View {
        let memberIDs = Set(group.members.filter { $0.id != store.profile?.id }.map(\.id))
        let selected = !memberIDs.isEmpty && memberIDs.isSubset(of: invitees)
        return Button {
            if selected { invitees.subtract(memberIDs) }
            else { invitees.formUnion(memberIDs) }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Image(systemName: "person.3.fill"); Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "circle") }
                Text(group.name).font(.subheadline.bold()).lineLimit(1)
                Text("\(memberIDs.count) Freunde").font(.caption2).foregroundStyle(selected ? .white.opacity(0.82) : FYColor.muted)
            }.padding(12).frame(width: 142, height: 94, alignment: .leading).foregroundStyle(selected ? .white : FYColor.ink).background(selected ? FYColor.lime : FYColor.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? FYColor.lime : FYColor.line))
        }.buttonStyle(.plain)
    }

    private var filteredCrew: [CrewMember] {
        guard !friendSearch.isEmpty else { return store.crew }
        return store.crew.filter { $0.profile.displayName.localizedCaseInsensitiveContains(friendSearch) || $0.profile.username.localizedCaseInsensitiveContains(friendSearch) }
    }

    private var storedSubtype: String? {
        guard sport == .gym else { return subtype }
        if let workoutPlan { return workoutPlan.name }
        let areas = GymBodyArea.allCases.filter(gymAreas.contains).map(\.title)
        if let subtype, !areas.isEmpty { return "\(subtype) (\(areas.joined(separator: ", ")))" }
        return subtype ?? (areas.isEmpty ? nil : areas.joined(separator: ", "))
    }

    private func synchronizeFavoritePlace() {
        placeDraft.synchronize(sport: sport, favorite: store.setup.value?.favoriteGymName)
        if placeDraft.usesFavorite { arrivalPlace = store.setup.value?.favoriteGymPlace }
        else if sport != .gym { arrivalPlace = nil; arrivalReminderEnabled = false }
    }
}

/// The compact system date pill truncates its year on some iOS versions. Show
/// the complete date as ordinary text and open the native calendar separately.
private struct SessionDateRow: View {
    @Binding var selection: Date
    @State private var showsCalendar = false
    private var dateLabel: String { selection.formatted(date: .abbreviated, time: .omitted) }

    var body: some View {
        Button { showsCalendar = true } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label("Datum", systemImage: "calendar")
                    Spacer(minLength: 12)
                    Text(dateLabel).fixedSize()
                    Image(systemName: "chevron.right").font(.caption.bold())
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Datum", systemImage: "calendar")
                    Text(dateLabel).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.foregroundStyle(FYColor.ink).padding(14).contentShape(Rectangle())
        }.buttonStyle(.plain)
            // Preserve the native Button role/action instead of wrapping it in
            // a replacement accessibility element with ignored children.
            .accessibilityLabel("Datum").accessibilityValue(dateLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("session-date")
            .sheet(isPresented: $showsCalendar) {
                NavigationStack {
                    ScrollView {
                        DatePicker("Datum", selection: $selection, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical).padding(16)
                            .accessibilityIdentifier("session-calendar")
                    }.background(FYColor.background)
                        .navigationTitle("Datum wählen").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Übernehmen") { showsCalendar = false }
                                    .accessibilityIdentifier("confirm-session-date")
                            }
                        }
                }.tint(FYColor.lime).preferredColorScheme(.light)
            }
    }
}

private struct ComposerRow<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    var body: some View { HStack(spacing: 12) { Image(systemName: symbol).frame(width: 22).foregroundStyle(FYColor.muted); Text(title); Spacer(); trailing() }.font(.subheadline).padding(14) }
}

struct SportHeroCard: View {
    let sport: SportKind
    let title: String
    let subtitle: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(sport.heroAssetName).resizable().scaledToFill().frame(maxWidth: .infinity, minHeight: 148, maxHeight: 148).clipped()
            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.title2.weight(.black)); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.78)).lineLimit(2) }
                Spacer()
                Image(systemName: sport.symbol).font(.title2).foregroundStyle(sport.accentColor)
            }.padding(16).foregroundStyle(.white)
        }.frame(height: 148).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18).stroke(FYColor.line))
    }
}

private extension SportKind {
    var heroAssetName: String {
        switch self {
        case .gym: "SportGymHero"
        case .running: "SportRunningHero"
        case .football: "SportFootballHero"
        case .basketball: "SportBasketballHero"
        case .cycling: "SportOutdoorHero"
        case .swimming: "SportSwimmingHero"
        case .martialArts: "SportCombatHero"
        case .racket: "SportRacketHero"
        case .yoga: "SportYogaHero"
        case .other: "SportOutdoorHero"
        }
    }
}

private extension Text {
    func composerSectionTitle() -> some View { self.font(.caption.weight(.black)).foregroundStyle(FYColor.muted).tracking(0.6) }
}

extension String {
    var trimmedNil: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value }
}

private extension Button {
    func chip(selected: Bool) -> some View { self.font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 10).foregroundStyle(selected ? .white : FYColor.ink).background(selected ? FYColor.lime : FYColor.surface, in: Capsule()).overlay(Capsule().stroke(selected ? FYColor.lime : FYColor.line)) }
}

struct LiveActivityView: View {
    @Environment(AppStore.self) private var store
    var opensCurrentSet = false
    @State private var workoutActivityID: UUID?
    @State private var blindWorkoutID: UUID?
    @State private var resolved = false
    var body: some View {
        Group {
            if let blindWorkoutID { BlindWorkoutDetailView(id: blindWorkoutID) }
            else if let workoutActivityID { WorkoutTrackingView(activityID: workoutActivityID, opensCurrentSet: opensCurrentSet) }
            else if resolved { FreeActivityView() }
            else { ProgressView() }
        }.task {
            guard !resolved else { return }
            if store.myActivity?.workoutPlanID != nil { workoutActivityID = store.myActivity?.id }
            blindWorkoutID = store.myActivity?.blindWorkoutID
            resolved = true
        }
    }
}

private struct FreeActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmCancel = false
    @State private var distanceKM = ""
    @State private var completedActivity: Activity?
    private var didComplete: Bool { completedActivity != nil }
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(spacing: 24) {
            HStack { Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Zurück").accessibilityIdentifier("close-free-activity"); Spacer() }.foregroundStyle(FYColor.ink)
            Spacer(minLength: 0)
            if let activity = completedActivity ?? store.myActivity {
                if didComplete {
                    Image(systemName: "trophy.fill").font(.system(size: 70)).foregroundStyle(FYColor.planned)
                    Text("Heute geschafft 🔥").font(.title.weight(.bold))
                    Text([activity.sport.title, activity.displaySubtype].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(FYColor.muted)
                    if let duration = activity.duration { HStack { ResultMetric(value: duration < 60 ? "\(max(0, Int(duration)))" : "\(Int(duration / 60))", label: duration < 60 ? "Sekunden" : "Minuten"); ResultMetric(value: "1", label: "Einheit"); ResultMetric(value: "✓", label: "Gespeichert") }.padding(.vertical, 8) }
                    Text("„Stärker als gestern.\nGenau so.“").multilineTextAlignment(.center).foregroundStyle(FYColor.muted).fyCard()
                } else {
                    LiveSessionVisual(activity: activity)
                    if activity.sport == .gym { WorkoutRestView(activityID: activity.id) }
                    if SessionIntervalConfiguration.supports(activity.sport) { SessionIntervalView(activity: activity) }
                    if activity.pausedAt != nil { Text("Pausiert").font(.subheadline.bold()).foregroundStyle(FYColor.muted) }
                    if let liveFriend = store.crew.first(where: { $0.todayStatus == .live }) {
                        Label("\(liveFriend.profile.displayName) ist ebenfalls LIVE.", systemImage: "person.2.fill").font(.subheadline).foregroundStyle(FYColor.live)
                    }
                    if let doneFriend = store.crew.first(where: { $0.todayStatus == .done }) {
                        Text("\(doneFriend.profile.displayName) war heute schon aktiv.").font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                    if activity.sport.supportsDistance { TextField("Distanz in km (optional)", text: $distanceKM).keyboardType(.decimalPad).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)) }
                }
            }
            Spacer(minLength: 8)
            if didComplete {
                if let activity = completedActivity { WorkoutFeedbackButton(activityID: activity.id) }
                Text("Deine Aktivität erscheint entsprechend deiner Privatsphäre-Einstellung im Feed.").font(.caption).foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
                Button("Im Feed ansehen") { store.selectedTab = 0; dismiss() }.buttonStyle(OutlineButtonStyle())
                Button("Fertig") { dismiss() }.buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("finish-free-activity")
            }
            else {
                HStack(spacing: 38) {
                    Button { Task { await store.setPaused(store.myActivity?.pausedAt == nil) } } label: {
                        Image(systemName: store.myActivity?.pausedAt != nil ? "play.fill" : "pause.fill").font(.title2).foregroundStyle(FYColor.ink).frame(width: 62, height: 62).background(FYColor.elevated, in: Circle())
                    }.disabled(store.isBusy).accessibilityLabel(store.myActivity?.pausedAt != nil ? "FORTSETZEN" : "PAUSIEREN")
                    Button { Task {
                        let normalized = distanceKM.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
                        let kilometers = Double(normalized)
                        if !normalized.isEmpty && (kilometers == nil || kilometers?.isFinite != true || !(0...10000).contains(kilometers ?? -1)) {
                            store.errorMessage = "Prüfe die optionale Distanz."; return
                        }
                        completedActivity = await store.finish(distanceMeters: kilometers.map { Int($0 * 1000) })
                        if completedActivity != nil { await store.weekly.prepareCelebration() }
                    } } label: { Image(systemName: "stop.fill").font(.title2).frame(width: 68, height: 68).background(FYColor.coral, in: Circle()).shadow(color: FYColor.coral.opacity(0.35), radius: 14) }.foregroundStyle(.white).disabled(store.isBusy).accessibilityLabel("ABSCHLIESSEN")
                }
                Text("Du machst das stark! 🔥").font(.subheadline).foregroundStyle(FYColor.muted)
                Button("Aktivität abbrechen") { confirmCancel = true }.font(.caption).foregroundStyle(FYColor.coral)
            }
        }.frame(minHeight: max(0, geometry.size.height - 48)).padding(24)
            // Leave scrollable clearance for the system's floating tab bar.
            .padding(.bottom, didComplete ? 76 : 24)
        }.background(FYColor.background).navigationBarBackButtonHidden()
            .overlay { TrainingConfetti(trigger: completedActivity?.id) }
            .confirmationDialog("Aktivität wirklich abbrechen?", isPresented: $confirmCancel) { Button("Aktivität abbrechen", role: .destructive) { Task { await store.cancelCurrent(); if store.errorMessage == nil { dismiss() } } }; Button("Weitermachen", role: .cancel) {} }
        }
    }
}

struct HostedSessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let hosted: HostedSession
    @State private var startsAt = Date()
    @State private var duration = 60
    @State private var note = ""
    @State private var placeName = ""
    @State private var arrivalPlace: SessionPlace?
    @State private var arrivalReminderEnabled = false
    @State private var showsPlacePicker = false
    @State private var arrivalPermissions = ArrivalPermissionStore()
    @State private var friendsCanJoin = true
    @State private var confirmCancel = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActivityLabel(activity: Activity(id: hosted.id, userID: hosted.session.hostID, sport: hosted.session.sport, subtype: hosted.session.subtype, status: .planned, plannedAt: startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: duration, note: note, plannedSessionID: hosted.id, workoutPlanID: hosted.session.workoutPlanID)).fyCard()
                DatePicker("Datum & Uhrzeit", selection: $startsAt, in: Date()...).fyCard()
                Stepper("ca. \(duration) Minuten", value: $duration, in: 15...240, step: 15).fyCard()
                HStack { Image(systemName: "mappin.and.ellipse").foregroundStyle(FYColor.muted); TextField("Ort / Treffpunkt (optional)", text: Binding(get: { placeName }, set: { value in
                    placeName = value
                    if value != arrivalPlace?.name { arrivalPlace = nil; arrivalReminderEnabled = false }
                })) }
                    .padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                Button { showsPlacePicker = true } label: { Label("Ort auf der Karte auswählen", systemImage: "map.fill") }
                    .buttonStyle(OutlineButtonStyle())
                if let arrivalPlace {
                    Toggle("Bei Ankunft erinnern", isOn: Binding(get: { arrivalReminderEnabled }, set: { arrivalReminderEnabled = $0 && arrivalPermissions.isReady }))
                        .tint(FYColor.lime).fyCard()
                    if !arrivalPermissions.isReady {
                        Text("Dafür braucht FYRUP Mitteilungen und Standortzugriff während der Nutzung. Die übrige App funktioniert auch ohne diese Freigaben.").font(.caption).foregroundStyle(FYColor.muted)
                        Button("FREIGABEN AKTIVIEREN") { Task { await arrivalPermissions.request() } }.font(.caption.bold()).frame(minHeight: 44)
                    } else if arrivalReminderEnabled {
                        Label("Einmalige Erinnerung bei der nächsten Ankunft", systemImage: "bell.badge.fill").font(.caption).foregroundStyle(FYColor.lime)
                    }
                    Text("Die genaue Koordinate bleibt auf diesem iPhone.").font(.caption2).foregroundStyle(FYColor.muted)
                } else if store.arrival.records[hosted.id] != nil {
                    Button("Ankunftserinnerung entfernen", role: .destructive) { store.arrival.remove(sessionID: hosted.id) }.frame(minHeight: 44)
                }
                TextField("Notiz (optional)", text: $note, axis: .vertical).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                Toggle("Freunde dürfen sich anschließen", isOn: $friendsCanJoin).fyCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("TEILNEHMER").font(.caption.weight(.black)).foregroundStyle(FYColor.muted)
                    HStack { AvatarView(profile: store.profile ?? fallbackProfile); Text(store.profile?.displayName ?? "Du").bold(); Spacer(); Text("HOST").statusChip(color: FYColor.lime) }
                    ForEach(hosted.participants) { participant in
                        HStack { AvatarView(profile: participant.profile); VStack(alignment: .leading) { Text(participant.profile.displayName).bold(); Text("@\(participant.profile.username)").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); Text(participant.status.sessionLabel).statusChip(color: participant.status.sessionColor) }
                    }
                    if hosted.participants.isEmpty { Text("Noch niemand eingeladen.").font(.subheadline).foregroundStyle(FYColor.muted) }
                }.fyCard()

                Button("ÄNDERUNGEN SPEICHERN") {
                    var session = hosted.session
                    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    session.startsAt = startsAt
                    session.durationMinutes = duration
                    session.note = trimmedNote.isEmpty ? nil : trimmedNote
                    session.placeName = trimmedPlace.isEmpty ? nil : trimmedPlace
                    session.friendsCanJoin = friendsCanJoin
                    Task {
                        await store.updateHostedSession(session, arrivalPlace: arrivalReminderEnabled ? arrivalPlace : nil)
                        if !arrivalReminderEnabled { store.arrival.remove(sessionID: hosted.id) }
                    }
                }.buttonStyle(SecondaryButtonStyle())
                if let planID = hosted.session.workoutPlanID {
                    NavigationLink { WorkoutPlanDetailView(planID: planID, sessionID: hosted.id) } label: { Text("Workout-Plan ansehen") }.buttonStyle(OutlineButtonStyle())
                }
                Button("LOSLEGEN") { Task { await store.start(sport: hosted.session.sport, subtype: hosted.session.subtype, plannedSessionID: hosted.id); if store.errorMessage == nil { dismiss() } } }.buttonStyle(PrimaryButtonStyle()).disabled(store.isBusy)
                Button("Session absagen", role: .destructive) { confirmCancel = true }.frame(maxWidth: .infinity).padding(.top, 4)
            }.padding(20).padding(.bottom, 44)
        }
        .background(FYColor.background)
        .navigationTitle("Session planen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startsAt = max(Date(), hosted.session.startsAt)
            duration = hosted.session.durationMinutes ?? 60
            note = hosted.session.note ?? ""
            placeName = hosted.session.placeName ?? ""
            friendsCanJoin = hosted.session.friendsCanJoin
            arrivalPlace = store.arrival.records[hosted.id]?.place
            arrivalReminderEnabled = arrivalPlace != nil
            await arrivalPermissions.refresh()
        }
        .sheet(isPresented: $showsPlacePicker) {
            SessionPlacePickerView(initialQuery: placeName) { place in
                placeName = place.name; arrivalPlace = place; arrivalReminderEnabled = false
            }
        }
        .confirmationDialog("Session wirklich absagen?", isPresented: $confirmCancel) {
            Button("Session absagen", role: .destructive) { Task { await store.cancelPlannedSession(hosted.id); if store.errorMessage == nil { dismiss() } } }
            Button("Behalten", role: .cancel) {}
        } message: { Text("Alle eingeladenen Freunde erhalten eine neutrale Absage.") }
    }

    private var fallbackProfile: Profile {
        Profile(id: hosted.session.hostID, username: "du", displayName: "Du", avatarPath: nil, birthYear: nil, city: nil, bio: nil, sports: [], weeklyGoal: 1, activityVisibility: "nobody")
    }
}

private extension InvitationStatus {
    var sessionLabel: String {
        switch self { case .pending: "WARTET"; case .accepted: "DABEI"; case .maybe: "VIELLEICHT"; case .declined: "KANN NICHT" }
    }
    var sessionColor: Color {
        switch self { case .pending: FYColor.muted; case .accepted: FYColor.live; case .maybe: FYColor.planned; case .declined: FYColor.muted }
    }
}

private extension Text {
    func statusChip(color: Color) -> some View {
        self.font(.caption2.bold()).foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 6).background(color.opacity(0.12), in: Capsule())
    }
}

struct ActivityDetailView: View {
    @Environment(AppStore.self) private var store
    let activity: Activity
    let owner: Profile
    @State private var showsJoin = false

    var body: some View {
        Group {
            if store.revokedFriendIDs.contains(owner.id) {
                ContentUnavailableView("Nicht mehr verfügbar", systemImage: "lock", description: Text("Ihr seid nicht mehr verbunden. Diese Aktivität wird nicht mehr angezeigt."))
            } else { detailContent }
        }
        .onChange(of: store.friendAccessRevision) { _, _ in
            if store.revokedFriendIDs.contains(owner.id) { showsJoin = false }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Image(activity.sport.heroAssetName).resizable().scaledToFill().frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190).clipped()
                    LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) { Text(activity.sport.title).font(.largeTitle.bold()); if let subtype = activity.displaySubtype { Text(subtype).font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(2) } }.padding(18).foregroundStyle(.white)
                }.frame(height: 190)
                VStack(spacing: 0) {
                    DetailRow(symbol: "figure.strengthtraining.traditional", title: "Kategorie", value: activity.sport.title, tint: activity.sport.accentColor)
                    if let subtype = activity.displaySubtype { DetailRow(symbol: "list.bullet", title: "Unterkategorie", value: subtype) }
                    if let date = activity.plannedAt ?? activity.startedAt { DetailRow(symbol: "calendar", title: "Datum", value: date.formatted(date: .abbreviated, time: .shortened)) }
                    if let minutes = activity.plannedDurationMinutes { DetailRow(symbol: "clock", title: "Dauer (geplant)", value: "ca. \(minutes) min") }
                    if let count = activity.exerciseCount { DetailRow(symbol: "list.bullet", title: "Workout-Plan", value: "\(count) Übungen") }
                    if activity.status == .completed && activity.workoutPlanID != nil && owner.id == store.profile?.id {
                        NavigationLink { WorkoutHistoryView(activityID: activity.id) } label: { Label("Mein privates Aktivitätsprotokoll", systemImage: "list.clipboard") }.buttonStyle(OutlineButtonStyle()).padding(.vertical, 12)
                    }
                    HStack(spacing: -7) { AvatarView(profile: owner).scaleEffect(0.72); Text(owner.displayName).font(.subheadline.bold()).padding(.leading, 12); Spacer(); StatusBadge(status: activity.status == .live ? .live : activity.status == .completed ? .done : .planned) }.padding(.vertical, 16)
                    detailAction.padding(.top, 10)
                }.padding(.horizontal, 18)
            }
        }
        .background(FYColor.background)
        .navigationTitle("Aktivitätsdetails")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsJoin) {
            if let planID = activity.workoutPlanID {
                NavigationStack {
                    WorkoutPlanDetailView(planID: planID, linkedActivityID: activity.id)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { showsJoin = false } } }
                }
            } else { ActivityComposerView(linkedActivityID: activity.id) }
        }
    }

    @ViewBuilder private var detailAction: some View {
        if owner.id == store.profile?.id, let blindID = activity.blindWorkoutID {
            NavigationLink { BlindWorkoutDetailView(id: blindID) } label: { Text("BLIND WORKOUT ÖFFNEN") }.buttonStyle(PrimaryButtonStyle())
        } else if owner.id == store.profile?.id, activity.status == .live {
            NavigationLink { LiveActivityView() } label: { Text("ÖFFNEN") }.buttonStyle(PrimaryButtonStyle())
        } else if activity.status == .live {
            Button("MITZIEHEN 🔥") { showsJoin = true }.buttonStyle(PrimaryButtonStyle())
        } else if let sessionID = activity.plannedSessionID {
            Button("DABEI?") { Task { await store.joinPlannedSession(sessionID) } }.buttonStyle(PrimaryButtonStyle())
        } else if activity.status == .completed {
            HStack(spacing: 12) {
                ForEach(ReactionKind.allCases, id: \.rawValue) { reaction in
                    Button(reaction.rawValue) { Task { await store.react(activity, reaction: reaction) } }
                        .font(.title2).frame(maxWidth: .infinity, minHeight: 48)
                        .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Mit \(reaction.rawValue) reagieren")
                }
            }
        }
    }
}

private struct DetailRow: View {
    let symbol: String
    let title: String
    let value: String
    var tint: Color = FYColor.ink
    var body: some View { HStack(spacing: 12) { Image(systemName: symbol).foregroundStyle(tint).frame(width: 24); VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(FYColor.muted); Text(value).font(.subheadline) }; Spacer() }.padding(.vertical, 13).overlay(alignment: .bottom) { Rectangle().fill(FYColor.line).frame(height: 1) } }
}

private struct ResultMetric: View {
    let value: String
    let label: String
    var body: some View { VStack(spacing: 4) { Text(value).font(.title3.bold()); Text(label).font(.caption2).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity) }
}
