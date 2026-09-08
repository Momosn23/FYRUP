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
- [QA #69](REFERENCE_QA_69.md) für exakt `e6eee6caa90c537f844d7d57b0e51bca308ddbf7` beendet: **515/515 Unit-Tests und 8/9 Referenz-UI-Tests PASS**, insgesamt FAIL nach 15m38s. Wetter-Bedientest scheitert an der AX-Link-Abfrage; Berlin/18 vorher erkannt. Alle 22 PNGs einzeln geprüft: A19/R18 besser, A01 bei Großschrift zu breit und R08-Kreislabel abgeschnitten. Neue gezielte Folgefixes sind lokal, nicht in diesem nativen Nachweis enthalten. Bisherige QA #68 gehört zu `4679d89`, nicht zu diesem Block. Kein paralleler Auftrag und kein automatischer Wiederholungslauf.
- Die neue Wetter-Testquelle existiert ausschließlich im DEBUG-/Simulator-Referenzpfad. 18 °C/Berlin sind ausdrücklich Fixture-Daten, kein Nachweis einer echten WeatherKit-Antwort.
- Apple-Capability, App-Service und erneuertes Profil wurden bereits eingerichtet; entitlements/project.yml sowie Codemagic-Verweis `fyrup_app_store_weatherkit` lokal geprüft. Signierte eingebettete Profilbytes, echte Wetterantwort und iPhone-/TestFlight-Test: NICHT AUSGEFÜHRT.
- Kein TestFlight-/App-Store-Upload. Keine neuen Dienste, Abos oder Backend-/Nutzeränderungen.

## Weiter offen

Erneute Prüfung auf Nachfrage zur Apple-Wetter-Anbindung am 08.09.2026: Der vorhandene `AppleCurrentWeatherReader` ruft direkt `WeatherService.shared.weather(for:including: .current)` und die vorgeschriebene Apple-Attribution ab. Es handelt sich um Apples WeatherKit-Dienst, nicht um das Auslesen der installierten Wetter-App oder ihrer gespeicherten Städte. Stadtwahl funktioniert ohne GPS, optionaler aktueller Ort mit eigener bewusster Standortfreigabe. Code, Entitlement und Profilverweis sind vorhanden; echter signierter Geräteabruf bleibt unbewiesen. [Apple WeatherKit](https://developer.apple.com/weatherkit/) ist im Developer-Programm mit bis zu 500.000 Abfragen pro Monat enthalten; es wurde kein zusätzliches Kontingent gekauft. Apples [Konfigurationsvorgaben](https://developer.apple.com/help/account/services/weatherkit) nennen App Service und Capability; die frühere Einrichtung beider ist oben dokumentiert. Kein neuer Build oder Live-Wetterabruf bei dieser Nachprüfung.

Tatsächliche Bildschirmdichte und weitere Referenzseiten im aktuellen Umfang; rechtlich freigegebene FYRUP-Texte; Zugangsdaten des ausdrücklich freigegebenen SMTP-Absenders; echte Geräte-/Mehrkonten-Abnahme. Nach späterer [Nutzerentscheidung](RELEASE_SCOPE_2026_09_08.md) ist Google vollständig gestrichen; Ernährungsdatenquelle, Suche, Barcode, Rezepte und Cloud-Abgleich sind verschoben und blockieren diesen Release nicht mehr. Nicht aus grünen lokalen Tests als erledigt ableiten.

## Separater lokaler Folgeblock während #69 wartet

Diese Änderungen sind **nicht** in `e6eee6c`/QA #69 enthalten und benötigen einen später gebündelten nativen Nachweis:

- A02-Wochenplan als zusammenhängende Tagesliste statt großer voneinander abgesetzter Zeilen. Pro Tag kompakte Vorschau und vorhandener Tagesdialog für alle Einträge. Ausstehende Sessions bleiben auch neben bereits abgeschlossenen Einheiten sichtbar; Duplikate, fremde Abschlüsse und abgesagte Sessions zählen nicht. Nicht geladene Kalenderdaten werden nicht als leere Woche ausgegeben. Zwei Swift-Tests und zwei zusätzliche Bilder im bestehenden UI-Fall vorbereitet.
- Die spätere IPA-Prüfung kontrolliert zusätzlich die **eingebetteten** Profile und Berechtigungen in beiden ausführbaren Dateien. WeatherKit, HealthKit, Apple-Login, Produktions-Push, App Group und Zielkennung werden nicht nur aus dem ursprünglichen CI-Profil abgeleitet. Nicht freigegebene Debug-Signierung wird zurückgewiesen. Keine allgemeine kryptografische Signatur-/Apple-Serverprüfung behauptet.
- 15 lokale synthetische IPA-Tests bestanden, darunter fehlende Wetterberechtigung im Profil oder in der eigentlichen App, fehlende eingebettete Dateien, unzulässige Dateipfade und Debug-Zugriff. Ausführung von `security`/`codesign` auf einem Mac und Prüfung der nächsten tatsächlichen IPA weiterhin AUSSTEHEND. Es wird kein extra signierter Build nur hierfür angelegt.
- Verfahren nach [Apple TN3125](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles) und [Apple TN2415](https://developer.apple.com/library/archive/technotes/tn2415/_index.html): Profilberechtigungen und die tatsächlich beanspruchten App-Berechtigungen sind getrennte Prüfstellen.
- Lokaler Gesamt-Preflight für diesen Folgeblock: **21/21 PASS, 15:55:55 UTC**. Der erste Durchlauf meldete ausschließlich den technischen Typnamen innerhalb einer neuen Accessibility-Kennung als Sprachverstoß; die Kennung wurde ohne pauschale Audit-Ausnahme formuliert. Native Swift-/UI-Ausführung dieser A02-Änderungen ausstehend.
