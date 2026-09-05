# Wochenrhythmus, privates Trainingsfeedback und Abschlussanimation

Stand 05.09.2026. Native Kompilierung und alle Tests in Build28 erfolgreich; Migration012 produktiv eingerichtet und separat geprüft. Erste Originalbilder kontrolliert; zusätzliche Geräte-/Animationsabnahme noch offen. Kein TestFlight-Update dieses Funktionsblocks bestätigt.

## Integrierter Code

- Freiwilliger zusätzlicher Einrichtungsschritt nach bestätigtem Streak-Ziel. Fester oder flexibler Wochenrhythmus pro Sport, optionale Dauer, jederzeit im Profil editierbar.
- Wochenkarte oben auf Heute mit Montag–Sonntag und Tagesdetails. Abgeschlossen nur aus eigenen echten Aktivitäten; konkrete Termine und private Rhythmuswünsche unterscheidbar. Keine künstlichen Einladungen oder Streak-Credits.
- Optional Easy/Mittel/Hardcore je bereits zugänglicher Übung sowie privates Gesamtgefühl/Notiz nach Abschluss. In normalen und Blind-Workouts angeschlossen; Feedback nicht Bestandteil der Teilen-Zusammenfassung.
- Neue Models, Repository-Methoden, kontogebundener Store und rückwärtskompatible Demo-Speicherung. Revisionsprüfung verhindert stilles Überschreiben durch veraltete Entwürfe. Halteantworten werden nach Logout/Accountwechsel verworfen; Wochenzugriffe auch bei Freundschaftsentzug ungültig.
- Kurzes dekoratives Konfetti nur nach bestätigtem Abschlussereignis und einmaligem Streak-Erfolg. Reduzierte Bewegung wird berücksichtigt; freies Training scrollfähig, damit zusätzliche Rückblick-Aktion kleine Displays nicht überfüllt.

## Tatsächlich geprüft

Lokaler Wegwerf-PostgreSQL-Lauf `node supabase/tests/run_personal_training_tests.mjs`: **66 neue Prüfungen +770 frühere Regressionen bestanden (836 insgesamt)**. Keine Verbindung zu produktiven Konten, keine Testdaten in Supabase.

Geprüft: Werte/Typen/Grenzen, fixed/flexible Wochentage, Revisionen, fehlende Anmeldung, Tabellen-RLS und gesperrte direkte Mutationen, nur eigene Aktivitäten, Zeitintervallgrenzen, akzeptierte aktuelle Freundestermine, Entfernung bei Blockierung, keine Doppelanzeige erledigter Termine, private Abschlussbewertung, verborgene Blind-Übungen sowie fremde Bewertungen nicht zugänglich.

Cloud-Build28, Commit `f10d61a`: **360 native Unit-Tests und25/25 Bildschirmabläufe bestanden**, `TEST SUCCEEDED` um10:49 CEST. Darunter14 neue persönliche Trainingsprüfungen sowie UI-Speichern/Neustart des Wochenplans, optionale Bewertung und Abwahl der Anstrengung. Simulatornachweis, keine Behauptung eines echten iPhone-Tests.

Produktive Migration012: vorab11 Versionen und keine der beiden neuen Tabellen; danach12 Versionen, beide neuen Tabellen mit RLS, fünf RPCs nur für angemeldete Nutzer aufrufbar, direkte Schreibrechte auf beide Tabellen gesperrt. Profilanzahl unverändert0, Standardbibliothek unverändert122. Das eingefügte Paket wurde vor Run vollständig mit der getesteten lokalen Quelle verglichen.

Sechs Original-Simulatorbilder geprüft: [visueller Nachweis](VISUAL_QA_BUILD28.md). Wochenleiste steht oben, Speicher-/Bewertungsaktionen sind sichtbar und erreichbar. Neue Korrektur im Folgestand: gleiche Symbolhöhe in den Tagesfeldern und eindeutig „Deine Streak“ als zweite Kartenüberschrift.

## Offene Abnahme

- Screenshots, kleine Displays, Tastatur, leere/offline Zustände und tatsächliche Animationen prüfen.
- Signierte TestFlight-Auslieferung und echte iPhone-/Mehrkonto-Prüfung.
- Standort/Widget, Kontakte-Einladungen, Supplement-Erinnerungen, Kalorienschätzung/KI und interaktive Muskelgrafik sind neue getrennte Aufträge in der zentralen Checkliste, nicht durch diesen Funktionsblock umgesetzt.
