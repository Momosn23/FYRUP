import SwiftUI

enum FYColor {
    // The approved editorial direction uses a nearly white, warm canvas. Green is
    // reserved for meaning (selection, progress, LIVE and success), not atmosphere.
    static let background = Color(red: 0.988, green: 0.990, blue: 0.987)
    static let surface = Color.white
    static let elevated = Color(red: 0.958, green: 0.962, blue: 0.960)
    static let line = Color(red: 0.875, green: 0.890, blue: 0.885)
    static let ink = Color(red: 0.025, green: 0.030, blue: 0.035)
    static let lime = Color(red: 0.024, green: 0.780, blue: 0.333)
    static let limeSoft = Color(red: 0.895, green: 0.990, blue: 0.930)
    static let cyan = Color(red: 0.08, green: 0.58, blue: 0.92)
    static let coral = Color(red: 1.0, green: 0.31, blue: 0.20)
    static let violet = Color(red: 0.58, green: 0.32, blue: 0.90)
    static let muted = Color(red: 0.39, green: 0.43, blue: 0.47)
    static let planned = Color(red: 1.0, green: 0.65, blue: 0.06)
    static let live = lime
    static let nutrition = Color(red: 1, green: 0.533, blue: 0.220)
}

enum FYLayout {
    static let page: CGFloat = 20
    static let card: CGFloat = 16
    static let gap: CGFloat = 12
    static let section: CGFloat = 24
    static let radius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let primaryHeight: CGFloat = 52
}

struct FYCardModifier: ViewModifier {
    var padding: CGFloat = FYLayout.card
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FYColor.surface, in: RoundedRectangle(cornerRadius: FYLayout.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FYLayout.radius, style: .continuous).stroke(FYColor.line, lineWidth: 0.7))
            .shadow(color: FYColor.ink.opacity(0.018), radius: 5, y: 2)
    }
}

extension View {
    func fyCard(padding: CGFloat = FYLayout.card) -> some View { modifier(FYCardModifier(padding: padding)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: FYLayout.primaryHeight)
            .background(FYColor.ink.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(FYColor.ink.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FYColor.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FYColor.line))
    }
}

struct FYRUPWordmark: View {
    var size: CGFloat = 30
    var color: Color = FYColor.ink

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "flame.fill").foregroundStyle(FYColor.lime)
            Text("FYRUP").tracking(1.2).foregroundStyle(color)
        }
        .font(.system(size: size, weight: .bold))
        .accessibilityElement(children: .combine)
    }
}

extension SportKind {
    var accentColor: Color {
        switch self {
        case .gym: FYColor.ink
        case .running, .cycling: FYColor.lime
        case .football: FYColor.ink
        case .basketball: .orange
        case .martialArts: FYColor.ink
        case .racket, .yoga: FYColor.violet
        case .swimming: FYColor.cyan
        case .other: FYColor.ink
        }
    }
}
