import SwiftUI

enum FYColor {
    static let background = Color(red: 0.018, green: 0.020, blue: 0.024)
    static let surface = Color(red: 0.070, green: 0.075, blue: 0.085)
    static let elevated = Color(red: 0.105, green: 0.112, blue: 0.124)
    static let line = Color.white.opacity(0.09)
    static let lime = Color(red: 0.20, green: 0.92, blue: 0.49)
    static let cyan = Color(red: 0.16, green: 0.72, blue: 0.98)
    static let coral = Color(red: 1.0, green: 0.27, blue: 0.25)
    static let violet = Color(red: 0.70, green: 0.40, blue: 1.0)
    static let muted = Color.white.opacity(0.57)
    static let planned = Color(red: 1.0, green: 0.75, blue: 0.13)
    static let live = Color(red: 0.18, green: 0.93, blue: 0.48)
}

struct FYCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(FYColor.line))
    }
}

extension View {
    func fyCard() -> some View { modifier(FYCardModifier()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(FYColor.elevated.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FYColor.line))
    }
}

struct FYRUPWordmark: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "flame.fill")
            Text("FYRUP").italic()
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

extension SportKind {
    var accentColor: Color {
        switch self {
        case .gym: FYColor.cyan
        case .running, .cycling: FYColor.lime
        case .football, .basketball, .martialArts: FYColor.coral
        case .racket, .yoga: FYColor.violet
        case .swimming: .cyan
        case .other: .white
        }
    }
}
