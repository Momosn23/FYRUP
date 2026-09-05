import SwiftUI

/// Original vector artwork. Every coloured patch uses the same MuscleGroup as its
/// labelled alternative; small patches deliberately never expand over neighbouring muscles.
struct MuscleBodyPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: Set<MuscleGroup>
    var available = Set(MuscleGroup.allCases)
    var identifierPrefix = "muscle"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dein Fokus").font(.title3.bold()).foregroundStyle(FYColor.ink)
                    Text("Tippe auf die Figur oder wähle unten. Mehrere Muskeln sind möglich.")
                        .font(.caption).foregroundStyle(FYColor.muted)
                }
                Spacer(minLength: 8)
                if !selection.isEmpty {
                    Button("Zurücksetzen") { update([]) }.font(.caption.bold())
                        .frame(minHeight: 44).accessibilityIdentifier("\(identifierPrefix)-clear")
                }
            }

            HStack(alignment: .top, spacing: 12) {
                diagram(.front)
                diagram(.back)
            }
            .padding(.horizontal, 12).padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Color.white, FYColor.limeSoft.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(FYColor.line))

            Text(selection.isEmpty ? "Noch kein Muskelfokus gewählt" : "\(selection.count) ausgewählt · \(MuscleSelection.ordered(selection).map(\.title).joined(separator: ", "))")
                .font(.caption.weight(.medium)).foregroundStyle(FYColor.ink)
                .accessibilityIdentifier("\(identifierPrefix)-selection-summary")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(MuscleSelection.Preset.allCases) { preset in
                    let groups = preset.groups.intersection(available)
                    Button { update(selection == groups ? [] : groups) } label: {
                        Text(preset.title).font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selection == groups ? FYColor.lime : FYColor.ink)
                            .background(selection == groups ? FYColor.limeSoft : FYColor.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection == groups ? FYColor.lime : FYColor.line))
                    }.buttonStyle(.plain).accessibilityAddTraits(selection == groups ? .isSelected : [])
                        .accessibilityIdentifier("\(identifierPrefix)-preset-\(preset.rawValue)")
                        .disabled(groups.isEmpty)
                }
            }

            // Full-width labels remain reachable with VoiceOver and at accessibility sizes.
            muscleGrid(columns: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
            if available.contains(.fullBody) || available.contains(.other) {
                Text("Ganzkörper und Sonstiges sind Übungskategorien ohne einzelnen Muskelbereich.")
                    .font(.caption2).foregroundStyle(FYColor.muted)
            }
        }.tint(FYColor.lime)
    }

    private func diagram(_ side: MuscleBodySide) -> some View {
        VStack(spacing: 8) {
            MuscleBodyDiagram(side: side, selection: selection, available: available, identifierPrefix: identifierPrefix) { group in
                var next = selection
                next.formSymmetricDifference([group])
                update(next)
            }
            .aspectRatio(100.0 / 260.0, contentMode: .fit)
            Text(side.title).font(.caption2.weight(.semibold)).foregroundStyle(FYColor.muted)
        }.frame(maxWidth: .infinity)
    }

    private func muscleGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 8) {
            ForEach(MuscleSelection.ordered(available)) { group in
                Button {
                    var next = selection
                    next.formSymmetricDifference([group])
                    update(next)
                } label: {
                    HStack(spacing: 8) {
                        Text(group.title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: selection.contains(group) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(group) ? FYColor.lime : FYColor.muted.opacity(0.55))
                    }.padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(FYColor.ink)
                        .background(selection.contains(group) ? FYColor.limeSoft : FYColor.surface, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(selection.contains(group) ? FYColor.lime : FYColor.line))
                }.buttonStyle(.plain).accessibilityLabel(group.title)
                    .accessibilityAddTraits(selection.contains(group) ? .isSelected : [])
                    .accessibilityIdentifier("\(identifierPrefix)-list-\(group.rawValue)")
            }
        }
    }

    private func update(_ groups: Set<MuscleGroup>) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { selection = groups.intersection(available) }
    }
}

enum MuscleBodySide: String { case front, back
    var title: String { self == .front ? "Vorderseite" : "Rückseite" }
}

private struct MuscleBodyDiagram: View {
    let side: MuscleBodySide
    let selection: Set<MuscleGroup>
    let available: Set<MuscleGroup>
    let identifierPrefix: String
    let onSelect: (MuscleGroup) -> Void

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 100
            ZStack(alignment: .topLeading) {
                BodyOutline().fill(LinearGradient(colors: [Color(red: 0.8, green: 0.85, blue: 0.85), Color(red: 0.62, green: 0.7, blue: 0.71)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(BodyOutline().stroke(Color.white.opacity(0.9), lineWidth: 1))
                    .allowsHitTesting(false).accessibilityHidden(true)
                Ellipse().fill(Color(red: 0.72, green: 0.79, blue: 0.79))
                    .frame(width: 23 * scale, height: 29 * scale).offset(x: 38.5 * scale, y: 4 * scale)
                    .allowsHitTesting(false).accessibilityHidden(true)
                ForEach(Array(BodyPatch.patches(side).enumerated()), id: \.offset) { index, patch in
                    let rect = patch.bounds
                    let isSelected = selection.contains(patch.muscle)
                    Button { onSelect(patch.muscle) } label: {
                        BodyPatchShape(patch: patch)
                            .fill(LinearGradient(colors: isSelected ? [FYColor.lime, Color(red: 0.02, green: 0.55, blue: 0.34)] : [Color.white.opacity(0.48), Color.white.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(BodyPatchShape(patch: patch).stroke(isSelected ? Color.white.opacity(0.95) : Color(red: 0.52, green: 0.63, blue: 0.65).opacity(0.65), lineWidth: 0.8))
                            .shadow(color: isSelected ? FYColor.lime.opacity(0.35) : .clear, radius: 5)
                            .contentShape(BodyPatchShape(patch: patch))
                    }
                    .buttonStyle(.plain)
                    .frame(width: rect.width * scale, height: rect.height * scale)
                    .offset(x: rect.minX * scale, y: rect.minY * scale)
                    .disabled(!available.contains(patch.muscle))
                    .accessibilityLabel("\(patch.muscle.title), \(side.title)")
                    .accessibilityHint("Auswahl ändern. Alternativ die beschriftete Liste unter der Figur verwenden.")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("\(identifierPrefix)-body-\(side.rawValue)-\(patch.muscle.rawValue)-\(index)")
                }
            }
        }
    }
}

private struct BodyOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 43, y: 29))
        p.addConnectedLines([CGPoint(x: 42, y: 38), CGPoint(x: 29, y: 43)])
        p.addQuadCurve(to: CGPoint(x: 21, y: 52), control: CGPoint(x: 23, y: 44))
        p.addConnectedLines([CGPoint(x: 15, y: 74), CGPoint(x: 12, y: 94), CGPoint(x: 5, y: 117), CGPoint(x: 3, y: 132), CGPoint(x: 7, y: 139), CGPoint(x: 11, y: 135), CGPoint(x: 11, y: 126), CGPoint(x: 17, y: 110), CGPoint(x: 25, y: 90), CGPoint(x: 28, y: 71), CGPoint(x: 32, y: 92), CGPoint(x: 33, y: 112), CGPoint(x: 27, y: 135)])
        p.addQuadCurve(to: CGPoint(x: 27, y: 156), control: CGPoint(x: 24, y: 144))
        p.addConnectedLines([CGPoint(x: 29, y: 182), CGPoint(x: 30, y: 196), CGPoint(x: 29, y: 213), CGPoint(x: 33, y: 238), CGPoint(x: 28, y: 247)])
        p.addQuadCurve(to: CGPoint(x: 41, y: 253), control: CGPoint(x: 27, y: 254))
        p.addConnectedLines([CGPoint(x: 44, y: 249), CGPoint(x: 41, y: 236), CGPoint(x: 44, y: 213), CGPoint(x: 42, y: 193), CGPoint(x: 45, y: 176), CGPoint(x: 49, y: 147), CGPoint(x: 51, y: 147), CGPoint(x: 55, y: 176), CGPoint(x: 58, y: 193), CGPoint(x: 56, y: 213), CGPoint(x: 59, y: 236), CGPoint(x: 56, y: 249)])
        p.addQuadCurve(to: CGPoint(x: 72, y: 247), control: CGPoint(x: 71, y: 258))
        p.addConnectedLines([CGPoint(x: 67, y: 238), CGPoint(x: 71, y: 213), CGPoint(x: 70, y: 196), CGPoint(x: 71, y: 182), CGPoint(x: 73, y: 156)])
        p.addQuadCurve(to: CGPoint(x: 73, y: 135), control: CGPoint(x: 76, y: 144))
        p.addConnectedLines([CGPoint(x: 67, y: 112), CGPoint(x: 68, y: 92), CGPoint(x: 72, y: 71), CGPoint(x: 75, y: 90), CGPoint(x: 83, y: 110), CGPoint(x: 89, y: 126), CGPoint(x: 89, y: 135), CGPoint(x: 93, y: 139), CGPoint(x: 97, y: 132), CGPoint(x: 95, y: 117), CGPoint(x: 88, y: 94), CGPoint(x: 85, y: 74), CGPoint(x: 79, y: 52)])
        p.addQuadCurve(to: CGPoint(x: 71, y: 43), control: CGPoint(x: 77, y: 44))
        p.addConnectedLines([CGPoint(x: 58, y: 38), CGPoint(x: 57, y: 29)])
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 260)).applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}

private extension Path {
    mutating func addConnectedLines(_ points: [CGPoint]) {
        for point in points { addLine(to: point) }
    }
}

struct BodyPatch {
    let muscle: MuscleGroup
    let points: [CGPoint]
    init(_ muscle: MuscleGroup, _ points: [(Double, Double)]) {
        self.muscle = muscle
        self.points = points.map { CGPoint(x: $0.0, y: $0.1) }
    }
    var bounds: CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    var mirrored: BodyPatch {
        BodyPatch(muscle, points.map { (Double(100 - $0.x), Double($0.y)) })
    }
    static func pair(_ muscle: MuscleGroup, _ points: [(Double, Double)]) -> [BodyPatch] {
        let left = BodyPatch(muscle, points)
        return [left, left.mirrored]
    }
    static func patches(_ side: MuscleBodySide) -> [BodyPatch] {
        var parts = pair(.shoulders, [(29,45),(36,44),(31,51),(28,63),(21,64),(22,53),(25,48)])
        parts += pair(.forearms, [(15,96),(23,94),(20,105),(12,124),(7,122),(10,108)])
        if side == .front {
            parts += pair(.chest, [(34,48),(48,47),(49,67),(40,70),(30,65),(30,56)])
            parts += pair(.biceps, [(21,66),(27,65),(26,80),(22,92),(16,91),(17,77)])
            parts += pair(.core, [(35,75),(40,76),(38,101),(43,118),(36,115),(33,96)])
            for y in [74.0, 86.0, 98.0] {
                parts += pair(.core, [(41,y),(49,y),(49,y+10),(40,y+9)])
            }
            parts += pair(.core, [(40,110),(49,111),(49,125),(44,130),(39,120)])
            parts += pair(.quads, [(30,130),(38,130),(44,146),(42,165),(38,184),(32,182),(29,162),(28,145)])
            parts += pair(.adductors, [(40,133),(48,138),(45,160),(42,168),(43,147)])
            parts += pair(.calves, [(32,198),(40,198),(42,215),(38,234),(34,229),(31,214)])
        } else {
            parts += pair(.traps, [(43,36),(49,38),(49,70),(41,60),(32,49),(38,44)])
            parts += pair(.back, [(31,55),(39,64),(49,74),(49,104),(42,112),(35,95),(31,78)])
            parts += pair(.triceps, [(21,66),(27,65),(27,78),(23,92),(17,91),(17,78)])
            parts += pair(.core, [(43,108),(49,105),(49,126),(37,124),(35,116)])
            parts += pair(.glutes, [(35,126),(48,128),(49,144),(43,151),(30,149),(29,140),(31,132)])
            parts += pair(.hamstrings, [(29,153),(42,154),(45,159),(40,187),(32,185),(29,171)])
            parts += pair(.calves, [(32,197),(40,196),(42,208),(40,221),(36,233),(32,219),(30,208)])
        }
        return parts
    }
}

private struct BodyPatchShape: Shape {
    let patch: BodyPatch
    func path(in rect: CGRect) -> Path {
        let bounds = patch.bounds
        let points = patch.points.map { CGPoint(x: ($0.x - bounds.minX) / bounds.width * rect.width + rect.minX, y: ($0.y - bounds.minY) / bounds.height * rect.height + rect.minY) }
        var p = Path()
        // Softened polygon corners give crisp, scalable anatomical zones without a bitmap.
        guard let first = points.first, let last = points.last else { return p }
        p.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
        for index in points.indices {
            let next = points[(index + 1) % points.count]
            p.addQuadCurve(to: CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2), control: points[index])
        }
        p.closeSubpath()
        return p
    }
}
