# Native Referenzprüfung #67 – 08.09.2026

Revision: `e39caf6b7494fe843857d0ee8ab702a3bb57b46c`, Checkout und Dashboard stimmen überein. [Abgeschlossener Codemagic-Lauf](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe8c4b674ec7ebe283655).

## Ergebnis und Reichweite

- Kompilierung und Testlauf **PASS**: 495 Unit-Tests, 3/3 ausgewählte `ReferenceCheckpointUITests`; kein automatischer Retry.
- Xcode 26.6 / 17F113, separat ausgewählte installierte Laufzeit iOS 26.5, iPhone 16, 393 × 852 pt. PNGs 1178 × 2556 Pixel; tatsächliches Seitenverhältnis vom Vergleichswerkzeug akzeptiert.
- Gesamtdauer laut Dashboard **5m04s**; 3,72 Minuten im Prüfscripttimer sind nicht die gesamte abrechenbare Laufzeit. Konservativ sechs Minuten, ca. 0,68 USD brutto. Gesamte neue Prüfserie konservativ 2,61 USD, Details im [Laufbuch](CI_BUDGET_2026_09.md).
- Keine vollständige UI-Regression, kein physisches iPhone, kein TestFlight-/Release-Archiv, keine Live-Health-/Wetter-/Push-Prüfung. Diese Nachweise sind **NICHT AUSGEFÜHRT**.

## Gesicherte Artefakte

Originaldownload: `C:/Users/Momo/Downloads/FYRUP_67_artifacts.zip` (72.297.209 Bytes). Entpackt unter `build/native-qa/67-e39caf6/extracted/`; von Git ausgeschlossen.

`build/reference-qa/run.json`, `xcodebuild.log` und XCResult dokumentieren Lauf und Revision. Sieben native PNGs samt Metadaten und isoliertem Accessibility-Baum:

- `A01-top`, `A01-scroll`
- `R05-body`, `R05-keyboard`, `R05-large-type-top`, `R05-large-type-scroll`
- `A19-manual-diary-checkpoint`

Alle sieben Bilder wurden lokal angesehen. Die echten Produktions-Views laufen mit isolierten Referenzdaten, Deutsch, Referenzdatum 22.05.2025 09:41 Berlin. Dies sind keine generierten Mockups und keine produktiven Nutzerdaten. Der Fixture-Einstieg ist für physische Release-Geräte ausgeschlossen.

Proportionale Gegenüberstellungen, Overlay und Differenz für A01/R05/A19: `build/native-qa/67-e39caf6/comparison-*/`. Die Collage wurde nur proportional auf gleiche Breite gebracht. Unterschiedliche Geräteproportionen und graue Vergleichsauffüllung sind keine Appfehler. Keine behauptete Pixelgleichheit; dieser Bericht hält die visuelle Bewertung fest.

## Behobene Probleme nach #65/#66

- Tabkennungen nicht mehr durch eine geerbte Elternkennung überschrieben. Heute → Wochenplan → Plus öffnen/schließen → Profil → Ernährung erfolgreich bedient.
- Hauptinhalte scrollen nicht mehr unter Statusleiste/Home-Indikator durch. Explizite Containergrenzen und separate Navigation sind in A01 oben und gescrollt erkennbar.
- R05: das letzte Körperdatenfeld ist mit maximaler unterstützter Großschrift durch Scrollen vollständig oberhalb des Fußbuttons erreichbar. Der Fußbereich besteht nur aus der Aktion; erklärender Text bleibt im Scrollbereich.
- R05: Größe editieren, Tastatur schließen, Weiter und Zurück funktionieren; Wert bleibt erhalten. Dies prüft keine komplette neue 18-seitige Registrierung.
- Wochenziel 2 ist in der nativen Testbasis zulässig. Alte negative Tests verwenden jetzt tatsächlich unzulässige Werte. Die produktive Datenbankmigration bleibt separat offen.

## Visuelle Bewertung: TEILWEISE, keine Gesamtfreigabe

**A01:** Reihenfolge, korrektes Referenzdatum, grüne Links, vier Supplementkarten und drei Crew-Karten in horizontalen Reihen stimmen strukturell. Schritte 8.421 / 10.000, 1.579 Rest; Ernährung 1.850 / 2.500, 650 kcal Rest; drei abgeschlossene Wochentage und Donnerstag als aktueller Tag. Kein großer LIVE-Hero und keine Satzpause auf Heute.

Offen: Hauptkarte und vertikale Abstände lassen die Crew erst nach Scrollen vollständig erscheinen. Supplementnamen brechen teils ungünstig um (`Magne-sium`); Icons und vom Nutzer festzulegende Mengen sind noch nicht wie in der Vorlage. Crew-Karten benötigen eine kompaktere Hierarchie und klare Aktionsflächen. Initialen sind ehrliche Platzhalter für Fixture-Profile ohne Foto, keine fertigen Referenzporträts. Ohne gewählten Wetterort wird korrekt `Ort wählen` statt erfundenem Wetter angezeigt.

**R05:** klare Felder und erreichbare Aktion, Tastatur und Großschrift funktionieren. Offen: Dezimaldarstellung `180.0` statt lokalisierter Eingabe, finale Abstände/Fortschrittsdarstellung und Einbindung in den neuen Ablauf. `2/4` stammt noch aus der bestehenden persönlichen Einrichtung, nicht aus dem verlangten neuen Gesamtfluss. Freiwilligkeit und lokale Datenverarbeitung werden ausdrücklich dargestellt und nicht zugunsten einer identischen Bildkopie verschwiegen.

**A19:** Navigation zur echten Ernährungsansicht funktioniert; Kalorien und Makros werden dargestellt, Aktion bleibt oberhalb der Navigation. Keine vollständige Ernährungsabnahme. Die bisherige manuelle Tagebuchansicht ist deutlich weniger kompakt als die Vorlage; Mahlzeitenzeilen, Fotos und vollständige Zustände fehlen im Referenzvergleich. Der Referenzdatensatz verteilt seine Energie nicht wie die Collage auf vier Mahlzeiten, deshalb bleibt Frühstück hier leer. Cloud-Synchronisierung, Lebensmittelanbieter, Barcode und Rezepte sind weiterhin offen.

## Sparsame Fortsetzung

Keine neue kostenpflichtige Wiederholung nach diesem grünen Prüfpunkt. Die offenen Layoutkorrekturen und der neue Einrichtungsablauf werden als nächste lokale Arbeitsblöcke gebündelt. Vollständige Produkt-, Backend- und Geräteabnahme bleiben getrennte Einträge in der [Funktionsmatrix](REFERENCE_IMPLEMENTATION_MATRIX.md).
