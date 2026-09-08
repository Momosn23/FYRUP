# Begrenztes QA-Budget

Freigabe: Nutzerantwort „ok“ vom 08.09.2026 auf maximal **10 USD einschließlich MwSt.** für gebündelte Prüfungen. M2-Tarif im Konto: 0,095 USD/Minute netto, 19 % MwSt. = 0,11305 USD/Minute. Alte Kosten sind nicht Teil dieses neuen Budgets.

## Laufbuch

| Lauf | Revision | Zweck | Status | Limit | Ist-Minuten | Geschätzte Bruttokosten |
| --- | --- | --- | --- | --- | --- | --- |
| [1 / #64](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fda2df58b307d3e170cb8) | `451ad09` | Native Unit Tests, A01/R05 und Screenshot-Export | FAIL vor Kompilierung: Simulatorauswahl `StopIteration` | 30 min | 1m24s | 0,16 USD nach Dauer; konservativ 0,23 USD bei Aufrundung auf 2 Minuten |
| [2 / #65](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fdd5072a8ff8c2ea8f144) | `ce071d0` | Native Unit Tests, A01/R05 und Screenshot-Export | Kompilierung erfolgreich; FAIL in zwei alten Wochenziel-Tests und A01-Navigationskennung; beide R05-Bedientests bestanden, aber Großschrift-Bildkontrolle nicht bestanden | 30 min | 6m24s | 0,72 USD nach Dauer; konservativ 0,79 USD bei Aufrundung auf 7 Minuten |
| [3 / #66](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe39341849fc327720979) | `3b62f33` | Navigationskennungen, Wochenziel-Tests, R05-Großschrift/Tastatur und klarere Diagnoseartefakte | 491 Unit-Tests PASS, 2/3 UI-Tests PASS; A01 bis Profil erfolgreich, Nutrition-Test tippt unter der schwebenden Navigation | 30 min | 7m01s | ca. 0,79 USD nach Dauer; konservativ 8 Minuten = ca. 0,90 USD |
| 4 | Korrekturen aus echten A01/R05-Aufnahmen und Grundlagen der Einrichtungspräferenzen | Safe-Area-/Kartenkorrektur, sichtbare Tap-Grenzen, gesamte Unit-Suite und Referenzseiten | vorbereitet, noch nicht gestartet | 30 min | – | Reserve 3,40 USD |

Konservativ verbraucht: **1,93 USD** (17 einzeln aufgerundete Laufminuten × 0,11305 USD, Gesamtsumme auf den nächsten Cent aufgerundet). Reserviert: 3,40 USD. Frei nach Reserve: 4,67 USD. Keine parallelen Läufe; keine automatische Wiederholung. Nach jedem Lauf Dashboard-Dauer, Ergebnis und Artefakte erfassen. Bei unklarem Kostenstand konservativ das gesamte Laufzeitlimit belasten. Erst Fehler analysieren und beheben, bevor ein neuer Lauf angelegt wird. Kein TestFlight-/Store-Upload in diesem Prüfpunkt.
