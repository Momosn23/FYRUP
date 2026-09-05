import SwiftUI

struct SharedProfileDestinationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let profile: Profile

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                AvatarView(profile: profile).scaleEffect(1.8).padding(28)
                Text(profile.displayName).font(.largeTitle.weight(.black)).multilineTextAlignment(.center)
                Text("@\(profile.username)").foregroundStyle(FYColor.muted)
                if let bio = profile.bio { Text(bio).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(FYColor.muted) }
                if profile.id == store.profile?.id {
                    Label("Das ist dein Profil", systemImage: "person.crop.circle.badge.checkmark").foregroundStyle(FYColor.lime)
                } else if store.crew.contains(where: { $0.id == profile.id }) {
                    Label("Ihr seid bereits Freunde", systemImage: "person.2.fill").foregroundStyle(FYColor.lime)
                } else {
                    Button("FREUNDSCHAFTSANFRAGE SENDEN") { Task { await store.sendFriendRequest(to: profile) } }
                        .buttonStyle(PrimaryButtonStyle()).disabled(store.isBusy)
                }
                Text("Ein Profillink zeigt keine privaten Aktivitäten, Körperdaten, Schritte oder Kontakte.").font(.caption).foregroundStyle(FYColor.muted).multilineTextAlignment(.center)
                Spacer()
            }.padding(24).background(FYColor.background)
                .navigationTitle("FYRUP Profil").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }.preferredColorScheme(.light)
    }
}
