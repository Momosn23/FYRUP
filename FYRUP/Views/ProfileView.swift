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
                HStack { Text("Profil").font(.title2.weight(.bold)); Spacer(); Image(systemName: "gearshape").font(.title3) }
                if let profile = store.profile {
                    HStack(spacing: 16) {
                        AvatarView(profile: profile).scaleEffect(1.45).padding(14)
                        VStack(alignment: .leading, spacing: 3) { Text(profile.displayName).font(.title3.bold()); Text("@\(profile.username)").font(.subheadline).foregroundStyle(FYColor.muted) }
                        Spacer()
                    }
                    HStack { Metric(value: "\(store.crew.count)", label: "Freunde"); Metric(value: "\(store.goals.monthCount)", label: "Workouts"); Metric(value: "\(store.goals.streak)", label: "Wochenstreak") }
                    Text("„Disziplin ist die Brücke zwischen Zielen und Ergebnissen.“").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.82)).fyCard()
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Meine Statistiken").font(.headline)
                        HStack { Text("Woche").foregroundStyle(.black).padding(.horizontal, 22).padding(.vertical, 7).background(.white, in: Capsule()); Spacer(); Text("Monat").foregroundStyle(FYColor.muted); Spacer(); Text("Jahr").foregroundStyle(FYColor.muted) }.font(.caption.bold())
                        HStack { Text("Workouts"); Spacer(); Text("\(store.goals.weeklyCount) / \(profile.weeklyGoal)").bold() }
                        HStack { Text("Aktive Wochen"); Spacer(); Text("\(store.goals.streak)").bold() }
                    }.fyCard()
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
