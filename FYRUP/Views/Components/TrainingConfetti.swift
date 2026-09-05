import SwiftUI

/// A short, decorative celebration triggered only by a successful completion event.
struct TrainingConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: UUID?
    @State private var began: Date?
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: began == nil || reduceMotion)) { context in
            Canvas { canvas, size in
                guard let began, !reduceMotion else { return }
                let elapsed = context.date.timeIntervalSince(began)
                guard elapsed >= 0, elapsed < 3.4 else { return }
                let colors: [Color] = [FYColor.lime, FYColor.cyan, FYColor.planned, FYColor.violet, FYColor.coral]
                for index in 0..<42 {
                    let seed = Double(index)
                    let speed = 170 + Double(index % 7) * 22
                    let x = size.width * Double((index * 37) % 101) / 100 + sin(elapsed * 2 + seed) * 22
                    let y = -40 - Double(index % 6) * 32 + elapsed * speed
                    let opacity = min(1, max(0, (3.4 - elapsed) / 0.7))
                    var piece = canvas
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .degrees(seed * 19 + elapsed * 125))
                    piece.fill(Path(roundedRect: CGRect(x: -3, y: -6, width: 6, height: 12), cornerRadius: 1), with: .color(colors[index % colors.count].opacity(opacity)))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
            .task(id: trigger) {
                guard trigger != nil, !reduceMotion else { began = nil; return }
                began = .now
                do { try await Task.sleep(for: .milliseconds(3400)) } catch { began = nil; return }
                began = nil
            }
            .onChange(of: reduceMotion) { _, enabled in if enabled { began = nil } }
    }
}
