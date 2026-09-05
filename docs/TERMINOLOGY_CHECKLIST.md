# Sprachüberarbeitung – Umsetzung und Abnahme

Neuer kumulativer Auftrag vom 05.09.2026. Dauerhafte Regeln: [TERMINOLOGY.md](TERMINOLOGY.md). Noch in Bearbeitung; nicht als neuer TestFlight-Stand ausgegeben.

- [x] TERM-01 Nutzerauftrag vollständig lesen und die neue Sprachlogik dauerhaft für zukünftige Arbeit im Projekt verankern (`AGENTS.md`, `TERMINOLOGY.md`).
- [ ] TERM-02 Allgemeine Aktivitäten, gemeinsame/geplante Sessions, Wochenziel-Einheiten und Gym-Workouts je Kontext unterscheiden.
- [ ] TERM-03 Heute, eigener Status, Plus-Flow, Öffnen/Start/Abschluss und soziale Aktionen prüfen.
- [ ] TERM-04 Gym-Auswahl und Workout-Plan-Bibliothek/-Editor/-Teilen/-Kopieren/-Historie vollständig überarbeiten.
- [ ] TERM-05 Onboarding, Wochenrhythmus und Wochenziel auf neue Sprache abstimmen.
- [ ] TERM-06 Wochenfortschritt, Flammenabschluss und Call My Shot konsequent mit Einheiten beschriften.
- [ ] TERM-07 Profil, Freundesprofil, Crews und Einladungen sprachlich prüfen.
- [ ] TERM-08 LIVE-Ablauf, Pause, Abbruch, Abschluss und privater Rückblick prüfen.
- [ ] TERM-09 Fehlermeldungen, leere Listen, Ladezustände, Einstellungen und VoiceOver berücksichtigen.
- [ ] TERM-10 Blind Workout, Call My Shot und Markenbegriffe erhalten; Schrittzahlen/-ziel nicht mit Wochenziel vermischen.
- [ ] TERM-11 Alle deutschen Localization-Strings inklusive früherer Schlüssel prüfen.
- [ ] TERM-12 Push-Texte einschließlich bereits wartender eigener Vorlagen prüfen; Nutzertexte nicht umschreiben.
- [ ] TERM-13 Persistierte Katalogwerte, Models, APIs und angewendete Migrationen stabil halten; alte Anzeigevorlagen sicher darstellen.
- [ ] TERM-14 Resttreffer projektweit prüfen und technische/historische/fachliche Ausnahmen dokumentieren.
- [ ] TERM-15 Vollständigen nativen Build sowie verfügbare Datenbank-, Logik- und UI-Tests ausführen und Ergebnisse festhalten.
- [ ] TERM-16 Tatsächliche Bildschirmaufnahmen aller betroffenen Seiten kontrollieren; keine abgeschnittenen neuen Labels.
- [ ] TERM-17 Neue Version signieren, Apple-Upload prüfen und TestFlight-Zuordnung verifizieren.
- [ ] TERM-18 Kurze Abschlussübersicht der Ersetzungen, bewussten Ausnahmen, geänderten Dateien und Testergebnisse liefern.

## Aktueller Zwischenstand

Kontextbezogene sichtbare Texte, VoiceOver, Fehler, deutsche Localization und UI-Test-Erwartungen überarbeitet. Technische Bezeichner und Datenfelder unangetastet. App-Inbox und Push verwenden dieselben16 geprüften Beispielvorlagen; inzwischen57 Node-Prüfungen bestehen. Alle drei nativen Terminologietests bestehen in Build30 und31. Die laufende Quelltextprüfung (`scripts/audit-terminology.mjs`) prüft81 App-Textdateien und besteht. Beide CI-Workflows führen sie mit aus.

Bewusste Resttreffer: neun Apple-Symbolnamen, sieben persistierte Katalogwerte, zwanzig Eingaben des getesteten Anzeige-Adapters, zwei alte Localization-Schlüssel mit neuen Ausgabewerten, neun stabile API-/Accessibility-IDs und ein reiner Katalogvergleich. Technische Typen/Testnamen und bereits angewendete SQL-Migrationen bleiben historische bzw. stabile Schnittstellen. Nutzertexte werden nicht verändert. Gespeicherte Benachrichtigungsvorlagen werden zur Anzeige modernisiert, nicht massenweise in Nutzerdaten umgeschrieben. Der geänderte Push-Adapter wurde zusammen mit den privaten Erinnerungen produktiv bereitgestellt; frische Laufzeitkontrolle folgt.

Build30 (`dc9d543`, `6a9be930fac9a246bed9474a`) enthält die Sprachüberarbeitung. Alle drei Terminologie-Einzeltests bestehen. Gesamtresultat: **379 Einzeltests mit einem Fehler, 26 UI-Abläufe mit einem Fehler**. In der Supplement-Demo rundete die Sommerzeitauflösung 02:30 auf 03:00; im Arbeitsstand durch `Calendar.nextDate` mit minutenerhaltender Auflösung korrigiert. Ein UI-Test prüfte irrtümlich die gleichlautende Entdecken-Überschrift hinter dem Dialog; er prüft nun die gezielt identifizierte Dialogüberschrift. Die anschließende native Wiederholung und neue Bildschirmkontrolle bleiben offen. Keine TestFlight-Auslieferung behauptet.

Vorheriger Build29 (`073b933`) bestand 365 Einzeltests und 26 UI-Abläufe; **er enthält diese Sprachüberarbeitung nicht**. Der noch nicht gestartete TestFlight-Dialog wurde geschlossen, damit der nächste Upload die neuen Begriffe berücksichtigen kann.

Build31 (`7910f6c`, `6a9befa83cf4759eab7d62a6`) hat inzwischen alle382 Einzeltests ohne Fehler bestanden. Die Bildschirmtests laufen noch; kein vorweggenommener Gesamterfolg oder TestFlight-Nachweis.
