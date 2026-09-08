import SwiftUI

struct SetupWeeklyChoices: View {
    @Binding var selection: Int?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
            ForEach(WeeklyGoal.options, id: \.self) { goal in
                Button { selection = goal } label: {
                    if typeSize.isAccessibilitySize {
                        goalLabel(goal).padding(12).frame(maxWidth: .infinity, minHeight: 92)
                            .background(selection == goal ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection == goal ? FYColor.lime : FYColor.line))
                    } else {
                        goalLabel(goal).padding(8).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .background(selection == goal ? FYColor.limeSoft : .white, in: Circle())
                            .overlay(Circle().stroke(selection == goal ? FYColor.lime : FYColor.line, lineWidth: selection == goal ? 2 : 1))
                    }
                }.buttonStyle(FYPressStyle()).foregroundStyle(FYColor.ink).accessibilityIdentifier("weekly-goal-\(goal)")
                    .accessibilityLabel("\(goal) Einheiten pro Woche").accessibilityAddTraits(selection == goal ? .isSelected : [])
            }
        }
    }
    private func goalLabel(_ goal: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(goal)").font(.title2.bold())
            Text("Einheiten").font(.footnote).fixedSize(horizontal: false, vertical: true)
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
                    Text(day.shortTitle).font(.body.weight(selection.contains(day) ? .bold : .medium))
                        .frame(width: typeSize.isAccessibilitySize ? nil : 56, height: typeSize.isAccessibilitySize ? nil : 56)
                        .padding(typeSize.isAccessibilitySize ? 12 : 0)
                        .frame(minWidth: 44, minHeight: 44)
                        .foregroundStyle(FYColor.ink)
                        .background(selection.contains(day) ? FYColor.limeSoft : .white, in: Capsule())
                        .overlay(Capsule().stroke(selection.contains(day) ? FYColor.lime : FYColor.line, lineWidth: selection.contains(day) ? 2 : 1))
                        .frame(maxWidth: .infinity)
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
