import SwiftUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsDelete = false
    @State private var showsEdit = false
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    FYRUPWordmark(size: 22).accessibilityIdentifier("profile-title")
                    Spacer()
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("Profileinstellungen").accessibilityIdentifier("profile-settings-shortcut")
                }
                if let profile = store.profile {
                    VStack(spacing: 8) {
                        Button { showsEdit = true } label: {
                            AvatarView(profile: profile, size: 88)
                                .overlay(alignment: .bottomTrailing) { Image(systemName: "pencil.circle.fill").font(.title2).symbolRenderingMode(.palette).foregroundStyle(FYColor.lime, .white) }
                        }.buttonStyle(FYPressStyle()).accessibilityLabel("Profil bearbeiten").accessibilityIdentifier("profile-edit")
                        Text(profile.displayName).font(.title.bold()).accessibilityIdentifier("profile-name")
                        Text("@\(profile.username)").font(.subheadline).foregroundStyle(FYColor.muted)
                        if let bio = profile.bio, !bio.isEmpty { Text(bio).font(.subheadline).foregroundStyle(FYColor.muted) }
                    }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    if typeSize.isAccessibilitySize {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Metric(value: "\(store.goals.monthCount)", label: "Einheiten / Monat").frame(width: 170)
                                Metric(value: store.weekly.state.map { "\($0.currentStreak)" } ?? "–", label: "Wochenstreak").frame(width: 170)
                                Metric(value: "\(store.crew.count)", label: "Freunde").frame(width: 170)
                            }
                        }
                        .accessibilityLabel("Profilübersicht")
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) { Divider().overlay(FYColor.line) }
                    } else {
                        HStack(spacing: 8) {
                            Metric(value: "\(store.goals.monthCount)", label: "Einheiten / Monat")
                            Metric(value: store.weekly.state.map { "\($0.currentStreak)" } ?? "–", label: "Wochenstreak")
                            Metric(value: "\(store.crew.count)", label: "Freunde")
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) { Divider().overlay(FYColor.line) }
                    }
                }
                VStack(spacing: 0) {
                    NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { SettingsRow(title: "Ziele & Wochenwünsche", symbol: "scope") }.accessibilityIdentifier("profile-weekly-routine")
                    Divider(); NavigationLink { ProfileStatisticsView() } label: { SettingsRow(title: "Statistiken", symbol: "chart.xyaxis.line") }.accessibilityIdentifier("profile-statistics")
                    Divider(); NavigationLink { BodyMeasurementsEditor() } label: { SettingsRow(title: "Körperdaten", symbol: "figure.stand") }.accessibilityIdentifier("profile-body-data")
                    Divider(); NavigationLink { NotificationPreferencesView() } label: { SettingsRow(title: "Erinnerungen", symbol: "bell") }
                    Divider(); NavigationLink { SettingsView() } label: { SettingsRow(title: "Einstellungen", symbol: "gearshape") }
                    Divider(); NavigationLink { SupportView() } label: { SettingsRow(title: "Hilfe & Feedback", symbol: "questionmark.circle") }.accessibilityIdentifier("profile-support")
                }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                Text("Dein Alltag").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 0) {
                    NavigationLink { WorkoutPlansView() } label: { SettingsRow(title: "Meine Workout-Pläne", symbol: "list.clipboard") }.accessibilityIdentifier("profile-workout-plans")
                    Divider()
                    NavigationLink { LiveAndRestSettingsView().toolbar(.visible, for: .navigationBar) } label: { SettingsRow(title: "LIVE & Satzpausen", symbol: "timer") }
                    Divider()
                    NavigationLink { NutritionView() } label: { SettingsRow(title: "Ernährung", symbol: "fork.knife") }.accessibilityIdentifier("profile-nutrition")
                    Divider()
                    NavigationLink { ScrollView { BodyAndEnergySettings().padding(FYLayout.page) }.background(FYColor.background).navigationTitle("Aktive Energie").toolbar(.visible, for: .navigationBar) } label: { SettingsRow(title: "Aktive Energie", symbol: "flame") }.accessibilityIdentifier("active-energy-card")
                    Divider()
                    NavigationLink { FavoriteGymView() } label: { SettingsRow(title: "Stammgym", symbol: "mappin.and.ellipse") }
                        .accessibilityIdentifier("profile-favorite-gym")
                    Divider(); NavigationLink { SupplementsView() } label: { SettingsRow(title: "Supplements", symbol: "pills") }
                }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 18))
                PersonalSetupHomeCard()
                VStack(spacing: 0) {
                    SystemNotificationSettingsRow()
                    Divider(); NavigationLink { PrivacyView() } label: { SettingsRow(title: "Privatsphäre", symbol: "lock") }
                    Divider(); Button { Task { await store.logout() } } label: { SettingsRow(title: "Abmelden", symbol: "rectangle.portrait.and.arrow.right") }
                    Divider(); Button(role: .destructive) { showsDelete = true } label: { SettingsRow(title: "Account löschen", symbol: "trash") }
                }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 22))
            }.frame(width: max(0, geometry.size.width - FYLayout.page * 2))
                .padding(FYLayout.page)
        }
        }
        .background(FYColor.background)
        .navigationBarHidden(true)
        .task { await store.weekly.refresh() }
        .sheet(isPresented: $showsEdit) { ProfileEditView() }
        .confirmationDialog("Account dauerhaft löschen?", isPresented: $showsDelete, titleVisibility: .visible) { Button("Account löschen", role: .destructive) { Task { await store.deleteAccount() } }; Button("Abbrechen", role: .cancel) {} } message: { Text("Deine personenbezogenen Daten und Verknüpfungen werden entfernt. Diese Aktion kann nicht rückgängig gemacht werden.") }
    }
}

private struct ProfileStatisticsView: View {
    @Environment(AppStore.self) private var store
    @State private var statisticsPeriod = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FYLayout.section) {
                OwnWeeklyCard()
                WeekActivityStrip(activities: ownActivities, now: store.presentationDate)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Meine Statistiken").font(.headline).accessibilityIdentifier("profile-statistics-title")
                    Picker("Zeitraum", selection: $statisticsPeriod) { Text("Woche").tag(0); Text("Monat").tag(1); Text("Jahr").tag(2) }.pickerStyle(.segmented)
                    if statisticsPeriod == 0 {
                        ActivityWeekBars(activities: periodActivities, now: store.presentationDate)
                    }
                    LabeledContent("Abgeschlossene Einheiten", value: "\(periodActivities.count)")
                    LabeledContent("Aktive Zeit", value: "\(Int(periodActivities.compactMap(\.duration).reduce(0, +) / 60)) min")
                    Text("Aus deinen geladenen Aktivitäten.").font(.caption).foregroundStyle(FYColor.muted)
                }.fyCard()
                if let profile = store.profile {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sportarten", systemImage: "figure.run").bold()
                        Text(profile.sports.map(\.title).joined(separator: " · ")).foregroundStyle(FYColor.muted)
                        if let focus = profile.gymFocus, !focus.isEmpty { Text(focus.map { FyrupLanguage.subtype($0, sport: .gym) ?? $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(FYColor.muted) }
                    }.fyCard()
                    RecentActivitiesCard(activities: ownActivities.filter { $0.status == .completed }, profile: profile)
                }
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationTitle("Statistiken").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private var ownActivities: [Activity] {
        ProfileActivityHistory.own(store.recentActivities, latest: store.myActivity, owner: store.profile?.id)
    }
    private var periodActivities: [Activity] {
        let calendar = TrainingWeekLogic.calendar()
        let component: Calendar.Component = statisticsPeriod == 0 ? .weekOfYear : statisticsPeriod == 1 ? .month : .year
        return ProfileActivityHistory.completed(ownActivities, period: component, now: store.presentationDate, calendar: calendar)
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
    var now: Date = Date()
    @Environment(\.dynamicTypeSize) private var typeSize
    private var week: ProfileWeekSnapshot { ProfileWeekSnapshot(activities: activities, now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Diese Woche").font(.headline)
                Spacer()
                Text("\(week.completedDays.count) geschafft").font(.caption).foregroundStyle(FYColor.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0)), count: typeSize.isAccessibilitySize ? 3 : 7), spacing: 8) {
                ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                    let isDone = week.completedDays.contains(day)
                    let isPlanned = week.plannedDays.contains(day)
                    let weekday = TrainingWeekLogic.weekday(day, calendar: week.calendar)
                    VStack(spacing: 7) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2.bold()).foregroundStyle(FYColor.muted)
                        ZStack {
                            Circle().fill(isDone ? FYColor.lime : isPlanned ? FYColor.planned : FYColor.elevated).frame(width: 31, height: 31)
                            if isDone { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black) }
                            else if isPlanned { Image(systemName: "clock.fill").font(.caption2.bold()).foregroundStyle(.black) }
                            else { Text(day.formatted(.dateTime.day())).font(.caption.bold()).foregroundStyle(FYColor.ink.opacity(0.72)) }
                        }
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("profile-week-day-\(weekday)")
                        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month()))
                        .accessibilityValue(isDone ? "DONE" : isPlanned ? "PLANNED" : "Keine Aktivität")
                }
            }
        }.fyCard()
    }

}

private struct ActivityWeekBars: View {
    let activities: [Activity]
    let now: Date
    private var days: [Date] { TrainingWeekLogic.days(containing: now) }
    private var counts: [Int] {
        let calendar = TrainingWeekLogic.calendar()
        return days.map { day in
            activities.filter { activity in
                guard activity.status == .completed,
                      let date = activity.endedAt ?? activity.startedAt else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }.count
        }
    }
    var body: some View {
        let ceiling = max(1, counts.max() ?? 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(counts[index] > 0 ? FYColor.lime : FYColor.elevated)
                        .frame(height: max(8, 72 * CGFloat(counts[index]) / CGFloat(ceiling)))
                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2).foregroundStyle(FYColor.muted)
                }.frame(maxWidth: .infinity)
            }
        }.frame(height: 104).accessibilityElement(children: .ignore)
            .accessibilityLabel("Einheiten dieser Woche: \(counts.reduce(0, +))")
    }
}

private struct RecentActivitiesCard: View {
    let activities: [Activity]
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Letzte Aktivitäten").font(.headline).padding(.bottom, 8)
            if activities.isEmpty {
                Text("Deine erste abgeschlossene Aktivität erscheint hier.")
                    .font(.subheadline).foregroundStyle(FYColor.muted).padding(.vertical, 10)
            } else {
                ForEach(Array(activities.prefix(4).enumerated()), id: \.offset) { index, activity in
                    if index > 0 { Divider().overlay(FYColor.line) }
                    NavigationLink { ActivityDetailView(activity: activity, owner: profile) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: activity.sport.symbol).foregroundStyle(activity.sport.accentColor)
                                .frame(width: 36, height: 36).background(activity.sport.accentColor.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text([activity.sport.title, activity.displaySubtype].compactMap { $0 }.joined(separator: " · ")).font(.subheadline.bold())
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

private struct SettingsRow: View { let title: String; let symbol: String; var body: some View { HStack(spacing: 12) { Label(title, systemImage: symbol).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(FYColor.muted) }.foregroundStyle(FYColor.ink).frame(minHeight: 44).padding(.horizontal, 16).padding(.vertical, 6).contentShape(Rectangle()) } }

private struct SettingsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FYRUPWordmark(size: 22)
                Text("Einstellungen").font(.largeTitle.weight(.black))
                if let profile = store.profile {
                    HStack(spacing: 14) {
                        AvatarView(profile: profile).scaleEffect(1.15).padding(6)
                        VStack(alignment: .leading) { Text(profile.displayName).font(.headline); Text("@\(profile.username)").font(.caption).foregroundStyle(FYColor.muted) }
                        Spacer()
                    }.padding(.vertical, 10).overlay(alignment: .bottom) { Divider().overlay(FYColor.line) }
                }
                VStack(spacing: 0) {
                    NavigationLink { NotificationPreferencesView() } label: { SettingsRow(title: "Benachrichtigungen", symbol: "bell") }
                    Divider(); NavigationLink { PrivacyView() } label: { SettingsRow(title: "Privatsphäre", symbol: "lock") }
                    Divider(); NavigationLink { FriendsView() } label: { SettingsRow(title: "Freunde", symbol: "person.2") }
                        .accessibilityIdentifier("settings-friends")
                    Divider(); NavigationLink { SupportView() } label: { SettingsRow(title: "Hilfe & Support", symbol: "questionmark.circle") }
                        .accessibilityIdentifier("settings-support")
                    Divider(); NavigationLink { AboutFyrupView() } label: { SettingsRow(title: "Über FYRUP", symbol: "info.circle") }
                        .accessibilityIdentifier("settings-about")
                }.background(.white)
                Button { Task { await store.logout() } } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right").foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding()
                }.background(.white, in: RoundedRectangle(cornerRadius: 16))
            }.padding(18)
        }.background(FYColor.background).navigationTitle("").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}

enum FyrupSupportContact {
    static let email = "Kundenservice@objektsignal.com"

    static func emailURL(subject: String = "FYRUP Support") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}

struct SupportView: View {
    @Environment(\.openURL) private var openURL
    @State private var copied = false
    @State private var emailStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FYRUPWordmark(size: 22)
                Text("Hilfe & FYRUP").font(.largeTitle.weight(.black))
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "questionmark.bubble.fill")
                        .font(.system(size: 42)).foregroundStyle(FYColor.lime)
                    Text("Wie können wir helfen?").font(.title2.weight(.black))
                    Text("Beschreibe kurz, wobei du Hilfe brauchst. Dein E-Mail-Programm öffnet sich mit unserer Adresse; versendet wird erst, wenn du selbst auf Senden tippst.")
                        .font(.subheadline).foregroundStyle(FYColor.muted)
                }.fyCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("KUNDENSERVICE")
                        .font(.caption.weight(.black)).foregroundStyle(FYColor.muted).padding(.top, 10)
                    Text(FyrupSupportContact.email).font(.body.weight(.semibold)).textSelection(.enabled)
                        .accessibilityIdentifier("support-email-address")
                    Button {
                        guard let url = FyrupSupportContact.emailURL() else {
                            emailStatus = "Die E-Mail-Adresse konnte nicht vorbereitet werden. Kopiere sie stattdessen."
                            return
                        }
                        openURL(url) { accepted in
                            Task { @MainActor in
                                emailStatus = accepted ? nil : "Kein E-Mail-Programm verfügbar. Kopiere die Adresse und schreibe uns direkt."
                            }
                        }
                    } label: {
                        Label("E-MAIL VORBEREITEN", systemImage: "envelope.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("support-compose-email")
                    Button {
                        UIPasteboard.general.string = FyrupSupportContact.email
                        copied = true
                    } label: {
                        Label(copied ? "Adresse kopiert" : "Adresse kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(OutlineButtonStyle()).accessibilityIdentifier("support-copy-email")
                    if let emailStatus {
                        Text(emailStatus).font(.footnote).foregroundStyle(FYColor.muted)
                            .accessibilityIdentifier("support-email-status")
                    }
                }.fyCard()
            }.padding(20)
        }.background(FYColor.background).navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutFyrupView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill").font(.system(size: 56)).foregroundStyle(FYColor.lime)
                    Text("FYRUP").font(.largeTitle.weight(.black))
                    Text("Gemeinsam aktiv. Eine stärkere Crew.").font(.headline).multilineTextAlignment(.center)
                    Text("Version \(version) · Build \(build)").font(.caption).foregroundStyle(FYColor.muted)
                        .accessibilityIdentifier("about-version")
                }.frame(maxWidth: .infinity).fyCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("ÜBER FYRUP")
                        .font(.caption.weight(.black)).foregroundStyle(FYColor.muted).padding(.top, 10)
                    Text("FYRUP verbindet deine Aktivitäten, Sessions, Workout-Pläne und deine Crew an einem Ort.")
                        .font(.subheadline).foregroundStyle(FYColor.muted)
                    NavigationLink { SupportView() } label: {
                        SettingsRow(title: "Hilfe & Support", symbol: "questionmark.circle")
                    }.background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("about-support")
                }.fyCard()
            }.padding(20)
        }.background(FYColor.background).navigationTitle("Über FYRUP")
    }
}

struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Form {
            Section {
                if let selected = store.activityPrivacy.value {
                    ForEach(ActivityVisibility.allCases, id: \.self) { value in
                        Button { Task { await store.saveActivityPrivacy(value) } } label: {
                            HStack {
                                Text(value.title).foregroundStyle(FYColor.ink)
                                Spacer()
                                if selected == value && store.activityPrivacy.isConfirmed { Image(systemName: "checkmark").foregroundStyle(FYColor.lime) }
                            }.frame(minHeight: 36)
                        }.disabled(store.activityPrivacy.isBusy || !store.activityPrivacy.isConfirmed)
                            .accessibilityIdentifier("activity-visibility-\(value.rawValue)")
                            .accessibilityAddTraits(selected == value && store.activityPrivacy.isConfirmed ? [.isSelected] : [])
                    }
                }
                if store.activityPrivacy.isBusy { ProgressView(store.activityPrivacy.isSaving ? "Wird bestätigt …" : "Wird geladen …") }
                if let error = store.activityPrivacy.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(FYColor.muted)
                        .accessibilityIdentifier("activity-privacy-error")
                }
                if !store.activityPrivacy.isConfirmed && !store.activityPrivacy.isBusy {
                    Button("Sichtbarkeit erneut laden") { Task { await store.refreshActivityPrivacy() } }
                        .accessibilityIdentifier("reload-activity-privacy")
                }
            } header: {
                Text("Wer sieht meine Aktivitäten?").textCase(nil)
                    .accessibilityIdentifier("privacy-visibility-heading")
            }
            Section { NavigationLink { StepSettingsView() } label: { Label("Schritte", systemImage: "figure.walk") }.accessibilityIdentifier("privacy-steps") }
            Section { Text("FYRUP zeigt in V1 weder Live-Standort noch GPS-Daten. Deine Aktivitäten sind niemals öffentlich.") }
        }.scrollContentBackground(.hidden).background(FYColor.background).navigationTitle("Datenschutz")
            .task { await store.refreshActivityPrivacy() }
    }
}

struct SystemNotificationSettingsRow: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Mitteilungen auf diesem iPhone", systemImage: "bell")
            Text(statusText).font(.caption).foregroundStyle(FYColor.muted)
                .accessibilityIdentifier("system-notification-status")
            Button(buttonTitle) { Task { await act() } }
                .disabled(isWorking)
                .accessibilityIdentifier("system-notification-settings")
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshStatus() } }
            }
    }

    private var statusText: String {
        guard let status else { return "Status noch nicht geladen" }
        switch status {
        case .notDetermined: return "Noch nicht eingerichtet"
        case .denied: return "In den iPhone-Einstellungen ausgeschaltet"
        case .authorized: return "Erlaubt. Anzeige, Töne und Hinweise legst du in den iPhone-Einstellungen fest."
        case .provisional: return "Vorläufig erlaubt – stille Zustellung"
        case .ephemeral: return "Vorübergehend erlaubt"
        @unknown default: return "Bitte prüfe den Status in den iPhone-Einstellungen."
        }
    }

    private var buttonTitle: String {
        guard let status else { return "Status aktualisieren" }
        return status == .notDetermined ? "Mitteilungen erlauben" : "iPhone-Mitteilungseinstellungen öffnen"
    }

    private func refreshStatus() async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        let rawStatus = await SystemNotificationAuthorization.rawStatus()
        guard !Task.isCancelled else { return }
        status = UNAuthorizationStatus(rawValue: rawStatus)
    }

    private func act() async {
        guard !isWorking else { return }
        guard let status else { await refreshStatus(); return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        if status == .notDetermined {
            do {
                let center = UNUserNotificationCenter.current()
                _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                let currentStatus = UNAuthorizationStatus(rawValue: await SystemNotificationAuthorization.rawStatus())
                guard !Task.isCancelled else { return }
                self.status = currentStatus
                if currentStatus == .authorized || currentStatus == .provisional {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch { errorMessage = "Die Anfrage konnte nicht abgeschlossen werden. Bitte versuche es erneut." }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            if await UIApplication.shared.open(url) == false {
                errorMessage = "Die Einstellungen konnten nicht geöffnet werden. Öffne auf deinem iPhone Einstellungen → Mitteilungen → FYRUP."
            }
        }
    }
}

private struct NotificationPreferencesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            if let snapshot = store.notificationSettings.value {
                NotificationPreferenceFields(initial: snapshot)
                    .id(store.notificationSettings.userID)
            } else {
                Section { Text("Deine gespeicherten Einstellungen werden erst nach erfolgreichem Laden angezeigt.").foregroundStyle(FYColor.muted) }
            }
            if store.notificationSettings.isLoading {
                Section { ProgressView("Einstellungen laden …") }
            }
            if let message = store.notificationSettings.errorMessage {
                Section { Text(message).font(.subheadline).foregroundStyle(.red) }
            }
            if !store.notificationSettings.isConfirmed {
                Section {
                    Button("Erneut laden") { Task { await store.notificationSettings.refresh() } }
                        .disabled(store.notificationSettings.isBusy)
                        .accessibilityIdentifier("reload-notification-preferences")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FYColor.background)
        .navigationTitle("Benachrichtigungen")
        .navigationBarBackButtonHidden(store.notificationSettings.isSaving)
        .interactiveDismissDisabled(store.notificationSettings.isSaving)
        .task(id: store.notificationSettings.userID) { await store.notificationSettings.refresh() }
    }
}

private struct NotificationPreferenceFields: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotificationPreferences
    @State private var baseline: NotificationPreferences

    init(initial: NotificationPreferences) {
        _draft = State(initialValue: initial); _baseline = State(initialValue: initial)
    }

    private var canEdit: Bool {
        store.notificationSettings.isConfirmed && !store.notificationSettings.isBusy && store.notificationSettings.value == baseline
    }

    var body: some View {
        Group {
            Section {
                Toggle("Freund ist jetzt LIVE", isOn: $draft.friendStarts)
                Toggle("FYR UP", isOn: $draft.fyrup)
                Toggle("Session-Einladungen", isOn: $draft.invitations)
                Toggle("Reaktionen", isOn: $draft.reactions)
                Toggle("Freundschaftsanfragen", isOn: $draft.friendRequests)
            } footer: {
                Text("Meldungen zu LIVE-Starts sind standardmäßig aus, damit deine Crew nicht zu viele Pushs bekommt.")
            }
            Section("Ziele und Erinnerungen") {
                Toggle("Erinnerungen", isOn: $draft.reminders)
                Toggle("Wochenziel", isOn: $draft.weeklyGoal)
                Toggle("Crew-Ziel", isOn: $draft.crewGoal)
            }
        }.disabled(!canEdit)
        if store.notificationSettings.isConfirmed, let latest = store.notificationSettings.value, latest != baseline {
            Section {
                Text("Es gibt einen neueren gespeicherten Stand. Deine bisherigen Eingaben wurden nicht gesendet.").font(.caption)
                Button("Aktuellen Stand übernehmen") { baseline = latest; draft = latest }
                    .disabled(store.notificationSettings.isBusy)
            }
        }
        Section {
            Button(store.notificationSettings.isSaving ? "Wird gespeichert …" : "Einstellungen speichern") {
                Task {
                    if await store.saveNotificationPreferences(draft, expected: baseline) { dismiss() }
                }
            }.frame(maxWidth: .infinity).fontWeight(.bold)
                .disabled(!canEdit || draft == baseline)
                .accessibilityIdentifier("save-notification-preferences")
        }
    }
}
