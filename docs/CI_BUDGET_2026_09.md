# Begrenztes QA-Budget

Freigabe: Nutzerantwort „ok“ vom 08.09.2026 auf maximal **10 USD einschließlich MwSt.** für gebündelte Prüfungen. M2-Tarif im Konto: 0,095 USD/Minute netto, 19 % MwSt. = 0,11305 USD/Minute. Alte Kosten sind nicht Teil dieses neuen Budgets.

## Laufbuch

| Lauf | Revision | Zweck | Status | Limit | Ist-Minuten | Geschätzte Bruttokosten |
| --- | --- | --- | --- | --- | --- | --- |
| [1 / #64](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fda2df58b307d3e170cb8) | `451ad09` | Native Unit Tests, A01/R05 und Screenshot-Export | FAIL vor Kompilierung: Simulatorauswahl `StopIteration` | 30 min | 1m24s | 0,16 USD nach Dauer; konservativ 0,23 USD bei Aufrundung auf 2 Minuten |
| [2 / #65](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fdd5072a8ff8c2ea8f144) | `ce071d0` | Native Unit Tests, A01/R05 und Screenshot-Export | Kompilierung erfolgreich; FAIL in zwei alten Wochenziel-Tests und A01-Navigationskennung; beide R05-Bedientests bestanden, aber Großschrift-Bildkontrolle nicht bestanden | 30 min | 6m24s | 0,72 USD nach Dauer; konservativ 0,79 USD bei Aufrundung auf 7 Minuten |
| [3 / #66](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe39341849fc327720979) | `3b62f33` | Navigationskennungen, Wochenziel-Tests, R05-Großschrift/Tastatur und klarere Diagnoseartefakte | 491 Unit-Tests PASS, 2/3 UI-Tests PASS; A01 bis Profil erfolgreich, Nutrition-Test tippt unter der schwebenden Navigation | 30 min | 7m01s | ca. 0,79 USD nach Dauer; konservativ 8 Minuten = ca. 0,90 USD |
| [4 / #67](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe8c4b674ec7ebe283655) | `e39caf6` | Safe-Area-/Kartenkorrektur, sichtbare Tap-Grenzen, gesamte Unit-Suite und Referenzseiten | PASS: 495 Unit-Tests, 3/3 ausgewählte UI-Tests; sieben echte Simulatorbilder lokal geprüft, Gestaltungsabnahme weiterhin TEILWEISE | 30 min | 5m04s | ca. 0,57 USD nach Dauer; konservativ 6 Minuten = ca. 0,68 USD |
| [5 / #68](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa017afec706db602ed05ee) | `4679d89` | Gesamte Unit-Suite, Einrichtung/E-Mail/Ernährung/Supplement-Referenzfälle | FAIL: 510/511 Unit-Tests und 5/7 UI-Tests PASS; drei Testhelfer-/Lebenszyklusfehler eingegrenzt. 17 echte PNGs geprüft | 30 min | 12m39s | konservativ 13 Minuten = 1,47 USD |
| [6 / #69](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa02c0c85e3d77f45aef815) | `e6eee6c` | Gebündelte kompakte Layouts, Wetter-Aktualisierung, gesamte Unit-Suite und neun Referenz-Bedienfälle | FAIL: 515/515 Unit-Tests, 8/9 Referenz-UI-Tests PASS. Wetter-AX-Abfrage fehlgeschlagen. 22 echte PNGs geprüft, zwei weitere visuelle Fehler lokal korrigiert | 30 min | 15m38s | konservativ 16 Minuten = 1,81 USD |

Konservativ verbraucht aus abgeschlossenen Läufen: **5,89 USD** (4,08 USD bis #68 plus 1,81 USD für #69). **Kein laufender Auftrag, keine Reserve, unreserviertes Restbudget 4,11 USD.** Dies ist eine konservative Kostenschätzung, keine abschließende Anbieterrechnung und kein Kontoguthaben.

Keine parallelen Läufe; keine automatische Wiederholung. Nach jedem Lauf Dashboard-Dauer, Ergebnis und Artefakte erfassen. Bei unklarem Kostenstand konservativ das gesamte Laufzeitlimit belasten. Erst Fehler analysieren und beheben, bevor ein neuer Lauf angelegt wird. Kein TestFlight-/Store-Upload in diesem Prüfpunkt.

Der Nutzer hat kostensparendes Arbeiten erneut ausdrücklich verlangt. Nach #67 wird deshalb **kein weiterer Build für einzelne Layoutkorrekturen** gestartet. Restabweichungen zunächst lokal bündeln und prüfen. Den nächsten nativen Lauf erst für einen substanziellen, lokal vorgeprüften Meilenstein innerhalb des verbleibenden Budgets erwägen. Keine zusätzlichen Dienste, Tarife oder Abos buchen.

Gebündelter Meilenstein #68 beendet, Details in [QA-Nachweis](REFERENCE_QA_68.md). Kein automatischer Folgelauf und kein Store-Archiv/Upload. Erst bestätigte Ursachen und weitere relevante Änderungen bündeln, lokal vorprüfen und dann innerhalb des Restbudgets nativ prüfen.

Auch #69 ist beendet; [vollständiger Test- und Bildnachweis](REFERENCE_QA_69.md). Kein automatischer Wiederholungslauf für einzelne Korrekturen. Folgefixes aus den tatsächlichen Bildern vor weiterer nativer Ausgabe bündeln.
