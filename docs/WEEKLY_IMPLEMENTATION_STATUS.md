# Wochenziel, Flames und gespeichertes Onboarding

Stand05.09.2026, in Arbeit. Noch keine neue signierte TestFlight-Auslieferung.

## Implementiert

- Bewusste Zielbestätigung3–7 im Onboarding; bestehende gültige Ziele werden übernommen. Änderungen in beide Richtungen gelten erst nächste Woche.
- Server-autoritatives Wochenbuch: eine abgeschlossene Aktivität, maximal ein Credit; eine Woche, maximal eine Flamme. Schritte, Planung, LIVE und Abbruch geben keine Credits.
- V1-Missbrauchsgrenze: mindestens60 aktive Sekunden. Kürzere abgeschlossene Workouts bleiben gespeichert, geben aber keinen Wochen-Credit. Diese technische Grenze ist keine Trainingsempfehlung.
- Fixierte lokale Wochenperioden, UTC-Zeitstempel, Sommer-/Winterzeit und verzögerter Zeitzonenwechsel. Reisewochen können einmalig kürzer/länger sein, ohne doppelte oder fehlende Zeiträume.
- Sofortige Flamme; Streak und Bestwert nur aus finalisierten Wochen, einschließlich ausgelassener Wochen.
- Freunde nur akzeptiert/nicht blockiert; ausstehende Ziel-/Zeitzonenänderungen bleiben privat. Fortschritt, Flame und Reaktionen aus bestätigten Serverantworten.
- Helle Karten auf Heute/Profil/Freundesprofil, Wochenhistorie, Zielauswahl, dezent animierte Fortschritte und einmaliger Erfolgsdialog mit Reduce-Motion-Unterstützung.
- Atomarer serverseitiger Präsentationsanspruch + lokaler Beleg gegen wiederholte Animationen. Bei Prozessabbruch genau zwischen Anspruch und Anzeige kann die Anzeige ausfallen; eine garantierte exakt-einmal sichtbare Animation ist nicht behauptet.
- Gym-Auswahl und Onboarding-Schritt werden gespeichert. Alte Profile werden durch Migration006 nicht erneut ins Onboarding geschickt. Neue Nutzer können ohne bestätigtes Wochenziel nicht abschließen.
- Eigene Erfolgsmitteilung und Flame-Reaktionen mit abschaltbaren bestehenden Mitteilungskategorien. Optionale Freund-erreicht-Ziel-/Wochenstart-/Fast-erreicht-Pushes noch nicht zusätzlich aktiviert.

## Tatsächlich geprüft

- `run_weekly_tests.mjs`:183 Wochenprüfungen plus82 Trainingsplan-,23 Pausen- und100 Schritteprüfungen =388 gemeinsam bestanden.
- `run_onboarding_tests.mjs`:50 PostgreSQL-/pgTAP-Prüfungen bestanden, inkl. Eigentümergrenzen, Bestätigungspflicht, flacher Gym-Auswahl, Legacy-Migration und Wiederherstellung.
- Das sind lokale PostgreSQL-WASM-Prüfungen, keine produktiven Supabase-/PostgREST- oder physischen Parallelverbindungstests.

## Noch offen

- Neue Weekly-Unit-/UI-Tests geschrieben; nach Integration nativ ausführen und neue Einzelbilder prüfen.
- Migrationen produktiv anwenden, reale Zweikonten- und Mitteilungsprüfung.
- Neues HealthKit-Signing, signierter Build und echte iPhone-/TestFlight-Abnahme.
- Call My Shot und Blind Workout sind separate folgende Blöcke. Die Wochenimplementierung allein erfüllt sie nicht.

Build22 vor Weekly-Integration:117 native Unit-Tests bestanden.19 UI-Tests ausgeführt,15 bestanden,4 fehlgeschlagen (Gym-Grid-Erreichbarkeit, Schritte-Freigabe und zwei Trainings-Bedienungen). Diese Fehler werden separat korrigiert und erneut geprüft.
