# Gezielt geprüfte Bilder – Build 35

[Codemagic 35](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c0376fac9a246bed97ed3), `1a953af`, ist nach 29 min 19 s vollständig erfolgreich; alle 27 UI-Abläufe bestanden. Das tatsächliche Archiv (247.252.692 Bytes) wurde heruntergeladen und 73 PNGs sicher unter `.qa/build35/` entpackt. Die sieben folgenden Aufnahmen wurden einzeln betrachtet.

| Aufnahme | Ergebnis |
| --- | --- |
| `54-unsaved-set-with-keyboard.png` | Gewicht (kg) und Wiederholungen bleiben auch über den eingetragenen Werten 81 / 9 sichtbar. Die geöffnete Zifferntastatur verdeckt die Beschriftungen nicht. |
| `55-restored-set-draft.png` | Nach tatsächlichem App-Neustart sind dieselben Werte mit dauerhaften Beschriftungen wiederhergestellt. „Satz abschließen“ und „Nur Werte speichern“ sind vollständig sichtbar. |
| `69-privacy-settings.png` | Die explizite Überschrift „Wer sieht meine Aktivitäten?“ ist vollständig und ohne automatische Großschreibung sichtbar. Kein Nachweis des später korrigierten Speichervorgangs; dieser Build enthält noch den alten Pfad. |
| `68-workout-complete-actions.png` | Fertig und Feed-Aktion bleiben nach Scrollen vollständig oberhalb der Tab-Leiste. |
| `01-home-feed.png` | Woche, Status, Streak und Supplements lesbar. Crew beginnt erst unterhalb dieser Karten und gerät zunächst hinter die Tab-Leiste; die Social-Gewichtung bleibt gegenüber der Vorlage zu schwach. Kein Beleg, dass die Zeilen nach Scrollen unbedienbar wären. |
| `onboarding-01-profile.png` | Optionales Foto mit Kameraknopf, Name, Username, Geburtsjahr und Stadt sichtbar; keine abgeschnittenen Felder. Überschrift, große Schrift und schwarzer Weiter-Knopf weichen weiterhin von der hellen Referenz mit grünem Knopf ab. Keine pixelgleiche Abnahme. |
| `05-plan-workout.png` | Das alte kompakte Datumsfeld liegt im sichtbaren Bereich, schneidet aber das Jahr ab. Die spätere eigenständige Datumszeile aus `717472c` ist noch nicht Teil dieses Bildes. |

GitHub 45 hat auf dem zweiten nativen Prüfaufbau ebenfalls 383 Einzeltests und 27 UI-Abläufe bestanden. Die Datum-/Supplements-/Privatsphäre-Korrekturen aus `717472c` werden erst durch GitHub 46 und Simulator 36 geprüft. Keine pauschale 73-Bilder-Abnahme, keine Pixelgleichheit und keine echte iPhone-Auslieferung aus diesen Bildern ableiten.
