import SwiftUI

struct ActivityComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let linkedActivityID: UUID?
    @State private var sport: SportKind?
    @State private var subtype: String?
    @State private var mode: Int
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var duration = 60
    @State private var note = ""
    @State private var placeName = ""
    @State private var friendsCanJoin = true
    @State private var invitees = Set<UUID>()
    @State private var search = ""

    init(linkedActivityID: UUID? = nil, initialMode: Int = 0) {
        self.linkedActivityID = linkedActivityID
        _mode = State(initialValue: initialMode)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(sport == nil ? "Aktivität wählen" : mode == 0 ? "Training starten" : "Training planen").font(.title2.bold())
                    if sport == nil { sportChooser }
                    else { details }
                }.padding(20)
            }.background(FYColor.background).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
    private var sportChooser: some View {
        VStack(spacing: 14) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted); TextField("Suchen …", text: $search) }
                .padding(12).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 12))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(SportKind.allCases.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { item in
                    Button { sport = item } label: {
                        VStack(spacing: 9) {
                            Image(systemName: item.symbol).font(.title2).foregroundStyle(item.accentColor)
                            Text(item.title).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(FYColor.line))
                    }.foregroundStyle(.white)
                }
            }
        }
    }
    @ViewBuilder private var details: some View {
        if let sport {
            Button { self.sport = nil; subtype = nil } label: { ActivityLabel(activity: Activity(id: UUID(), userID: UUID(), sport: sport, subtype: subtype, status: .planned, plannedAt: nil, startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: nil, note: nil, plannedSessionID: nil)) }.buttonStyle(.plain)
            if let choices = SportCatalog.subtypes[sport] {
                ScrollView(.horizontal, showsIndicators: false) { HStack { Button("Überspringen") { subtype = nil }.chip(selected: subtype == nil); ForEach(choices, id: \.self) { item in Button(item) { subtype = item }.chip(selected: subtype == item) } } }
            }
            Picker("Startart", selection: $mode) { Text("JETZT STARTEN").tag(0); Text("PLANEN").tag(1) }.pickerStyle(.segmented)
            if mode == 1 {
                DatePicker("Datum & Uhrzeit", selection: $startsAt, in: Date()...).datePickerStyle(.compact).fyCard()
                Stepper("ca. \(duration) Minuten", value: $duration, in: 15...240, step: 15).fyCard()
                HStack { Image(systemName: "mappin.and.ellipse").foregroundStyle(FYColor.muted); TextField("Ort / Treffpunkt (optional)", text: $placeName) }
                    .padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                TextField("Notiz (optional)", text: $note, axis: .vertical).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                Toggle("Freunde dürfen sich anschließen", isOn: $friendsCanJoin).fyCard()
                if !store.crew.isEmpty { Text("Wen willst du einladen?").font(.headline); ForEach(store.crew) { member in Button { invitees.formSymmetricDifference([member.id]) } label: { HStack { AvatarView(profile: member.profile); Text(member.profile.displayName); Spacer(); Image(systemName: invitees.contains(member.id) ? "checkmark.circle.fill" : "circle") }.foregroundStyle(.white) }.buttonStyle(.plain) } }
            }
            Button(mode == 0 ? "JETZT STARTEN" : "TRAINING PLANEN") { Task { if mode == 0 { await store.start(sport: sport, subtype: subtype, linked: linkedActivityID) } else { await store.plan(sport: sport, subtype: subtype, startsAt: startsAt, duration: duration, note: note.isEmpty ? nil : note, placeName: placeName.isEmpty ? nil : placeName, friendsCanJoin: friendsCanJoin, invitees: Array(invitees)) } } }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("confirm-activity")
        }
    }
}

private extension Button {
    func chip(selected: Bool) -> some View { self.font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 10).foregroundStyle(selected ? .black : .white).background(selected ? FYColor.lime : FYColor.elevated, in: Capsule()) }
}

struct LiveActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmCancel = false
    @State private var distanceKM = ""
    @State private var didComplete = false
    var body: some View {
        VStack(spacing: 24) {
            HStack { Button { dismiss() } label: { Image(systemName: "chevron.left") }; Spacer() }.foregroundStyle(.white)
            Spacer(minLength: 20)
            if let activity = store.myActivity {
                if didComplete {
                    Image(systemName: "trophy.fill").font(.system(size: 70)).foregroundStyle(FYColor.planned)
                    Text("Workout geschafft!").font(.title.weight(.bold))
                    Text([activity.sport.title, activity.subtype].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(FYColor.muted)
                    if let duration = activity.duration { HStack { ResultMetric(value: "\(max(1, Int(duration / 60)))", label: "Minuten"); ResultMetric(value: "1", label: "Workout"); ResultMetric(value: "🔥", label: "Status") }.padding(.vertical, 8) }
                    Text("„Stärker als gestern.\nGenau so.“").multilineTextAlignment(.center).foregroundStyle(FYColor.muted).fyCard()
                } else {
                    StatusBadge(status: .live).font(.headline)
                    Text([activity.sport.title, activity.subtype].compactMap { $0 }.joined(separator: " · ")).font(.headline)
                    LiveTimer(start: activity.startedAt ?? .now).font(.system(size: 46, weight: .bold, design: .monospaced))
                    if let liveFriend = store.crew.first(where: { $0.todayStatus == .live }) {
                        Label("\(liveFriend.profile.displayName) trainiert ebenfalls.", systemImage: "person.2.fill").font(.subheadline).foregroundStyle(FYColor.live)
                    }
                    if let doneFriend = store.crew.first(where: { $0.todayStatus == .done }) {
                        Text("\(doneFriend.profile.displayName) hat heute bereits trainiert.").font(.subheadline).foregroundStyle(FYColor.muted)
                    }
                    if activity.sport.supportsDistance { TextField("Distanz in km (optional)", text: $distanceKM).keyboardType(.decimalPad).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)) }
                }
            }
            Spacer()
            if didComplete {
                Button("Auf Feed teilen") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                Button("Fertig") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            else {
                Button { Task { let normalized = distanceKM.replacingOccurrences(of: ",", with: "."); let meters = Double(normalized).map { Int($0 * 1000) }; await store.finish(distanceMeters: meters); didComplete = store.myActivity?.status == .completed } } label: { Image(systemName: "stop.fill").font(.title2).frame(width: 68, height: 68).background(FYColor.coral, in: Circle()).shadow(color: FYColor.coral.opacity(0.35), radius: 14) }.foregroundStyle(.white).accessibilityLabel("TRAINING BEENDEN")
                Text("Du machst das stark! 🔥").font(.subheadline).foregroundStyle(FYColor.muted)
                Button("Training abbrechen") { confirmCancel = true }.font(.caption).foregroundStyle(FYColor.coral)
            }
        }.padding(24).background(FYColor.background).confirmationDialog("Training wirklich abbrechen?", isPresented: $confirmCancel) { Button("Training abbrechen", role: .destructive) { Task { await store.cancelCurrent(); dismiss() } }; Button("Weiter trainieren", role: .cancel) {} }
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
    @State private var friendsCanJoin = true
    @State private var confirmCancel = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActivityLabel(activity: Activity(id: hosted.id, userID: hosted.session.hostID, sport: hosted.session.sport, subtype: hosted.session.subtype, status: .planned, plannedAt: startsAt, startedAt: nil, endedAt: nil, distanceMeters: nil, plannedDurationMinutes: duration, note: note, plannedSessionID: hosted.id)).fyCard()
                DatePicker("Datum & Uhrzeit", selection: $startsAt, in: Date()...).fyCard()
                Stepper("ca. \(duration) Minuten", value: $duration, in: 15...240, step: 15).fyCard()
                HStack { Image(systemName: "mappin.and.ellipse").foregroundStyle(FYColor.muted); TextField("Ort / Treffpunkt (optional)", text: $placeName) }
                    .padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
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
                    Task { await store.updateHostedSession(session) }
                }.buttonStyle(SecondaryButtonStyle())
                Button("TRAINING STARTEN") { Task { await store.start(sport: hosted.session.sport, subtype: hosted.session.subtype, plannedSessionID: hosted.id); dismiss() } }.buttonStyle(PrimaryButtonStyle())
                Button("Training absagen", role: .destructive) { confirmCancel = true }.frame(maxWidth: .infinity).padding(.top, 4)
            }.padding(20)
        }
        .background(FYColor.background)
        .navigationTitle("Training planen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startsAt = max(Date(), hosted.session.startsAt)
            duration = hosted.session.durationMinutes ?? 60
            note = hosted.session.note ?? ""
            placeName = hosted.session.placeName ?? ""
            friendsCanJoin = hosted.session.friendsCanJoin
        }
        .confirmationDialog("Training wirklich absagen?", isPresented: $confirmCancel) {
            Button("Training absagen", role: .destructive) { Task { await store.cancelPlannedSession(hosted.id); dismiss() } }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [activity.sport.accentColor.opacity(0.42), FYColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: activity.sport.symbol).font(.system(size: 78)).foregroundStyle(.white.opacity(0.16)).frame(maxWidth: .infinity, alignment: .trailing).padding(20)
                    VStack(alignment: .leading, spacing: 4) { Text(activity.sport.title).font(.largeTitle.bold()); if let subtype = activity.subtype { Text(subtype).foregroundStyle(.white.opacity(0.76)) } }.padding(18)
                }.frame(height: 180)
                VStack(spacing: 0) {
                    DetailRow(symbol: "figure.strengthtraining.traditional", title: "Kategorie", value: activity.sport.title, tint: activity.sport.accentColor)
                    if let subtype = activity.subtype { DetailRow(symbol: "list.bullet", title: "Unterkategorie", value: subtype) }
                    if let date = activity.plannedAt ?? activity.startedAt { DetailRow(symbol: "calendar", title: "Datum", value: date.formatted(date: .abbreviated, time: .shortened)) }
                    if let minutes = activity.plannedDurationMinutes { DetailRow(symbol: "clock", title: "Dauer (geplant)", value: "ca. \(minutes) min") }
                    HStack(spacing: -7) { AvatarView(profile: owner).scaleEffect(0.72); Text(owner.displayName).font(.subheadline.bold()).padding(.leading, 12); Spacer(); StatusBadge(status: activity.status == .live ? .live : activity.status == .completed ? .done : .planned) }.padding(.vertical, 16)
                    detailAction.padding(.top, 10)
                }.padding(.horizontal, 18)
            }
        }
        .background(FYColor.background)
        .navigationTitle("Aktivitätsdetails")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsJoin) { ActivityComposerView(linkedActivityID: activity.id) }
    }

    @ViewBuilder private var detailAction: some View {
        if owner.id == store.profile?.id, activity.status == .live {
            NavigationLink { LiveActivityView() } label: { Text("TRAINING ÖFFNEN") }.buttonStyle(PrimaryButtonStyle())
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
    var tint: Color = .white
    var body: some View { HStack(spacing: 12) { Image(systemName: symbol).foregroundStyle(tint).frame(width: 24); VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(FYColor.muted); Text(value).font(.subheadline) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted) }.padding(.vertical, 13).overlay(alignment: .bottom) { Rectangle().fill(FYColor.line).frame(height: 1) } }
}

private struct ResultMetric: View {
    let value: String
    let label: String
    var body: some View { VStack(spacing: 4) { Text(value).font(.title3.bold()); Text(label).font(.caption2).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity) }
}
