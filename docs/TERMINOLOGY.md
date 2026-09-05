# FYRUP – dauerhafte Sprachrichtlinie

Verbindlicher Nutzerauftrag vom 05.09.2026, Quelle: `84148860-e5fb-4272-a5dc-526493f4877c/pasted-text.txt`. Gilt für die bestehende App und jede zukünftige Erweiterung. Der anschließende Nutzerauftrag verlangt ausdrücklich, diese Sprachlogik für die Zukunft zu behalten.

## Bedeutung vor Ersetzung

| Kontext | Verbindlicher Begriff | Beispiel |
| --- | --- | --- |
| Sportartenübergreifende Bewegung | Aktivität | Letzte Aktivität |
| Wochenziel, Fortschritt, gezählte Abschlüsse | Einheit / Einheiten | 3 / 4 Einheiten |
| Termin, gemeinsame Aktivität, Einladung | Session | Session planen |
| Gym, Übungsablauf, Satzwerte | Workout | Workout starten |
| Wiederverwendbare Übungszusammenstellung | Workout-Plan | Meine Workout-Pläne |

Nicht überall dasselbe Wort einsetzen. Ein persönlicher Wochenrhythmus bleibt „Mein Wochenplan“ – das ist kein Gym-Workout-Plan. Schritte und Wochenziel bleiben unterschiedliche Systeme; Schrittzahlen und Health-Texte werden nicht in Einheiten umgedeutet.

## Aktionen und Status

- Allgemeiner Start: „JETZT LOS“ oder „Loslegen“. Im Gym: „Workout starten“.
- Abschluss: „ABSCHLIESSEN“ bzw. „Workout abschließen“. Erfolg: „DONE 🔥“ oder „Heute geschafft 🔥“.
- Plus-Einstieg: „Was hast du vor?“.
- Gym-Einstieg: „Wie willst du loslegen?“ mit „Workout-Plan wählen“, „Freies Workout“, „Session für später planen“.
- Geplanter Status: „PLANNED“, „SESSION ÖFFNEN“.
- Laufend: „LIVE“, „ÖFFNEN“.
- Noch nichts: „Noch nichts geplant“ oder „Heute noch nichts“; „JETZT LOS“ / „FÜR SPÄTER PLANEN“.
- Geplant gemeinsam: „MITMACHEN“. Bei bereits laufender Aktivität: „MITZIEHEN 🔥“.
- Einladungen: „Momo lädt dich zu einer Session ein.“ Antworten bleiben „Dabei“, „Vielleicht“, „Kann nicht“.
- Sozialer Blick: „Was macht deine Crew heute?“ / „Wer ist heute aktiv?“. Kein „Max trainiert gerade“, sondern „Max ist gerade LIVE“.

## Wochenziel und Marke

- „Wie oft willst du pro Woche aktiv sein?“
- „Setze dein Wochenziel und hol dir deine Flamme 🔥“.
- 3–7 Einheiten; vorhandene Zielgrenzen und Gültigkeitsregeln nicht durch Sprachänderungen verändern.
- „Noch 1 Einheit bis zur Flamme 🔥“ oder im eindeutigen Kontext „Noch 1 bis zur Flamme 🔥“.
- „FLAMME GEHOLT 🔥“, „Wochenziel geschafft“, „4 / 4 Einheiten“.
- Bereich **Deine Streak** bleibt der frühere ausdrückliche Nutzerwunsch. Keine neue Überschrift „Deine Flames“.
- **LIVE, PLANNED, DONE, FYR UP, FLAME, CALL MY SHOT, CALLED IT, Blind Workout, Workout, Session** bleiben zulässige Markenbegriffe. Erklärungen sonst primär auf Deutsch.

## Reichweite und Sicherheit

Alle sichtbaren Oberflächen berücksichtigen: Buttons, Überschriften, Karten, leere Listen, Einladungen, Profile/Freunde, Settings, Onboarding, Wochenziel, Erfolgsansichten, Fehler, Pushs, VoiceOver und deutsche Lokalisierung. Keine bürokratischen Erfolgstexte und keine unsystematische Deutsch-Englisch-Mischung.

Interne Typen (`TrainingGroup`, `TrainingRoutine`), Funktions-/Tabellennamen, JSON-Felder, Analytics-Ereignisse, Symbolnamen von Apple, Accessibility-IDs und bereits angewendete Migrationsdateien dürfen bleiben. Eine interne Umbenennung ist kein Ziel dieses Auftrags. Historische gespeicherte Katalogwerte können eine sichere Darstellungsschicht bekommen; die Daten selbst müssen nicht umgeschrieben werden.

Selbst geschriebene Profiltexte, Plan-/Gruppennamen, Notizen, Übungsnamen und freier Nutzerinhalt werden **nicht** automatisch übersetzt oder umformuliert. Ein Nutzer darf seinen eigenen Plan weiterhin „Training mit Max“ nennen.

## Pflichtprüfung

Nach jeder sprachlichen Änderung neue und angepasste UI-Tests mitziehen, UI-, Push- und Modelltexte erneut durchsuchen und verbleibende Treffer dokumentieren. Vollständiger Build, verfügbare automatische Tests und Bildschirmkontrolle sind unterschiedliche Nachweise; echte Geräte-/Pushzustellung nicht aus Quellcode ableiten.

Aktueller Umsetzungs- und Abnahmestand: [TERMINOLOGY_CHECKLIST.md](TERMINOLOGY_CHECKLIST.md).
