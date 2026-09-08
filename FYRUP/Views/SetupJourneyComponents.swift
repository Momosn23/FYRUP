import SwiftUI

struct SetupWeeklyChoices: View {
    @Binding var selection: Int?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
            ForEach(WeeklyGoal.options, id: \.self) { goal in
                Button { selection = goal } label: {
                    VStack(spacing: 4) {
                        Text("\(goal)").font(.title2.bold())
                        Text("Einheiten").font(.footnote)
                        Image(systemName: selection == goal ? "checkmark.circle.fill" : "circle").foregroundStyle(selection == goal ? FYColor.lime : FYColor.line)
                    }.frame(maxWidth: .infinity, minHeight: 92).padding(8)
                        .background(selection == goal ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection == goal ? FYColor.lime : FYColor.line))
                }.buttonStyle(FYPressStyle()).foregroundStyle(FYColor.ink).accessibilityIdentifier("weekly-goal-\(goal)")
                    .accessibilityLabel("\(goal) Einheiten pro Woche").accessibilityAddTraits(selection == goal ? .isSelected : [])
            }
        }
    }
}

struct SetupDayChoices: View {
    let selection: Set<SetupWeekday>
    let choose: (SetupWeekday) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 12) {
            ForEach(SetupWeekday.allCases, id: \.self) { day in
                Button { choose(day) } label: {
                    VStack(spacing: 6) {
                        Text(day.shortTitle).font(.body.weight(.medium))
                        Image(systemName: selection.contains(day) ? "checkmark.circle.fill" : "circle").font(.footnote)
                    }.frame(maxWidth: .infinity, minHeight: 64).padding(8)
                        .foregroundStyle(selection.contains(day) ? FYColor.lime : FYColor.ink)
                        .background(selection.contains(day) ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(FYPressStyle()).accessibilityLabel(day.title).accessibilityAddTraits(selection.contains(day) ? .isSelected : [])
                    .accessibilityIdentifier("setup-day-\(day.rawValue)")
            }
        }
    }
}

struct SetupFriendSearchView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FYInputField(title: "Benutzername", placeholder: "Deine Freunde suchen", text: $query, identifier: "setup-friend-query")
                    .textInputAutocapitalization(.never).submitLabel(.search).onSubmit { Task { await store.searchUsers(query) } }
                Button("Suchen") { Task { await store.searchUsers(query) } }.buttonStyle(OutlineButtonStyle()).disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || store.isBusy)
                ForEach(store.userSearchResults) { profile in
                    HStack {
                        AvatarView(profile: profile)
                        VStack(alignment: .leading) { Text(profile.displayName).font(.headline); Text("@\(profile.username)").font(.footnote).foregroundStyle(FYColor.muted) }
                        Spacer()
                        Button { Task { await store.sendFriendRequest(to: profile) } } label: { Image(systemName: "person.badge.plus").frame(width: 44, height: 44) }
                            .accessibilityLabel("\(profile.displayName) eine Anfrage senden").disabled(store.isBusy)
                    }.fyCard()
                }
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationTitle("Freunde suchen").navigationBarTitleDisplayMode(.inline)
            .onDisappear { store.clearUserSearch() }
    }
}
