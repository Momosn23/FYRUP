# Freiwilliger Trainingsrhythmus und Wochenübersicht

Nutzerauftrag vom 05.09.2026: Anfangs Ziele wie Laufen/Gym mit Häufigkeit und Dauer eingeben können; optional beliebige Wochentage wählen. Auf Heute oben die Woche mit erledigten und noch anstehenden Einheiten zeigen.

Arbeitsstand: [Implementierung und getrennte Prüfnachweise](PERSONAL_TRAINING_IMPLEMENTATION_STATUS.md). 66 neue lokale Datenbankprüfungen bestanden; native/visuelle/produktive/iPhone-Abnahme des neuen Blocks noch offen. Deshalb noch keine vollständige Anforderung als ausgeliefert abgehakt.

- [ ] ROUTINE-01 Freiwillige Eingabe während der Einrichtung; Überspringen blockiert weder Anmeldung noch Training.
- [ ] ROUTINE-02 Pro Sportart Häufigkeit und optionale Dauer anlegen, ändern und entfernen; Tage frei wählen oder offenlassen.
- [ ] ROUTINE-03 Einstellungen dauerhaft und nur für den eigenen Account speichern; Neustart, Fehlerzustand, Abmelden und Accountwechsel prüfen.
- [ ] ROUTINE-04 Oben auf Heute Montag–Sonntag zeigen; heutiger Tag hervorgehoben. Erledigt ausschließlich aus echten abgeschlossenen Aktivitäten ableiten.
- [ ] ROUTINE-05 Gewünschten Rhythmus und konkret geplante Aktivitäten verständlich unterscheiden; keine heimlich erzeugten Einladungen oder vorgetäuschten Trainings.
- [ ] ROUTINE-06 Auswahl eines Tages zeigt erledigte/konkret geplante Aktivitäten und noch offene Rhythmuswünsche. Ziele ohne feste Tage bleiben als flexible Einheiten sichtbar.
- [ ] ROUTINE-07 Änderungen jederzeit erreichbar; private Zeit-/Dauerziele nicht ungefragt in Feed oder Push übertragen.
- [ ] ROUTINE-08 Bestehendes Wochenziel-/Streak-System behält seine Zählregeln: nur echte abgeschlossene Trainings, keine Schritte oder bloßen Pläne.
- [ ] ROUTINE-09 Helle Karten, gut lesbare Tagesleiste, dezente Animationen und reduzierte Bewegung berücksichtigen.
- [ ] ROUTINE-10 Modelle, Zugriffsschutz, Persistenz, Wochen-/Zeitzonengrenzen und Bedienablauf testen; Bildschirmansichten prüfen; erst danach als ausgeliefert kennzeichnen.

## Ergänzung: Trainingsgefühl und Satzübersicht

- [ ] FEEDBACK-01 Während des Trainings die tatsächlich eingetragenen Gewichte und Wiederholungen je Übung/Satz zeigen; Zielvorgaben niemals als erzielte Werte ausgeben.
- [ ] FEEDBACK-02 Pro Übung drei freiwillige Auswahlfelder: Easy, Mittel, Hardcore. Auswahl ändern/entfernen und nach Neustart wiederherstellen können.
- [ ] FEEDBACK-03 Beim Abschluss freiwillig festhalten, wie das gesamte Training war; optionaler privater Kommentar. Auch ohne Bewertung abschließen können.
- [ ] FEEDBACK-04 Bewertungen nur vom Besitzer setzen/lesen; kein ungefragtes Teilen in Feed, Einladungen, Kopien oder Exporten.
- [ ] FEEDBACK-05 Normale und Blind-Workouts integrieren, ohne noch verborgene Übungen zu verraten; Speichern/Fehler/Neustart prüfen.

## Ergänzung: Lebendige Darstellung

- [ ] MOTION-01 Kurzes Konfetti nach echtem Trainingsabschluss, keine Endlosschleife oder erneute Feier bei bloßem Öffnen alter Einträge.
- [ ] MOTION-02 Dezentes Feedback für Tagesauswahl, Fortschritt und Streak-Erfolg; keine unruhige Animation jeder Karte.
- [ ] MOTION-03 „Bewegung reduzieren“ respektieren, dekorative Effekte für Bedienung/VoiceOver unsichtbar halten und nach Verlassen stoppen.
