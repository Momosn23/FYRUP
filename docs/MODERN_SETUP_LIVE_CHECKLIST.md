# Rückmeldung zur installierbaren Version – 05.09.2026, ab 17:45 CEST

Verbindlicher Zusatz zur zentralen Produktliste. Nutzer: Startseite wirkt billig, falsches „Guten Morgen“ am Nachmittag, Kalorien/Körperdaten fehlen, Health/Schrittziel/Teilen versteckt, LIVE-Oberfläche und dauerhafte Anzeige fehlen. Alle Freigaben verständlich im Einstieg anbieten; die App insgesamt visuell modern und lebendig gestalten. Keine erzwungenen oder stellvertretend angenommenen iOS-/Health-Freigaben.

## Abnahme

- [ ] NEU-01 Begrüßung anhand lokaler Uhrzeit, Zeitzone, Vordergrund-/Tageswechsel. Insbesondere 17:45 nie „Guten Morgen“.
- [ ] NEU-02 Startseite mit Fotografie, Crew, Wochenleiste, klarer Hierarchie, lesbaren Karten und sinnvollen Bewegungseffekten; mit echten Simulator-Aufnahmen und Referenz vergleichen.
- [ ] NEU-03 LIVE verändert Heute sichtbar: Foto/Status/Zeit, Session öffnen, Gym-Satzpause direkt bedienbar.
- [ ] NEU-04 Satzpause mit auswählbarer Dauer, echter verstrichener Zeit, Seiten-/Hintergrundwechsel und Wiederöffnung; unabhängig von globaler Session-Pause und Satzprotokoll. Keine Daten anderer Konten.
- [ ] NEU-05 Geführte Ersteinrichtung für neue Nutzer und sichtbarer Nachhol-Einstieg für bestehende Konten; wieder erreichbar im Profil.
- [ ] NEU-06 Schritte mit Erklärung direkt verbinden, eigenes Tagesziel erfassen, separat mit bestätigten Freunden teilen; Teilen nicht vorab einschalten, unbekannten Serverstatus nicht als bestätigt ausgeben.
- [ ] NEU-07 Körpergröße/Gewicht optional erfassen, valide und privat speichern, wieder öffnen, ändern und löschen. Ungespeicherte Eingaben nicht beim Weitergehen verlieren.
- [ ] NEU-08 Geschätzte aktive Energie aus Apple Health auf Heute samt eigenem Ziel, Quelle, Stand und ehrlichem Zustand ohne Daten. Separate Lesefreigabe; kein Ruheverbrauch/Schrittwert zusätzlich addieren.
- [ ] NEU-09 Eigene Schätzung aus Schritten und Intensität sowie freiwilliger KI-Vorschlag bleiben eigenständige offene Punkte aus der Kalorienliste. Apples Wert ist **keine** fertige FYRUP-Rechenformel; Körperdaten in FYRUP ändern Apple Health nicht.
- [ ] NEU-10 Mitteilungen im Einstieg erklären und explizit beim System anfragen. Freigaben werden weder umgangen noch durch UI-Toggles vorgetäuscht.
- [ ] NEU-11 Live-Aktivität separat erklären und freiwillig automatisch pro tatsächlicher Session starten. Sperrbildschirm/Dynamic Island mit Zeit, Pause, Satzpause und Rückweg; Abschluss/Abbruch/Logout/Opt-out entfernen sie. Nutzer-Dismiss nicht durch ständiges Neuerstellen übergehen.
- [ ] NEU-12 Widget-Erweiterung wirklich einbetten, richtig signieren, gleiche App-/Buildversion und Health-Erklärungstexte im tatsächlichen IPA prüfen.
- [ ] NEU-13 Sperrbildschirm-Satzpause ohne App-Wechsel, frei angepasste Pausenzeiten, separates Homescreen-Widget und sportartspezifische Intervalltimer aus der Standort-/Live-Liste weiter umsetzen. Echte App-Intent-Aktion und Homescreen-Widget sind im Quellstand ergänzt; App Group, Signierung, nativer Lauf und iPhone-Bedienung bleiben offen.
- [ ] NEU-14 Fotos nur nach gezielter Auswahl. Kontakte/Standort nicht ohne vorhandene Funktion vorsorglich anfragen; zunächst jeweilige Funktionen aus den Zusatzlisten fertigstellen, dann in die Ersteinrichtung aufnehmen.
- [ ] NEU-15 Muskel-Figur: eine bedienbare Region pro Muskel statt winziger Teilflächen; markierte Form und beschriftete Liste synchron, echte Übungsauswahl weiterhin korrekt.
- [ ] NEU-16 Alle weiteren Referenzseiten einzeln überarbeiten und visuell prüfen, nicht nur neue Zahlen/Ringe hinzufügen. Reduce Motion, VoiceOver, Kontrast, Tastatur und kleine Displays prüfen.
- [ ] NEU-17 Native Unit-/Bedientests, reale neue Screenshots und echte iPhone-/Health-/Live-Abnahme getrennt belegen. Nichts aus bloßem Quellcode als bestanden markieren.
- [ ] NEU-18 Neuen signierten Build tatsächlich in TestFlight verfügbar machen. Build-Minuten, Apple-Verarbeitung und Testergruppe frisch prüfen.

## Vorbereiteter Code, noch nicht nativ abgenommen

Implementiert in dieser Arbeitsrunde: zeitabhängige Begrüßung; Foto-/Crew-/LIVE-Umbau; endliche Karten-/Buttonanimationen mit Reduce Motion; kontogetrennter Satzpausen-Countdown; geführte Einrichtung; Keychain-Speicherung privater Körperdaten; gesonderter read-only Health-Energiepfad; Live-Activity-Erweiterung samt kontrolliertem Rücklink; gruppierte Muskelflächen; zusätzliche Tests. Diese Liste bedeutet noch keinen vollständigen Funktionshaken.

Für Kalorien wird zunächst Apples aktive Energie übernommen, nicht durch eine unvalidierte neue Schrittlängen-/Intensitätsformel ersetzt. Ohne Daten keine erfundenen Standard-kcal. Körperdaten, Energie und Ziele gehen nicht an Freunde/Server/KI. Konto- und Tageswechsel sind eigene Testfälle.

## Apple und Auslieferung

Nutzer hat nach konkreter Rückfrage die neue Kennung und das Profil ausdrücklich freigegeben. `app.fyrup.ios.live` / „FYRUP Live Activities“ ist bei Apple registriert. Profil „FYRUP Live App Store 2026“, Apple-ID `KCSXYTTB76`, App Store, Ablauf 04.09.2027, vorhandenes Distribution-Zertifikat. Kein zusätzliches Health-/Push-/Kontakte-/App-Group-Recht an der Erweiterung aktiviert.

Historischer Stand: Codemagic meldete zunächst aufgebrauchte Build-Minuten. Nach der späteren Kostenfreigabe wurde der gebündelte Quellstand nativ geprüft. [Simulator-Build 45](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9cd7873cf4759eab7f4c28) und der [signierte Build 46](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9cdff81f365de10aeeec57) bestanden jeweils 459 Einzeltests und 33 Bedienabläufe ohne Fehler. Build 46 erzeugte FYRUP `1.0.0` / Build `11` und wurde ohne Uploadfehler zu Apple übertragen. Apple-Verarbeitung, Testergruppe und echte iPhone-Abnahme bleiben getrennt offen.

Das neue Profil wurde anschließend über „Fetch profiles“ in Codemagic importiert und als `fyrup_live_app_store` gespeichert. Oberfläche bestätigt Bundle `app.fyrup.ios.live` und vorhandenes passendes Zertifikat „FYRUP Apple Distribution“. Der signierte Workflow verwendet beide Profile. Lokaler IPA-Regressionscheck: 10/10 grün; aktueller Terminologieaudit: 110 App-Textdateien, keine ungeprüften Altbegriffe. Native Kompilierung und UI-Läufe sind in Build 45/46 vollständig grün. Die noch fehlenden Haken betreffen insbesondere visuelle Einzelabnahme und reale iPhone-/Systemfunktionen, nicht einen roten Cloud-Build.

## Technische Primärquellen

- [Apple: Health-Freigaben](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data): fein getrennte Datenarten, Lesezustimmung nicht aus erfolgreichem Dialogabschluss ableitbar.
- [Apple: aktive Energie](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned): aktive Energie ist nicht Ruhe-/Gesamtverbrauch.
- [Apple: Live-Aktivitäten](https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities): Widget-Erweiterung, Verfügbarkeit, Lebenszyklus und Systemgrenzen.
- [Apple: Aktivierungspunkt](https://developer.apple.com/documentation/swiftui/view/accessibilityactivationpoint(_:)-9l0w0): expliziter Fokuspunkt für geformte Bedienelemente.
