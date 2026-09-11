import SwiftUI

/// Finite entrance motion: no endless animations that delay interactions or
/// accessibility. Layout and hit areas stay unchanged. Reduce Motion is respected.
private struct FYEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0.65)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .onAppear {
                guard !appeared else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.42).delay(delay)) { appeared = true }
            }
    }
}

extension View {
    func fyEntrance(delay: Double = 0) -> some View { modifier(FYEntrance(delay: delay)) }
}

struct FYPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension SportKind {
    var editorialImage: String {
        switch self {
        case .gym: "SportGymHero"
        case .running: "SportRunningHero"
        case .football: "SportFootballHero"
        case .basketball: "SportBasketballHero"
        case .cycling: "SportOutdoorHero"
        case .swimming: "SportSwimmingHero"
        case .martialArts: "SportCombatHero"
        case .racket: "SportRacketHero"
        case .yoga: "SportYogaHero"
        case .other: "SportOutdoorHero"
        }
    }
}

/// Images are clipped to their own container; they cannot change a card's width
/// or leave an accidental seam across the screen.
struct SportPhoto: View {
    let sport: SportKind
    var body: some View {
        GeometryReader { geometry in
            Image(sport.editorialImage).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

extension GymExercise {
    var editorialImage: String {
        let value = name.lowercased()
        if value.contains("schrägbank") || value.contains("incline") { return "ExerciseInclinePress" }
        if value.contains("bankdrücken") || value.contains("bench press") { return "ExerciseBenchPress" }
        if value.contains("schulterdrücken") || value.contains("shoulder press") || value.contains("overhead press") { return "ExerciseShoulderPress" }
        if value.contains("kniebeuge") || value.contains("squat") { return "ExerciseSquat" }
        if value.contains("latzug") || value.contains("pulldown") { return "ExerciseLatPulldown" }
        if value.contains("rudern") || value.contains("row") { return "ExerciseRow" }
        return "SportGymHero"
    }
}

struct ExercisePhoto: View {
    let exercise: GymExercise
    var body: some View {
        GeometryReader { geometry in
            Image(exercise.editorialImage).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct LiveSessionVisual: View {
    let activity: Activity
    var title: String? = nil
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 18) {
            HStack {
                Label(activity.pausedAt == nil ? "LIVE · DEINE SESSION" : "SESSION PAUSIERT", systemImage: activity.pausedAt == nil ? "waveform.path" : "pause.fill")
                    .font(.caption.weight(.heavy))
                Spacer()
                Image(systemName: activity.sport.symbol).font(.title3)
            }.foregroundStyle(Color.white.opacity(0.95))
            Text(title ?? [activity.sport.title, activity.displaySubtype].compactMap { $0 }.joined(separator: " · "))
                .font(compact ? .title3.bold() : .title2.bold()).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            LiveActivityTimer(activity: activity)
                .font(.system(size: compact ? 32 : 46, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
            if !compact { Text("Aktive Zeit · Satzpausen bleiben Teil deiner Session").font(.caption).foregroundStyle(.white.opacity(0.86)) }
        }
        .padding(compact ? 20 : 24).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SportPhoto(sport: activity.sport)
                .overlay(LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.40)], startPoint: .leading, endPoint: .trailing))
                .overlay(alignment: .bottom) { Rectangle().fill(FYColor.lime).frame(height: 3) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: FYColor.ink.opacity(0.14), radius: 16, y: 7).fyEntrance()
    }
}
