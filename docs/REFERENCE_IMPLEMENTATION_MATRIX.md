# FYRUP – Funktionsmatrix zur ausgewählten Vorlage

Stand: 08.09.2026, erster Referenz-Prüfpunkt in Arbeit. FEHLT / TEILWEISE / IMPLEMENTIERT / GETESTET / BLOCKIERT beziehen sich auf den neuen Auftrag. Bestehende historische CI-Nachweise sind keine Prüfung dieser neuen Gestaltung. Einzelne gerätegebundene Teile bleiben auch bei funktionierendem Quellstand NICHT GETESTET. Details, Kosten und Fortsetzung: [Arbeitsnachweis](REFERENCE_CHECKPOINT_2026_09_08.md).

## Bestand

Native SwiftUI-App, iOS 17+, Swift 6, XcodeGen; Bundle `app.fyrup.ios`, Widget `app.fyrup.ios.live`. Supabase mit REST/Auth und Migrationen 001–016, bestehende Accounts/Daten bleiben bestehen. Separater SecureSessionStore, private Keychain-Einstellungen, serverseitige RPC-/RLS-Tests. HealthKit liest Schritte und bisher optional aktive Energie; APNs, ActivityKit/App Group, gezielte Kontaktauswahl und Kartenort existieren. WeatherKit, Google OAuth und Ernährung sind im Bestand nicht vorhanden.

Assets: 11 benannte Bildgruppen plus App-Icon, 122 katalogisierte Übungen mit strukturierten Muskelzuordnungen. Der genaue Asset-/Lizenznachweis und neue Originalmotive sind offen. 26 Referenzscreens sind ausgeschnitten, keine neuen App-Renderings. Kein lokales Xcode/Swift vorhanden. Der lokale Preflight umfasst jetzt 21 Prüfgruppen, darunter 12 PostgreSQL-Programme und Vergleichswerkzeug-/Konfigurationsprüfungen. Die bisherigen 20 Gruppen sowie die vier neu hinzugefügten Simulatorauswahlfälle bestanden lokal. Neue Swift-/UI-Tests sind geschrieben; noch kein bestandenes natives Ergebnis. Codemagic-YAML ist auf manuelle Meilensteine, Xcode 26.6 und getrennte QA/Release-Wege umgestellt; pauschaler DerivedData-Cache entfernt. `451ad09` und die Runner-Korrektur `ce071d0` sind auf main gepusht. Tarif live geprüft: 0,095 USD/M2-Minute plus 19 % MwSt.; freies macOS-Kontingent verbraucht. Erstlauf stoppte nach 1m24s vor der Kompilierung; zweiter Lauf auf nachgewiesenem `ce071d0` läuft. Neues Gesamtbudget: höchstens 10 USD inklusive MwSt.; siehe Laufbuch.

## Registrierung

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| R01 | Willkommen | TEILWEISE | Alte dreiteilige Einführung, neues Layout/Links nötig; Originalmotiv fehlt |
| R02 | Anmeldeart | TEILWEISE | Apple/E-Mail vorhanden; Google-Provider fehlt |
| R03 | E-Mail/Passwort | TEILWEISE | Sichtbarkeit, Backend-Regelabgleich, Feldfehler |
| R03a | Bestätigung | TEILWEISE | Eigene Bestätigungsseite/Limit/Korrekturweg fehlen |
| R03b | Login | TEILWEISE | Bestehende Auth-/Wiederherstellung prüfen; neues Layout |
| R03c | Reset | TEILWEISE | Versand existiert; vollständiger Recovery-Deep-Link-Flow offen |
| R04 | Persönliche Angaben | TEILWEISE | Foto/Name/Username vorhanden; Neuordnung/Privatsphäre prüfen |
| R05 | Körperdaten | TEILWEISE | Neue freiwillige Felder, gemeinsamer Editor; native Bedien-Tests bestanden. Tatsächliche Großschrift-Bilder zeigen Footer-/Umbruchmängel; Korrektur und strengerer Test vorbereitet. Siehe REFERENCE_QA_65.md |
| R06 | Hauptziel | FEHLT | Vier persistente Auswahlkarten |
| R07 | Weitere Ziele | FEHLT | Optionale Mehrfachauswahl |
| R08 | Wochenziel | TEILWEISE | App-Grenze 2–7; Migration 017 lokal mit Datenbestand, RLS und Wiederholung geprüft. NICHT produktiv angewendet; neues Referenzlayout offen |
| R09 | Wochentage | TEILWEISE | Bisher sportgebundene Routine; freie Vorliebe fehlt |
| R10 | Uhrzeit | FEHLT | Persistente optionale Zeitpräferenz |
| R11 | Supplements | TEILWEISE | Eigene Liste vorhanden, neuer Einrichtungsschritt fehlt |
| R11a | Eigener Eintrag | TEILWEISE | Mengen/Einheiten und optionale Zeiten fehlen teilweise |
| R12 | Ernährung aktivieren | TEILWEISE | Manuelle eigene Aufnahme-/Makroziele erreichbar; eigenständiger R12-Einrichtungsschritt und vollständiger Onboardingfluss offen |
| R13 | Schritte | TEILWEISE | Health und Schrittziel jetzt ohne Pflichtwerte überspringbar; bestehende separate Freunde-Freigabe bleibt. Eigene R13-Referenzseite offen |
| R14 | Rechte/Ort | TEILWEISE | Separate manuelle Stadt-/optionale Standortansicht ergänzt. LIVE/Satzpausen in eigene Unterseite ausgelagert. Native Rechteprüfung und fertiger R14-Fluss offen |
| R15 | Privatsphäre | TEILWEISE | Aktivität/Schritte vorhanden; Ernährungs-/Stadtfreigabe fehlt |
| R16 | Freunde finden | TEILWEISE | Suche/Link/Einzelkontakt vorhanden; neue Einrichtungsanordnung |
| R17 | Erste Einheit | FEHLT | Drei optionale echte Folgeaktionen |
| R18 | Zusammenfassung | TEILWEISE | Bestehender Erfolg ohne editierbare echte Zusammenfassung |

## Haupt-/Detailseiten

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| A01 | Heute | TEILWEISE | Neue echte Produktions-View: Logo/Datum/Wetter, gemeinsame Tagesmetriken, Wochentage, Supplements vor kleinen Crew-Karten; großer Hero entfernt. Fester Fixture-Zustand und UI-Test vorbereitet, NICHT gerendert/abgenommen |
| A02 | Wochenplan | TEILWEISE | Neuer eigener Tab mit Diese/Nächste Woche, Tagesdetails und realen Daten; native Funktions-/Layoutabnahme offen |
| A03–04 | Plus/Sport/Unterkategorien | TEILWEISE | Bestehende Flows; Layout und Kampfsportdimensionen prüfen |
| A05–09 | Pläne/Bibliothek/eigene Übungen | TEILWEISE | Kernpfade und Historie vorhanden; neue Darstellung, Zeitvorgaben prüfen |
| A10–11 | Planen/Einladen/Antworten | TEILWEISE | Kernpfade vorhanden; Änderungsbestätigung/Privatsphäre abnehmen |
| A12–13 | LIVE/Abschluss | TEILWEISE | Timer/Sätze/Pause vorhanden; Hierarchie, Offlinekorrektur, echte Abnahme |
| A14–15 | Crew/Social | TEILWEISE | Freundschaften, FYR UP, Mitziehen vorhanden; Limits/Entzug neu prüfen |
| A16 | Flamme/Streak | TEILWEISE | Serverlogik vorhanden; Mindestziel 2 und nachträgliche Korrekturen |
| A17 | Call My Shot | TEILWEISE | Kernpfad vorhanden; neues Mindestziel/Sichtbarkeit |
| A18 | Blind Workout | TEILWEISE | Reveal vorhanden; freiwillig vollständig ansehen/ersetzen ergänzen |
| A19 | Ernährungstagebuch | TEILWEISE | Aufnahme/Restziel/Makros/Mahlzeiten aus denselben Einträgen; private kontogetrennte lokale Datei, manuell anlegen/bearbeiten/löschen. Cloud-Sync, Kopieren/Export und native Tests fehlen |
| A20 | Lebensmittel/Barcode | TEILWEISE | Manueller pro-100-g-Eintrag mit Grammrechnung vorhanden; Anbieter/Lizenz, Suche, Favoriten und Barcode fehlen |
| A21 | Lebensmittel/Rezepte | FEHLT | Nährwertbasis, Zutaten, Portionen, Kopien/Sharing |
| A22 | Supplements | TEILWEISE | Speicherung/Rückgängig vorhanden; Mengen und Tagesnavigation |
| A23 | Schritte | TEILWEISE | Aggregate/Opt-in/Widerruf vorhanden; neuer Tageszugang |
| A24 | Entdecken | TEILWEISE | Bisher Sportkacheln, echte Inhalte und neue Anordnung fehlen |
| A25 | Profil | TEILWEISE | Körperdaten, Ernährung, Crew sowie LIVE/Satzpausen von dort erreichbar; vollständiges Referenzlayout und Kennzahlenabnahme offen |
| A26 | Mitteilungen | TEILWEISE | Routing/Lesestatus vorhanden; Regression nötig |
| A27 | Konto/Hilfe | TEILWEISE | Logout/Löschung/Support vorhanden; Export und Recovery prüfen |
| W01 | WeatherKit | TEILWEISE | Capability + App Service bei bestehender Apple-ID aktiviert, bestehendes Profil erneuert und nach Codemagic importiert. Swift-Reader, Stadt, Attribution, Cache/Backoff/Fehler und Fixture-Tests vorhanden. Echte Antwort, Signierungsbytes, TestFlight und Standortdialog NICHT GETESTET |
| QA01 | Render-Vergleich | TEILWEISE | Vier echte R05-Bilder aus #65 geprüft; normaler Vergleich erstellt, visuelle Großschrift-Abnahme nicht bestanden. A01 scheiterte vor Export an geerbter Navigationskennung; gemeinsame Korrekturen vorbereitet |
| QA02 | Geräte-/Mehrkontenprüfung | BLOCKIERT | Kein steuerbares physisches iPhone; NICHT GETESTET |
| CI01 | Kostenkontrollierte QA | TEILWEISE | Konto/Tarif geprüft, YAML geparst, 30-Minuten-Prüfpunkt/60-Minuten-Vollregression ohne Auto-Retry eingerichtet. 10 USD inklusive MwSt. freigegeben; ein früher Runner-Fehler beendet, zweiter korrigierter Lauf aktiv. Laufbuch: CI_BUDGET_2026_09.md |

## Arbeitsreihenfolge

1. Referenzzuordnung/Design-Tokens; Heute und repräsentative Registrierung.
2. Ernährungsdaten strikt von aktiver Energie trennen, sichere Speicherung/Tests; Wochenzielmigration.
3. Nach Budgetentscheidung lokalen Stand pushen, genau einen begrenzten A01/R05-Simulatorlauf ausführen und echte Bilder prüfen. Gemeinsame Komponenten zuerst korrigieren.
4. Danach vollständiger 18-Seiten-Einrichtungsfluss und verbleibende Seiten; Google/Datenanbieter, Ernährungssynchronisierung und Freigaben ergänzen. Vorhandene UI-Regressionspfade weiter an neue Navigation anpassen, nicht einfach löschen.
5. Vollständige native Regression, Mehrkonten-/RLS- und Geräteabnahme; erst danach signiertes Archiv.

Apple-Video und erneute Einreichung sind auf Nutzeranweisung bis zur Korrektur zurückgestellt. Keine unkontrollierten kostenpflichtigen Wiederholungen.
