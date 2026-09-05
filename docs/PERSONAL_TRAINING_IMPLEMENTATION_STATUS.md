# Wochenrhythmus, privates Trainingsfeedback und Abschlussanimation

Stand 05.09.2026. Neue Implementierung vorbereitet; native Kompilierung/Tests, visuelle Abnahme und produktive Migration012 noch offen. Kein TestFlight-Update dieses Funktionsblocks bestätigt.

## Integrierter Code

- Freiwilliger zusätzlicher Einrichtungsschritt nach bestätigtem Streak-Ziel. Fester oder flexibler Wochenrhythmus pro Sport, optionale Dauer, jederzeit im Profil editierbar.
- Wochenkarte oben auf Heute mit Montag–Sonntag und Tagesdetails. Abgeschlossen nur aus eigenen echten Aktivitäten; konkrete Termine und private Rhythmuswünsche unterscheidbar. Keine künstlichen Einladungen oder Streak-Credits.
- Optional Easy/Mittel/Hardcore je bereits zugänglicher Übung sowie privates Gesamtgefühl/Notiz nach Abschluss. In normalen und Blind-Workouts angeschlossen; Feedback nicht Bestandteil der Teilen-Zusammenfassung.
- Neue Models, Repository-Methoden, kontogebundener Store und rückwärtskompatible Demo-Speicherung. Revisionsprüfung verhindert stilles Überschreiben durch veraltete Entwürfe. Halteantworten werden nach Logout/Accountwechsel verworfen; Wochenzugriffe auch bei Freundschaftsentzug ungültig.
- Kurzes dekoratives Konfetti nur nach bestätigtem Abschlussereignis und einmaligem Streak-Erfolg. Reduzierte Bewegung wird berücksichtigt; freies Training scrollfähig, damit zusätzliche Rückblick-Aktion kleine Displays nicht überfüllt.

## Tatsächlich geprüft

Lokaler Wegwerf-PostgreSQL-Lauf `node supabase/tests/run_personal_training_tests.mjs`: **66 neue Prüfungen +770 frühere Regressionen bestanden (836 insgesamt)**. Keine Verbindung zu produktiven Konten, keine Testdaten in Supabase.

Geprüft: Werte/Typen/Grenzen, fixed/flexible Wochentage, Revisionen, fehlende Anmeldung, Tabellen-RLS und gesperrte direkte Mutationen, nur eigene Aktivitäten, Zeitintervallgrenzen, akzeptierte aktuelle Freundestermine, Entfernung bei Blockierung, keine Doppelanzeige erledigter Termine, private Abschlussbewertung, verborgene Blind-Übungen sowie fremde Bewertungen nicht zugänglich.

Native Tests neu hinzugefügt, aber noch nicht ausgeführt: Modell-/Datums-/DST-Fälle, Demo-Persistenz, Fehler-/Logout-/Held-Response-Fälle, Onboarding-Wiederaufnahme; UI-Speichern/Neustart des Wochenplans, optionale Bewertung und Abwahl der Anstrengung. CI führt zusätzlich alle bisherigen Regressionen aus.

## Offene Abnahme

- Cloud-Build für diesen Commit kompilieren, alle Tests lesen und Abweichungen beheben.
- Screenshots, kleine Displays, Tastatur, leere/offline Zustände und tatsächliche Animationen prüfen.
- Migration012 erst nach geprüftem Deploymentpaket produktiv ausrollen und separat nachweisen.
- Signierte TestFlight-Auslieferung und echte iPhone-/Mehrkonto-Prüfung.
- Standort/Widget, Kontakte-Einladungen, Supplement-Erinnerungen, Kalorienschätzung/KI und interaktive Muskelgrafik sind neue getrennte Aufträge in der zentralen Checkliste, nicht durch diesen Funktionsblock umgesetzt.
