# Native QA #70 – gebündelter Prüfstand

08.09.2026, [Codemagic #70](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa050523ffb6b3dd927bc2d), exakt `704674e971469f1b0be98f4dceb13bd04d779f56`. GitHub-main und Dashboard-Checkout vor beziehungsweise nach Start unabhängig bestätigt. Start 20:13 CEST, Gesamtdauer **12m22s**, Status **FAIL**. Keine Wiederholung und kein Apple-Upload.

## Prüfauftrag

- Alle nativen Unit-Tests, einschließlich der neuen Netzwerk-, Such- und Profilfälle.
- Zwölf gezielte Referenz-Bedienfälle: Heute, Wetter, Körperdaten, lokale Ernährung, Einrichtung/Supplements, Entdecken und Profil; normale und große Schrift.
- Echte Simulator-PNGs und Accessibility-Hierarchien zur anschließenden visuellen Kontrolle.
- Lokaler Vorprüfstand: 21/21 Prüfgruppen PASS vom 08.09.2026 17:59:38 UTC; ersetzt nicht die nun gestartete native Ausführung.

Der Workflow `ios-cloud-validation` verwendete Mac mini M2, festes Xcode 26.6 und iPhone 16 / iOS 26.5. Harte Jobgrenze bei #70: 30 Minuten, keine automatische Wiederholung. Nicht die komplette frühere UI-Testsammlung und keine physischen iPhone-Tests.

## Kosten und Freigabe

Die vorherige Reserve von 3,40 USD ist durch konservativ auf 13 Minuten aufgerundete **1,47 USD brutto** ersetzt; verbleibend 2,64 USD, [Budgetlaufbuch](CI_BUDGET_2026_09.md). TestFlight-Archiv erst nach passendem grünem Prüfergebnis, Bildkontrolle und erneuter Budgetprüfung. Echte Netzwerkwechsel, Health/WeatherKit, Mailzustellung und iPhone-/TestFlight-Abnahme weiterhin **NICHT AUSGEFÜHRT**.

## Belegter Fehler und lokale Folgekorrektur

Der im Dashboard gezeigte Fehler ist `DiscoveryContentTests.testPlanSearchUsesOnlyOwnPlansAndTheirExerciseMetadata`, Zeile 36. Die Suche nach „Rücken“ findet fälschlich einen Push-Plan mit „Bankdrücken“, weil die normalisierte Folge `rucken` innerhalb von `bankdrucken` liegt. Der Test wird nicht abgeschwächt. Die gemeinsame Suche für Übungen und Entdecken berücksichtigt im Folgecode Wortanfänge: echte Muskelbegriffe/Übungsaliase sowie Präfixe bleiben auffindbar, irreführende Treffer mitten im Wort entfallen. Zwei weitere native Tests für Wortgrenzen, Präfixe und Satzzeichen vorbereitet; noch nicht erneut nativ ausgeführt.

Xcode 26.6 (17F113), iPhone 16 / iOS 26.5 aus dem Runner-Bericht bestätigt. Der Nutzer hat das zuvor nicht automatisiert herunterladbare Paket als `C:/Users/Momo/Downloads/FYRUP_70_artifacts.zip` bereitgestellt. Original unverändert, 119455097 Bytes, SHA-256 `fc634adedb521cf1ad3beddd428e28c9b304ea3ef87a54352f93c527733739c4`. 2893 Archivpfade vor der Extraktion auf Traversierung und Symlinks geprüft; frisch unter `build/native-qa/70-704674e/verified/` entpackt.

## Vollständiger Testnachweis

- `build/reference-qa/xcodebuild.log`: **539/540 Unit-Tests PASS**, genau der oben beschriebene Suchfehler. Keine weitere fehlgeschlagene Assertion.
- **12/12 ReferenceCheckpointUITests PASS**, 420,486 Sekunden. Alle bisherigen Referenzfälle plus die drei neuen Entdecken-/Profilfälle. Andere UI-Testklassen wurden in diesem begrenzten Lauf nicht ausgewählt.
- Alle zwölf neuen Netzwerk-Regressionsfälle bestanden. Die einschlägigen vollständigen Klassen: `AppStoreConnectivityTests` 5/5, `SupabaseRESTClientTests` 7/7, `WorkoutStoreTests` 35/35 PASS. Simulierte Repository-/Transportantworten, kein physischer Funkwechsel und kein produktiver Ausfalltest.
- Runner `automaticRetries: 0`; keine signierte IPA, kein Apple-Upload. `run.json` beschreibt nur 11,11 Minuten Skriptlaufzeit, Abrechnung weiterhin nach 12m22s Dashboard-Gesamtdauer.

## Einzelbildkontrolle – 33 echte Simulator-PNGs

Alle Bilder wurden einzeln geöffnet, nicht lediglich die Kontaktübersicht. Originalformat 1178 × 2556 Pixel; Anzeige im Prüfwerkzeug ggf. verkleinert, Originale nicht verändert. Fixture-Daten sind keine echten Konten, Wetter-/Health-Antworten oder aktuelle Uhrzeit.

| Bereich | Aufnahmen | Ergebnis und verbleibende Abweichung |
| --- | --- | --- |
| A01 | top, scroll, large-type-top | Reihenfolge, Schritte/Ernährungswerte, Tagesleiste, Supplements und Crew geprüft. Großschrift liegt jetzt innerhalb der Bildschirmbreite. Crew-Aktionen bleiben teilweise unterhalb des ersten Ausschnitts und per Scrollen erreichbar; keine vollständige Pixelgleichheit zur Collage. Initialen statt Fotos wegen leerer Fixture-Avatarwerte. |
| Wetter | weather-fixture, weather-removed | Berlin/18 °C/Apple-Weather-Verweis sichtbar; nach Entfernen keine alte Temperatur. Echte WeatherKit-Antwort und Signierung weiterhin offen. |
| A02 | week-plan, next-week | Montag–Sonntag und Wechsel zur nächsten Woche korrekt. Planungsaktion weiter unten per Scrollen erreichbar. |
| A19 | manual-diary-checkpoint, edited-meal-summary, large-type-top, large-type-meal | Vier Mahlzeiten, 1850→925 kcal und Rest 650→1575 geprüft; große Schrift umbrechend/scrollbar, Eintragen erreichbar. Manuelle Einträge, keine vorhandene Lebensmitteldatenbank behauptet. |
| A24 | discover-top, library-search, exercise-details, large-text | Reale Bildkarten, Suche, Metadaten/Favorit und Sportnavigation vorhanden. Befund: Sportarten-Filter bei Standardschrift umgebrochen; AX-Filter ungünstig zweispaltig, Sport-Icon über seinem festen Platz; Bildkarten oben versetzt. Im Folgecode korrigiert, erneutes Bild offen. Keine individuellen Übungsfotos oder verschobenen Rezepte. |
| A25 | profile-top, profile-statistics, large-text | Zentrierter Kopf, sechs Hauptzugänge und getrennte Statistik geprüft. Befund: Statistik-Tagesleiste startet Sonntag statt Montag und zählt alle geladenen Tage. Im Folgecode auf gemeinsame lokale Wochenlogik begrenzt; eigener Test für Wochenränder/Sommerzeit und UI-Wochentag ergänzt. |
| R01–R03 | welcome, account-choice, email-form | Apple/E-Mail ohne Google; kein alter Bildtrenner. Willkommen nutzt bestehendes Motiv, nicht die exakte neue Bergcollage. Eigene FYRUP-Rechtslinks weiterhin fehlend, Website-Link ausdrücklich als ObjektSignal bezeichnet. Passwortregel zeigt konfigurierte sechs Zeichen statt ungeprüfter Vorgaben der Illustration. |
| R05 | body, keyboard, large-type-top, large-type-scroll | Felder, 182-cm-Eingabe, Tastaturabschluss, Zielgewicht und Fußaktionen erreichbar. Große Schrift scrollt, freiwillige Angaben bleiben überspringbar. |
| R06–R10 | primary-goal, additional-goals, weekly-goal, preferred-days, preferred-time | Auswahlen klar grün; Wochenzielkreise und einzeiliges Einheiten-Label jetzt korrekt. Wünsche erzeugen keine stillen Termine/Rechte. |
| R11/R18 | own-supplement-amount, supplement-grid, setup-summary | Eigene 1,5 g, Raster, bestätigte Speicherung ohne Erinnerungsfreigabe; sechs Summary-Zeilen und Bearbeiten erreichbar. Keine Dosierungsempfehlung. |

Gestaltungsabnahme **TEILWEISE**, nicht vollständig. Vier verbleibende Folgekorrekturen (Suche, Filter/Karten, Wochenleiste, Budgetlimit) werden zusammen erneut geprüft; kein kosmetischer Einzelbuild. Physische iPhone-/TestFlight-, Mailzustellungs-, Health-, Live-Activity- und reale Netzwechseltests **NICHT AUSGEFÜHRT**.

Lokaler Preflight für die gebündelten Folgekorrekturen: **21/21 PASS am 08.09.2026 um 19:23:33 UTC**. Ein erster eingeschränkter Lauf konnte das bereits vorhandene PyYAML nicht lesen; die freigegebene lokale Ausführung mit unveränderter Bibliothek bestand. Ein Terminologie-Fehlalarm durch einen technischen Typnamen innerhalb einer Accessibility-ID wurde durch Auslagern der Berechnung beseitigt, nicht durch Abschalten der Sprachprüfung. Der nächste native Lauf enthält unverändert alle Unit-Tests und zwölf Referenz-Bedienfälle, zwei zusätzliche Wochenmodelltests sowie strengere Filter-/Wochen-Assertions. Kostenlimit auf 20 Minuten reduziert.

Lokale Schlussprüfung der gemeinsamen Wortanfangssuche am 08.09.2026 um **18:34:26 UTC: 21/21 Preflight-Gruppen PASS**. Die zwei neuen Swift-Tests und die beibehaltene fehlgeschlagene Assertion sind dadurch nicht nativ ausgeführt. Kein weiterer bezahlter Lauf angelegt; vor einer Wiederholung vollständige Artefakte auswerten und das Joblimit an die verbleibenden 2,64 USD anpassen.

## Apple-Vorkontrolle

Der Nutzer hat die abgelaufene Apple-Browsersitzung eigenständig erneuert. App Store Connect für App `6808742803` frisch lesend bestätigt: neuester vorhandener Upload `1.0.0 (15)` vom 07.09.2026, Upload abgeschlossen, interne Gruppe „FYRUP Intern“ zugeordnet. Die neue Revision aus #70 ist noch nicht hochgeladen. Keine Tester, Gruppen oder öffentliche Einreichung verändert; installierte Version auf dem physischen iPhone weiterhin nicht direkt abgelesen.
