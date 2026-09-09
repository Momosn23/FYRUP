# Native QA #71 – gebündelte Nachprüfung

08.09.2026, [Codemagic #71](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa0623fa9ff08be9e9dba7f), exakt `b538d05adcdeea2fd1186c9d2f4a7dd5e0949f15`. GitHub-main und Checkout im Dashboard unabhängig bestätigt. Start **21:30 CEST**, Mac mini M2. **Gesamtlauf erfolgreich beendet nach 13m11s**; Testschritt 11m36s, Bildübersicht 8s, Artefaktveröffentlichung 11s. Am 09.09.2026 Nutzer-ZIP vollständig ausgewertet: **544/544 Unit-Tests und 12/12 ausgewählte UI-Tests PASS, TEST SUCCEEDED**. Alle 33 einzelnen Bildschirmaufnahmen angesehen. Keine Produkt-Gesamtabnahme oder Auslieferung durch diesen QA-Lauf.

## Inhalt und Schutzgrenzen

- Suchkorrektur aus `8f4d655`: Wortanfänge statt irreführender Teiltreffer Rücken/Bankdrücken; ursprüngliche fehlgeschlagene Assertion und zwei neue Suchtests bleiben enthalten.
- Aus 33 einzeln geprüften #70-PNGs: Filter in Standardschrift einzeilig, bei AX-Schrift einspaltig; Sport-Icon erhält echte Breite, Bildkarten oben ausgerichtet.
- Profil-Wochenstreifen verwendet dieselbe Montag-basierte lokale Woche wie Heute und Wochenplan. Abschlüsse ohne Enddatum oder außerhalb dieser Woche zählen nicht; Mehrfacheinträge eines Tages bleiben ein Tag. Zwei neue Tests für Wochenränder/Sommerzeit sowie UI-Assertions für Montag/Filtergeometrie.
- Unverändert sämtliche Unit-Tests und zwölf ausgewählte Referenz-Bedienfälle. Tatsächlich **544 Unit-Tests ohne Fehler** (1,260 s Testzeit) und **12 Referenz-Bedienfälle ohne Fehler** (419,234 s Testzeit). Kein Test übersprungen, um Grün zu erreichen; andere UI-Testklassen gehören weiterhin nicht zu diesem begrenzten Referenzlauf.
- Harte Jobgrenze **20 Minuten**, interner Testprozess höchstens 17 Minuten; keine automatische Wiederholung, keine parallelen Jobs. Die Reserve von 2,27 USD ist aufgelöst; konservativ 14 ganze Minuten = **1,59 USD brutto** belastet, siehe [Budget](CI_BUDGET_2026_09.md).
- Lokaler Preflight vor Start: **21/21 PASS**, 08.09.2026 19:23:33 UTC. Native Kompilierung damit nicht ersetzt.
- Erneuter lokaler Preflight nach ZIP-Auswertung und Budgetbegrenzung am 09.09.2026: **21/21 PASS**. Zwischen `b538d05` und der Paketvorbereitung keine Änderungen an App, Widget, Ressourcen oder nativen Tests; nur Prüfprotokolle, CI-Zeitlimit und dessen lokale Absicherung.

## Nach Abschluss

- [x] Gesamtdauer, grünes Dashboard-Ergebnis und konservative Kosten erfasst; Reserve aufgelöst.
- [x] Vollständige Unit-/Referenz-UI-Zahlen und Fehlerfreiheit aus dem vollständigen Protokoll bestätigt.
- [x] Alle 33 neuen Bilder einzeln geprüft, einschließlich A24-Filter/Karten und A25-Woche; keine Pixelgleichheit behauptet.
- [x] Signiertes internes TestFlight-Prüfpaket nach grünem relevantem Lauf und Bildkontrolle vorbereitet. Release-Limit vor Start von 120 auf neun Minuten reduziert, keine erneute vollständige Testsuite, maximal 1,02 USD brutto. Noch kein Start-/Uploadnachweis in diesem Dokument.

Kein Apple-Upload in diesem Auftrag. Aktuell vorhandener Apple-Stand vor #71: 1.0.0 (15), nicht dieser Quellcode. Physische iPhone-Netzwechsel, echte Health-/WeatherKit-Antwort, Live-Activity-Sperrbildschirm und Mailzustellung **NICHT AUSGEFÜHRT**. Veröffentlichte FYRUP-Rechtslinks fehlen weiterhin. Öffentliche Store-Einreichung ist nicht Teil dieser QA.

## Artefaktzugriff

Die im Browser bis ans Ende gescrollte Run-Zusammenfassung bestätigt unabhängig vom grünen Dashboard: `status: PASS`, exakter Commit `b538d05adcdeea2fd1186c9d2f4a7dd5e0949f15`, Xcode 26.6 / Build 17F113, iPhone 16 / iOS 26.5, `automaticRetries: 0`, `deviceTests: NOT RUN`, Skriptdauer 11,59 Minuten. Die Gesamtzahlen sind inzwischen separat aus dem vollständigen `xcodebuild.log` bestätigt, nicht aus diesem JSON abgeleitet.

Codemagic bietet `FYRUP_71_artifacts.zip` (112,07 MB) und die Simulator-App (31,20 MB) an. Der frühere automatische Download war blockiert (`ERR_BLOCKED_BY_CLIENT` beziehungsweise HTTP 401 ohne Zugangsdaten). Keine Sitzungs-Cookies oder Tokens extrahiert. **Am 09.09.2026 hat der Nutzer das ZIP bereitgestellt**, damit ist diese Zugriffslücke geschlossen. Original unverändert: `C:/Users/Momo/Downloads/FYRUP_71_artifacts.zip`, **117.515.543 Bytes**, SHA-256 `ade3edafb4f8e8061d073ab1c3e450acc94ef10600837778b4395fe4bb609001`. 2.844 Einträge / 120.290.731 unkomprimierte Bytes; alle Zielpfade und Symlink-Attribute vor Extraktion geprüft. Frischer lokaler Extraktionsordner: `build/native-qa/71-b538d05/verified/`; keine Artefaktdateien ausgeführt oder eingecheckt.

Apple TestFlight in der erneuerten Sitzung nach Laufende erneut gelesen: neuester damals vorhandener Upload **1.0.0 (15)** vom 07.09.2026, Gruppe FYRUP Intern. Kein neuer Upload durch #71. Das Restbudget von 1,05 USD erlaubt höchstens einen auf neun Minuten begrenzten M2-Auftrag (max. 1,02 USD). Ob ein vollständiges Archiv samt Upload in neun Minuten gelingt, ist nicht garantiert; bei Abbruch keine automatische Wiederholung.

## Einzelbildkontrolle am 09.09.2026

Alle aufgeführten PNGs stammen aus exakt `b538d05`, 1178 × 2556 Pixel (393-pt-Referenzbreite). Die Anzeige im Prüfwerkzeug wurde auf 944 × 2048 verkleinert; Originaldateien unverändert. Die Kontaktübersicht ersetzt keine Einzelprüfung. Vergleichsgrundlage: ausgewählte September-Collagen mit nachträglich gestrichenem Google-Login und verschobenem Lebensmittel-/Rezeptbereich.

| PNG(s) | Tatsächlicher Befund / Grenze |
| --- | --- |
| A01-top, A01-scroll | Schritte/Ernährung, Wochenleiste, Supplements, Crew und Aktionen geordnet; Crew-Aktionen nach Scrollen lesbar. Kein alter Login-Trennstrich. Initialen sind der fehlende Fotozustand des Fixtures, keine geprüfte Fotoübertragung. |
| A01-large-type-top | Breite bleibt auf dem Bildschirm; Werte wachsen untereinander. Weiteres Scrollen nötig, keine kompakte Standardansicht bei AX-Schrift behauptet. |
| A01-weather-fixture, A01-weather-removed | Berlin/18 °C und Apple-Quelle sichtbar; nach Entfernen nur Ort wählen, keine alte Temperatur. Testdaten, keine echte WeatherKit-/GPS-Abnahme. |
| A02-week-plan, A02-next-week | Montag–Sonntag, korrekte aktuelle/nächste Woche, drei Abschlüsse nur in aktueller Woche. Session-Aktion liegt unten im Scrollinhalt, nicht stets vollständig im ersten Ausschnitt. |
| A19-manual-diary-checkpoint, A19-edited-meal-summary | 1.850→925 kcal, Rest 650→1.575; Makros halbiert. Vier Mahlzeiten und feste Eintragen-Aktion. Quellenhinweis unterhalb des ersten Ausschnitts scrollbar. |
| A19-large-type-top, A19-large-type-meal | Lesbare umbrechende Werte und erreichbare Aktion; Snack-Detail mit Eintrag hinzufügen. Sehr große Schrift benötigt Scrollen. |
| A24-discover-top | Vier Filter einzeilig; beide Bildkarten beginnen jetzt auf gleicher Höhe. Unterschiedliche Kartenhöhen wegen Textlänge bleiben. Keine erfundenen eigenen Pläne. |
| A24-library-search, A24-exercise-details | Passende Bankdrücken-Treffer, Metadaten und bestätigter Favoritenzustand. Eigene Übungsillustrationen aus der Collage fehlen weiter; Symbole sind kein Bildersatz mit Pixelgleichheit. |
| A24-large-text | Einspaltige Filter jetzt vollständig lesbar, kein Sportarten-Wortbruch. Sportzeilen liegen außerhalb dieses Ausschnitts; deren Icon-Geometrie ist hier nicht visuell nachgewiesen. |
| A25-profile-top, A25-large-text | Zentrierter Kopf und sechs getrennte Hauptziele. AX-Schrift stapelt Kennzahlen; großes Bearbeiten-Symbol überlagert einen Teil des Avatarplatzhalters. Kein neuer Bedienblocker, vollständige Gestaltungsfreigabe bleibt offen. |
| A25-profile-statistics | Jetzt Mo–So und genau drei abgeschlossene Tage der sichtbaren Woche, konsistent zum Wochenplan. Streak und Statistik getrennt. |
| R01-welcome, R02-account-choice | Direkter Willkommen-/Apple-/E-Mail-Einstieg ohne Google. Bestehendes Athletenmotiv statt Wanderer der Vorlage; eigene veröffentlichte FYRUP-Rechtslinks fehlen weiterhin. |
| R03-email-form | Beschriftete echte Felder, Passwortsichtbarkeit, tatsächliche 6-Zeichen-Regel statt erfundener Backend-Regel. Deaktivierter Konto-Button bleibt optisch grün; vollständige Referenzgestaltung offen. Keine produktive Anmeldung durch das Fixture. |
| R05-body, R05-keyboard | Optionale Daten klar getrennt von Mahlzeiten, 182-cm-Änderung und Tastatur-Fertig/Weiter sichtbar. |
| R05-large-type-top, R05-large-type-scroll | Felder/Wörter umbrechen im Scrollbereich; Weiter/Später bleiben erreichbar. |
| R06-primary-goal, R07-additional-goals | Ausgewählte Ziele grün, Erklärungen lesbar; zusätzliche Ziele erteilen keine Freigaben. |
| R08-weekly-goal, R09-preferred-days, R10-preferred-time | Kreiswerte 2–7 passen; Mo/Sa sowie Unterschiedlich markiert. Wünsche getrennt von Terminen und Erinnerungsfreigaben. |
| R11-own-supplement-amount, R11-supplement-grid | Eigene Menge 1,5 g mit Einheit/Zeiten, keine Dosierungsvorgabe; vier markierte Supplement-Einträge, Speichern erreichbar. |
| R18-setup-summary | Sechs kompakte bearbeitbare Zeilen, Weitere Einstellungen und Zu FYRUP sichtbar. Zusammenfassung enthält Fixture-Daten, keine echten Health-Berechtigungen. |

**Ergebnis: gezielte Fehlerkorrekturen bestätigt; neue Bedienregression in diesen zwölf Fällen nicht festgestellt. Gesamte Design-/Funktionsabnahme bleibt TEILWEISE.** Andere Referenzseiten, echtes Gerät, Mailzustellung und Live-Activity-Systemoberfläche sind nicht durch diese 33 PNGs abgenommen. Ein internes TestFlight-Paket dient der weiteren Geräteprüfung, nicht als Behauptung eines fertigen öffentlichen Releases.

## Konkrete Regressionen

Ursprünglicher Rücken/Bankdrücken-Test und beide neuen Wortanfangs-Suchtests PASS. Alle sechs `ProfileActivityHistoryTests` einschließlich lokaler Wochenränder/Sommerzeit PASS. `AppStoreConnectivityTests` 5/5, `SupabaseRESTClientTests` 7/7 und `WorkoutStoreTests` 35/35 PASS. Wiederverbindung/Fehlerklassifizierung verwenden simulierte Antworten; physische Netzwechsel und echter Tokenablauf auf dem iPhone **NICHT AUSGEFÜHRT**.
