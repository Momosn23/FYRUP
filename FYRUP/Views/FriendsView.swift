import SwiftUI

struct FriendsView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var showsGroupEditor = false
    @State private var segment = 0
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Freunde").font(.largeTitle.weight(.black))
                Picker("Freunde", selection: $segment) { Text("Meine Freunde").tag(0); Text("Anfragen (\(store.friendRequests.count))").tag(1) }.pickerStyle(.segmented)
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted); TextField("Freunde suchen …", text: $query).textInputAutocapitalization(.never).onSubmit { Task { await store.searchUsers(query) } } }
                    .padding(.horizontal, 14).frame(height: 46).background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 13))
                if !store.userSearchResults.isEmpty { Text("ERGEBNISSE").sectionTitle(); ForEach(store.userSearchResults) { profile in PersonRow(profile: profile) { Button("HINZUFÜGEN") { Task { await store.sendFriendRequest(to: profile) } }.font(.caption.bold()).foregroundStyle(FYColor.lime) } } }
                if segment == 1 {
                    if store.friendRequests.isEmpty { ContentUnavailableView("Keine offenen Anfragen", systemImage: "person.badge.clock") }
                    ForEach(store.friendRequests) { profile in PersonRow(profile: profile) { HStack { Button("Annehmen") { Task { await store.answerRequest(from: profile, accept: true) } }.foregroundStyle(FYColor.lime); Button("Ablehnen") { Task { await store.answerRequest(from: profile, accept: false) } }.foregroundStyle(FYColor.muted) }.font(.caption.bold()) } }
                }
                if segment == 0 {
                HStack { Text("TRAININGSGRUPPEN").sectionTitle(); Spacer(); Button { showsGroupEditor = true } label: { Label("Gruppe erstellen", systemImage: "plus.circle.fill").font(.caption.bold()) }.foregroundStyle(FYColor.lime).padding(.top, 10) }
                if store.trainingGroups.isEmpty {
                    Button { showsGroupEditor = true } label: { HStack(spacing: 12) { Image(systemName: "person.3.fill").font(.title2).foregroundStyle(FYColor.lime); VStack(alignment: .leading, spacing: 3) { Text("Deine erste Crew erstellen").bold(); Text("Freunde gemeinsam zu Trainings einladen").font(.caption).foregroundStyle(FYColor.muted) }; Spacer(); Image(systemName: "chevron.right") }.padding(15).background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(FYColor.line)) }.buttonStyle(.plain).foregroundStyle(FYColor.ink)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 11) { ForEach(store.trainingGroups) { group in NavigationLink { TrainingGroupDetailView(group: group) } label: { TrainingGroupCard(group: group) }.buttonStyle(.plain).foregroundStyle(FYColor.ink) } } }
                }
                Text("DEINE FREUNDE").sectionTitle()
                if store.crew.isEmpty { ContentUnavailableView("Deine Crew ist noch leer", systemImage: "person.2") }
                ForEach(store.crew) { member in NavigationLink { FriendProfileView(member: member) } label: { PersonRow(profile: member.profile) { VStack(alignment: .trailing) { StatusBadge(status: member.todayStatus); FriendWeeklyLine(userID: member.id) } } }.buttonStyle(.plain).accessibilityIdentifier("friend-\(member.profile.username)") }
                }
            }.padding(20)
        }.background(FYColor.background).navigationBarHidden(true).fullScreenCover(isPresented: $showsGroupEditor) { TrainingGroupEditorView() }
            .task { await store.weekly.refreshFriends() }
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
    @State private var recentActivities: [Activity] = []
    @State private var sharedPlans: [WorkoutPlan] = []
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AvatarView(profile: member.profile).scaleEffect(1.7).padding(22)
                Text(member.profile.displayName.uppercased()).font(.largeTitle.weight(.black))
                Text("@\(member.profile.username)").foregroundStyle(FYColor.muted)
                if let bio = member.profile.bio { Text(bio).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(FYColor.ink.opacity(0.8)) }
                FriendWeeklyCard(userID: member.id)
                FriendStepsLine(userID: member.id)
                VStack(alignment: .leading, spacing: 8) { Text("Sportarten").font(.headline); Text(member.profile.sports.map(\.title).joined(separator: " · ")).foregroundStyle(FYColor.muted) }.frame(maxWidth: .infinity, alignment: .leading).fyCard()
                WeekActivityStrip(activities: recentActivities + [member.activity].compactMap { $0 })
                if let activity = member.activity { NavigationLink { ActivityDetailView(activity: activity, owner: member.profile) } label: { ActivityLabel(activity: activity).fyCard() }.buttonStyle(.plain) }
                if !sharedPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Freigegebene Trainingspläne").font(.headline)
                        ForEach(sharedPlans) { plan in
                            NavigationLink { WorkoutPlanDetailView(planID: plan.id) } label: { WorkoutPlanCard(plan: plan) }.buttonStyle(.plain)
                        }
                    }
                }
                Menu("Freundschaft verwalten") { Button("Freund entfernen", role: .destructive) { confirmRemove = true }; Button("Blockieren", role: .destructive) { Task { await store.block(member.profile) } } }.foregroundStyle(FYColor.muted)
            }.padding(20)
        }
        .background(FYColor.background)
        .task {
            await store.steps.refresh()
            _ = await store.weekly.loadFriend(userID: member.id)
            recentActivities = (try? await store.repository.recentActivities(userID: member.id)) ?? []
            sharedPlans = await store.workouts.sharedPlans(ownerID: member.id) ?? []
        }
        .confirmationDialog("Freund entfernen?", isPresented: $confirmRemove) { Button("Entfernen", role: .destructive) { Task { await store.removeFriend(member.profile) } } }
    }
}

private extension Text { func sectionTitle() -> some View { self.font(.caption.weight(.black)).foregroundStyle(FYColor.muted).padding(.top, 10) } }
