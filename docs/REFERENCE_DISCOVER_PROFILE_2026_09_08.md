# Entdecken, Profil und SMTP – gebündelter Folgeblock

08.09.2026, nach `c7b7f71`. Keine Änderungen am gestrichenen Google-Login oder an den verschobenen Ernährungserweiterungen. Keine Bildgenerierung und kein zusätzlicher kostenpflichtiger Build für diesen Zwischenstand.

## Quellcode

- A24: echte Suche über verfügbare Übungen, eigene Workout-Pläne und Sportarten. Vier erreichbare Filter; keine vorgeschobene Rezept-/Barcode-Suche oder erfundene Beliebtheitszahlen. Vorhandene Gym-/Laufbilder führen zu echten Plänen beziehungsweise zum Wochenplan-Tab. Der Wochenplan verwendet weiterhin den vorhandenen Ladeweg dieses Tabs.
- Suche berücksichtigt Umlaute, Schreibweise, Übungsaliase, Muskeln und Geräte. Archivierte Übungen, fremde eigene Übungen und fremde Pläne bleiben ausgeschlossen; ohne angemeldeten Eigentümer keine gecachten Ergebnisse. Keine neue öffentliche Backend-Freigabe.
- Übungsdetails zeigen vorhandene Metadaten/Notizen und den echten bestätigten Favoritenstatus. Der ausgewählte Sport öffnet denselben vorhandenen Aktivitätsdialog. Erste Übersichten begrenzen die sichtbare Anzahl; alle Ergebnisse bleiben über die Filter erreichbar.
- A25: zentrierter Profilkopf mit echtem optionalem Foto/Bearbeitung, kompakte Kennzahlen und sechs Hauptzugänge. Statistiken, Sportarten und Aktivitätsverlauf liegen auf einer eigenen Seite. Bestehende Ziele, Körperdaten, Ernährung, Workout-Pläne, Stammgym, Satzpause, Supplements, Freigaben, Kontolöschung und Support bleiben erreichbar.
- Der Statistiken-Zeitraum nutzt die gleiche Uhr wie die übrige Ansicht; nur eigene Aktivitäten, eindeutige Kennungen und zeitlich passende Abschlüsse zählen. Wochenstreak bleibt eine Wochenzahl, nicht die tägliche Kette der Illustration. Die Auswertung geladener Aktivitäten ist weiterhin ausdrücklich so beschriftet, keine behauptete vollständige Historie.
- Layouts wachsen bei großer Schrift, Filter brauchen kein verstecktes horizontales Wischen. Navigation/Aktionen mindestens 44 Punkte hoch. Dezente Auswahl-/Druckbewegung respektiert „Bewegung reduzieren“. Sieben A24-/A25-Bilder aus #70 einzeln geprüft; Filterumbruch/Kartenausrichtung und Sonntag-Wochenbeginn aus dem Bild als Folgekorrekturen erfasst.

## Prüfstatus

- Von elf neuen Swift-Unit-Tests für Suche/Kontotrennung und Profilstatistiken bestanden in #70 zehn; der verbleibende Rücken/Bankdrücken-Suchfehler ist in `8f4d655` mit Wortanfangsabgleich korrigiert, ursprüngliche Assertion bleibt. Zwei weitere Suchtests im Folgecode, native Wiederholung offen.
- Alle zwölf neuen Netzwerk-Regressionsfälle bestanden in #70; zusammen **22/23 neue Unit-Tests PASS**. [Stille Reconnect-Nachweise](TESTFLIGHT_CONNECTIVITY_AUDIT_2026-09-06.md), weiterhin kein Beleg am installierten TestFlight-Build.
- Alle drei neuen Referenz-Bedientests bestanden: Suche/Favorit/Wochentab, Profil/Statistiken/Bearbeitung/Support sowie Entdecken/Profil mit großer Schrift. #70 insgesamt 539/540 Unit- und 12/12 Referenz-UI-Tests PASS. Andere UI-Testklassen nicht ausgewählt.
- Alle 33 echten Bilder aus #70 einzeln geprüft. Folgekorrekturen: einzeilige normale Filter, einspaltige AX-Filter und passend breite Sport-Icons; oben ausgerichtete Bildkarten; Profil-Tagesleiste verwendet dieselbe Montag-Woche wie Heute/Wochenplan und zählt keine fremden Wochen. Zwei zusätzliche native Wochenrand-/Sommerzeitfälle und UI-Assertions vorbereitet, noch nicht ausgeführt. Keine behauptete Pixelgleichheit oder Geräteabnahme.
- Lokaler Gesamt-Preflight einschließlich Schutz nicht bestätigter Workout-Speichervorgänge am 08.09.2026 um 17:59:38 UTC: **21/21 PASS**. Aktuelles Ergebnis in `build/reference-preflight/report.json`. Der Preflight ersetzt keinen Swift-Compiler oder visuellen Test.

## Produktiver Mailversand

Der Nutzer hat nun ausdrücklich `kundenservice@minaluneva.com` als Absender freigegeben. SMTP mit Zoho EU und dem vom Nutzer erstellten App-Passwort gespeichert, Aktivierung nach unabhängigem Nachladen bestätigt. MFA bleibt an, keine DNS-/Postfachänderung. App-Passwort nicht in Dateien/Logs übernehmen. Die App-Supportadresse bleibt unverändert. Details: [Auth-/SMTP-Nachweis](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md).

Echte Zustellung, Bestätigungs-/Reset-Link auf iPhone sowie veröffentlichte FYRUP-Rechtstexte sind weiterhin offen. Nicht als vollständige Releasefreigabe kennzeichnen.
