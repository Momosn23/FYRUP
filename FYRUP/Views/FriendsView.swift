import SwiftUI

struct FriendsView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("FREUNDE").font(.largeTitle.weight(.black))
                TextField("Username suchen", text: $query).textInputAutocapitalization(.never).padding(14).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)).onSubmit { Task { await store.searchUsers(query) } }
                if !store.userSearchResults.isEmpty { Text("ERGEBNISSE").sectionTitle(); ForEach(store.userSearchResults) { profile in PersonRow(profile: profile) { Button("HINZUFÜGEN") { Task { await store.sendFriendRequest(to: profile) } }.font(.caption.bold()).foregroundStyle(FYColor.lime) } } }
                if !store.friendRequests.isEmpty { Text("ANFRAGEN").sectionTitle(); ForEach(store.friendRequests) { profile in PersonRow(profile: profile) { HStack { Button("Annehmen") { Task { await store.answerRequest(from: profile, accept: true) } }; Button("Ablehnen") { Task { await store.answerRequest(from: profile, accept: false) } }.foregroundStyle(FYColor.muted) }.font(.caption.bold()) } } }
                Text("DEINE FREUNDE").sectionTitle()
                if store.crew.isEmpty { ContentUnavailableView("Deine Crew ist noch leer", systemImage: "person.2") }
                ForEach(store.crew) { member in NavigationLink { FriendProfileView(member: member) } label: { PersonRow(profile: member.profile) { VStack(alignment: .trailing) { StatusBadge(status: member.todayStatus); Text("\(member.weeklyCount) diese Woche").font(.caption).foregroundStyle(FYColor.muted) } } }.buttonStyle(.plain) }
            }.padding(20)
        }.background(FYColor.background).navigationBarHidden(true)
    }
}

private struct PersonRow<Trailing: View>: View {
    let profile: Profile; @ViewBuilder let trailing: () -> Trailing
    var body: some View { HStack { AvatarView(profile: profile); VStack(alignment: .leading) { Text(profile.displayName).bold(); Text("@\(profile.username)").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); trailing() }.fyCard() }
}

struct FriendProfileView: View {
    @Environment(AppStore.self) private var store
    let member: CrewMember
    @State private var confirmRemove = false
    var body: some View {
        ScrollView { VStack(spacing: 18) { AvatarView(profile: member.profile).scaleEffect(1.7).padding(22); Text(member.profile.displayName.uppercased()).font(.largeTitle.weight(.black)); Text("@\(member.profile.username)").foregroundStyle(FYColor.muted); HStack { Label("\(member.weeklyCount) / \(member.profile.weeklyGoal)", systemImage: "target"); Spacer(); Label("Wochenziel", systemImage: "flame.fill") }.fyCard(); if let activity = member.activity { ActivityLabel(activity: activity).fyCard() }; Menu("Freundschaft verwalten") { Button("Freund entfernen", role: .destructive) { confirmRemove = true }; Button("Blockieren", role: .destructive) { Task { await store.block(member.profile) } } }.foregroundStyle(FYColor.muted) }.padding(20) }.background(FYColor.background).confirmationDialog("Freund entfernen?", isPresented: $confirmRemove) { Button("Entfernen", role: .destructive) { Task { await store.removeFriend(member.profile) } } }
    }
}

private extension Text { func sectionTitle() -> some View { self.font(.caption.weight(.black)).foregroundStyle(FYColor.muted).padding(.top, 10) } }
