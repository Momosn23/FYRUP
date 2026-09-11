# Editorial-UI – nativer Prüfstand vom 11.09.2026

## Geprüfter Umfang

- Der vollständige redaktionelle Quellblock ab `0fc34e3` wurde auf Codemagic mit Xcode 26.6 und einem iPhone-16-Simulator kompiliert.
- Der breite Lauf 74 auf `42496f0` prüfte die vorhandene Unit-Suite, die Referenzansichten und den gezielten LIVE-Workout-Ablauf. Der App-Bau und alle gemeldeten Prüfungen bis auf die editierbare Einrichtungszusammenfassung bestanden.
- Die zuvor abgeschnittene Großschrift-Darstellung im Profil bestand im Folgelauf.
- Für die Zusammenfassung wurden die Darstellung in eine eigene, ruhige Seite und der Bedientest auf korrektes Scrollen in einer verzögert aufgebauten SwiftUI-Liste umgestellt (`283c2f7`, `0ee227a`, `309617f`).
- Lokale Abschlussprüfungen: Terminologie 137 App-Textdateien bestanden; Übungskatalog 122 Einträge und 127 Muskelzuordnungen bestanden; Backend-Suiten bestanden; Prüfskript syntaktisch gültig; `git diff --check` ohne Befund.

## Noch nicht behauptet

- Der abschließende einzelne Simulator-Folgetest für `309617f` konnte noch nicht gestartet werden, weil Codemagic beim Laden der Branches und Builds mit „Failed to fetch builds“ abbrach. Es wurde kein alter Stand ersatzweise gestartet.
- Eine echte visuelle iPhone-/TestFlight-Abnahme der neuen Editorial-UI ist **NICHT AUSGEFÜHRT**.
- Wetter, HealthKit, Dynamic Island/Live Activity, Kontakte, Push und reale Netzwechsel sind auf einem echten Gerät weiterhin **NICHT AUSGEFÜHRT**.
- Pixelidentität zu generierten Boards wird nicht behauptet. Die Boards sind die freigegebene visuelle Richtung; native iOS-Darstellung, echte Daten, Barrierefreiheit und sichere Zustände haben Vorrang.

## Kostenregel

Der temporäre Push-Auslöser wurde wieder entfernt und der gezielte QA-Modus zurückgesetzt. Es gibt keinen automatischen Folgelauf. Sobald Codemagic wieder synchronisiert, wird zuerst nur der einzelne offene Simulator-Folgetest ausgeführt. Erst wenn er grün ist, wird genau ein signierter TestFlight-Paketlauf ohne erneute Vollsuite gestartet.
