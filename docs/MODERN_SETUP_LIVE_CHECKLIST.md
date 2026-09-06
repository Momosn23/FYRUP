# Rückmeldung zur installierbaren Version – 05.09.2026, ab 17:45 CEST

Verbindlicher Zusatz zur zentralen Produktliste. Nutzer: Startseite wirkt billig, falsches „Guten Morgen“ am Nachmittag, Kalorien/Körperdaten fehlen, Health/Schrittziel/Teilen versteckt, LIVE-Oberfläche und dauerhafte Anzeige fehlen. Alle Freigaben verständlich im Einstieg anbieten; die App insgesamt visuell modern und lebendig gestalten. Keine erzwungenen oder stellvertretend angenommenen iOS-/Health-Freigaben.

## Abnahme

- [x] NEU-01 Begrüßung anhand lokaler Uhrzeit, Zeitzone, Vordergrund-/Tageswechsel. Insbesondere 17:45 nie „Guten Morgen“.
- [ ] NEU-02 Startseite mit Fotografie, Crew, Wochenleiste, klarer Hierarchie, lesbaren Karten und sinnvollen Bewegungseffekten; mit echten Simulator-Aufnahmen und Referenz vergleichen.
- [x] NEU-03 LIVE verändert Heute sichtbar: Foto/Status/Zeit, Session öffnen, Gym-Satzpause direkt bedienbar.
- [x] NEU-04 Satzpause mit auswählbarer Dauer, echter verstrichener Zeit, Seiten-/Hintergrundwechsel und Wiederöffnung; unabhängig von globaler Session-Pause und Satzprotokoll. Keine Daten anderer Konten.
- [x] NEU-05 Geführte Ersteinrichtung für neue Nutzer und sichtbarer Nachhol-Einstieg für bestehende Konten; wieder erreichbar im Profil.
- [x] NEU-06 Schritte mit Erklärung direkt verbinden, eigenes Tagesziel erfassen, separat mit bestätigten Freunden teilen; Teilen nicht vorab einschalten, unbekannten Serverstatus nicht als bestätigt ausgeben.
- [x] NEU-07 Körpergröße/Gewicht optional erfassen, valide und privat speichern, wieder öffnen, ändern und löschen. Ungespeicherte Eingaben nicht beim Weitergehen verlieren.
- [x] NEU-08 Geschätzte aktive Energie aus Apple Health auf Heute samt eigenem Ziel, Quelle, Stand und ehrlichem Zustand ohne Daten. Separate Lesefreigabe; kein Ruheverbrauch/Schrittwert zusätzlich addieren.
- [ ] NEU-09 Eigene, transparent beschriebene Schätzung aus Schritten oder bewerteten abgeschlossenen Aktivitäten ist umgesetzt; Sportart und aktive Dauer werden berücksichtigt, überlappende Quellen nicht addiert. Die freiwillige lokale Zielhilfe ist klar als Berechnung auf dem iPhone gekennzeichnet und keine externe KI. Apples Wert bleibt eine eigenständige Health-Quelle; Körperdaten in FYRUP ändern Apple Health nicht. Offen bleibt die ausdrücklich gewünschte echte externe KI bis zu sicherer Anbieterwahl, Einwilligung und Kostenlimit.
- [x] NEU-10 Mitteilungen im Einstieg erklären und explizit beim System anfragen. Freigaben werden weder umgangen noch durch UI-Toggles vorgetäuscht.
- [x] NEU-11 Live-Aktivität wird separat erklärt und freiwillig nur für eine bestätigte eigene LIVE-Session gestartet. Sperrbildschirm/Dynamic Island zeigen Zeit, Pause, Satzpause und Rückweg; Abschluss, Abbruch, Logout, Kontowechsel und Opt-out entfernen den Zustand. Pro Session wird höchstens ein Startversuch gespeichert, sodass ein Dismiss nicht in einer Dauerschleife umgangen wird. Echte iPhone-Bedienung bleibt unter NEU-17 offen.
- [x] NEU-12 Widget-Erweiterung wirklich einbetten, richtig signieren, gleiche App-/Buildversion und Health-Erklärungstexte im tatsächlichen IPA prüfen.
- [x] NEU-13 Sperrbildschirm-Satzpause ohne App-Wechsel, frei angepasste Pausenzeiten, separates Homescreen-Widget und sportartspezifische Intervalltimer aus der Standort-/Live-Liste weiter umsetzen. App-Intent, App Group, Profile, signierter nativer Build und IPA sind belegt; echte iPhone-Bedienung bleibt in NEU-11/17 offen.
- [x] NEU-14 Fotos nur nach gezielter Auswahl. Kontakte/Standort nicht ohne vorhandene Funktion vorsorglich anfragen; zunächst jeweilige Funktionen aus den Zusatzlisten fertigstellen, dann in die Ersteinrichtung aufnehmen.
- [x] NEU-15 Muskel-Figur: eine bedienbare Region pro Muskel statt winziger Teilflächen; markierte Form und beschriftete Liste synchron, echte Übungsauswahl weiterhin korrekt.
- [ ] NEU-16 Alle weiteren Referenzseiten einzeln überarbeiten und visuell prüfen, nicht nur neue Zahlen/Ringe hinzufügen. Reduce Motion, VoiceOver, Kontrast, Tastatur und kleine Displays prüfen.
- [ ] NEU-17 Native Unit-/Bedientests, reale neue Screenshots und echte iPhone-/Health-/Live-Abnahme getrennt belegen. Nichts aus bloßem Quellcode als bestanden markieren.
- [x] NEU-18 Signierter Build 11 ist von Apple verarbeitet, trägt den Status „Bereit zur Übermittlung“ und ist der internen Gruppe „FYRUP Intern“ mit einer Einladung zugeordnet; am 06.09.2026 frisch in App Store Connect geprüft. Der danach lokal ergänzte Stand ist darin noch nicht enthalten.

## Vorbereiteter Code, noch nicht nativ abgenommen

Implementiert in dieser Arbeitsrunde: zeitabhängige Begrüßung; Foto-/Crew-/LIVE-Umbau; endliche Karten-/Buttonanimationen mit Reduce Motion; kontogetrennter Satzpausen-Countdown; geführte Einrichtung; Keychain-Speicherung privater Körperdaten; gesonderter read-only Health-Energiepfad; Live-Activity-Erweiterung samt kontrolliertem Rücklink; gruppierte Muskelflächen; zusätzliche Tests. Diese Liste bedeutet noch keinen vollständigen Funktionshaken.

Für Kalorien wird zunächst Apples aktive Energie übernommen, nicht durch eine unvalidierte neue Schrittlängen-/Intensitätsformel ersetzt. Ohne Daten keine erfundenen Standard-kcal. Körperdaten, Energie und Ziele gehen nicht an Freunde/Server/KI. Konto- und Tageswechsel sind eigene Testfälle.

## Apple und Auslieferung

Nutzer hat nach konkreter Rückfrage die neue Kennung und das Profil ausdrücklich freigegeben. `app.fyrup.ios.live` / „FYRUP Live Activities“ ist bei Apple registriert. Profil „FYRUP Live App Store 2026“, Apple-ID `KCSXYTTB76`, App Store, Ablauf 04.09.2027, vorhandenes Distribution-Zertifikat. Kein zusätzliches Health-/Push-/Kontakte-/App-Group-Recht an der Erweiterung aktiviert.

Historischer Stand: Codemagic meldete zunächst aufgebrauchte Build-Minuten. Nach der späteren Kostenfreigabe wurde der gebündelte Quellstand nativ geprüft. [Simulator-Build 45](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9cd7873cf4759eab7f4c28) und der [signierte Build 46](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9cdff81f365de10aeeec57) bestanden jeweils 459 Einzeltests und 33 Bedienabläufe ohne Fehler. Build 46 erzeugte FYRUP `1.0.0` / Build `11` und wurde ohne Uploadfehler zu Apple übertragen. Apple hat Build 11 inzwischen verarbeitet und „FYRUP Intern“ zugeordnet; echte iPhone-Abnahme bleibt getrennt offen.

Das neue Profil wurde anschließend über „Fetch profiles“ in Codemagic importiert und als `fyrup_live_app_store` gespeichert. Oberfläche bestätigt Bundle `app.fyrup.ios.live` und vorhandenes passendes Zertifikat „FYRUP Apple Distribution“. Der signierte Workflow verwendet beide Profile. Lokaler IPA-Regressionscheck: 10/10 grün; aktueller Terminologieaudit: 110 App-Textdateien, keine ungeprüften Altbegriffe. Native Kompilierung und UI-Läufe sind in Build 45/46 vollständig grün. Die noch fehlenden Haken betreffen insbesondere visuelle Einzelabnahme und reale iPhone-/Systemfunktionen, nicht einen roten Cloud-Build.

## Technische Primärquellen

- [Apple: Health-Freigaben](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data): fein getrennte Datenarten, Lesezustimmung nicht aus erfolgreichem Dialogabschluss ableitbar.
- [Apple: aktive Energie](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned): aktive Energie ist nicht Ruhe-/Gesamtverbrauch.
- [Apple: Live-Aktivitäten](https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities): Widget-Erweiterung, Verfügbarkeit, Lebenszyklus und Systemgrenzen.
- [Apple: Aktivierungspunkt](https://developer.apple.com/documentation/swiftui/view/accessibilityactivationpoint(_:)-9l0w0): expliziter Fokuspunkt für geformte Bedienelemente.
