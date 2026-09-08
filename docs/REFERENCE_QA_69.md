# Native QA #69 – Ergebnis und Einzelbildkontrolle

08.09.2026, [Codemagic #69](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa02c0c85e3d77f45aef815), exakt `e6eee6caa90c537f844d7d57b0e51bca308ddbf7`. Dashboard: **FAIL**, 15m38s auf Mac mini M2. Xcode 26.6 (17F113), iPhone 16 / iOS 26.5. Kein Archiv, kein Apple-Upload und keine automatische Wiederholung.

## Vollständige Belege

Das vom Nutzer nachgereichte `C:/Users/Momo/Downloads/FYRUP_69_artifacts.zip` wurde ohne Änderung des Originals nach `build/native-qa/69-e6eee6c/` entpackt. Zielpfade vorher auf Zugehörigkeit zu diesem neuen Unterordner geprüft. SHA-256: `ab9bc4d6033499e8391acb946abdffdc081b251ba6086979ace3ae64b284a074`.

- Vollständiges `build/reference-qa/xcodebuild.log`: **515/515 Unit-Tests PASS**, **8/9 Referenz-UI-Tests PASS**. Die übrigen UI-Testklassen waren in diesem begrenzten Meilenstein nicht ausgewählt.
- Alle **8 WeatherStoreTests PASS**, einschließlich Cacheablauf bei offen bleibender Ansicht, Offline-Rückkehr und Ortsentfernung während einer laufenden Antwort. Kein Live-API-Aufruf in diesen Tests.
- Alle **7 EmailAuthFlowTests** und **8 SetupJourneyTests PASS**. Auch der zuvor nicht aktivierte Wochen-Store wird jetzt über den regulären Lebenszyklus getestet, ohne automatische Zielwahl.
- Ernährungsänderung **500 → 250 g** gespeichert und in Tagesübersicht/Heute bestätigt: **1.850 → 925 kcal**, Rest **1.575**, Makros halbiert. Supplement-Eigenmenge **1,5 g** gespeichert, wieder geöffnet, Erinnerungen bleiben aus. Die zwei zuvor abbrechenden Testhelferpfade sind damit nativ bestätigt.
- **22 unveränderte echte Simulator-PNGs** einzeln angesehen, einschließlich Hierarchien für die beiden neuen Layoutfehler. Keine generierten Bilder als App-Nachweis.

## Einziger fehlgeschlagener automatischer Test

- Der App-/Test-Build erreichte die Referenz-Bedienprüfungen. Das begrenzte Fehlerprotokoll meldet einen fehlgeschlagenen Test: `testWeatherCardRendersSelectedCityAndRemovalWithoutGPS`, Zeile 103 der geprüften Revision.
- Dort prüfte der Test `app.links["weather-attribution"].exists`. Die vorherigen Prüfungen für vorhandene Wetterkarte, gewählte Stadt Berlin und Temperatur 18 bestanden; `continueAfterFailure = false` war aktiv. Dies sind isolierte Fixture-Daten und **keine echte Apple-Wetterantwort**.
- Der Wetterort-Entfernungsweg liegt nach der fehlgeschlagenen Prüfung und ist deshalb durch diesen Lauf **nicht** abgenommen.
- Die Runner-Zusammenfassung meldet FAIL und `automaticRetries: 0`; derselbe eine Fehler ist auch im vollständigen Log bestätigt.
- Wetter-PNG/Hierarchie wurden im alten Test erst hinter dieser Assertion erzeugt und fehlen deshalb. Die konkrete AX-Rolle der Attribution ist nicht abschließend belegt. Keine echte WeatherKit-Störung aus einem Fixture-Bedientest ableiten.
- Physisches iPhone, signierte Release-IPA, TestFlight, tatsächliche WeatherKit-Antwort und Berechtigungsdialoge: **NICHT AUSGEFÜHRT**.

## Visuelle Einzelkontrolle aller 22 PNGs

| Bilder | Ergebnis |
| --- | --- |
| A01-top / A01-scroll | Reihenfolge korrekt, Magnesium nicht mehr auseinandergerissen. Crew-Aktionen weiterhin erst nach Scrollen vollständig; keine volle Referenzgleichheit. Keine erfundenen Avatare oder Wetterdaten. |
| A01-large-type-top | **Sichtbarer Produktfehler:** Inhalte links abgeschnitten, Glocke rechts außerhalb des Bildes. AX: ScrollView x=−86,7, Breite 566,3 bei Bildschirmbreite 393. Sieben nebeneinanderliegende große Wochentage und weitere horizontale Gruppen drücken die gesamte Ansicht auseinander. Tabtexte extrem verkürzt. Folgekorrektur unten, noch nicht erneut nativ geprüft. |
| A19-manual-diary-checkpoint / A19-edited-meal-summary | Jetzt alle vier Mahlzeiten vor dem Scrollen oberhalb von Eintragen sichtbar. Mengen-/Makroänderung und Rest korrekt. Hinweistext unterhalb ist scrollbar; echte Lebensmittelbilder/Datenquelle weiterhin offen. |
| A19-large-type-top / A19-large-type-meal | Eigene Werte wachsen vertikal; Snacks-Dialog und Eintragsaktion erreichbar. Keine horizontale Überbreite wie auf Heute. Die große Hauptnavigation benötigt dieselbe separate Korrektur. |
| R01-welcome / R02-account-choice / R03-email-form | R02 hat jetzt eine saubere einfache Apple-Kontur und hellen E-Mail-Knopf. R01-Motiv, FYRUP-Rechtstexte/Google sowie R03-Feldgestaltung bleiben gegenüber der Referenz offen. Echte Anmeldung/Mailzustellung nicht aus Formularbedienung ableiten. |
| R05-body / R05-keyboard / R05-large-type-top / R05-large-type-scroll | Alle vier kontrolliert: Daten, Rückkehr, Tastaturabschluss und Zielgewicht im großen scrollbaren Layout vorhanden. Kein seitliches Herauslaufen in diesen Bildern. |
| R06-primary-goal / R07-additional-goals | Klare Untertexte und kompakte Karten. R06-Auswahl nun vollständig grün statt Übergangsbild; beide R07-Auswahlen sichtbar und später gespeichert. |
| R08-weekly-goal | **Sichtbarer Produktfehler:** Kreise nur etwa 64 pt, „Einheiten“ zweizeilig bis über den Rand. AX belegt Texte 37,7 pt breit und 33,7 pt hoch. Textbezogenes Seitenverhältnis verengt die Karte auf ihre Eigenhöhe statt die Rasterbreite. Folgekorrektur unten. Keine automatische Zielwahl; 4 stammt aus bestätigter Bestands-Fixture. |
| R09-preferred-days / R10-preferred-time | Runde Mo/Sa-Auswahl korrekt; Unterschiedlich und erklärende Untertexte sichtbar. Keine automatisch erzeugten Termine oder Rechte. |
| R11-own-supplement-amount / R11-supplement-grid | Eigene 1,5 g, erfolgreiches Speichern und wieder geöffneter Wert belegt. Grüne vorhandene Einträge stammen aus der Fixture, nicht Neuregistrierungs-Vorgaben. Raster/weitere Zeilen scrollbar; Mengen-/Erinnerungsdetails sind echte eigene Einstellungen. |
| R18-setup-summary | Alle sechs wesentlichen Zeilen sowie Weitere Einstellungen oberhalb der Hauptaktion sichtbar. Wiederöffnung/Bearbeitung inklusive Mo/Sa bestanden. Referenz-Endgestaltung/Konfetti und vollständiger Neuregistrierungsfluss bleiben getrennt offen. |

## Lokaler Folgefix, noch nicht nativ geprüft

Die Wetterprüfung sucht nun nach der stabilen Kennung unabhängig davon, ob SwiftUI den Link als AX-Link oder AX-Button ausweist. Sie verlangt weiterhin Existenz, den genauen Datenquellen-Text und tatsächliche Erreichbarkeit. Die Aufnahme von PNG/Hierarchie liegt jetzt vor dieser Assertion, damit bei einem weiteren Fehler Belege erhalten bleiben. Diese Änderung entfernt keine Produktanforderung und aktiviert keine echte externe Anfrage im Fixture-Test. Die konkrete AX-Rolle im fehlgeschlagenen Lauf bleibt bis zu einem entsprechenden Artefaktnachweis offen.

Der bereits separat lokal gespeicherte Block `953a0fd` (kompakter Wochenplan, eingebettete Release-Berechtigungen) sowie dieser Folgefix sind **nicht in QA #69 enthalten**. Keine native Abnahme dafür behaupten.

Die beiden sichtbaren Fehler werden im selben lokalen Folgeblock korrigiert:

- Heute erhält eine explizite Inhaltsbreite aus dem sichtbaren Container. Die großen Wochentage verteilen sich auf drei Spalten; Streak- und Abschnittsüberschriften wechseln bei großer Schrift untereinander. Keine globale Verkleinerung der Hauptinhalte. Neue UI-Assertions prüfen die tatsächlichen horizontalen Grenzen von ScrollView, Begrüßung, Glocke, Wetter und Schritten.
- Nur die räumlich begrenzte Hauptnavigation verwendet gedeckelte Textgröße und Apples [Large Content Viewer](https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(_:)) für die vollständige vergrößerte Beschriftung. Alle fünf Buttons behalten Namen und Kennungen.
- R08-Kreis nimmt die Rasterbreite an und legt das Label darüber, statt die Text-Eigenhöhe zum Kreismaß zu machen. Neue Prüfung fordert quadratische Breite und einzeiliges Einheiten-Label bei Standardschrift.
- Heute-Links und Crew-Aktionen bekommen die mindestens 44 pt hohen Trefferflächen innerhalb ihrer eigentlichen Labels. Supplement-Untertext bleibt auch beim Bearbeiten bereits vorhandener Einträge zutreffend. Es werden keine Mengen oder Erinnerungen vorausgewählt.

Lokale Prüfung dieses Folgeblocks: **21/21 Preflight-Gruppen PASS**, Abschluss `2026-09-08T16:31:43.237Z`. Darin eingeschlossen sind die 15 synthetischen Release-IPA-Prüfungen. Das ist keine Swift-/Xcode-Ausführung und kein Nachweis der korrigierten Layouts auf einem iPhone; dafür bleibt ein gebündelter nativer Folgetest offen.

## Kosten und Fortsetzung

Konservativ auf 16 Minuten aufgerundet: 1,81 USD brutto; kumulativ 5,89 USD des freigegebenen 10-USD-Budgets, 4,11 USD unreserviert. Keine Anbieterrechnung ersetzt. Der eigens eingerichtete Prüflauf-Monitor ist nach Abschluss pausiert; keine weiteren Builds/Uploads gestartet.

Die neuen Bild-/Testkorrekturen sind lokal gemeinsam geprüft. Erst für einen substanziellen gebündelten Meilenstein weiteren nativen Prüfbedarf entscheiden. Die aktuelle vollständige Referenzabnahme ist nicht grün; alte Bilder oder erzeugte Mockups dürfen die fehlenden Nachweise nach dem Folgefix nicht ersetzen.
