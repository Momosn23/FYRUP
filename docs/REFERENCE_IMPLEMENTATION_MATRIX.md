# FYRUP – Funktionsmatrix zur ausgewählten Vorlage

Stand: 08.09.2026, erster Referenz-Prüfpunkt in Arbeit. FEHLT / TEILWEISE / IMPLEMENTIERT / GETESTET / BLOCKIERT beziehen sich auf den neuen Auftrag. Bestehende historische CI-Nachweise sind keine Prüfung dieser neuen Gestaltung. Einzelne gerätegebundene Teile bleiben auch bei funktionierendem Quellstand NICHT GETESTET. Details, Kosten und Fortsetzung: [Arbeitsnachweis](REFERENCE_CHECKPOINT_2026_09_08.md).

**Spätere verbindliche Umfangsentscheidung:** [Release-Abgrenzung](RELEASE_SCOPE_2026_09_08.md). **VERSCHOBEN** bedeutet ausdrücklich spätere Version, nicht erledigt und kein aktueller Release-Blocker. Google-Anmeldung ist vollständig **GESTRICHEN**; Apple/E-Mail und der echte Mailversand bleiben. Ältere Prüfberichte dokumentieren ihren damaligen Umfang.

Folgeblöcke nach `e39caf6`: [Einrichtung und kompaktere Übersichten](REFERENCE_LOCAL_SETUP_2026_09_08.md), [E-Mail-Anmeldung/Recovery und Supplement-Mengen](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md). [QA #68](REFERENCE_QA_68.md) prüfte `4679d89`: **510/511 Unit-Tests und 5/7 Referenz-UI-Tests PASS**, Gesamtstatus FAIL. Die drei damaligen Testfehler sind im abgeschlossenen Prüfpunkt #69 behoben; dessen verbleibender Fehler und zusätzliche Bildbefunde sind unten getrennt dokumentiert. [017–019 produktiv nachgeprüft](REFERENCE_BACKEND_2026_09_08.md). „Im Code“ ist nicht „auf dem iPhone abgenommen“.

## Bestand

**Neuester Nachweis:** [QA #71](REFERENCE_QA_71.md) auf `b538d05`, **544/544 Unit-Tests und 12/12 Referenz-UI-Tests PASS**. Vollständiges Nutzer-ZIP und alle 33 neuen PNGs am 09.09.2026 geprüft. Such-/Filter-/Kartenkorrekturen und lokale Montag-Profilwoche bestätigt. Netzwerk-Regressionsfälle bestanden; echte iPhone-/TestFlight-Fälle bleiben NICHT AUSGEFÜHRT. Aktuelle Kosten/Reserve ausschließlich im [Budgetlaufbuch](CI_BUDGET_2026_09.md); ältere #68–#70-Angaben darunter sind historische Belege und keine aktuelle Gesamtaussage. Gesamte Gestaltungs-/Geräteabnahme weiterhin TEILWEISE.

Folgeblock nach `f66069d`: [Layout/Wetter](REFERENCE_LAYOUT_WEATHER_2026_09_08.md) bearbeitet A01/A19/R06–R10/R18 sowie W01. [QA #69](REFERENCE_QA_69.md) für exakt `e6eee6c`: **515/515 Unit-Tests, 8/9 Referenz-UI-Tests PASS**, insgesamt FAIL wegen der Wetter-AX-Link-Abfrage. Alle 22 PNGs geprüft. A01-Großschrift-Überbreite und R08-Kreistextüberlauf zusätzlich aus Bildern/Hierarchien belegt und im lokalen Folgeblock korrigiert. Der separate lokale Block `953a0fd` (A02/Release-Berechtigungen) und diese Folgefixes sind nicht in #69 enthalten. Die unten ausdrücklich genannten #68-Bilder gehören weiterhin zum vorherigen Stand.

Ausgangsbestand des Referenzauftrags: Native SwiftUI-App, iOS 17+, Swift 6, XcodeGen; Bundle `app.fyrup.ios`, Widget `app.fyrup.ios.live`. Supabase mit REST/Auth, separater SecureSessionStore, private Keychain-Einstellungen, serverseitige RPC-/RLS-Tests. HealthKit liest Schritte und optional aktive Energie; APNs, ActivityKit/App Group, gezielte Kontaktauswahl und Kartenort existieren. Inzwischen sind auch Migrationen 017–019 produktiv, WeatherKit im Code und ein privates lokales manuelles Ernährungstagebuch implementiert. Google OAuth ist gestrichen, externe Ernährungsdatenquelle und Ernährungssynchronisierung sind verschoben. Bestehende Accounts/Daten bleiben bestehen.

Assets: 11 benannte Bildgruppen plus App-Icon, 122 katalogisierte Übungen mit strukturierten Muskelzuordnungen. Asset-/Lizenznachweis und neue Originalmotive offen. 26 ausgeschnittene Referenzen sind getrennt von sieben Simulatorbildern aus #67, 17 aus #68 und 22 aus #69 abgelegt. Kein lokales Xcode/Swift. Alle 21 lokalen Preflight-Gruppen bestanden, zuletzt für den Folgefix am 08.09.2026 um 16:31 UTC. Neue Bildabnahme **TEILWEISE**, aktuelle Restabweichungen in [QA #69](REFERENCE_QA_69.md). Letzter vollständig grüner älterer Stand #67 (`e39caf6`), letzter abgeschlossener Stand #69 FAIL. Codemagic verwendet manuelle Meilensteine und getrennte QA/Release-Wege. Sechs Läufe beendet, keiner aktiv; konservativ **5,89 USD** verbraucht, **4,11 USD** unreserviert. Keine Wiederholung einzelner kosmetischer Änderungen. [Laufbuch](CI_BUDGET_2026_09.md).

## Registrierung

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| R01 | Willkommen | TEILWEISE | Neuer direkter Einstieg im Code; genaue Bergvorlage und Lizenznachweis offen. Eigene FYRUP-Rechtstexte fehlen: vorhandener Website-Link ist ausdrücklich nicht die FYRUP-Erklärung |
| R02 | Anmeldeart | TEILWEISE | Apple/E-Mail vorhanden, Layout im Simulator geprüft; vollständiger Anmelde-/Gerätenachweis offen. Google vollständig GESTRICHEN: kein Button und keine Integration im App-Code, kein Release-Blocker. Keine produktiven Konten/Anbietereinstellungen geändert |
| R03 | E-Mail/Passwort | TEILWEISE | #68: Sichtbarkeit/Formularwechsel und getrennte Passwörter PASS; echter Versand/Fehlermeldungen und Referenzlayout offen |
| R03a | Bestätigung | TEILWEISE | Eigene maskierte Bestätigungsseite, 60s-Abstand, Adresswechsel und gerätegebundener PKCE-Callback im Code; exakte Supabase-Rückkehradresse produktiv geprüft. SMTP und echte Zustellung offen |
| R03b | Login | TEILWEISE | Bestehende Auth-/Wiederherstellung prüfen; neues Layout |
| R03c | Reset | TEILWEISE | Separater Recovery-Zustand; alle 7 Auth-Tests in #68 PASS. Echte Mail-Zustellung, Mail-App und iPhone offen |
| R04 | Persönliche Angaben | TEILWEISE | Profilfelder/Foto neu angeordnet, optionales privates Geburtsjahr, Tastaturcontainer/feste Aktion im Code; native Prüfung offen |
| R05 | Körperdaten | TEILWEISE | #68: Normal-/Tastatur-/Großschriftbilder geprüft; Speichern/Zurück mit 182 cm und Zielgewicht-Erreichbarkeit PASS. Ganze Einrichtungs-/Geräteabnahme offen |
| R06 | Hauptziel | TEILWEISE | #69: Auswahl/Summary-Bearbeitung PASS, stabiles grünes Auswahlbild und kompakte Untertexte geprüft; gesamte Neueinrichtung/Gerät offen |
| R07 | Weitere Ziele | TEILWEISE | #69: zwei Auswahlen, Untertexte und kompakte Karten geprüft; keine Freigabe durch Zielauswahl |
| R08 | Wochenziel | TEILWEISE | 2–7; 017/018 produktiv. #70: Auswahlkreise im richtigen Verhältnis und Einheiten-Text einzeilig; gezielte Geometrie-Assertions PASS, Einzelbild geprüft. Geräteabnahme offen |
| R09 | Wochentage | TEILWEISE | #69: runde Mo/Sa-Auswahl, Speichern und Bearbeitungsrückkehr PASS; keine automatischen Termine. Vollständige Großschriftprüfung offen |
| R10 | Uhrzeit | TEILWEISE | #69: Unterschiedlich gespeichert, neue Untertexte/Bild geprüft; keine Push-Erlaubnis durch Auswahl |
| R11 | Supplements | TEILWEISE | Echtes Auswahlraster, bestehende private Einträge, eigene Menge/Einheit und Zeiten im Code. Keine Dosierungsvorgabe oder pauschale Zustimmung. Native Referenzprüfung offen |
| R11a | Eigener Eintrag | TEILWEISE | 019 produktiv; #69: 1,5 g gespeichert und wieder geöffnet, Erinnerungen bleiben aus. Echte Zustellung/Gerät offen |
| R12 | Ernährung aktivieren | TEILWEISE | Eigener Schritt mit echtem Ziel-Editor/Überspringen angeschlossen, keine 2500-Vorgabe; native Abnahme offen |
| R13 | Schritte | TEILWEISE | Eigener freiwilliger Health-/Zielschritt; Schutz vor Löschen noch nicht geladener Ziele, Freunde-Freigabe separat R15. Native Rechteprüfung offen |
| R14 | Rechte/Ort | TEILWEISE | Einzeln bedienbare echte Unterseiten für Wetterort, Mitteilungen, LIVE/Satzpausen im Ablauf; kein Alle-erlauben. Native Rechteprüfung offen |
| R15 | Privatsphäre | TEILWEISE | Echte bestätigte Aktivitäts-/Schritte-Freigaben im neuen Ablauf. Neue Profile standardmäßig privat mit 018. Ernährungs-/Stadtfreigabe fehlt |
| R16 | Freunde finden | TEILWEISE | Neue Anordnung mit Suche/Profil-Link/Einzelkontakt im Code; späte Suchantworten abgesichert. Native Integration offen |
| R17 | Erste Einheit | TEILWEISE | Drei Aktionen im Code: echter Start-/Planungsdialog erst nach Abschluss oder Heute; keine automatisch gestartete Aktivität. Native Abnahme offen |
| R18 | Zusammenfassung | TEILWEISE | #69: sechs kompakte Zeilen und Weitere Einstellungen sichtbar; gespeicherte Entscheidungen/Bearbeitungsrücksprung PASS. Gesamte neue Einrichtung/Gerät und finales Erfolgsdesign offen |

## Haupt-/Detailseiten

| ID | Bereich | Status | Konkrete Lücke/Nachweis |
| --- | --- | --- | --- |
| A01 | Heute | TEILWEISE | #70: Reihenfolge/Werte/Navigation PASS; Großschrift-Überbreite behoben und Bild geprüft. Crew-Aktionen weiter scrollbar, keine Pixelgleichheit der Gesamtcollage. Echte Health-/Kontodaten offen |
| A02 | Wochenplan | TEILWEISE | #70: Diese/Nächste Woche, Montag–Sonntag und echter Tabwechsel aus Entdecken PASS; beide Bilder geprüft. Geräte-/produktive Mehrkontoabnahme offen |
| A03–04 | Plus/Sport/Unterkategorien | TEILWEISE | Bestehende Flows; Layout und Kampfsportdimensionen prüfen |
| A05–09 | Pläne/Bibliothek/eigene Übungen | TEILWEISE | Kernpfade und Historie vorhanden; neue Darstellung, Zeitvorgaben prüfen |
| A10–11 | Planen/Einladen/Antworten | TEILWEISE | Kernpfade vorhanden; Änderungsbestätigung/Privatsphäre abnehmen |
| A12–13 | LIVE/Abschluss | TEILWEISE | Timer/Sätze/Pause vorhanden; Hierarchie, Offlinekorrektur, echte Abnahme |
| A14–15 | Crew/Social | TEILWEISE | Freundschaften, FYR UP, Mitziehen vorhanden; Limits/Entzug neu prüfen |
| A16 | Flamme/Streak | TEILWEISE | Serverlogik vorhanden; Mindestziel 2 und nachträgliche Korrekturen |
| A17 | Call My Shot | TEILWEISE | Kernpfad vorhanden; neues Mindestziel/Sichtbarkeit |
| A18 | Blind Workout | TEILWEISE | Reveal vorhanden; freiwillig vollständig ansehen/ersetzen ergänzen |
| A19 | Ernährungstagebuch | TEILWEISE | Lokales manuelles Tagebuch bleibt: #69 bestätigt vier Mahlzeiten, 500→250 g und 1.850→925 kcal, Rest/Makros sowie Heute-Abgleich; große Schrift bedienbar. Weitere Gestaltung/Export und Geräteabnahme offen. Cloud-Sync ausdrücklich VERSCHOBEN |
| A20 | Lebensmittel/Barcode | VERSCHOBEN | Anbieter/Lizenz, Lebensmittelsuche/Katalog/Favoriten und Barcode für spätere Version; kein aktueller Release-Blocker. Vorhandener manueller pro-100-g-Eintrag mit Grammrechnung bleibt in A19 |
| A21 | Lebensmittel/Rezepte | VERSCHOBEN | Nährwertbasis, Zutaten, Portionen, Rezeptkopien/Sharing für spätere Version; keine derzeit nutzbaren Rezepte versprechen |
| A22 | Supplements | TEILWEISE | Speicherung/Rückgängig sowie private Menge/Einheit im Code; 019 produktiv, neue native Abnahme und Tagesnavigation noch offen |
| A23 | Schritte | TEILWEISE | Aggregate/Opt-in/Widerruf vorhanden; neuer Tageszugang |
| A24 | Entdecken | TEILWEISE | #71: Suchfehler samt neuen Wortanfangstests behoben, Such-/Favorit-/Wochenweg und Großschrift-Bedienung PASS; vier neue Bilder geprüft, Filter/Karten oben ausgerichtet. Übungsillustrationen/Geräteabnahme offen; Rezept-/Lebensmittelbereich verschoben |
| A25 | Profil | TEILWEISE | #71: Profil-/Statistik-/Bearbeitungs-/Supportnavigation und alle sechs Profilmodelltests PASS; drei Bilder geprüft. Montag–Sonntag und nur aktuelle lokale Woche bestätigt. Gesamtes Referenz-/Gerätedesign offen |
| A26 | Mitteilungen | TEILWEISE | Routing/Lesestatus vorhanden; Regression nötig |
| A27 | Konto/Hilfe | TEILWEISE | Logout/Löschung/Support vorhanden; Export und Recovery prüfen |
| W01 | WeatherKit | TEILWEISE | Capability/App Service/Profil eingerichtet. #70: Wetter-Fixture, sichtbare/bedienbare Apple-Quelle und Entfernen ohne alte Temperatur PASS; Bilder einzeln geprüft. Echte Antwort, Signierungsbytes, TestFlight und Standortdialog NICHT GETESTET |
| QA01 | Render-Vergleich | TEILWEISE | Alle 33 echten PNGs aus #71 einzeln geprüft; A01/R08 sowie Filter-/Profilwochenkorrekturen bestätigt. Übungs-/Wanderermotive fehlen, nicht alle Referenzseiten erfasst. Keine Pixelgleichheit, keine Gesamtfreigabe |
| QA02 | Geräte-/Mehrkontenprüfung | BLOCKIERT | Kein steuerbares physisches iPhone; NICHT GETESTET |
| CI01 | Kostenkontrollierte QA | TEILWEISE | Acht manuelle QA-Läufe abgeschlossen, #71 PASS. 8,95 USD konservativ verbraucht, 1,05 USD Rest vor Paketreserve. Release-Limit auf neun Minuten reduziert, keine automatische Wiederholung; aktueller Start/Reserve ausschließlich im Budgetlaufbuch |

## Arbeitsreihenfolge

1. Referenzzuordnung/Design-Tokens; Heute und repräsentative Registrierung.
2. Ernährungsdaten strikt von aktiver Energie trennen, sichere Speicherung/Tests; Wochenzielmigration.
3. Erster nativer A01/R05-Prüfpunkt #67 bestanden, sieben echte Bilder geprüft. Verbleibende gemeinsame Layoutkorrekturen lokal bündeln, keinen einzelnen kosmetischen Änderungsstand erneut kostenpflichtig bauen.
4. Danach vollständiger Einrichtungsfluss und verbleibende Seiten im reduzierten Release-Umfang: Apple/E-Mail samt echtem Versand, verbleibende Freigaben und Export. Google ist gestrichen; Lebensmittelanbieter/-suche, Barcode, Rezepte und Ernährungssynchronisierung sind verschoben. Vorhandene UI-Regressionspfade weiter an neue Navigation anpassen, nicht einfach löschen.
5. Vollständige native Regression, Mehrkonten-/RLS- und Geräteabnahme; erst danach signiertes Archiv.

Apple-Video und erneute Einreichung sind auf Nutzeranweisung bis zur Korrektur zurückgestellt. Keine unkontrollierten kostenpflichtigen Wiederholungen.
