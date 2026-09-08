# FYRUP – Funktionsmatrix zur ausgewählten Vorlage

Stand: 08.09.2026, erster Referenz-Prüfpunkt in Arbeit. FEHLT / TEILWEISE / IMPLEMENTIERT / GETESTET / BLOCKIERT beziehen sich auf den neuen Auftrag. Bestehende historische CI-Nachweise sind keine Prüfung dieser neuen Gestaltung. Einzelne gerätegebundene Teile bleiben auch bei funktionierendem Quellstand NICHT GETESTET. Details, Kosten und Fortsetzung: [Arbeitsnachweis](REFERENCE_CHECKPOINT_2026_09_08.md).

Folgeblöcke nach `e39caf6`: [Einrichtung und kompaktere Übersichten](REFERENCE_LOCAL_SETUP_2026_09_08.md), [E-Mail-Anmeldung/Recovery und Supplement-Mengen](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md). [QA #68](REFERENCE_QA_68.md) prüfte `4679d89`: **510/511 Unit-Tests und 5/7 Referenz-UI-Tests PASS**, Gesamtstatus FAIL. Drei Testfehler in der Arbeitskopie korrigiert, noch kein Folgelauf. [017–019 produktiv nachgeprüft](REFERENCE_BACKEND_2026_09_08.md). „Im Code“ ist nicht „auf dem iPhone abgenommen“.

## Bestand

Native SwiftUI-App, iOS 17+, Swift 6, XcodeGen; Bundle `app.fyrup.ios`, Widget `app.fyrup.ios.live`. Supabase mit REST/Auth und Migrationen 001–016, bestehende Accounts/Daten bleiben bestehen. Separater SecureSessionStore, private Keychain-Einstellungen, serverseitige RPC-/RLS-Tests. HealthKit liest Schritte und bisher optional aktive Energie; APNs, ActivityKit/App Group, gezielte Kontaktauswahl und Kartenort existieren. WeatherKit, Google OAuth und Ernährung sind im Bestand nicht vorhanden.

Assets: 11 benannte Bildgruppen plus App-Icon, 122 katalogisierte Übungen mit strukturierten Muskelzuordnungen. Asset-/Lizenznachweis und neue Originalmotive offen. 26 ausgeschnittene Referenzen sind getrennt von sieben Simulatorbildern aus #67 und 17 aus #68 abgelegt. Kein lokales Xcode/Swift. Alle 21 lokalen Preflight-Gruppen bestanden. Neue Bildkontrolle **TEILWEISE**, konkrete Restabweichungen in [QA #68](REFERENCE_QA_68.md). Letzter vollständig grüner älterer Stand #67 (`e39caf6`), aktueller Stand #68 FAIL. Codemagic verwendet manuelle Meilensteine und getrennte QA/Release-Wege. Fünf Läufe beendet, keiner aktiv; konservativ **4,08 USD** verbraucht, **5,92 USD** übrig. Keine Wiederholung einzelner kosmetischer Änderungen. [Laufbuch](CI_BUDGET_2026_09.md).

## Registrierung

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| R01 | Willkommen | TEILWEISE | Neuer direkter Einstieg im Code; genaue Bergvorlage und Lizenznachweis offen. Eigene FYRUP-Rechtstexte fehlen: vorhandener Website-Link ist ausdrücklich nicht die FYRUP-Erklärung |
| R02 | Anmeldeart | TEILWEISE | Apple/E-Mail vorhanden; Supabase-Dashboard am 08.09. live gelesen: Apple/E-Mail Enabled, Google Disabled. Keine Anbietereinstellung geändert. Google-OAuth-Konfiguration fehlt weiterhin |
| R03 | E-Mail/Passwort | TEILWEISE | #68: Sichtbarkeit/Formularwechsel und getrennte Passwörter PASS; echter Versand/Fehlermeldungen und Referenzlayout offen |
| R03a | Bestätigung | TEILWEISE | Eigene maskierte Bestätigungsseite, 60s-Abstand, Adresswechsel und gerätegebundener PKCE-Callback im Code; exakte Supabase-Rückkehradresse produktiv geprüft. SMTP und echte Zustellung offen |
| R03b | Login | TEILWEISE | Bestehende Auth-/Wiederherstellung prüfen; neues Layout |
| R03c | Reset | TEILWEISE | Separater Recovery-Zustand; alle 7 Auth-Tests in #68 PASS. Echte Mail-Zustellung, Mail-App und iPhone offen |
| R04 | Persönliche Angaben | TEILWEISE | Profilfelder/Foto neu angeordnet, optionales privates Geburtsjahr, Tastaturcontainer/feste Aktion im Code; native Prüfung offen |
| R05 | Körperdaten | TEILWEISE | #68: Normal-/Tastatur-/Großschriftbilder geprüft; Speichern/Zurück mit 182 cm und Zielgewicht-Erreichbarkeit PASS. Ganze Einrichtungs-/Geräteabnahme offen |
| R06 | Hauptziel | TEILWEISE | Auswahl und Summary-Bearbeitung in #68 PASS. PNG/AX-Übergang beim Häkchen auffällig; stabile Aufnahme und kompakteres Referenzlayout offen |
| R07 | Weitere Ziele | TEILWEISE | Mehrfachauswahl in #68 PASS/Bild geprüft; keine Freigabe durch Zielauswahl. Untertexte/Abstände noch nicht referenzgleich |
| R08 | Wochenziel | TEILWEISE | 2–7; 017/018 produktiv. #68 zeigt bestätigtes Bestandsziel, kein Neuregistrierungsdefault. Neuer Unit-Test korrigiert; runde Referenzauswahl und vollständige native Abnahme offen |
| R09 | Wochentage | TEILWEISE | #68: Mo/Sa-Auswahl und Summary PASS, Bild geprüft. Runde Referenz-Auswahl statt großer Kacheln noch offen; keine automatischen Termine |
| R10 | Uhrzeit | TEILWEISE | #68: Unterschiedlich gespeichert, Bild geprüft. Abstände/Untertexte noch nicht referenzgleich; keine Push-Erlaubnis durch Auswahl |
| R11 | Supplements | TEILWEISE | Echtes Auswahlraster, bestehende private Einträge, eigene Menge/Einheit und Zeiten im Code. Keine Dosierungsvorgabe oder pauschale Zustimmung. Native Referenzprüfung offen |
| R11a | Eigener Eintrag | TEILWEISE | 019 produktiv; #68 zeigt 1,5 g und sichtbaren Speichern-Knopf. Tap-Helfer korrigiert; Speichern/Wiederöffnung im nativen Folgelauf noch nachzuweisen |
| R12 | Ernährung aktivieren | TEILWEISE | Eigener Schritt mit echtem Ziel-Editor/Überspringen angeschlossen, keine 2500-Vorgabe; native Abnahme offen |
| R13 | Schritte | TEILWEISE | Eigener freiwilliger Health-/Zielschritt; Schutz vor Löschen noch nicht geladener Ziele, Freunde-Freigabe separat R15. Native Rechteprüfung offen |
| R14 | Rechte/Ort | TEILWEISE | Einzeln bedienbare echte Unterseiten für Wetterort, Mitteilungen, LIVE/Satzpausen im Ablauf; kein Alle-erlauben. Native Rechteprüfung offen |
| R15 | Privatsphäre | TEILWEISE | Echte bestätigte Aktivitäts-/Schritte-Freigaben im neuen Ablauf. Neue Profile standardmäßig privat mit 018. Ernährungs-/Stadtfreigabe fehlt |
| R16 | Freunde finden | TEILWEISE | Neue Anordnung mit Suche/Profil-Link/Einzelkontakt im Code; späte Suchantworten abgesichert. Native Integration offen |
| R17 | Erste Einheit | TEILWEISE | Drei Aktionen im Code: echter Start-/Planungsdialog erst nach Abschluss oder Heute; keine automatisch gestartete Aktivität. Native Abnahme offen |
| R18 | Zusammenfassung | TEILWEISE | #68: gespeicherte Entscheidungen/Bearbeitungsrücksprung PASS. Bild zeigt zu hohe Einzelkarten; kompakte Vorlage noch offen |

## Haupt-/Detailseiten

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| A01 | Heute | TEILWEISE | #68: Reihenfolge/Werte/Navigation PASS, Top/Scroll geprüft. Crew weiterhin erst nach Scrollen vollständig, ungünstige Namensumbrüche. Kompakte Vorlage/Großschrift offen |
| A02 | Wochenplan | TEILWEISE | Neuer eigener Tab mit Diese/Nächste Woche, Tagesdetails und realen Daten; native Funktions-/Layoutabnahme offen |
| A03–04 | Plus/Sport/Unterkategorien | TEILWEISE | Bestehende Flows; Layout und Kampfsportdimensionen prüfen |
| A05–09 | Pläne/Bibliothek/eigene Übungen | TEILWEISE | Kernpfade und Historie vorhanden; neue Darstellung, Zeitvorgaben prüfen |
| A10–11 | Planen/Einladen/Antworten | TEILWEISE | Kernpfade vorhanden; Änderungsbestätigung/Privatsphäre abnehmen |
| A12–13 | LIVE/Abschluss | TEILWEISE | Timer/Sätze/Pause vorhanden; Hierarchie, Offlinekorrektur, echte Abnahme |
| A14–15 | Crew/Social | TEILWEISE | Freundschaften, FYR UP, Mitziehen vorhanden; Limits/Entzug neu prüfen |
| A16 | Flamme/Streak | TEILWEISE | Serverlogik vorhanden; Mindestziel 2 und nachträgliche Korrekturen |
| A17 | Call My Shot | TEILWEISE | Kernpfad vorhanden; neues Mindestziel/Sichtbarkeit |
| A18 | Blind Workout | TEILWEISE | Reveal vorhanden; freiwillig vollständig ansehen/ersetzen ergänzen |
| A19 | Ernährungstagebuch | TEILWEISE | #68: korrekte Aufnahme/Restziel/Makros im Bild. Mengenänderung vor Tastaturabschluss durch Testhelfer abgebrochen; korrigierter Helfer noch ohne Wiederholung. Vier Zeilen nicht initial sichtbar; Layout, Cloud-Sync, Kopieren/Export offen |
| A20 | Lebensmittel/Barcode | TEILWEISE | Manueller pro-100-g-Eintrag mit Grammrechnung vorhanden; Anbieter/Lizenz, Suche, Favoriten und Barcode fehlen |
| A21 | Lebensmittel/Rezepte | FEHLT | Nährwertbasis, Zutaten, Portionen, Kopien/Sharing |
| A22 | Supplements | TEILWEISE | Speicherung/Rückgängig sowie private Menge/Einheit im Code; 019 produktiv, neue native Abnahme und Tagesnavigation noch offen |
| A23 | Schritte | TEILWEISE | Aggregate/Opt-in/Widerruf vorhanden; neuer Tageszugang |
| A24 | Entdecken | TEILWEISE | Bisher Sportkacheln, echte Inhalte und neue Anordnung fehlen |
| A25 | Profil | TEILWEISE | Körperdaten, Ernährung, Crew sowie LIVE/Satzpausen von dort erreichbar; vollständiges Referenzlayout und Kennzahlenabnahme offen |
| A26 | Mitteilungen | TEILWEISE | Routing/Lesestatus vorhanden; Regression nötig |
| A27 | Konto/Hilfe | TEILWEISE | Logout/Löschung/Support vorhanden; Export und Recovery prüfen |
| W01 | WeatherKit | TEILWEISE | Capability + App Service bei bestehender Apple-ID aktiviert, bestehendes Profil erneuert und nach Codemagic importiert. Swift-Reader, Stadt, Attribution, Cache/Backoff/Fehler und Fixture-Tests vorhanden. Echte Antwort, Signierungsbytes, TestFlight und Standortdialog NICHT GETESTET |
| QA01 | Render-Vergleich | TEILWEISE | Zusätzlich alle 17 echten PNGs aus #68 geprüft; konkrete Dichte-/Karten-/Motivabweichungen in REFERENCE_QA_68.md. Keine Pixelgleichheit, keine Gesamtfreigabe |
| QA02 | Geräte-/Mehrkontenprüfung | BLOCKIERT | Kein steuerbares physisches iPhone; NICHT GETESTET |
| CI01 | Kostenkontrollierte QA | TEILWEISE | Fünf manuelle Läufe abgeschlossen, letzter FAIL; konservativ 4,08 USD, Rest 5,92 USD. Kein Lauf/Archiv aktiv. Korrekturen vor weiterer Ausgabe bündeln |

## Arbeitsreihenfolge

1. Referenzzuordnung/Design-Tokens; Heute und repräsentative Registrierung.
2. Ernährungsdaten strikt von aktiver Energie trennen, sichere Speicherung/Tests; Wochenzielmigration.
3. Erster nativer A01/R05-Prüfpunkt #67 bestanden, sieben echte Bilder geprüft. Verbleibende gemeinsame Layoutkorrekturen lokal bündeln, keinen einzelnen kosmetischen Änderungsstand erneut kostenpflichtig bauen.
4. Danach vollständiger 18-Seiten-Einrichtungsfluss und verbleibende Seiten; Google/Datenanbieter, Ernährungssynchronisierung und Freigaben ergänzen. Vorhandene UI-Regressionspfade weiter an neue Navigation anpassen, nicht einfach löschen.
5. Vollständige native Regression, Mehrkonten-/RLS- und Geräteabnahme; erst danach signiertes Archiv.

Apple-Video und erneute Einreichung sind auf Nutzeranweisung bis zur Korrektur zurückgestellt. Keine unkontrollierten kostenpflichtigen Wiederholungen.
