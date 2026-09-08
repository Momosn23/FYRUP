# Native QA #70 – gebündelter Prüfstand

08.09.2026, [Codemagic #70](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa050523ffb6b3dd927bc2d), exakt `704674e971469f1b0be98f4dceb13bd04d779f56`. GitHub-main und Dashboard-Checkout vor beziehungsweise nach Start unabhängig bestätigt. Start 20:13 CEST, Gesamtdauer **12m22s**, Status **FAIL**. Keine Wiederholung und kein Apple-Upload.

## Prüfauftrag

- Alle nativen Unit-Tests, einschließlich der neuen Netzwerk-, Such- und Profilfälle.
- Zwölf gezielte Referenz-Bedienfälle: Heute, Wetter, Körperdaten, lokale Ernährung, Einrichtung/Supplements, Entdecken und Profil; normale und große Schrift.
- Echte Simulator-PNGs und Accessibility-Hierarchien zur anschließenden visuellen Kontrolle.
- Lokaler Vorprüfstand: 21/21 Prüfgruppen PASS vom 08.09.2026 17:59:38 UTC; ersetzt nicht die nun gestartete native Ausführung.

Der Workflow `ios-cloud-validation` verwendet Mac mini M2, festes Xcode 26.6 und einen vorhandenen iPhone-16/15-Simulator. Harte Jobgrenze 30 Minuten, keine automatische Wiederholung. Nicht die komplette frühere UI-Testsammlung und keine physischen iPhone-Tests. Ergebnis, genaue native Testzahlen und Bilder nach Abschluss getrennt protokollieren.

## Kosten und Freigabe

Die vorherige Reserve von 3,40 USD ist durch konservativ auf 13 Minuten aufgerundete **1,47 USD brutto** ersetzt; verbleibend 2,64 USD, [Budgetlaufbuch](CI_BUDGET_2026_09.md). TestFlight-Archiv erst nach passendem grünem Prüfergebnis, Bildkontrolle und erneuter Budgetprüfung. Echte Netzwerkwechsel, Health/WeatherKit, Mailzustellung und iPhone-/TestFlight-Abnahme weiterhin **NICHT AUSGEFÜHRT**.

## Belegter Fehler und lokale Folgekorrektur

Der im Dashboard gezeigte Fehler ist `DiscoveryContentTests.testPlanSearchUsesOnlyOwnPlansAndTheirExerciseMetadata`, Zeile 36. Die Suche nach „Rücken“ findet fälschlich einen Push-Plan mit „Bankdrücken“, weil die normalisierte Folge `rucken` innerhalb von `bankdrucken` liegt. Der Test wird nicht abgeschwächt. Die gemeinsame Suche für Übungen und Entdecken berücksichtigt im Folgecode Wortanfänge: echte Muskelbegriffe/Übungsaliase sowie Präfixe bleiben auffindbar, irreführende Treffer mitten im Wort entfallen. Zwei weitere native Tests für Wortgrenzen, Präfixe und Satzzeichen vorbereitet; noch nicht erneut nativ ausgeführt.

Xcode 26.6 (17F113), iPhone 16 / iOS 26.5 aus dem Runner-Bericht bestätigt. Simulator-App und 113,92-MB-Artefaktpaket vorhanden. Der geschützte ZIP-Download ist im automatisierten Browser nicht zugänglich; ein offizieller Download ohne Zugangsdaten wurde vom Server mit 403 abgelehnt. Keine Cookies oder anderen Zugangsdaten ausgelesen. Nutzer um Bereitstellung des Pakets gebeten. **Vollständige Testzahlen, einzelne neue Netzwerk-Testergebnisse und visuelle Bildkontrolle bleiben bis zur Auswertung offen.** Keine Vollabnahme aus dem verkürzten Fehlerauszug ableiten.

Lokale Schlussprüfung der gemeinsamen Wortanfangssuche am 08.09.2026 um **18:34:26 UTC: 21/21 Preflight-Gruppen PASS**. Die zwei neuen Swift-Tests und die beibehaltene fehlgeschlagene Assertion sind dadurch nicht nativ ausgeführt. Kein weiterer bezahlter Lauf angelegt; vor einer Wiederholung vollständige Artefakte auswerten und das Joblimit an die verbleibenden 2,64 USD anpassen.

## Apple-Vorkontrolle

Der Nutzer hat die abgelaufene Apple-Browsersitzung eigenständig erneuert. App Store Connect für App `6808742803` frisch lesend bestätigt: neuester vorhandener Upload `1.0.0 (15)` vom 07.09.2026, Upload abgeschlossen, interne Gruppe „FYRUP Intern“ zugeordnet. Die neue Revision aus #70 ist noch nicht hochgeladen. Keine Tester, Gruppen oder öffentliche Einreichung verändert; installierte Version auf dem physischen iPhone weiterhin nicht direkt abgelesen.
