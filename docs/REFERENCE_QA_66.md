# Native Prüfung #66 – 08.09.2026

Revision `3b62f33`, Xcode 26.6, iPhone 16 / iOS 26.5. [Lauf](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9fe39341849fc327720979), Dauer 7m01s. Kein Archiv/Upload.

## Nachweis

- **491 native Unit-Tests bestanden**, ohne Fehler. Dies schließt WeatherKit-Testquelle, Ernährung und Körperdaten ein, aber keine produktiven Dienste.
- Zwei R05-UI-Tests bestanden, jetzt einschließlich tatsächlicher Erreichbarkeit des letzten Feldes oberhalb der Hauptaktion bei Accessibility XXXL.
- A01: Begrüßung, Supplements-vor-Crew, Wochenplan, Plus und Rückkehr zum Profil bestanden. Der anschließende Nutrition-Check schlug fehl. XCTest hatte den Profileintrag bei y=788,7–842 als erreichbar eingestuft, obwohl die schwebende Navigation dort liegt; der Tap öffnete das Ernährungstagebuch nicht. Testhilfe prüft künftig zusätzlich vollständige sichtbare Grenzen oberhalb der Navigation.
- Sechs native PNGs mit Metadaten und Accessibility-Texten erhalten: `build/native-qa/66-3b62f33/extracted/`. A01 oben/gescrollt, R05 normal/Tastatur/Großschrift oben/gescrollt.

## Visuelle Auswertung und nächste Korrektur

R05: Footer verdrängt den Inhalt nicht mehr. Letztes Feld ist oberhalb von Weiter erreichbar; beim Zahlenfeld kein durch den Footer sichtbares anderes Eingabefeld mehr. Freiwilligkeits- und lokale Datenschutzhinweise bleiben erhalten. Große Schrift scrollt bewusst, kein Zusammenquetschen.

A01 zeigt tatsächlich 8.421/10.000 Schritte, 1.850/2.500 erfasste kcal, 650 kcal übrig, drei abgeschlossene Wochentage und 3/4 Einheiten. Donnerstag hat nur einen Ring, keine erfundene Erledigung. Kein Ort gewählt: Datum und Ortsauswahl, kein Fake-Wetter. Fehlende Profilbilder bleiben Initialen statt fremder Fotos.

Noch nicht visuell abgenommen: gescrollter Inhalt überlagert die Statusleiste und scheint unter dem Home-Indikator durch; Karten sind gegenüber der Vorlage zu breit, Headerabstände zu groß, Abschnittslinks fälschlich schwarz. Korrektur: sichtbare Tab-/Scrollgrenzen, kompakterer Header/Metrikkarte, vier Supplement- bzw. drei Crew-Karten in normaler Größe (bei großer Schrift weiterhin horizontal scrollbar), grüne Abschnittslinks. Echte Vergleichsbilder dieser Korrektur stehen noch aus.

Zusätzliche lokale Vorbereitung: `SetupChoices` für R06/R07/R09/R10 mit optionalen, privaten Auswahlwerten. Noch keine angeschlossenen neuen Onboardingseiten; vier neue Unit-Tests erst in der nächsten Revision enthalten. Das bestehende `setupPage` wird weder umnummeriert noch als neuer Fortschritt ausgegeben.

Physisches iPhone, TestFlight, echte Health-/Wetter-/Standortantwort, produktive Migration 017: **NICHT AUSGEFÜHRT**. Gesamte Checkliste weiterhin offen. Nächsten kostenpflichtigen Lauf erst nach lokalem Preflight und Restbudgetprüfung starten.
