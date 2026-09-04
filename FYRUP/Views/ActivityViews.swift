import SwiftUI

struct ActivityComposerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let linkedActivityID: UUID?
    @State private var sport: SportKind?
    @State private var subtype: String?
    @State private var mode = 0
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var duration = 60
    @State private var note = ""
    @State private var invitees = Set<UUID>()

    init(linkedActivityID: UUID? = nil) { self.linkedActivityID = linkedActivityID }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Was machst du?").font(.largeTitle.bold())
                    if sport == nil { sportChooser }
                    else { details }
                }.padding(20)
            }.background(FYColor.background).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
    private var sportChooser: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(SportKind.allCases) { item in Button { sport = item } label: { VStack(spacing: 10) { Image(systemName: item.symbol).font(.title); Text(item.title).font(.subheadline.bold()) }.frame(maxWidth: .infinity, minHeight: 96).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 20)) }.foregroundStyle(.white) }
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
                TextField("Notiz (optional)", text: $note, axis: .vertical).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                if !store.crew.isEmpty { Text("Wen willst du einladen?").font(.headline); ForEach(store.crew) { member in Button { invitees.formSymmetricDifference([member.id]) } label: { HStack { AvatarView(profile: member.profile); Text(member.profile.displayName); Spacer(); Image(systemName: invitees.contains(member.id) ? "checkmark.circle.fill" : "circle") }.foregroundStyle(.white) }.buttonStyle(.plain) } }
            }
            Button(mode == 0 ? "JETZT STARTEN" : "TRAINING PLANEN") { Task { if mode == 0 { await store.start(sport: sport, subtype: subtype, linked: linkedActivityID) } else { await store.plan(sport: sport, subtype: subtype, startsAt: startsAt, duration: duration, note: note.isEmpty ? nil : note, invitees: Array(invitees)) } } }.buttonStyle(PrimaryButtonStyle())
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
        VStack(spacing: 22) {
            Spacer()
            if let activity = store.myActivity {
                Image(systemName: activity.sport.symbol).font(.system(size: 66)).foregroundStyle(FYColor.lime)
                Text(didComplete ? "DID IT. 🔥" : activity.sport.title.uppercased()).font(.largeTitle.weight(.black))
                if let subtype = activity.subtype { Text(subtype).font(.title3).foregroundStyle(FYColor.muted) }
                if didComplete {
                    if let duration = activity.duration { Text("\(max(1, Int(duration / 60))) MIN").font(.title.bold()) }
                    Text("Heute geschafft ✓").font(.headline)
                } else {
                    LiveTimer(start: activity.startedAt ?? .now).font(.largeTitle)
                    Text("Du ziehst gerade durch 🔥").font(.headline)
                    if activity.sport.supportsDistance { TextField("Distanz in km (optional)", text: $distanceKM).keyboardType(.decimalPad).padding().background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)) }
                }
            }
            Spacer()
            if didComplete { Button("FERTIG") { dismiss() }.buttonStyle(PrimaryButtonStyle()) }
            else {
                Button("TRAINING BEENDEN") { Task { let normalized = distanceKM.replacingOccurrences(of: ",", with: "."); let meters = Double(normalized).map { Int($0 * 1000) }; await store.finish(distanceMeters: meters); didComplete = store.myActivity?.status == .completed } }.buttonStyle(PrimaryButtonStyle())
                Button("Abbrechen") { confirmCancel = true }.foregroundStyle(FYColor.muted)
            }
        }.padding(24).background(FYColor.background).confirmationDialog("Training wirklich abbrechen?", isPresented: $confirmCancel) { Button("Training abbrechen", role: .destructive) { Task { await store.cancelCurrent(); dismiss() } }; Button("Weiter trainieren", role: .cancel) {} }
    }
}
