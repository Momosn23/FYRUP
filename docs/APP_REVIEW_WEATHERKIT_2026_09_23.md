# App-Prüfung: sichtbare WeatherKit-Quellenangabe

## Befund

Apple hat die Einreichung `246512fb-0f6a-4812-8632-7346b1bc52e8`, Version 1.0 (17), am 19.09.2026 erneut nach Richtlinie 5.2.5 abgelehnt. Der beigefügte Screenshot vom iPhone 17 Pro Max zeigt auf der weißen Heute-Wetterkarte Datum, Temperatur und Berlin, aber keine sichtbare Apple-Weather-Marke und keinen erkennbaren Link zu den rechtlichen Datenquellen.

Die Ursache lag im App-Code: Für die dauerhaft weiße Karte wurde `combinedMarkDarkURL` ausgewählt. Diese helle Markendarstellung verschwand auf dem weißen Hintergrund. Die frühere Antwort und das Gerätevideo konnten die fehlende sichtbare Kennzeichnung in Build 17 deshalb nicht ersetzen.

## Lokale Korrektur

- Auf der weißen Oberfläche wird nun Apples `combinedMarkLightURL` verwendet.
- Die Apple-Weather-Marke und der unterstrichene Link „Datenquellen“ stehen direkt bei jedem angezeigten Wetterwert.
- Falls das externe Markenbild vorübergehend nicht geladen werden kann, bleibt „ Weather“ sichtbar; der rechtliche Link bleibt bedienbar.
- Die Wetterort-Detailseite verwendet dieselbe sichtbare Quellenkomponente.
- Der Referenz-Bedientest verlangt die zugängliche Kennzeichnung „ Weather · Rechtliche Datenquellen“.

## Nachweise und offene Abnahme

- Terminologie, Daten-/Backendtests, Benachrichtigungsregeln, Signierungs- und IPA-Prüffälle sowie Whitespace: lokal bestanden.
- Portable Gesamtprüfung: 20 von 21 Prüfpunkten bestanden. Nur der unveränderte YAML-Konfigurationsprüfer konnte im lokalen Windows-Lauf nicht starten, weil dem verfügbaren Python-Interpreter PyYAML fehlt; das ist kein Swift- oder Produktfehler.
- Der einmalige Codemagic-Release-Lauf `6ab3b502e73fb2f7326818c4` hat Commit `facc598` auf Mac mini M2 nativ kompiliert, signiert und als Version 1.0.0 (18) paketiert. Profil-, WeatherKit-/App-Group-, Produktionsbackend- und fertige IPA-Prüfung liefen ohne Fehler; Dauer 5m04s. Die vollständige Testsuite war für diesen kostensparenden Paketlauf bewusst deaktiviert.
- Upload zu App Store Connect erfolgreich ohne Fehler, Delivery UUID `c1973bfc-089e-4913-b7fa-26ae546192d3`. Apple hat Build 18 verarbeitet; Status „Bereit zur Übermittlung“, interne Gruppe „FYRUP Intern“.
- Simulatorbild und echter iPhone-/TestFlight-Test dieser Korrektur: **NICHT AUSGEFÜHRT**.
- Keine Antwort an Apple und keine erneute Einreichung wurden ausgelöst.

Vor der erneuten Einreichung muss Build 18 auf einem echten Gerät sichtbar geprüft werden: „ Weather“ und „Datenquellen“ müssen unmittelbar auf der Heute-Wetterkarte erscheinen und der Link Apples rechtliche Quellenseite öffnen. Danach gehört eine kurze echte Geräteaufnahme in die Hinweise für die App-Prüfung; erst dann Build 17 in der Store-Version durch Build 18 ersetzen und erneut übermitteln.
