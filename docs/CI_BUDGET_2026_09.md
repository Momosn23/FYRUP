# Begrenztes QA-Budget

Freigabe: Nutzerantwort „ok“ vom 08.09.2026 auf maximal **10 USD einschließlich MwSt.** für gebündelte Prüfungen. M2-Tarif im Konto: 0,095 USD/Minute netto, 19 % MwSt. = 0,11305 USD/Minute. Alte Kosten sind nicht Teil dieses neuen Budgets.

## Laufbuch

| Lauf | Revision | Zweck | Status | Limit | Ist-Minuten | Geschätzte Bruttokosten |
| --- | --- | --- | --- | --- | --- | --- |
| [1 / #64](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fda2df58b307d3e170cb8) | `451ad09` | Native Unit Tests, A01/R05 und Screenshot-Export | FAIL vor Kompilierung: Simulatorauswahl `StopIteration` | 30 min | 1m24s | 0,16 USD nach Dauer; konservativ 0,23 USD bei Aufrundung auf 2 Minuten |
| [2 / #65](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fdd5072a8ff8c2ea8f144) | `ce071d0` | Native Unit Tests, A01/R05 und Screenshot-Export | Kompilierung erfolgreich; FAIL in zwei alten Wochenziel-Tests und A01-Navigationskennung; beide R05-Bedientests bestanden, aber Großschrift-Bildkontrolle nicht bestanden | 30 min | 6m24s | 0,72 USD nach Dauer; konservativ 0,79 USD bei Aufrundung auf 7 Minuten |
| [3 / #66](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe39341849fc327720979) | `3b62f33` | Navigationskennungen, Wochenziel-Tests, R05-Großschrift/Tastatur und klarere Diagnoseartefakte | 491 Unit-Tests PASS, 2/3 UI-Tests PASS; A01 bis Profil erfolgreich, Nutrition-Test tippt unter der schwebenden Navigation | 30 min | 7m01s | ca. 0,79 USD nach Dauer; konservativ 8 Minuten = ca. 0,90 USD |
| [4 / #67](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe8c4b674ec7ebe283655) | `e39caf6` | Safe-Area-/Kartenkorrektur, sichtbare Tap-Grenzen, gesamte Unit-Suite und Referenzseiten | PASS: 495 Unit-Tests, 3/3 ausgewählte UI-Tests; sieben echte Simulatorbilder lokal geprüft, Gestaltungsabnahme weiterhin TEILWEISE | 30 min | 5m04s | ca. 0,57 USD nach Dauer; konservativ 6 Minuten = ca. 0,68 USD |

Konservativ verbraucht: **2,61 USD** (23 einzeln aufgerundete Laufminuten × 0,11305 USD, Gesamtsumme auf den nächsten Cent aufgerundet). Keine aktive Reserve, kein laufender Build. Verbleibendes freigegebenes Budget: **7,39 USD**. Dies ist eine konservative Kostenschätzung für diese vier neuen Läufe, keine abschließende Anbieterrechnung und kein Kontoguthaben.

Keine parallelen Läufe; keine automatische Wiederholung. Nach jedem Lauf Dashboard-Dauer, Ergebnis und Artefakte erfassen. Bei unklarem Kostenstand konservativ das gesamte Laufzeitlimit belasten. Erst Fehler analysieren und beheben, bevor ein neuer Lauf angelegt wird. Kein TestFlight-/Store-Upload in diesem Prüfpunkt.

Der Nutzer hat kostensparendes Arbeiten erneut ausdrücklich verlangt. Nach #67 wird deshalb **kein weiterer Build für einzelne Layoutkorrekturen** gestartet. Restabweichungen zunächst lokal bündeln und prüfen. Den nächsten nativen Lauf erst für einen substanziellen, lokal vorgeprüften Meilenstein innerhalb des verbleibenden Budgets erwägen. Keine zusätzlichen Dienste, Tarife oder Abos buchen.

Nächster gebündelter Meilenstein vorbereitet: kompletter persönlicher Einrichtungsablauf, E-Mail-PKCE/Recovery, kompaktere Heute-/Ernährungsseiten und Supplement-Mengen. Lokaler Gesamt-Preflight 21/21 PASS. Vorgesehen ist **ein** manueller QA-Lauf mit 30-Minuten-Limit und 7 Referenz-UI-Tests, ohne Store-Archiv/Upload. Vor Auslösen 3,40 USD konservative Reserve aus den 7,39 USD einplanen; ungebundener Rest dann 3,99 USD. Dies ist bislang eine Planung, keine Behauptung eines gestarteten Laufs.
