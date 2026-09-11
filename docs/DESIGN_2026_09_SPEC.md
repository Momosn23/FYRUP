# Verbindliche Referenzumsetzung, 08.09.2026

> **Neuere visuelle Freigabe vom 11.09.2026:** Die Editorial-UI in
> [EDITORIAL_DESIGN_APPROVAL_2026_09_11.md](EDITORIAL_DESIGN_APPROVAL_2026_09_11.md)
> ersetzt ab jetzt die frühere kartenlastige Optik als Gestaltungsziel. Fachliche Regeln,
> Datenschutz, Release-Umfang und Terminologie dieser Spezifikation bleiben bestehen.

Quelle: Nutzerauftrag `839a13d5-5cbe-483f-9c2c-66198bc0df65`, ausgewählte Collagen `af0dfbe0-a365-4cd9-94fe-5cfc3f80df98.png` und `ad52d2c6-c191-46c4-89ab-93c85c626c2c.png`. Der Text hat Vorrang vor Bildfehlern. Die erwähnte zusätzliche Einzelreferenz für Heute liegt diesem Auftrag nicht separat bei; vorerst gilt A01 aus der Collage. Ältere Storyboards sind keine aktuelle Designfreigabe.

Spätere Nutzerentscheidung am 08.09.2026: [Umfangsänderung](RELEASE_SCOPE_2026_09_08.md). Google-Anmeldung ist gestrichen, auch wenn sie in R02 der Collage erscheint. Lebensmittelanbieter/-suche, Barcode, Rezepte und Ernährungssynchronisierung sind auf eine spätere Version verschoben. Für den aktuellen Release keine funktionslosen Aktionen oder Rezeptversprechen aus diesen Bildteilen übernehmen. Manuelles lokales Tagebuch und Kalorienanzeigen bleiben erhalten.

## Bildzuordnung und Maßstab

`scripts/prepare-design-references.py` schneidet R01–R18 sowie A01/A02/A06/A19/A22/A08/A24/A25 nach `docs/reference/2026-09/`. Das Manifest dokumentiert Ausschnitte. Dies sind Referenzen, keine Screenshots einer Implementierung. Die Collagen besitzen niedrigere Auflösung und leicht unterschiedliche Geräteproportionen; Vergrößerung stellt verlorene Bilddetails nicht wieder her. Schrift-/Abstandswerte werden daher nicht als pixelgenau vermessen ausgegeben.

Primäres Layout: 393 × 852 pt; kompakt und groß vor Abnahme zusätzlich prüfen. Reale Texte und native Systembereiche, kein Bitmap als bedienbare Oberfläche. Inhalte scrollen. Referenz-/Simulatorbilder bei gleicher Inhaltsbreite vergleichen, Seitenverhältnis erhalten.

## Gemeinsame Gestaltung

| Token | Startwert | Einsatz |
| --- | --- | --- |
| Hintergrund | #F7FBF9 | Sehr hell, zurückhaltendes Mint |
| Oberfläche | #FFFFFF | Karten/Felder |
| Text | #101415 | Überschriften und Hauptwerte |
| Sekundärtext | #69727A | Erklärungen |
| Aktion | #06C755 | Primäre Aktionen, Auswahl |
| Auswahlfläche | #ECFBF2 | Markierte Karte |
| Linie | #E4E9E8 | Dezente Trennung |
| Ernährung/Flamme | #FF8838 | Gezielter Akzent |
| Seitenabstand | 20 pt | Gemeinsame Inhaltskante |
| Karteninnenabstand | 16 pt | 12 pt für kompakte Einträge |
| Abschnittsabstand | 24 pt | Hauptabschnitte |
| Kartenabstand | 12 pt | Gleichartige Einträge |
| Rundung | 16 pt | Karten; 12 pt Felder/Buttons |
| Hauptaktion | mindestens 52 pt | Volle Inhaltsbreite |
| Titel/Text/Hinweis | 28 / 17 / 13 pt | Systemschrift mit Dynamic Type |

Wiederverwendbare Komponenten: Seiten-/Einrichtungsheader, beschriftetes Feld, Auswahlkarte, Suchfeld, Hauptaktion, Metrikring, Wochenleiste, Supplement-/Crew-Karten, Tabnavigation. Kurze Auswahl-/Wertübergänge respektieren Bewegung reduzieren. Keine dauerhafte Animation jeder Karte.

## Feste Reihenfolge A01

Logo/Glocke → Begrüßung und Datum/Wetter → eine gemeinsame Schritte-/Ernährungskarte → Wochentage und kompakter Wochenstand → Supplements heute → Deine Crew → Heute für dich → Navigation. LIVE erhält einen kompakten direkten Einstieg bei den Aktionen, keinen bildfüllenden Hero und keine dominierende Satzpausenschaltfläche auf Heute.

Kalorien sind ausschließlich protokollierte Nahrungsenergie. Rest = Ziel − Aufnahme. Überschreitung neutral beschriften. Bisherige aktive Energie bleibt eine separate private Funktion. Fehlendes Ernährungsziel zeigt Einrichten. Heute besitzt kein Bergbanner und keine zusätzliche Motivationskarte.

Navigation: Heute | Wochenplan | + | Entdecken | Profil. Plus öffnet eine Aktion. Crew bleibt über Heute/Profil erreichbar. Unterseiten dürfen fokussiert bleiben; Safe Areas schützen Inhalt und Hauptaktionen.

## Einrichtungsregeln

Körperdaten und Health sind optional. Wochenziel 2–7, unabhängig von bevorzugten Tagen. Vorlieben erzeugen keine Termine oder Einwilligungen. Schritte, Ernährung und Stadt getrennt freigeben, standardmäßig aus. Alte Persistenz darf nicht ungeprüft umnummeriert oder gelöscht werden. Anmeldung ausschließlich mit Apple oder E-Mail; Google ist ausdrücklich gestrichen. Zusammenfassung zeigt nur tatsächlich gespeicherte Entscheidungen.

## Assets und Nachweise

Vorhandene FYRUP-Assets bleiben nutzbar; die genaue Herkunft/Lizenz ist noch einzeln zu dokumentieren. Das Wanderer-Motiv aus R01, Lebensmittelbilder und kleine Übungsillustrationen liegen nicht als Originalassets vor. Ersatzmotive ausdrücklich benennen, keine Pixelgleichheit behaupten.

Pro Seite: Screen-ID, Datenzustand, Commit, Simulatorgröße, tatsächliches PNG, Vergleich, Restabweichungen. Sieben echte Simulatorbilder auf `e39caf6` wurden im ersten A01/R05-Prüfpunkt einschließlich eines A19-Zwischenstands geprüft; siehe [REFERENCE_QA_67.md](REFERENCE_QA_67.md). Die vollständige visuelle Referenz- und Geräteabnahme bleibt offen.
