import SwiftUI

struct StatusBadge: View {
    let status: TodayStatus
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 8, height: 8); Text(title).font(.caption.weight(.black)) }
            .foregroundStyle(color).accessibilityLabel(title)
    }
    private var title: String { switch status { case .live: "LIVE"; case .planned: "PLANNED"; case .done: "DONE"; case .notYet: "NOT YET" } }
    private var color: Color { switch status { case .live: FYColor.live; case .planned: FYColor.planned; case .done: FYColor.lime; case .notYet: FYColor.muted } }
}

struct ActivityLabel: View {
    let activity: Activity
    var body: some View {
        HStack { Image(systemName: activity.sport.symbol).foregroundStyle(activity.sport.accentColor); Text(activity.sport.title).bold(); if let subtype = activity.subtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
    }
}

struct AvatarView: View {
    let profile: Profile
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [FYColor.elevated, FYColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(profile.displayName.prefix(1).uppercased()).font(.headline.bold()).foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .overlay(Circle().stroke(Color.white.opacity(0.18)))
        .accessibilityLabel("Profilbild von \(profile.displayName)")
    }
}
