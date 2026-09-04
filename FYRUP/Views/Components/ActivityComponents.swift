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
        HStack { Image(systemName: activity.sport.symbol).foregroundStyle(FYColor.lime); Text(activity.sport.title).bold(); if let subtype = activity.subtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
    }
}

struct AvatarView: View {
    let profile: Profile
    var body: some View {
        ZStack { Circle().fill(FYColor.elevated); Text(profile.displayName.prefix(1).uppercased()).font(.headline.bold()).foregroundStyle(FYColor.lime) }
            .frame(width: 48, height: 48).accessibilityLabel("Profilbild von \(profile.displayName)")
    }
}
