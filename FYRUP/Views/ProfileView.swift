import SwiftUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var showsDelete = false
    @State private var showsEdit = false
    @State private var notificationsEnabled = false
    @State private var statisticsPeriod = 0
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Profil").font(.title2.weight(.bold))
                    Spacer()
                    Button { showsEdit = true } label: { Image(systemName: "pencil").font(.title3).frame(width: 36, height: 36).background(FYColor.elevated, in: Circle()) }
                        .accessibilityLabel("Profil bearbeiten")
                }
                if let profile = store.profile {
                    HStack(spacing: 16) {
                        AvatarView(profile: profile).scaleEffect(1.45).padding(14)
                        VStack(alignment: .leading, spacing: 3) { Text(profile.displayName).font(.title3.bold()); Text("@\(profile.username)").font(.subheadline).foregroundStyle(FYColor.muted); if let bio = profile.bio { Text(bio).font(.caption).foregroundStyle(FYColor.ink.opacity(0.78)).padding(.top, 3) } }
                        Spacer()
                    }
                    HStack { Metric(value: "\(store.crew.count)", label: "Freunde"); Metric(value: "\(store.goals.monthCount)", label: "Workouts / Monat"); Metric(value: store.weekly.state.map { "\($0.currentStreak)" } ?? "–", label: "Wochenstreak") }
                    OwnWeeklyCard()
                    WeekActivityStrip(activities: store.recentActivities + [store.myActivity].compactMap { $0 })
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Meine Statistiken").font(.headline)
                        Picker("Zeitraum", selection: $statisticsPeriod) { Text("Woche").tag(0); Text("Monat").tag(1); Text("Jahr").tag(2) }.pickerStyle(.segmented)
                        HStack { Text("Abgeschlossene Workouts"); Spacer(); Text("\(periodActivities.count)").bold() }
                        HStack { Text("Aktive Zeit"); Spacer(); Text("\(Int(periodActivities.compactMap(\.duration).reduce(0, +) / 60)) min").bold() }
                        Text("Aus deinem geladenen Trainingsverlauf.").font(.caption2).foregroundStyle(FYColor.muted)
                    }.fyCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Sportarten", systemImage: "figure.run").bold()
                        Text(profile.sports.map(\.title).joined(separator: " · ")).foregroundStyle(FYColor.muted)
                        if let focus = profile.gymFocus, !focus.isEmpty { Text(focus.joined(separator: " · ")).font(.caption).foregroundStyle(FYColor.muted) }
                    }.fyCard()
                    NavigationLink { WorkoutPlansView() } label: {
                        HStack { Label("Meine Trainingspläne", systemImage: "list.clipboard").font(.headline); Spacer(); Image(systemName: "chevron.right") }.foregroundStyle(FYColor.ink).fyCard()
                    }.buttonStyle(.plain).accessibilityIdentifier("profile-workout-plans")
                    RecentActivitiesCard(activities: store.recentActivities, profile: profile)
                }
                VStack(spacing: 0) {
                    Toggle(isOn: $notificationsEnabled) { Label("Mitteilungen", systemImage: "bell") }.padding().onChange(of: notificationsEnabled) { _, enabled in if enabled { Task { let center = UNUserNotificationCenter.current(); if try await center.requestAuthorization(options: [.alert, .badge, .sound]) { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } } } } }
                    Divider(); NavigationLink { NotificationPreferencesView() } label: { SettingsRow(title: "Benachrichtigungen", symbol: "bell.badge") }
                    Divider(); NavigationLink { SettingsView() } label: { SettingsRow(title: "Einstellungen", symbol: "gearshape") }
                    Divider(); NavigationLink { PrivacyView() } label: { SettingsRow(title: "Privatsphäre", symbol: "lock") }
                    Divider(); Button { Task { await store.logout() } } label: { SettingsRow(title: "Abmelden", symbol: "rectangle.portrait.and.arrow.right") }
                    Divider(); Button(role: .destructive) { showsDelete = true } label: { SettingsRow(title: "Account löschen", symbol: "trash") }
                }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 22))
            }.padding(20)
        }
        .background(FYColor.background)
        .navigationBarHidden(true)
        .task { await store.weekly.refresh(); let settings = await UNUserNotificationCenter.current().notificationSettings(); notificationsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional }
        .sheet(isPresented: $showsEdit) { ProfileEditView() }
        .confirmationDialog("Account dauerhaft löschen?", isPresented: $showsDelete, titleVisibility: .visible) { Button("Account löschen", role: .destructive) { Task { await store.deleteAccount() } }; Button("Abbrechen", role: .cancel) {} } message: { Text("Deine personenbezogenen Daten und Verknüpfungen werden entfernt. Diese Aktion kann nicht rückgängig gemacht werden.") }
    }
    private var periodActivities: [Activity] {
        var calendar = Calendar(identifier: .gregorian); calendar.firstWeekday = 2
        let component: Calendar.Component = statisticsPeriod == 0 ? .weekOfYear : statisticsPeriod == 1 ? .month : .year
        guard let interval = calendar.dateInterval(of: component, for: Date()) else { return [] }
        var seen = Set<UUID>()
        return (store.recentActivities + [store.myActivity].compactMap { $0 }).filter { activity in
            guard activity.userID == store.profile?.id, activity.status == .completed, let ended = activity.endedAt,
                  interval.start <= ended, ended < interval.end else { return false }
            return seen.insert(activity.id).inserted
        }
    }
}

private struct ProfileEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var birthYear = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var avatarJPEG: Data?
    @State private var selectedSports = Set<SportKind>()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AvatarPicker(profile: store.profile, jpegData: $avatarJPEG).padding(.vertical, 8)
                    editField("Anzeigename", text: $name, symbol: "person")
                    editField("Username", text: $username, symbol: "at").textInputAutocapitalization(.never).autocorrectionDisabled()
                    editField("Geburtsjahr (optional)", text: $birthYear, symbol: "calendar").keyboardType(.numberPad)
                    editField("Stadt (optional)", text: $city, symbol: "location")
                    TextField("Bio (optional)", text: $bio, axis: .vertical).lineLimit(3...5).padding(14)
                        .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(FYColor.line))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sportarten").font(.headline)
                        SportGrid(selected: $selectedSports)
                    }
                    Button("ÄNDERUNGEN SPEICHERN") {
                        Task {
                            await store.updateProfile(displayName: name, username: username, birthYear: Int(birthYear), city: city, bio: bio, sports: SportKind.allCases.filter(selectedSports.contains), avatarJPEG: avatarJPEG)
                            if store.errorMessage == nil { dismiss() }
                        }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(name.isEmpty || username.isEmpty || selectedSports.isEmpty)
                }.padding(20)
            }
            .background(FYColor.background)
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
        .preferredColorScheme(.light)
        .task {
            guard let profile = store.profile else { return }
            name = profile.displayName
            username = profile.username
            birthYear = profile.birthYear.map(String.init) ?? ""
            city = profile.city ?? ""
            bio = profile.bio ?? ""
            selectedSports = Set(profile.sports)
        }
    }

    private func editField(_ title: String, text: Binding<String>, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(FYColor.muted).frame(width: 22)
            TextField(title, text: text)
        }
        .padding(.horizontal, 14).frame(minHeight: 50)
        .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FYColor.line))
    }
}

private struct Metric: View { let value: String; let label: String; var body: some View { VStack { Text(value).font(.title2.bold()); Text(label).font(.caption).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity) } }

struct WeekActivityStrip: View {
    let activities: [Activity]
    private let calendar = Calendar(identifier: .iso8601)

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Diese Woche").font(.headline)
                Spacer()
                Text("\(completedDays.count) geschafft").font(.caption).foregroundStyle(FYColor.muted)
            }
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let isDone = completedDays.contains(calendar.startOfDay(for: day))
                    let isPlanned = plannedDays.contains(calendar.startOfDay(for: day))
                    VStack(spacing: 7) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2.bold()).foregroundStyle(FYColor.muted)
                        ZStack {
                            Circle().fill(isDone ? FYColor.lime : isPlanned ? FYColor.planned : FYColor.elevated).frame(width: 31, height: 31)
                            if isDone { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black) }
                            else if isPlanned { Image(systemName: "clock.fill").font(.caption2.bold()).foregroundStyle(.black) }
                            else { Text(day.formatted(.dateTime.day())).font(.caption.bold()).foregroundStyle(FYColor.ink.opacity(0.72)) }
                        }
                    }.frame(maxWidth: .infinity)
                }
            }
        }.fyCard()
    }

    private var days: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var completedDays: Set<Date> {
        Set(activities.compactMap { activity in
            guard activity.status == .completed, let date = activity.endedAt ?? activity.startedAt else { return nil }
            return calendar.startOfDay(for: date)
        })
    }

    private var plannedDays: Set<Date> {
        Set(activities.compactMap { activity in
            guard [.planned, .ready].contains(activity.status), let date = activity.plannedAt else { return nil }
            return calendar.startOfDay(for: date)
        })
    }
}

private struct RecentActivitiesCard: View {
    let activities: [Activity]
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Letzte Aktivitäten").font(.headline).padding(.bottom, 8)
            if activities.isEmpty {
                Text("Dein erstes abgeschlossenes Training erscheint hier.")
                    .font(.subheadline).foregroundStyle(FYColor.muted).padding(.vertical, 10)
            } else {
                ForEach(Array(activities.prefix(4).enumerated()), id: \.offset) { index, activity in
                    if index > 0 { Divider().overlay(FYColor.line) }
                    NavigationLink { ActivityDetailView(activity: activity, owner: profile) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: activity.sport.symbol).foregroundStyle(activity.sport.accentColor)
                                .frame(width: 36, height: 36).background(activity.sport.accentColor.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text([activity.sport.title, activity.subtype].compactMap { $0 }.joined(separator: " · ")).font(.subheadline.bold())
                                Text(detail(activity)).font(.caption).foregroundStyle(FYColor.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted)
                        }.foregroundStyle(FYColor.ink).padding(.vertical, 10)
                    }
                }
            }
        }.fyCard()
    }

    private func detail(_ activity: Activity) -> String {
        let date = (activity.endedAt ?? activity.startedAt ?? Date()).formatted(date: .abbreviated, time: .omitted)
        guard let duration = activity.duration else { return date }
        return "\(date) · \(max(1, Int(duration / 60))) Min."
    }
}

private struct SettingsRow: View { let title: String; let symbol: String; var body: some View { HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").foregroundStyle(FYColor.muted) }.foregroundStyle(FYColor.ink).padding() } }

private struct SettingsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let profile = store.profile {
                    HStack(spacing: 14) {
                        AvatarView(profile: profile).scaleEffect(1.15).padding(6)
                        VStack(alignment: .leading) { Text(profile.displayName).font(.headline); Text("@\(profile.username)").font(.caption).foregroundStyle(FYColor.muted) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(FYColor.muted)
                    }.fyCard()
                }
                VStack(spacing: 0) {
                    NavigationLink { NotificationPreferencesView() } label: { SettingsRow(title: "Benachrichtigungen", symbol: "bell") }
                    Divider(); NavigationLink { PrivacyView() } label: { SettingsRow(title: "Privatsphäre", symbol: "lock") }
                    Divider(); SettingsRow(title: "Freunde & Blockierte", symbol: "person.2")
                    Divider(); SettingsRow(title: "Hilfe & Support", symbol: "questionmark.circle")
                    Divider(); SettingsRow(title: "Über FYRUP", symbol: "info.circle")
                }.background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(FYColor.line))
                Button { Task { await store.logout() } } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right").foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding()
                }.background(.white, in: RoundedRectangle(cornerRadius: 16))
            }.padding(18)
        }.background(FYColor.background).navigationTitle("Einstellungen")
    }
}

private struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Form {
            Section("Wer sieht meine Aktivitäten?") {
                Picker("Sichtbarkeit", selection: visibilityBinding) { Text("Freunde").tag("friends"); Text("Niemand").tag("nobody") }.pickerStyle(.inline)
            }
            Section { NavigationLink { StepSettingsView() } label: { Label("Schritte", systemImage: "figure.walk") }.accessibilityIdentifier("privacy-steps") }
            Section { Text("FYRUP zeigt in V1 weder Live-Standort noch GPS-Daten. Deine Aktivitäten sind niemals öffentlich.") }
        }.scrollContentBackground(.hidden).background(FYColor.background).navigationTitle("Datenschutz")
    }
    private var visibilityBinding: Binding<String> { Binding(get: { store.profile?.activityVisibility ?? "friends" }, set: { value in guard var profile = store.profile else { return }; profile.activityVisibility = value; Task { try? await store.repository.saveProfile(profile); await MainActor.run { store.profile = profile } } }) }
}

private struct NotificationPreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotificationPreferences = .standard

    var body: some View {
        Form {
            Section {
                Toggle("Freund startet Training", isOn: $draft.friendStarts)
                Toggle("FYR UP", isOn: $draft.fyrup)
                Toggle("Trainingseinladungen", isOn: $draft.invitations)
                Toggle("Reaktionen", isOn: $draft.reactions)
                Toggle("Freundschaftsanfragen", isOn: $draft.friendRequests)
            } footer: {
                Text("Normale Trainingsstarts sind standardmäßig aus, damit deine Crew nicht mit Pushs überladen wird.")
            }
            Section("Ziele und Erinnerungen") {
                Toggle("Trainingserinnerungen", isOn: $draft.reminders)
                Toggle("Wochenziel", isOn: $draft.weeklyGoal)
                Toggle("Crew-Ziel", isOn: $draft.crewGoal)
            }
            Section {
                Button("Einstellungen speichern") {
                    Task {
                        await store.saveNotificationPreferences(draft)
                        if store.errorMessage == nil { dismiss() }
                    }
                }.frame(maxWidth: .infinity).fontWeight(.bold)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FYColor.background)
        .navigationTitle("Benachrichtigungen")
        .task { draft = store.notificationPreferences }
    }
}
