# Trainingsplan-Baustein – Arbeitsnachweis

Stand 05.09.2026, vor erster Cloud-Abnahme dieses Bausteins. Zugehörige Anforderungen: [Produkt-Checkliste](PRODUCT_CHECKLIST.md), insbesondere PLAN/LIB/CUSTOM/SHARE/TRACK/DATA/SEC. Offene Haken bleiben offen bis zur vollständigen Abnahme.

## Im Code angeschlossen

- Helle Planauswahl, Planeditor, Übungssuche/Muskelfilter/Favoriten/eigene Übungen, Inline-Erstellen, Duplikathinweis, Vorgaben, Reihenfolge, Privat-/Freunde-Sichtbarkeit.
- Live- und Demo-Repository, gespeicherte Pläne/Custom-Übungen, gezieltes Teilen, unabhängige Kopien und archivierte statt gelöschte Historie.
- Planen mit Freunden/Gruppen, Vorschau vor Einladungsantwort, planbasiertes Mittrainieren, getrennte private Protokolle.
- Einfach-/Tracken-Ansicht, optionale tatsächliche Satzwerte, Übungsabschluss, gespeicherte Ergebnis-/Verlaufsansicht.
- Echte serverseitige Pause/Fortsetzen mit Pausensumme, auch bei Abschluss/Abbruch. Zielgewicht ist keine tatsächliche Messung.
- Neue Datenzugriffe nach Logout/Kontowechsel geschützt; alte Antworten dürfen neue Speicherungen/Fehler nicht überschreiben.
- Lokale, kontogetrennte ungespeicherte Planentwürfe werden unter Meine Pläne fortgesetzt; explizites Verwerfen/Logout entfernt sie. Beschädigte Daten werden vor Überschreiben gesichert. Zusätzliche Neustart- und Regressionstests geschrieben.

## Tatsächlich ausgeführt

1. `node scripts/validate-exercise-catalog.mjs`: PASS, 122 eindeutige Übungen, alle 127 Muskel-/Namenszuordnungen aus dem Originalauftrag und unveränderliche IDs.
2. `node supabase/tests/run_workout_tests.mjs`: PASS, relevante Bestandsmigrationen plus neue Migrationen 001/002/004 in temporärem PostgreSQL/PGlite. Vollständige App-/DB-Katalogmetadaten identisch. 82 Plan-/Kopier-/Protokoll-/RLS-Tests und 23 Pausen-Tests bestanden.
3. `git diff --check`: keine Whitespace-Fehler; Git weist auf bestehende Windows-Zeilenenden hin.

Die lokale PostgreSQL-Prüfung arbeitet mit minimalen Supabase-Auth-Fixtures, nicht mit einem gehosteten Auth-/PostgREST-Dienst. Sie belegt weder parallele reale Datenbanksitzungen noch Push oder iPhone-Funktion.

## Noch auszuführen / zu ergänzen

- Neue native Modell-, Repository-, State- und Eingabetests: **NICHT AUSGEFÜHRT**, bis ein echter Xcode-Lauf bestätigt ist.
- Neue UI-Flows (Plan-Neustart, Inline-Custom, Einfach/Tracken/Pause) und sämtliche Bestands-UI-Flows im Cloud-Simulator.
- Screenshots/Animationen manuell prüfen, lange Texte, Dynamic Type, VoiceOver, kleine Displays und Fehlerzustände.
- Produktive Migrationen/REST/RLS, echte Zwei-Konten-Endabnahme und Push-Zustellung.
- Signierter TestFlight-Upload/Installation dieses Bausteins; bestehende TestFlight-Builds enthalten diese neuen Änderungen nicht.
- Native Neustart-Abnahme der ungespeicherten Planeditor-Entwürfe.
- Die weiteren Auftragspakete HealthKit, neue Wochenflammen, Blind Workout und Call My Shot sind von diesem Baustein nicht als fertig abgedeckt.

Cloud-Zwischenstand: Build 19 fand den Swift-Parserkonflikt `set.id` (durch `self.set.id` behoben); Build 20 fand einen Actor-/Autoclosure-Konflikt in DemoRepository (Crew-Prüfung vorab ausgewertet). Beide Builds haben die Featuretests **nicht ausgeführt**; nächster Lauf erforderlich.

## Lokal reproduzieren

Benötigt Node.js; temporäre Testabhängigkeiten werden nicht in die App aufgenommen:

```sh
npm install --prefix .qa/workout-db --ignore-scripts --no-audit --no-fund @electric-sql/pglite@0.5.8 @electric-sql/pglite-pgtap@0.0.9
node scripts/validate-exercise-catalog.mjs
node supabase/tests/run_workout_tests.mjs
```

XcodeGen kopiert beide TSV-Katalogdateien ausdrücklich in die jeweils benötigten App-/Test-Bundles. Referenz: [XcodeGen Sources / buildPhase](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#sources).
