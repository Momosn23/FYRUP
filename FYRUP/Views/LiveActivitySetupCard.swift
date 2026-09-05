import SwiftUI
import UIKit

struct LiveActivitySetupCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.title).foregroundStyle(FYColor.lime)
                VStack(alignment: .leading) { Text("Deine Session bleibt sichtbar").font(.headline); Text("Sperrbildschirm & Dynamic Island").font(.caption).foregroundStyle(FYColor.muted) }
            }
            Text("Wenn du eine Session startest, zeigt dein iPhone Sportart, aktive Zeit und deine Satzpause an. Die Anzeige lässt sich öffnen und wird beim Abschluss entfernt.").font(.subheadline).foregroundStyle(FYColor.muted)
            Toggle("LIVE automatisch anzeigen", isOn: Binding(get: { store.setup.value?.liveActivityEnabled == true }, set: { enabled in
                if store.setup.update({ $0.liveActivityEnabled = enabled }) { store.synchronizeLiveSurface() }
            })).disabled(store.setup.value == nil).accessibilityIdentifier("setup-live-activity")
            Text("Auf dem Sperrbildschirm können auch andere diese Angaben sehen. Körperdaten, Kalorien, Freunde und Satzgewichte werden dort nicht angezeigt.").font(.caption).foregroundStyle(FYColor.muted)
            Text(store.liveSurface.systemEnabled ? "Das iPhone erlaubt Live-Aktivitäten. Die erste beginnt erst mit deiner nächsten LIVE-Session." : "Live-Aktivitäten sind in den iPhone-Einstellungen ausgeschaltet.").font(.caption).foregroundStyle(FYColor.muted)
            if !store.liveSurface.systemEnabled {
                Button("iPhone-Einstellungen öffnen") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.font(.subheadline.bold()).frame(minHeight: 44)
            }
            if let error = store.liveSurface.errorMessage {
                Text(error).font(.caption).foregroundStyle(FYColor.coral)
                Button("Live-Anzeige erneut versuchen") { store.synchronizeLiveSurface(retry: true) }.frame(minHeight: 44)
            }
            Text("Eine Live-Aktivität ist keine normale Push-Mitteilung. Apple entscheidet über Verfügbarkeit und Anzeigedauer; du kannst sie jederzeit wegwischen oder ausschalten.").font(.caption).foregroundStyle(FYColor.muted)
        }.fyCard().onAppear { store.synchronizeLiveSurface() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { store.synchronizeLiveSurface() } }
    }
}
