import SwiftUI

enum FYColor {
    static let background = Color(red: 0.975, green: 0.982, blue: 0.982)
    static let surface = Color.white
    static let elevated = Color(red: 0.940, green: 0.952, blue: 0.956)
    static let line = Color(red: 0.855, green: 0.878, blue: 0.886)
    static let ink = Color(red: 0.035, green: 0.050, blue: 0.065)
    static let lime = Color(red: 0.055, green: 0.790, blue: 0.355)
    static let limeSoft = Color(red: 0.895, green: 0.990, blue: 0.930)
    static let cyan = Color(red: 0.08, green: 0.58, blue: 0.92)
    static let coral = Color(red: 1.0, green: 0.31, blue: 0.20)
    static let violet = Color(red: 0.58, green: 0.32, blue: 0.90)
    static let muted = Color(red: 0.39, green: 0.43, blue: 0.47)
    static let planned = Color(red: 1.0, green: 0.65, blue: 0.06)
    static let live = lime
}

struct FYCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(FYColor.line, lineWidth: 0.8))
            .shadow(color: FYColor.ink.opacity(0.045), radius: 10, y: 4)
            .fyEntrance()
    }
}

extension View {
    func fyCard() -> some View { modifier(FYCardModifier()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(FYColor.lime.opacity(configuration.isPressed ? 0.76 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: FYColor.lime.opacity(0.20), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(FYColor.ink.opacity(configuration.isPressed ? 0.76 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy, value: configuration.isPressed)
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
            Text("FYRUP").italic().foregroundStyle(color)
        }
        .font(.system(size: size, weight: .black, design: .rounded))
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
