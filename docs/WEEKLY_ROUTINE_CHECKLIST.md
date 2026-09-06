# Freiwilliger Trainingsrhythmus und Wochenübersicht

Nutzerauftrag vom 05.09.2026: Anfangs Ziele wie Laufen/Gym mit Häufigkeit und Dauer eingeben können; optional beliebige Wochentage wählen. Auf Heute oben die Woche mit erledigten und noch anstehenden Einheiten zeigen.

Arbeitsstand: [Implementierung und getrennte Prüfnachweise](PERSONAL_TRAINING_IMPLEMENTATION_STATUS.md). Die Funktionspunkte bestanden bereits 66 gezielte lokale Datenbankprüfungen, native Tests und Bedienabläufe; produktive Speicherung 012 ist installiert und sechs Originalbilder sind kontrolliert. Im aktuellen Gesamtstand bestanden Codemagic 45 und der signierte Build 46 jeweils 459 Einzeltests und 33 Bedienabläufe. Build 46 wurde als Build 11 ohne Uploadfehler an Apple übertragen. Die Haken unten bezeichnen Code-, Backend- und Simulator-Abnahme; echte iPhone-, Mehrkonto- und Animationsabnahme bleiben ausdrücklich getrennt offen.

- [x] ROUTINE-01 Freiwillige Eingabe während der Einrichtung; Überspringen blockiert weder Anmeldung noch Aktivität.
- [x] ROUTINE-02 Pro Sportart Häufigkeit und optionale Dauer anlegen, ändern und entfernen; Tage frei wählen oder offenlassen.
- [x] ROUTINE-03 Einstellungen dauerhaft und nur für den eigenen Account speichern; Neustart, Fehlerzustand, Abmelden und Accountwechsel prüfen.
- [x] ROUTINE-04 Oben auf Heute Montag–Sonntag zeigen; heutiger Tag hervorgehoben. Erledigt ausschließlich aus echten abgeschlossenen Aktivitäten ableiten.
- [x] ROUTINE-05 Gewünschten Rhythmus und konkret geplante Aktivitäten verständlich unterscheiden; keine heimlich erzeugten Einladungen oder vorgetäuschten Einheiten.
- [x] ROUTINE-06 Auswahl eines Tages zeigt erledigte/konkret geplante Aktivitäten und noch offene Rhythmuswünsche. Ziele ohne feste Tage bleiben als flexible Einheiten sichtbar.
- [x] ROUTINE-07 Änderungen jederzeit erreichbar; private Zeit-/Dauerziele nicht ungefragt in Feed oder Push übertragen.
- [x] ROUTINE-08 Bestehendes Wochenziel-/Streak-System behält seine Zählregeln: nur echte abgeschlossene Einheiten, keine Schritte oder bloßen Pläne.
- [x] ROUTINE-09 Helle Karten, gut lesbare Tagesleiste, dezente Animationen und reduzierte Bewegung berücksichtigen.
- [x] ROUTINE-10 Modelle, Zugriffsschutz, Persistenz, Wochen-/Zeitzonengrenzen und Bedienablauf testen; Bildschirmansichten prüfen; erst danach als ausgeliefert kennzeichnen.

## Ergänzung: Trainingsgefühl und Satzübersicht

- [x] FEEDBACK-01 Während des Workouts die tatsächlich eingetragenen Gewichte und Wiederholungen je Übung/Satz zeigen; Zielvorgaben niemals als erzielte Werte ausgeben.
- [x] FEEDBACK-02 Pro Übung drei freiwillige Auswahlfelder: Easy, Mittel, Hardcore. Auswahl ändern/entfernen und nach Neustart wiederherstellen können.
- [x] FEEDBACK-03 Beim Abschluss freiwillig festhalten, wie das Workout war; optionaler privater Kommentar. Auch ohne Bewertung abschließen können.
- [x] FEEDBACK-04 Bewertungen nur vom Besitzer setzen/lesen; kein ungefragtes Teilen in Feed, Einladungen, Kopien oder Exporten.
- [x] FEEDBACK-05 Normale und Blind Workouts integrieren, ohne noch verborgene Übungen zu verraten; Speichern/Fehler/Neustart prüfen.

## Ergänzung: Lebendige Darstellung

- [x] MOTION-01 Kurzes Konfetti nur nach einem neu bestätigten Abschluss; der Effekt endet nach 3,4 Sekunden und startet beim bloßen Öffnen alter Einträge nicht erneut.
- [x] MOTION-02 Dezentes Feedback für Tagesauswahl, Fortschritt und Streak-Erfolg; keine unruhige Animation jeder Karte.
- [x] MOTION-03 „Bewegung reduzieren“ wird respektiert; Konfetti ist für Bedienung und VoiceOver unsichtbar und sein endlicher Task wird beim Verlassen beendet.
