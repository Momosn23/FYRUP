# Native QA #71 – gebündelte Nachprüfung

08.09.2026, [Codemagic #71](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa0623fa9ff08be9e9dba7f), exakt `b538d05adcdeea2fd1186c9d2f4a7dd5e0949f15`. GitHub-main und Checkout im Dashboard unabhängig bestätigt. Start **21:30 CEST**, Mac mini M2. **Gesamtlauf erfolgreich beendet nach 13m11s**; Testschritt 11m36s, Bildübersicht 8s, Artefaktveröffentlichung 11s. Vollständige Testzahlen und neue Einzelbilder noch nicht aus dem ZIP geprüft; keine Produkt-Gesamtabnahme oder Auslieferung.

## Inhalt und Schutzgrenzen

- Suchkorrektur aus `8f4d655`: Wortanfänge statt irreführender Teiltreffer Rücken/Bankdrücken; ursprüngliche fehlgeschlagene Assertion und zwei neue Suchtests bleiben enthalten.
- Aus 33 einzeln geprüften #70-PNGs: Filter in Standardschrift einzeilig, bei AX-Schrift einspaltig; Sport-Icon erhält echte Breite, Bildkarten oben ausgerichtet.
- Profil-Wochenstreifen verwendet dieselbe Montag-basierte lokale Woche wie Heute und Wochenplan. Abschlüsse ohne Enddatum oder außerhalb dieser Woche zählen nicht; Mehrfacheinträge eines Tages bleiben ein Tag. Zwei neue Tests für Wochenränder/Sommerzeit sowie UI-Assertions für Montag/Filtergeometrie.
- Unverändert sämtliche Unit-Tests und zwölf ausgewählte Referenz-Bedienfälle. Erwartet 544 Unit-Tests; tatsächliche Testzahlen erst nach vollständigem Protokoll bestätigen. Kein Test übersprungen, um Grün zu erreichen; andere UI-Testklassen gehören weiterhin nicht zu diesem begrenzten Referenzlauf.
- Harte Jobgrenze **20 Minuten**, interner Testprozess höchstens 17 Minuten; keine automatische Wiederholung, keine parallelen Jobs. Die Reserve von 2,27 USD ist aufgelöst; konservativ 14 ganze Minuten = **1,59 USD brutto** belastet, siehe [Budget](CI_BUDGET_2026_09.md).
- Lokaler Preflight vor Start: **21/21 PASS**, 08.09.2026 19:23:33 UTC. Native Kompilierung damit nicht ersetzt.

## Nach Abschluss

- [x] Gesamtdauer, grünes Dashboard-Ergebnis und konservative Kosten erfasst; Reserve aufgelöst.
- [ ] Vollständige Unit-/Referenz-UI-Zahlen und etwaige Fehler auswerten.
- [ ] Neue Bilder für A24-Filter/Karten sowie A25-Woche einzeln prüfen; keine Pixelgleichheit behaupten.
- [ ] Signiertes TestFlight-Paket nur nach grüner relevanter Nachprüfung, Bildkontrolle und passendem verbleibendem Budget erwägen. Vorhandenes 120-Minuten-Release-Limit darf nicht gestartet werden.

Kein Apple-Upload in diesem Auftrag. Aktuell vorhandener Apple-Stand vor #71: 1.0.0 (15), nicht dieser Quellcode. Physische iPhone-Netzwechsel, echte Health-/WeatherKit-Antwort, Live-Activity-Sperrbildschirm und Mailzustellung **NICHT AUSGEFÜHRT**. Veröffentlichte FYRUP-Rechtslinks fehlen weiterhin. Öffentliche Store-Einreichung ist nicht Teil dieser QA.

## Artefaktzugriff

Die im Browser bis ans Ende gescrollte Run-Zusammenfassung bestätigt unabhängig vom grünen Dashboard: `status: PASS`, exakter Commit `b538d05adcdeea2fd1186c9d2f4a7dd5e0949f15`, Xcode 26.6 / Build 17F113, iPhone 16 / iOS 26.5, `automaticRetries: 0`, `deviceTests: NOT RUN`, Skriptdauer 11,59 Minuten. Sie enthält keine Gesamtzahl der Tests; diese bleibt bis zum vollständigen `xcodebuild.log` ausdrücklich unbestätigt.

Codemagic bietet `FYRUP_71_artifacts.zip` (112,07 MB) und die Simulator-App (31,20 MB) an. Offiziellen Downloadlink über die angemeldete Browser-UI versucht; Browser meldet `ERR_BLOCKED_BY_CLIENT`. Ein direkter Download ohne Browser-Zugangsdaten antwortet HTTP 401. Keine Sitzungs-Cookies oder Tokens extrahiert, keine weiteren automatischen Versuche. Nutzer um das ZIP gebeten. Die alten #70-Bilder ersetzen diese Nachkontrolle nicht.

Apple TestFlight in der erneuerten Sitzung nach Laufende erneut gelesen: neuester vorhandener Upload weiterhin **1.0.0 (15)** vom 07.09.2026, Gruppe FYRUP Intern. Keine Gruppe, Einladung oder Einreichung verändert. Bis zu Bild-/Logkontrolle kein weiterer bezahlter Auftrag; das Restbudget von 1,05 USD erlaubt höchstens einen vorab auf neun Minuten begrenzten M2-Auftrag (max. 1,02 USD), nicht die unveränderte 120-Minuten-Release-Konfiguration. Ob ein vollständiges Archiv samt Upload in neun Minuten gelingt, ist nicht garantiert.
