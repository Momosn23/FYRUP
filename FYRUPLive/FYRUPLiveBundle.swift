import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FYRUPLiveBundle: WidgetBundle {
    var body: some Widget { FYRUPLiveWidget() }
}

struct FYRUPLiveWidget: Widget {
    private let green = Color(red: 0.055, green: 0.79, blue: 0.355)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionLiveAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("FYRUP · \(context.state.pausedSeconds == nil ? "LIVE" : "PAUSIERT")", systemImage: "flame.fill").font(.caption.bold()).foregroundStyle(green)
                    Spacer()
                    Text(context.state.sport).font(.subheadline.bold())
                }
                HStack {
                    sessionTime(context.state).font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                    Spacer()
                    if let end = context.state.restEndsAt, let start = context.state.restStartedAt {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Satzpause").font(.caption)
                            Text(timerInterval: start...end, countsDown: true).font(.title3.bold()).monospacedDigit().frame(width: 80)
                        }.foregroundStyle(green)
                    }
                }
                HStack {
                    Link(destination: SessionLiveLink.url(sessionID: context.attributes.sessionID)) {
                        Label("ÖFFNEN", systemImage: "arrow.up.right").font(.caption.bold()).padding(.horizontal, 16).padding(.vertical, 9)
                            .background(green.opacity(0.14), in: Capsule())
                    }
                    Spacer()
                    if context.state.isGym {
                        Link(destination: SessionLiveLink.url(sessionID: context.attributes.sessionID, opensRest: true)) {
                            Label("Satzpause öffnen", systemImage: "timer").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }.padding(18).foregroundStyle(.white).activityBackgroundTint(Color(red: 0.04, green: 0.07, blue: 0.06))
                .activitySystemActionForegroundColor(green)
                .widgetURL(SessionLiveLink.url(sessionID: context.attributes.sessionID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label(context.state.sport, systemImage: context.state.symbol).font(.headline).foregroundStyle(green) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.pausedSeconds == nil ? "LIVE" : "PAUSE").font(.caption.bold()).foregroundStyle(green) }
                DynamicIslandExpandedRegion(.center) { sessionTime(context.state).font(.title.bold()).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Deine Session läuft in FYRUP").font(.caption)
                        Spacer()
                        if let end = context.state.restEndsAt, let start = context.state.restStartedAt {
                            Image(systemName: "timer").foregroundStyle(green)
                            Text(timerInterval: start...end, countsDown: true).font(.caption.bold()).monospacedDigit().frame(width: 65)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.symbol).foregroundStyle(green)
            } compactTrailing: {
                sessionTime(context.state).monospacedDigit().font(.caption2.bold()).frame(width: 66)
            } minimal: {
                Image(systemName: context.state.pausedSeconds == nil ? "flame.fill" : "pause.fill").foregroundStyle(green)
            }.widgetURL(SessionLiveLink.url(sessionID: context.attributes.sessionID)).keylineTint(green)
        }
    }
    @ViewBuilder private func sessionTime(_ state: SessionLiveAttributes.ContentState) -> some View {
        if let paused = state.pausedSeconds {
            Text(String(format: "%02d:%02d:%02d", paused / 3600, paused / 60 % 60, paused % 60)).accessibilityLabel("Aktive Zeit, pausiert")
        } else {
            Text(timerInterval: state.timerReference...state.timerReference.addingTimeInterval(604800), countsDown: false).accessibilityLabel("Aktive Zeit")
        }
    }
}
