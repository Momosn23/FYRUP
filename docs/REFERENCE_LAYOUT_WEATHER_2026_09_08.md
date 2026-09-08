# Gebündelter Folgeblock: Layout und Wetter

08.09.2026, nach `f66069d`. Anlass: sichtbare Abweichungen in den 17 tatsächlichen Simulatorbildern aus QA #68 und erneute Nachfrage nach der Wetterkarte. Keine erzeugten Mockups als Produktnachweis.

## Änderungen im Quellcode

- A01: kleinere Ringe und Abstände, kompaktere Supplement-/Crew-Karten. Supplement-Namen werden nicht mehr auf eine feste Zweizeilenhöhe gezwungen. Große Schrift ordnet Begrüßung/Wetter sowie Kennzahlen vertikal an. Links und Crew-Aktionen bleiben mindestens 44 Punkte hoch. Ernährungsaufnahme und aktive Energie bleiben getrennt.
- A19: kompaktere Kalorien-/Makroübersicht und vier Mahlzeitzeilen mit mindestens 44 Punkten. Bei großer Schrift werden Kalorien und Makrowerte untereinander angeordnet. Echte private Mengen-/Zielwerte und Speichern bleiben erhalten.
- R06/R07/R10: zusammenhängende Auswahlgruppen mit 10 Punkten Abstand, erklärende Untertexte, kompaktere Karten ohne Textabschneiden.
- R08/R09: runde Auswahl für 2–7 Einheiten und freiwillige Wochentage. Für Barrierefreiheits-Schriftgrößen weiter wachsendes Layout. Keine automatisch angelegten Termine, keine neue Standardauswahl.
- R18: sechs wichtige Einstellungen in einer kompakten, vollständig bearbeitbaren Liste. Weitere Entscheidungen separat ausklappbar, mit Reduce-Motion-Rücksicht und eigenem bedienbarem Knopf. Keine zuvor gespeicherte Wahl gelöscht.
- W01: Wetterkarte prüft auch bei dauerhaft geöffnetem Heute jede Minute, ob eine Aktualisierung nötig ist. Vorhandener 30-Minuten-Cache, zusammengefasste Anfragen und Fehlerwartezeiten begrenzen echte Apple-Abfragen. Stadt bleibt freiwillig und privat; keine automatische GPS-Abfrage. Entfernung einer Stadt entfernt auch deren Anzeige.

## Nachweise getrennt halten

- Lokaler Preflight: alle 21 Gruppen bestanden am 08.09.2026 um 15:31 UTC und erneut für das fertige Paket um 15:35:12 UTC.
- Vier neue Swift-Tests vorbereitet: Wetter-Minutenprüfung/Cacheablauf, Offline-Wiederkehr, Ortsentfernung während laufender Antwort und stabile Auswahlbeschreibungen/Persistenzschlüssel.
- Referenz-UI-Suite von sieben auf neun Fälle erweitert: Wetterdarstellung/Ortsentfernung mit isolierten Daten sowie Heute/Ernährung in großer Schrift. Zusätzlich erste sichtbare vier Mahlzeiten, sechs Summary-Zeilen und erneutes Bearbeiten der Wochentage prüfen.
- Neuer nativer Lauf und neue Bildkontrolle: AUSSTEHEND. Bisherige QA #68 gehört zu `4679d89`, nicht zu diesem Block.
- Die neue Wetter-Testquelle existiert ausschließlich im DEBUG-/Simulator-Referenzpfad. 18 °C/Berlin sind ausdrücklich Fixture-Daten, kein Nachweis einer echten WeatherKit-Antwort.
- Apple-Capability, App-Service und erneuertes Profil wurden bereits eingerichtet; entitlements/project.yml sowie Codemagic-Verweis `fyrup_app_store_weatherkit` lokal geprüft. Signierte eingebettete Profilbytes, echte Wetterantwort und iPhone-/TestFlight-Test: NICHT AUSGEFÜHRT.
- Kein TestFlight-/App-Store-Upload. Keine neuen Dienste, Abos oder Backend-/Nutzeränderungen.

## Weiter offen

Tatsächliche Bildschirmdichte und sämtliche weiteren Referenzseiten; rechtlich freigegebene FYRUP-Texte; Zugangsdaten des ausdrücklich freigegebenen SMTP-Absenders; Google-Konfiguration; Ernährungsdatenquelle/Cloud-Abgleich; echte Geräte-/Mehrkonten-Abnahme. Nicht aus grünen lokalen Tests als erledigt ableiten.
