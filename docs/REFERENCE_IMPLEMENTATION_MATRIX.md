# FYRUP – Funktionsmatrix zur ausgewählten Vorlage

Stand: 08.09.2026, erster Referenz-Prüfpunkt in Arbeit. FEHLT / TEILWEISE / IMPLEMENTIERT / GETESTET / BLOCKIERT beziehen sich auf den neuen Auftrag. Bestehende historische CI-Nachweise sind keine Prüfung dieser neuen Gestaltung. Einzelne gerätegebundene Teile bleiben auch bei funktionierendem Quellstand NICHT GETESTET. Details, Kosten und Fortsetzung: [Arbeitsnachweis](REFERENCE_CHECKPOINT_2026_09_08.md).

Neue lokale Folgeblöcke nach `e39caf6`: [Einrichtung und kompaktere Übersichten](REFERENCE_LOCAL_SETUP_2026_09_08.md), danach [E-Mail-Anmeldung/Recovery, Supplement-Mengen und Veröffentlichungsvoraussetzungen](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md), Migrationen 018/019. **Kein nativer Nachweis für diese Arbeitskopie**, kein neuer bezahlter Lauf. „Im Code“ ist nicht „auf dem iPhone abgenommen“.

## Bestand

Native SwiftUI-App, iOS 17+, Swift 6, XcodeGen; Bundle `app.fyrup.ios`, Widget `app.fyrup.ios.live`. Supabase mit REST/Auth und Migrationen 001–016, bestehende Accounts/Daten bleiben bestehen. Separater SecureSessionStore, private Keychain-Einstellungen, serverseitige RPC-/RLS-Tests. HealthKit liest Schritte und bisher optional aktive Energie; APNs, ActivityKit/App Group, gezielte Kontaktauswahl und Kartenort existieren. WeatherKit, Google OAuth und Ernährung sind im Bestand nicht vorhanden.

Assets: 11 benannte Bildgruppen plus App-Icon, 122 katalogisierte Übungen mit strukturierten Muskelzuordnungen. Der genaue Asset-/Lizenznachweis und neue Originalmotive sind offen. 26 ausgeschnittene Referenzen sind getrennt von sieben echten Simulatorbildern aus #67 abgelegt. Kein lokales Xcode/Swift vorhanden. Alle 21 lokalen Preflight-Gruppen bestanden, darunter 12 PostgreSQL-Programme und Vergleichswerkzeug-/Konfigurationsprüfungen. **Native QA #67 auf `e39caf6`: 495 Unit-Tests und 3/3 ausgewählte UI-Tests PASS.** Bildkontrolle bleibt TEILWEISE, keine vollständige Produkt- oder Geräteabnahme. Codemagic-YAML verwendet manuelle Meilensteine, Xcode 26.6, separat gewählte installierte iOS-Laufzeit und getrennte QA/Release-Wege. Vier neue Läufe beendet, kein Lauf aktiv; konservativ **2,61 USD** von höchstens 10 USD inklusive MwSt. verbraucht. Keine weitere kostenpflichtige Wiederholung für einzelne Layoutkorrekturen. Siehe [QA #67](REFERENCE_QA_67.md) und [Laufbuch](CI_BUDGET_2026_09.md).

## Registrierung

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| R01 | Willkommen | TEILWEISE | Neuer direkter Einstieg im Code; genaue Bergvorlage und Lizenznachweis offen. Eigene FYRUP-Rechtstexte fehlen: vorhandener Website-Link ist ausdrücklich nicht die FYRUP-Erklärung |
| R02 | Anmeldeart | TEILWEISE | Apple/E-Mail vorhanden; Supabase-Dashboard am 08.09. live gelesen: Apple/E-Mail Enabled, Google Disabled. Keine Anbietereinstellung geändert. Google-OAuth-Konfiguration fehlt weiterhin |
| R03 | E-Mail/Passwort | TEILWEISE | Sichtbar/unsichtbar, Inline-Rückmeldungen, Backend-Regelabgleich (6 Zeichen/keine Zeichenklassen) im Code. Native Abnahme und echter Versand offen |
| R03a | Bestätigung | TEILWEISE | Eigene maskierte Bestätigungsseite, 60s-Abstand, Adresswechsel und gerätegebundener PKCE-Callback im Code; exakte Supabase-Rückkehradresse produktiv geprüft. SMTP und echte Zustellung offen |
| R03b | Login | TEILWEISE | Bestehende Auth-/Wiederherstellung prüfen; neues Layout |
| R03c | Reset | TEILWEISE | Separater PKCE-Recovery-Zustand/Passwortseite ohne Hauptkonto-Aktivierung im Code, 7 Auth-Tests vorbereitet. Nativer und echter Mail-/iPhone-Nachweis offen |
| R04 | Persönliche Angaben | TEILWEISE | Profilfelder/Foto neu angeordnet, optionales privates Geburtsjahr, Tastaturcontainer/feste Aktion im Code; native Prüfung offen |
| R05 | Körperdaten | TEILWEISE | #67 belegt den vorherigen Editor. Danach lokal: Zahlenformat ohne .0, Komma ohne Rundungsverlust, neuer benannter Ablauf/Zurückweg. Neue native Bildprüfung offen |
| R06 | Hauptziel | TEILWEISE | Vier echte Karten mit privater Speicherung, keiner Vorauswahl, Zurück/Summary-Bearbeitung im Code; native Tests/Bilder offen |
| R07 | Weitere Ziele | TEILWEISE | Vier Mehrfachauswahlkarten gespeichert, keine Freigaben durch Zielauswahl; native Tests/Bilder offen |
| R08 | Wochenziel | TEILWEISE | Neue Auswahl 2–7 ohne Standardauswahl, echte Bestätigung/Folgewochenänderung. 017/018 lokal geprüft, NICHT produktiv; native Abnahme offen |
| R09 | Wochentage | TEILWEISE | Separate Mehrfachauswahl/Unterschiedlich im Code, ISO-Reihenfolge und kontogetrennte Speicherung; keine automatischen Termine. Native Abnahme offen |
| R10 | Uhrzeit | TEILWEISE | Vier echte Vorlieben-Karten mit Speicherung, keine Push-Erlaubnis durch Auswahl; native Abnahme offen |
| R11 | Supplements | TEILWEISE | Echtes Auswahlraster, bestehende private Einträge, eigene Menge/Einheit und Zeiten im Code. Keine Dosierungsvorgabe oder pauschale Zustimmung. Native Referenzprüfung offen |
| R11a | Eigener Eintrag | TEILWEISE | Optionales Mengenfeld mit eigener Einheit, Validierung und Altclient-Schutz; Migration 019 lokal geprüft, noch nicht produktiv |
| R12 | Ernährung aktivieren | TEILWEISE | Eigener Schritt mit echtem Ziel-Editor/Überspringen angeschlossen, keine 2500-Vorgabe; native Abnahme offen |
| R13 | Schritte | TEILWEISE | Eigener freiwilliger Health-/Zielschritt; Schutz vor Löschen noch nicht geladener Ziele, Freunde-Freigabe separat R15. Native Rechteprüfung offen |
| R14 | Rechte/Ort | TEILWEISE | Einzeln bedienbare echte Unterseiten für Wetterort, Mitteilungen, LIVE/Satzpausen im Ablauf; kein Alle-erlauben. Native Rechteprüfung offen |
| R15 | Privatsphäre | TEILWEISE | Echte bestätigte Aktivitäts-/Schritte-Freigaben im neuen Ablauf. Neue Profile standardmäßig privat mit 018. Ernährungs-/Stadtfreigabe fehlt |
| R16 | Freunde finden | TEILWEISE | Neue Anordnung mit Suche/Profil-Link/Einzelkontakt im Code; späte Suchantworten abgesichert. Native Integration offen |
| R17 | Erste Einheit | TEILWEISE | Drei Aktionen im Code: echter Start-/Planungsdialog erst nach Abschluss oder Heute; keine automatisch gestartete Aktivität. Native Abnahme offen |
| R18 | Zusammenfassung | TEILWEISE | Tatsächlich gespeicherte Entscheidungen und Rücksprung zum Bearbeiten im Code, nächste Woche getrennt; native Abnahme offen |

## Haupt-/Detailseiten

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| A01 | Heute | TEILWEISE | #67 belegt vorherige Reihenfolge/Rechenwerte/Navigation. Danach lokal kleinere Ringe/Abstände, kompakte Crew-Köpfe, breitere Supplement-Texte. Neue Bild-/Großschriftprüfung offen |
| A02 | Wochenplan | TEILWEISE | Neuer eigener Tab mit Diese/Nächste Woche, Tagesdetails und realen Daten; native Funktions-/Layoutabnahme offen |
| A03–04 | Plus/Sport/Unterkategorien | TEILWEISE | Bestehende Flows; Layout und Kampfsportdimensionen prüfen |
| A05–09 | Pläne/Bibliothek/eigene Übungen | TEILWEISE | Kernpfade und Historie vorhanden; neue Darstellung, Zeitvorgaben prüfen |
| A10–11 | Planen/Einladen/Antworten | TEILWEISE | Kernpfade vorhanden; Änderungsbestätigung/Privatsphäre abnehmen |
| A12–13 | LIVE/Abschluss | TEILWEISE | Timer/Sätze/Pause vorhanden; Hierarchie, Offlinekorrektur, echte Abnahme |
| A14–15 | Crew/Social | TEILWEISE | Freundschaften, FYR UP, Mitziehen vorhanden; Limits/Entzug neu prüfen |
| A16 | Flamme/Streak | TEILWEISE | Serverlogik vorhanden; Mindestziel 2 und nachträgliche Korrekturen |
| A17 | Call My Shot | TEILWEISE | Kernpfad vorhanden; neues Mindestziel/Sichtbarkeit |
| A18 | Blind Workout | TEILWEISE | Reveal vorhanden; freiwillig vollständig ansehen/ersetzen ergänzen |
| A19 | Ernährungstagebuch | TEILWEISE | Aufnahme/Restziel/Makros aus privater kontogetrennter lokaler Datei. Nach #67 vier kompakte Mahlzeitenzeilen und echte Detailbearbeitung im Code; Mengenänderung/Heute-Abgleich als UI-Test vorbereitet. Neue native Abnahme, Cloud-Sync, Kopieren/Export offen |
| A20 | Lebensmittel/Barcode | TEILWEISE | Manueller pro-100-g-Eintrag mit Grammrechnung vorhanden; Anbieter/Lizenz, Suche, Favoriten und Barcode fehlen |
| A21 | Lebensmittel/Rezepte | FEHLT | Nährwertbasis, Zutaten, Portionen, Kopien/Sharing |
| A22 | Supplements | TEILWEISE | Speicherung/Rückgängig sowie private Menge/Einheit im Code; 019 produktiv, neue native Abnahme und Tagesnavigation noch offen |
| A23 | Schritte | TEILWEISE | Aggregate/Opt-in/Widerruf vorhanden; neuer Tageszugang |
| A24 | Entdecken | TEILWEISE | Bisher Sportkacheln, echte Inhalte und neue Anordnung fehlen |
| A25 | Profil | TEILWEISE | Körperdaten, Ernährung, Crew sowie LIVE/Satzpausen von dort erreichbar; vollständiges Referenzlayout und Kennzahlenabnahme offen |
| A26 | Mitteilungen | TEILWEISE | Routing/Lesestatus vorhanden; Regression nötig |
| A27 | Konto/Hilfe | TEILWEISE | Logout/Löschung/Support vorhanden; Export und Recovery prüfen |
| W01 | WeatherKit | TEILWEISE | Capability + App Service bei bestehender Apple-ID aktiviert, bestehendes Profil erneuert und nach Codemagic importiert. Swift-Reader, Stadt, Attribution, Cache/Backoff/Fehler und Fixture-Tests vorhanden. Echte Antwort, Signierungsbytes, TestFlight und Standortdialog NICHT GETESTET |
| QA01 | Render-Vergleich | TEILWEISE | Sieben echte PNGs aus #67 geprüft, proportionale Vergleiche A01/R05/A19 vorhanden. Frühere Identifier-/Safe-Area-/Footerfehler korrigiert, Restabweichungen explizit in REFERENCE_QA_67.md; keine Pixelgleichheit oder Gesamtfreigabe |
| QA02 | Geräte-/Mehrkontenprüfung | BLOCKIERT | Kein steuerbares physisches iPhone; NICHT GETESTET |
| CI01 | Kostenkontrollierte QA | TEILWEISE | Vier manuelle Läufe abgeschlossen, letzter PASS; insgesamt konservativ 2,61 USD, Rest 7,39 USD. Keine aktive Wiederholung/kein Archiv. Weitere Änderungen lokal bündeln; Laufbuch CI_BUDGET_2026_09.md |

## Arbeitsreihenfolge

1. Referenzzuordnung/Design-Tokens; Heute und repräsentative Registrierung.
2. Ernährungsdaten strikt von aktiver Energie trennen, sichere Speicherung/Tests; Wochenzielmigration.
3. Erster nativer A01/R05-Prüfpunkt #67 bestanden, sieben echte Bilder geprüft. Verbleibende gemeinsame Layoutkorrekturen lokal bündeln, keinen einzelnen kosmetischen Änderungsstand erneut kostenpflichtig bauen.
4. Danach vollständiger 18-Seiten-Einrichtungsfluss und verbleibende Seiten; Google/Datenanbieter, Ernährungssynchronisierung und Freigaben ergänzen. Vorhandene UI-Regressionspfade weiter an neue Navigation anpassen, nicht einfach löschen.
5. Vollständige native Regression, Mehrkonten-/RLS- und Geräteabnahme; erst danach signiertes Archiv.

Apple-Video und erneute Einreichung sind auf Nutzeranweisung bis zur Korrektur zurückgestellt. Keine unkontrollierten kostenpflichtigen Wiederholungen.
