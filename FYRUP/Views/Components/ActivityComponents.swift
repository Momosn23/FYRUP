import SwiftUI
import UIKit

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
        HStack { Image(systemName: activity.sport.symbol).foregroundStyle(activity.sport.accentColor); Text(activity.sport.title).bold(); if let subtype = activity.displaySubtype { Text("· \(subtype)").foregroundStyle(FYColor.muted) } }
    }
}

struct AvatarView: View {
    @Environment(AppStore.self) private var store
    let profile: Profile
    var size: CGFloat = 48
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [FYColor.elevated, FYColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(profile.displayName.prefix(1).uppercased()).font(.headline.bold()).foregroundStyle(FYColor.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(FYColor.line))
        .accessibilityLabel("Profilbild von \(profile.displayName)")
        .task(id: profile.avatarPath) {
            guard let path = profile.avatarPath else { image = nil; return }
            image = await store.avatarImage(path: path)
        }
    }
}
