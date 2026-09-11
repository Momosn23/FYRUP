import SwiftUI

struct FYSectionHeader: View {
    let title: String
    var body: some View { Text(title).font(.headline).foregroundStyle(FYColor.ink) }
}

struct FYInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var unit: String? = nil
    var identifier: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(FYColor.ink)
            HStack(spacing: 12) {
                TextField(placeholder, text: $text).font(.body).autocorrectionDisabled()
                    .accessibilityLabel(title + (unit.map { ", \($0)" } ?? ""))
                    .accessibilityIdentifier(identifier ?? title)
                if let unit { Text(unit).font(.subheadline).foregroundStyle(FYColor.muted) }
            }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: FYLayout.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: FYLayout.controlRadius).stroke(FYColor.line))
        }
    }
}

struct FYSelectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title2).frame(width: 30).foregroundStyle(FYColor.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(FYColor.ink).fixedSize(horizontal: false, vertical: true)
                    if !subtitle.isEmpty { Text(subtitle).font(.footnote).foregroundStyle(FYColor.muted).fixedSize(horizontal: false, vertical: true) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? FYColor.lime : FYColor.line)
            }.padding(12).frame(maxWidth: .infinity, minHeight: 64)
                .background(selected ? FYColor.limeSoft : .white, in: RoundedRectangle(cornerRadius: FYLayout.radius))
                .overlay(RoundedRectangle(cornerRadius: FYLayout.radius).stroke(selected ? FYColor.lime : FYColor.line))
        }.buttonStyle(FYPressStyle()).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct FYProgressRing: View {
    let progress: Double?
    let symbol: String
    var accent = FYColor.lime
    var diameter: CGFloat = 80
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(FYColor.line, lineWidth: 7)
            Circle().trim(from: 0, to: safeProgress)
                .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
            Image(systemName: symbol).font(.system(size: 28, weight: .medium)).foregroundStyle(accent)
        }.frame(width: diameter, height: diameter).padding(4).accessibilityHidden(true)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: safeProgress)
    }
    private var safeProgress: Double { guard let progress, progress.isFinite else { return 0 }; return min(1, max(0, progress)) }
}

struct FYSetupHeading: View {
    let title: String
    let subtitle: String
    let step: Int
    let total: Int
    var showsBack = true
    var showsProgress = true
    let back: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if showsBack {
                    Button(action: back) { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).frame(width: 44, height: 44) }
                        .accessibilityLabel("Zurück")
                } else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
                Spacer()
                if showsProgress {
                    ProgressView(value: Double(step), total: Double(max(1, total))).tint(FYColor.lime).frame(width: 120)
                        .accessibilityLabel("Persönliche Einrichtung, Schritt \(step) von \(total)")
                    Spacer()
                    Text("\(step)/\(total)").font(.caption).foregroundStyle(FYColor.muted)
                        .lineLimit(1).fixedSize().dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(minWidth: 44)
                }
            }
            FYRUPWordmark(size: 19)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title.weight(.black))
                if !subtitle.isEmpty { Text(subtitle).font(.body).foregroundStyle(FYColor.muted) }
            }
        }
    }
}
