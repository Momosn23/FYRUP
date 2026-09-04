import SwiftUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var showsDelete = false
    @State private var notificationsEnabled = false
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("PROFIL").font(.largeTitle.weight(.black)).frame(maxWidth: .infinity, alignment: .leading)
                if let profile = store.profile {
                    AvatarView(profile: profile).scaleEffect(1.7).padding(24)
                    Text(profile.displayName.uppercased()).font(.title.weight(.black))
                    Text("@\(profile.username)").foregroundStyle(FYColor.muted)
                    Text("🔥 \(store.goals.streak) Wochen Streak").font(.headline)
                    HStack { Metric(value: "\(store.goals.weeklyCount) / \(profile.weeklyGoal)", label: "Diese Woche"); Metric(value: "\(store.goals.monthCount)", label: "Diesen Monat"); Metric(value: "\(store.crew.count)", label: "Freunde") }.fyCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Sportarten", systemImage: "figure.run").bold()
                        Text(profile.sports.map(\.title).joined(separator: " · ")).foregroundStyle(FYColor.muted)
                        Stepper("Wochenziel: \(profile.weeklyGoal)", value: weeklyGoalBinding, in: 1...7)
                    }.fyCard()
                }
                VStack(spacing: 0) {
                    Toggle(isOn: $notificationsEnabled) { Label("Mitteilungen", systemImage: "bell") }.padding().onChange(of: notificationsEnabled) { _, enabled in if enabled { Task { let center = UNUserNotificationCenter.current(); if try await center.requestAuthorization(options: [.alert, .badge, .sound]) { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } } } } }
                    Divider(); NavigationLink { PrivacyView() } label: { SettingsRow(title: "Datenschutz", symbol: "hand.raised") }
                    Divider(); Button { Task { await store.logout() } } label: { SettingsRow(title: "Abmelden", symbol: "rectangle.portrait.and.arrow.right") }
                    Divider(); Button(role: .destructive) { showsDelete = true } label: { SettingsRow(title: "Account löschen", symbol: "trash") }
                }.background(FYColor.surface, in: RoundedRectangle(cornerRadius: 22))
            }.padding(20)
        }.background(FYColor.background).navigationBarHidden(true).task { let settings = await UNUserNotificationCenter.current().notificationSettings(); notificationsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional }.confirmationDialog("Account dauerhaft löschen?", isPresented: $showsDelete, titleVisibility: .visible) { Button("Account löschen", role: .destructive) { Task { await store.deleteAccount() } }; Button("Abbrechen", role: .cancel) {} } message: { Text("Deine personenbezogenen Daten und Verknüpfungen werden entfernt. Diese Aktion kann nicht rückgängig gemacht werden.") }
    }
    private var weeklyGoalBinding: Binding<Int> { Binding(get: { store.profile?.weeklyGoal ?? 4 }, set: { value in guard var profile = store.profile else { return }; profile.weeklyGoal = value; Task { try? await store.repository.saveProfile(profile); await MainActor.run { store.profile = profile } } }) }
}

private struct Metric: View { let value: String; let label: String; var body: some View { VStack { Text(value).font(.title2.bold()); Text(label).font(.caption).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity) } }
private struct SettingsRow: View { let title: String; let symbol: String; var body: some View { HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "chevron.right").foregroundStyle(FYColor.muted) }.foregroundStyle(.white).padding() } }

private struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Form {
            Section("Wer sieht meine Aktivitäten?") {
                Picker("Sichtbarkeit", selection: visibilityBinding) { Text("Freunde").tag("friends"); Text("Niemand").tag("nobody") }.pickerStyle(.inline)
            }
            Section { Text("FYRUP zeigt in V1 weder Live-Standort noch GPS-Daten. Deine Aktivitäten sind niemals öffentlich.") }
        }.scrollContentBackground(.hidden).background(FYColor.background).navigationTitle("Datenschutz")
    }
    private var visibilityBinding: Binding<String> { Binding(get: { store.profile?.activityVisibility ?? "friends" }, set: { value in guard var profile = store.profile else { return }; profile.activityVisibility = value; Task { try? await store.repository.saveProfile(profile); await MainActor.run { store.profile = profile } } }) }
}
