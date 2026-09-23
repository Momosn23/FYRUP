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
- Nativer Swift-Build, Simulatorbild und echter iPhone-/TestFlight-Test dieser Korrektur: **NICHT AUSGEFÜHRT**.
- Kein neuer kostenpflichtiger Build, kein Upload, keine Antwort an Apple und keine erneute Einreichung wurden durch diese lokale Korrektur ausgelöst.

Für die erneute Prüfung ist ein neuer Build erforderlich, weil Build 17 den Fehler selbst enthält. Vor der Einreichung muss auf einem echten Gerät sichtbar geprüft werden, dass „ Weather“ und „Datenquellen“ unmittelbar auf der Heute-Wetterkarte erscheinen und der Link Apples rechtliche Quellenseite öffnet. Danach gehört eine kurze echte Geräteaufnahme in die Hinweise für die App-Prüfung.
