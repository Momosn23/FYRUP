import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct FYRUPLiveBundle: WidgetBundle {
    var body: some Widget {
        FYRUPLiveWidget()
        FYRUPHomeWidget()
    }
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
                        Button(intent: ToggleFYRUPRestIntent(activityID: context.attributes.sessionID, ownerID: context.attributes.ownerID)) {
                            Label(context.state.restEndsAt.map { $0 > Date() } == true ? "Satzpause beenden" : "Satzpause", systemImage: "timer").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                                .background(.white.opacity(0.1), in: Capsule())
                        }.buttonStyle(.plain)
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

private struct FYRUPHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: FYRUPWidgetSnapshot?
}

private struct FYRUPHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> FYRUPHomeEntry { FYRUPHomeEntry(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (FYRUPHomeEntry) -> Void) {
        completion(FYRUPHomeEntry(date: .now, snapshot: FYRUPWidgetState.snapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FYRUPHomeEntry>) -> Void) {
        let entry = FYRUPHomeEntry(date: .now, snapshot: FYRUPWidgetState.snapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
    }
}

private struct FYRUPHomeWidgetView: View {
    let entry: FYRUPHomeEntry
    private let green = Color(red: 0.055, green: 0.79, blue: 0.355)

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "flame.fill").foregroundStyle(green); Text("FYRUP · LIVE").font(.caption.bold()); Spacer() }
                Text(snapshot.state.sport).font(.headline).lineLimit(1)
                if let rest = snapshot.activeRest {
                    Text(timerInterval: rest.startedAt...rest.endsAt, countsDown: true)
                        .font(.title2.bold()).monospacedDigit().foregroundStyle(green)
                } else if let paused = snapshot.state.pausedSeconds {
                    Text(String(format: "%02d:%02d:%02d", paused / 3600, paused / 60 % 60, paused % 60)).font(.title3.bold()).monospacedDigit()
                } else {
                    Text(timerInterval: snapshot.state.timerReference...snapshot.state.timerReference.addingTimeInterval(604800), countsDown: false)
                        .font(.title3.bold()).monospacedDigit()
                }
                if snapshot.state.isGym {
                    Button(intent: ToggleFYRUPRestIntent(activityID: snapshot.sessionID, ownerID: snapshot.ownerID)) {
                        Label(snapshot.activeRest == nil ? "Satzpause" : "Beenden", systemImage: snapshot.activeRest == nil ? "timer" : "stop.fill")
                            .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.plain).foregroundStyle(.white).background(green, in: Capsule())
                } else {
                    Link("ÖFFNEN", destination: SessionLiveLink.url(sessionID: snapshot.sessionID)).font(.caption.bold()).foregroundStyle(green)
                }
            }
            .containerBackground(Color(red: 0.04, green: 0.07, blue: 0.06), for: .widget)
            .foregroundStyle(.white)
            .widgetURL(SessionLiveLink.url(sessionID: snapshot.sessionID))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "flame.fill").font(.title).foregroundStyle(green)
                Text("Bereit für deine nächste Aktivität?").font(.headline)
                Text("Starte in FYRUP – der LIVE-Timer erscheint hier.").font(.caption).foregroundStyle(.secondary)
            }.containerBackground(Color.white, for: .widget)
        }
    }
}

struct FYRUPHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FYRUPHomeWidget", provider: FYRUPHomeProvider()) { entry in FYRUPHomeWidgetView(entry: entry) }
            .configurationDisplayName("FYRUP LIVE")
            .description("Aktive Zeit und Satzpause direkt auf deinem Homescreen.")
            .supportedFamilies([.systemSmall])
    }
}
