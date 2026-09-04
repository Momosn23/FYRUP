import SwiftUI

enum FYColor {
    static let background = Color(red: 0.035, green: 0.04, blue: 0.045)
    static let surface = Color(red: 0.09, green: 0.10, blue: 0.11)
    static let elevated = Color(red: 0.13, green: 0.14, blue: 0.15)
    static let lime = Color(red: 0.72, green: 1.0, blue: 0.18)
    static let muted = Color.white.opacity(0.58)
    static let planned = Color.yellow
    static let live = Color.green
}

struct FYCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(FYColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06)))
    }
}

extension View {
    func fyCard() -> some View { modifier(FYCardModifier()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(FYColor.lime.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(FYColor.elevated.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

