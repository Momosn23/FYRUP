# Begrenztes QA-Budget

Freigabe: Nutzerantwort „ok“ vom 08.09.2026 auf maximal **10 USD einschließlich MwSt.** für gebündelte Prüfungen. M2-Tarif im Konto: 0,095 USD/Minute netto, 19 % MwSt. = 0,11305 USD/Minute. Alte Kosten sind nicht Teil dieses neuen Budgets.

## Laufbuch

| Lauf | Revision | Zweck | Status | Limit | Ist-Minuten | Geschätzte Bruttokosten |
| --- | --- | --- | --- | --- | --- | --- |
| [1 / #64](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fda2df58b307d3e170cb8) | `451ad09` | Native Unit Tests, A01/R05 und Screenshot-Export | FAIL vor Kompilierung: Simulatorauswahl `StopIteration` | 30 min | 1m24s | 0,16 USD nach Dauer; konservativ 0,23 USD bei Aufrundung auf 2 Minuten |
| 2 | Korrektur der Simulatorauswahl | Gleiches A01/R05-Ziel, Auswahl anhand tatsächlich installierter iOS-Version | noch nicht gestartet | 30 min | – | Reserve 3,40 USD |

Konservativ verbraucht: 0,23 USD. Reserviert: 3,40 USD. Frei nach Reserve: 6,37 USD. Keine parallelen Läufe; keine automatische Wiederholung. Nach jedem Lauf Dashboard-Dauer, Ergebnis und Artefakte erfassen. Bei unklarem Kostenstand konservativ das gesamte Laufzeitlimit belasten. Erst Fehler analysieren und beheben, bevor ein neuer Lauf angelegt wird. Kein TestFlight-/Store-Upload in diesem Prüfpunkt.
