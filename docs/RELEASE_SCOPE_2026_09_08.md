# FYRUP – verbindliche Umfangsänderung vom 08.09.2026

Nutzerentscheidung nach der offenen Sieben-Punkte-Liste: „Lass den 2. Punkt für eine spätere version. 4. Google anmelden muss nicht sein lass es komplett raus.“ Diese Entscheidung hat für den aktuellen Release Vorrang vor älteren Aufträgen, Collagen und Prüfberichten.

## Auf eine spätere Version verschoben

Diese Erweiterungen sind nicht erledigt, aber keine Voraussetzungen mehr für den aktuellen Release:

- [ ] Lebensmittelanbieter und Lebensmittelsuche einschließlich Katalog/Favoriten.
- [ ] Barcode-Erfassung und zugehörige Nährwertdaten.
- [ ] Rezepte, Zutaten/Portionen und zugehörige Kopier-/Teilen-Funktionen.
- [ ] Geräteübergreifende Synchronisierung des Ernährungstagebuchs.

Keine Umsetzung, Anbieterbuchung oder zusätzliche Build-Runde für diesen Folgeversionsblock im aktuellen Auftrag. Eine spätere Wiederaufnahme braucht einen neuen Auftrag. Insbesondere keine Suche-, Barcode- oder Rezeptaktionen als bereits verfügbar darstellen.

## Vollständig gestrichen

Google-Anmeldung entfällt aus dem Produktauftrag, nicht nur aus diesem Release. Keine Google-Schaltfläche, Integration oder offene Google-Freigabe mehr vorsehen. Die App bietet Apple und E-Mail an. Eine spätere Google-Einführung wäre ein neuer ausdrücklicher Auftrag.

Der bisher geprüfte App-Code enthält bereits keine Google-Integration und keinen Google-Button; die vorhandene Negativprüfung wird nun mit dieser dauerhaften Produktentscheidung begründet. Produktionskonfiguration, Konten, Schlüssel und Sitzungen werden dafür nicht verändert oder gelöscht.

## Im aktuellen Release erhalten

- Privates lokales manuelles Ernährungstagebuch mit vorhandenen Einträgen, Mengen, Kalorien, Makros, Tageszielen und Anzeige auf Heute.
- Klare Kennzeichnung der lokalen Speicherung; keine Mehrgeräte-Synchronisierung versprechen. Ernährungsaufnahme und aktive Energie bleiben getrennt.
- Apple-/E-Mail-Anmeldung sowie funktionierende Bestätigungs- und Passwort-Mails. Der Versand über das freigegebene Kundenservice-Postfach bleibt offen.
- Verbleibende Design-, Freigabe-, Export-, Datenschutz-, Funktions- und Geräteprüfungen. Der allgemeine Datenexport wird durch das Verschieben der Ernährungserweiterungen nicht gestrichen.
- WeatherKit, Health, Kontakte, LIVE-Anzeige und die übrigen nicht abgewählten Anforderungen.

## Nachweis und Umgang mit älteren Listen

Aktuelle [Funktionsmatrix](REFERENCE_IMPLEMENTATION_MATRIX.md), [Produktcheckliste](PRODUCT_CHECKLIST.md) und [Designregeln](DESIGN_2026_09_SPEC.md) führen diese Abgrenzung. Historische Prüfberichte bleiben Belege für ihre damalige Revision; dort noch genannte Google-/Ernährungserweiterungen sind kein aktueller Release-Blocker. Bestehende Nutzerdaten und Ernährungsfunktionen bleiben unverändert. Diese Umfangsänderung ist weder eine vollständige Produktabnahme noch ein neuer nativer Testnachweis.

Lokale Kontrolle: App-/Konfigurationssuche bestätigt keine Google-Implementierung; nur erklärender Kommentar und Negativtest angepasst. Sprachprüfung über 134 App-Textdateien sowie `git diff --check` bestanden. Die erweiterte native Negativprüfung ist hier nicht ausgeführt (Windows ohne Xcode). Kein kostenpflichtiger Build, keine Anbieteränderung und kein Apple-Upload für diese Umfangsänderung.
