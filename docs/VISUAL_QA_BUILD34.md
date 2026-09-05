# Bildnachkontrolle – Build 34

Am 05.09.2026 wurde das tatsächliche Archiv von [Simulator-Build 34](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9bfa953cf4759eab7d79ab) (`6e79a31`) lokal unter `.qa/build34/` entpackt: 71 Einzelaufnahmen und eine Übersicht. Alle 27 UI-Abläufe bestanden; das ersetzt keine visuelle Abnahme. Diese Nachkontrolle betrifft vier einzeln betrachtete Bilder, nicht pauschal alle 71.

| Bild | Tatsächlicher Befund |
| --- | --- |
| `05-plan-workout.png` | Die kompakte native Datumsanzeige zeigt weiterhin `05.09....`. Die erste Layoutkorrektur reicht auf diesem Simulator nicht aus. |
| `08-workout-complete.png` | Im Ausgangsbild liegt der untere Fertig-Knopf noch hinter der schwebenden Tab-Leiste. |
| `68-workout-complete-actions.png` | Nach Scrollen sind Fertig und Feed-Aktion vollständig über der Tab-Leiste sichtbar. Der geometrische Bediennachweis besteht. Der zusätzliche Scrollfreiraum funktioniert. |
| `66-supplement-confirmed.png` | Der Einleitungstext endet weiterhin abgeschnitten bei „auf dei...“. Die erste Höhenkorrektur reicht nicht aus. Bestätigung und Rückgängig sind sichtbar. |

Neue lokale Nachbesserung: ausgeschriebenes Datum mit separatem nativen Kalender; Supplements-Hinweise in drei kurzen Zeilen mit eigenständigen Textnachweisen und zusätzlichem unterem Scrollfreiraum. Die erweiterten UI-Tests erzeugen `70-session-calendar` und `71-supplement-purpose`. **Noch kein nativer Bildnachweis dieser neuen Änderungen.**

Die dauerhaften Gewicht-/Wiederholungsbeschriftungen und die explizite Datenschutzüberschrift sind erst in `1a953af` enthalten; Build 34 kann sie nicht belegen. Der vollständige Referenzvergleich des Vorgängers bleibt in [Build 31](VISUAL_QA_BUILD31.md) dokumentiert. Kein TestFlight- oder echtes iPhone-Ergebnis aus Simulatorbildern ableiten.
