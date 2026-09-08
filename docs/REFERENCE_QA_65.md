# Native Prüfung #65 – 08.09.2026

Revision `ce071d0`, Xcode 26.6 (17F113), iPhone 16 Simulator, iOS 26.5 (23F77), 393 × 852 pt. [Codemagic-Lauf](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fdd5072a8ff8c2ea8f144). Gesamtdauer 6m24s. Kein Archiv/Upload, kein physisches Gerät.

## Ergebnis

- Swift-Kompilierung erfolgreich. 490 Unit-Tests ausgeführt; vier fehlgeschlagene Assertions in zwei Testmethoden. Beide erwarten noch, dass ein Wochenziel von 2 unzulässig sei. Die neue, ausdrücklich angeordnete Grenze ist 2–7. Die Negativfälle werden auf 1 geändert; ein positiver Store-Fall für 2 kommt hinzu.
- Drei Referenz-UI-Tests ausgeführt: beide R05-Fälle bestanden; A01 scheiterte an `tab-week`, nicht an Anmeldung oder Begrüßung. Die originale Accessibility-Aufzeichnung enthält fünf vorhandene Navigationsbuttons, alle mit der vom Elterncontainer geerbten Kennung `main-navigation`. Der Eltern-Identifier wird entfernt; eindeutige Kennungen der tatsächlichen Buttons bleiben erhalten.
- Echte R05-Bilder aus dem Testlauf sind lokal unter `build/native-qa/65-ce071d0/extracted/` erhalten. `comparison-R05/side-by-side.png` zeigt den proportionalen Vergleich mit der Collage, keine gestreckte oder neu erfundene App-Oberfläche.
- Visuelle R05-Abnahme **nicht bestanden**, obwohl der bisherige Bedien-Test grün war: Bei Accessibility XXXL verdrängt der lange feste Footer die Felder; der Schrittzähler bricht um. Beim geöffneten Zahlenfeld ragen Inhalte unter den Footer. Korrektur: Hinweis in den scrollenden Bereich, unten nur die Hauptaktion; Scrollbereich begrenzen; Schrittzähler einzeilig und Zurück-Symbol kompakt. Der Test muss künftig auch das letzte Eingabefeld oberhalb der Hauptaktion erreichen.
- A01 wurde vor dem bisherigen PNG-Aufruf abgebrochen. Originale Simulator-Testaufzeichnung und Accessibility-Protokoll liegen im XCResult. Künftig wird der A01-Zustand vor den Navigationsassertions als PNG mit Metadaten gespeichert. Ein direktes A01-PNG und der restliche Navigationsdurchlauf bleiben offen.

## Abweichungen und Grenzen

Die Collage hat eine andere proportionale Höhe als das reale Gerät und eine niedrige Ausgangsauflösung. Die Referenz enthält keine Freiwilligkeitskennzeichnung für Größe/Gewicht; der verbindliche Textauftrag verlangt sie. Diese Abweichung bleibt absichtlich. R05 gehört derzeit noch zum alten vierteiligen persönlichen Einrichtungsschritt: Anzeige 2/4 statt einer fiktiven abgeschlossenen 18-Seiten-Registrierung. Vollständiger Ablauf bleibt offen.

WeatherKit-/Ernährungs-/Körperdaten-Unit-Tests wurden im Simulator mit Fixtures ausgeführt. Eine echte Wetterantwort, produktive Migration 017, Release-Signierung und reale iPhone-/Health-/Standortfreigaben sind dadurch **nicht geprüft**. Physisches iPhone/TestFlight: **NICHT AUSGEFÜHRT**.

Die Änderungen nach #65 werden vor einer einzigen gebündelten Nachprüfung lokal geprüft. Keine unveränderte Wiederholung; Kosten siehe [Laufbuch](CI_BUDGET_2026_09.md).
