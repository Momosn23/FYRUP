# Editorial-UI – nativer Prüfstand vom 11./12.09.2026

## Geprüfter Umfang

- Der vollständige Editorial-Quellblock ab `0fc34e3` wurde auf Codemagic mit Xcode 26.6 und einem iPhone-16-Simulator kompiliert.
- Frühere fokussierte Läufe isolierten vier Navigations- und Sichtbarkeitslücken. Freunde-Details, geplante Sessions und die editierbare Einrichtungszusammenfassung wurden anschließend grün bestätigt.
- Der private Workout-Rückblick bleibt nun direkt in der Abschlussseite, klappt animiert auf und unterscheidet die drei sicht- und vorlesbaren Bewertungen zuverlässig.
- Der finale Lauf 91 auf `d053dad` prüfte ohne automatische Wiederholung den vollständigen Workout-Weg bis zur gespeicherten Bewertung sowie separat deren private Wiederherstellung nach einem Neustart. Ergebnis: `PASS` auf iPhone 16 mit iOS 26.5; Laufzeit des Testskripts 6,38 Minuten.
- Lokale Abschlussprüfungen: Terminologie 137 App-Textdateien bestanden; QA-Auswahl- und Referenztests bestanden; Prüfskript syntaktisch gültig; `git diff --check` ohne Befund.

## Noch nicht behauptet

- Eine echte visuelle iPhone-/TestFlight-Abnahme der neuen Editorial-UI ist **NICHT AUSGEFÜHRT**.
- Wetter, HealthKit, Dynamic Island/Live Activity, Kontakte, Push und reale Netzwechsel sind auf einem echten Gerät weiterhin **NICHT AUSGEFÜHRT**.
- Pixelidentität zu generierten Boards wird nicht behauptet. Die Boards sind die freigegebene visuelle Richtung; native iOS-Darstellung, echte Daten, Barrierefreiheit und sichere Zustände haben Vorrang.

## Kostenregel

Der gezielte QA-Modus ist zurückgesetzt; es gibt keinen automatischen Folgelauf. Nach dem grünen Simulator-Nachweis wird genau ein signierter TestFlight-Build ohne erneute Vollsuite gestartet.
