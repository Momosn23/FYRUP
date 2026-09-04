import SwiftUI

struct TrainingGroupEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var memberIDs = Set<UUID>()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        Image("SportGymHero").resizable().scaledToFill().frame(height: 154).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "person.3.fill").font(.title2).foregroundStyle(FYColor.lime)
                            Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Deine Crew" : name).font(.title2.weight(.black))
                            Text("Private Trainingsgruppe").font(.caption).foregroundStyle(FYColor.muted)
                        }.padding(16)
                    }.frame(height: 154).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(FYColor.line))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("GRUPPENNAME").groupSectionTitle()
                        TextField("z. B. Gym Crew", text: $name).textInputAutocapitalization(.words).padding(14).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("group-name")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("FREUNDE AUSWÄHLEN").groupSectionTitle()
                        Text(memberIDs.isEmpty ? "Mindestens eine Person auswählen" : "\(memberIDs.count) Freunde ausgewählt").font(.caption).foregroundStyle(FYColor.muted)
                        ForEach(store.crew) { member in
                            Button { memberIDs.formSymmetricDifference([member.id]) } label: {
                                HStack(spacing: 12) {
                                    AvatarView(profile: member.profile)
                                    VStack(alignment: .leading, spacing: 2) { Text(member.profile.displayName).font(.subheadline.bold()); Text("@\(member.profile.username)").font(.caption).foregroundStyle(FYColor.muted) }
                                    Spacer()
                                    Image(systemName: memberIDs.contains(member.id) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(memberIDs.contains(member.id) ? FYColor.lime : FYColor.muted)
                                }.padding(12).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(memberIDs.contains(member.id) ? FYColor.lime.opacity(0.45) : FYColor.line))
                            }.buttonStyle(.plain).foregroundStyle(.white).accessibilityLabel(member.profile.displayName)
                        }
                    }
                }.padding(20)
            }
            .background(FYColor.background)
            .navigationTitle("Neue Trainingsgruppe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button("GRUPPE ERSTELLEN") {
                    Task {
                        await store.createTrainingGroup(name: name, memberIDs: Array(memberIDs))
                        if store.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || memberIDs.isEmpty || store.isBusy)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || memberIDs.isEmpty ? 0.45 : 1)
                .accessibilityIdentifier("create-group")
                .padding(.horizontal, 20).padding(.vertical, 12).background(.ultraThinMaterial)
            }
        }.preferredColorScheme(.dark)
    }
}

struct TrainingGroupCard: View {
    let group: TrainingGroup
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "person.3.fill").foregroundStyle(FYColor.lime); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(FYColor.muted) }
            Text(group.name).font(.headline).lineLimit(1)
            HStack(spacing: -8) {
                ForEach(Array(group.members.prefix(4))) { profile in AvatarView(profile: profile).scaleEffect(0.72).frame(width: 35, height: 35) }
                if group.members.count > 4 { Text("+\(group.members.count - 4)").font(.caption2.bold()).frame(width: 34, height: 34).background(FYColor.elevated, in: Circle()) }
                Spacer()
                Text("\(group.members.count)").font(.caption.bold()).foregroundStyle(FYColor.muted)
            }
        }.padding(14).frame(width: 180, height: 128).background(LinearGradient(colors: [FYColor.surface, FYColor.elevated], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(FYColor.line))
    }
}

struct TrainingGroupDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let group: TrainingGroup
    @State private var confirmsDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SportHeroCard(sport: .gym, title: group.name, subtitle: "\(group.members.count) Mitglieder")
                Text("MITGLIEDER").groupSectionTitle()
                ForEach(group.members) { profile in
                    HStack(spacing: 12) { AvatarView(profile: profile); VStack(alignment: .leading) { Text(profile.displayName).bold(); Text("@\(profile.username)").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); Image(systemName: "checkmark.circle.fill").foregroundStyle(FYColor.lime) }.fyCard()
                }
                if group.ownerID == store.profile?.id {
                    Button("Gruppe löschen", role: .destructive) { confirmsDelete = true }.frame(maxWidth: .infinity).padding(.top, 12)
                }
            }.padding(20)
        }
        .background(FYColor.background)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Trainingsgruppe löschen?", isPresented: $confirmsDelete) {
            Button("Gruppe löschen", role: .destructive) { Task { await store.deleteTrainingGroup(group); dismiss() } }
            Button("Behalten", role: .cancel) {}
        }
    }
}

private extension Text {
    func groupSectionTitle() -> some View { self.font(.caption.weight(.black)).foregroundStyle(FYColor.muted).tracking(0.6) }
}
