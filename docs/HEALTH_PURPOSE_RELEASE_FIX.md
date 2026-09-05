# Apple-Upload: Health-Erklärungstext

[Signierter Build 9](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c07536942048ebcb1f844), Commit `7472300`, hat alle 27 UI-Abläufe bestanden, eine signierte IPA erzeugt und den bisherigen Konfigurationsschritt passiert. Apple hat die Datei am 05.09.2026 um 14:57 CEST beim Upload mit **90683 / Missing purpose string** zurückgewiesen: Im tatsächlichen FYRUP-App-Bundle fehlt `NSHealthUpdateUsageDescription`. **Keine neue TestFlight-Version aus diesem Lauf verfügbar.**

Apple dokumentiert getrennte Erklärungstexte für Lesen und Schreiben und verlangt die entsprechenden Usage-Keys für den Autorisierungsaufruf: [Health-Datenzugriff](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [Autorisierungs-API](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:)). Maßgeblicher konkreter Auslöser ist die oben gelesene Uploadablehnung.

## Korrektur

- Den fehlenden Key im generierten App-Info.plist ergänzen. Wahrheitsgemäßer Text: FYRUP schreibt keine Daten in Apple Health; die Schrittanzeige liest ausschließlich freiwillig freigegebene Schritte.
- `HealthKitStepReader` bleibt bei `toShare: []` und nur `read: [stepCount]`. Kein neues Schreibrecht, keine zusätzliche Datenart und keine automatische Berechtigungsabfrage.
- Neuer nativer Einzeltest liest beide Texte aus dem **gebauten App-Bundle**, nicht allein aus der Projektdatei. Ausführung im nächsten Lauf offen.
- Neuer Vorabtest öffnet die **tatsächliche IPA** nur lesend und verlangt eindeutiges FYRUP-App-Bundle, beide nichtleeren Health-Texte und passende Produktionskonfiguration. Er druckt keine Backend-Schlüssel. Er prüft nicht selbst Apples Signatur und ersetzt weder den Signierungsprofil-Test noch Apples Annahme.
- Der bisherige Konfigurationsschritt erhält `set -euo pipefail`, damit ein fehlgeschlagener früher Vergleich nicht durch einen erfolgreichen späteren Befehl verdeckt werden kann.

## Nachweis

Sieben lokale Python-Tests bestanden (XML/binary, fehlende/leere/falsche Zwecktexte, falsches Bundle, beide Backend-Felder und Umgebung jeweils unabhängig, fehlende Erwartungswerte, mehrdeutiges Bundle, ungültiges Archiv). Native Bundle-Prüfung, neuer signierter Build und Apple-Annahme bleiben bis zum tatsächlichen Nachweis offen.
