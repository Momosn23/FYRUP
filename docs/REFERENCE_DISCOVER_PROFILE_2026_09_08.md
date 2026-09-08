# Entdecken, Profil und SMTP – gebündelter Folgeblock

08.09.2026, nach `c7b7f71`. Keine Änderungen am gestrichenen Google-Login oder an den verschobenen Ernährungserweiterungen. Keine Bildgenerierung und kein zusätzlicher kostenpflichtiger Build für diesen Zwischenstand.

## Quellcode

- A24: echte Suche über verfügbare Übungen, eigene Workout-Pläne und Sportarten. Vier erreichbare Filter; keine vorgeschobene Rezept-/Barcode-Suche oder erfundene Beliebtheitszahlen. Vorhandene Gym-/Laufbilder führen zu echten Plänen beziehungsweise zum Wochenplan-Tab. Der Wochenplan verwendet weiterhin den vorhandenen Ladeweg dieses Tabs.
- Suche berücksichtigt Umlaute, Schreibweise, Übungsaliase, Muskeln und Geräte. Archivierte Übungen, fremde eigene Übungen und fremde Pläne bleiben ausgeschlossen; ohne angemeldeten Eigentümer keine gecachten Ergebnisse. Keine neue öffentliche Backend-Freigabe.
- Übungsdetails zeigen vorhandene Metadaten/Notizen und den echten bestätigten Favoritenstatus. Der ausgewählte Sport öffnet denselben vorhandenen Aktivitätsdialog. Erste Übersichten begrenzen die sichtbare Anzahl; alle Ergebnisse bleiben über die Filter erreichbar.
- A25: zentrierter Profilkopf mit echtem optionalem Foto/Bearbeitung, kompakte Kennzahlen und sechs Hauptzugänge. Statistiken, Sportarten und Aktivitätsverlauf liegen auf einer eigenen Seite. Bestehende Ziele, Körperdaten, Ernährung, Workout-Pläne, Stammgym, Satzpause, Supplements, Freigaben, Kontolöschung und Support bleiben erreichbar.
- Der Statistiken-Zeitraum nutzt die gleiche Uhr wie die übrige Ansicht; nur eigene Aktivitäten, eindeutige Kennungen und zeitlich passende Abschlüsse zählen. Wochenstreak bleibt eine Wochenzahl, nicht die tägliche Kette der Illustration. Die Auswertung geladener Aktivitäten ist weiterhin ausdrücklich so beschriftet, keine behauptete vollständige Historie.
- Layouts wachsen bei großer Schrift, Filter brauchen kein verstecktes horizontales Wischen. Navigation/Aktionen mindestens 44 Punkte hoch. Dezente Auswahl-/Druckbewegung respektiert „Bewegung reduzieren“. Noch kein optischer Abnahmenachweis für diesen neuen Stand.

## Prüfstatus

- Elf neue Swift-Unit-Tests für Suche/Kontotrennung/reduzierten Umfang sowie Profilstatistiken, Aktualität, Zeitraumgrenzen und Sommerzeit vorbereitet; **NICHT AUSGEFÜHRT** mangels lokalem Xcode.
- Zusätzlich zwölf native Netzwerk-Regressionsfälle nach erneutem Nutzerhinweis vorbereitet; zusammen **23 neue Unit-Tests** in diesem Paket. [Belegte stille Reconnect-Korrekturen](TESTFLIGHT_CONNECTIVITY_AUDIT_2026-09-06.md). Kein Nachweis am installierten TestFlight-Build.
- Drei neue native Referenz-Bedientests vorbereitet: Suche/Favorit/Wochentab, Profil/Statistiken/Bearbeitung/Support sowie Entdecken/Profil mit großer Schrift. Die vorhandenen Sportwahl-/Datenschutz-/Logout-Regressionswege folgen der neuen Navigation; Prüfungen nicht entfernt.
- Noch keine neuen echten Simulatorbilder, kein aktueller nativer Build, kein physisches iPhone-/TestFlight-Ergebnis. QA #69 gilt ausschließlich für seinen damaligen Commit.
- Lokaler Gesamt-Preflight einschließlich Schutz nicht bestätigter Workout-Speichervorgänge am 08.09.2026 um 17:59:38 UTC: **21/21 PASS**. Aktuelles Ergebnis in `build/reference-preflight/report.json`. Der Preflight ersetzt keinen Swift-Compiler oder visuellen Test.

## Produktiver Mailversand

Der Nutzer hat nun ausdrücklich `kundenservice@minaluneva.com` als Absender freigegeben. SMTP mit Zoho EU und dem vom Nutzer erstellten App-Passwort gespeichert, Aktivierung nach unabhängigem Nachladen bestätigt. MFA bleibt an, keine DNS-/Postfachänderung. App-Passwort nicht in Dateien/Logs übernehmen. Die App-Supportadresse bleibt unverändert. Details: [Auth-/SMTP-Nachweis](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md).

Echte Zustellung, Bestätigungs-/Reset-Link auf iPhone sowie veröffentlichte FYRUP-Rechtstexte sind weiterhin offen. Nicht als vollständige Releasefreigabe kennzeichnen.
