# Trainingsort, Stammgym, Ankunftserinnerung und Trainingstimer

Zusatzauftrag vom 05.09.2026. Ort/Stammgym, Ankunftslogik, Timer sowie App-/Widget-Einbettung sind im Quellstand umgesetzt und automatisiert geprüft; reale Ankunft, Systemanzeige und interaktive Bedienung auf dem iPhone bleiben offen.

Nachtrag: [Lokale Umsetzung und getrennte Nachweise](LOCAL_CONTINUATION_2026-09-05.md). Live-Aktivität, gemeinsame Satzpause sowie eigene Dauer und freiwillige einmalige Ablauf-Mitteilung sind in Arbeit. Cloud-Guthaben ist wieder vorhanden; auf ausdrücklichen Nutzerwunsch werden Änderungen zunächst lokal gebündelt und erst danach gemeinsam nativ geprüft. Die Haken unten bleiben bis zur jeweiligen Abnahme offen.

**Aktueller Stand für LIVEUI/TIMER:** Die Live-Anzeige besitzt eine echte interaktive Satzpausenaktion statt des früheren reinen Öffnen-Links. Zusätzlich ist ein kleines Homescreen-Widget mit laufender Zeit und Start/Beenden der Satzpause eingebettet. App, Widget und Live-Anzeige verwenden im Produktionspfad denselben privaten App-Group-Zustand; bestehende lokale Pauseneinstellungen werden übernommen. Bei tatsächlichen Änderungen wird das Homescreen-Widget sofort, bei unverändertem Stand nicht unnötig neu geladen. Die freiwillige Ablauf-Mitteilung wird auch bei Start aus dem Widget berücksichtigt. `group.app.fyrup.shared` ist bei Apple registriert, beiden App-Kennungen zugeordnet und beide App-Store-Profile wurden am 05.09.2026 erneuert. Die Profile sind in Codemagic gespeichert und im Workflow eingetragen. Build 45 und der signierte Build 46 kompilieren App/Erweiterung und bestehen alle nativen Tests; Build 46 prüft die Profile, baut die IPA und lädt sie ohne Fehler zu Apple. Die echte Sperrbildschirm-/Dynamic-Island-/Widget-Bedienung auf dem iPhone fehlt weiterhin.

**Stammgym-/Ankunftsstand:** Eigene Seite direkt im Profil und in der Einrichtung; freiwilliger Name, kontogetrennt im privaten Gerätespeicher, ändern/entfernen. Eine Apple-Karten-Suche kann zusätzlich eine eindeutige Koordinate für das Stammgym oder eine einzelne geplante Session auswählen. Die Koordinate und die lokale Erinnerung bleiben kontogetrennt auf dem Gerät; an Backend und Teilnehmer geht weiterhin nur der bewusst freigegebene Treffpunktname. Geplante und sofort gestartete Aktivitäten besitzen ein freiwilliges Ortsfeld; Gym übernimmt das Stammgym, lässt sich pro Aktivität ändern oder leeren. Für spontane Starts wird ausschließlich der gekürzte Ortsname gespeichert, nicht die Kartenkoordinate. Pro geplanter eigener Session ist nach erklärter, optionaler Mitteilungs- und Standortfreigabe eine einmalige Eintrittserinnerung verdrahtet. Kennung, Konto, Sessionstatus, Zeit und Ort werden beim Erstellen, Bearbeiten, Starten, Absagen, Aktualisieren, Abmelden und Löschen abgeglichen; ein Tipp öffnet erst nach bestätigter Serverprüfung die richtige Session. Migration 015 ist produktiv angewendet und separat kontrolliert; Modelle, Speicherung und Bedienwege bestanden die aktuellen nativen Läufe. Die echte Ankunftsfahrt und Systemzustellung auf dem iPhone bleiben offen.

**Nachweisgrenze:** PLACE-01 bis PLACE-05 und ARRIVAL-01 bis ARRIVAL-06 sind in App, Demo, produktiver Migration und automatisierten Tests belegt. ARRIVAL-07 bleibt die getrennte reale Geräteabnahme.

**Signierungsschutz:** Der gebündelte Release-Ablauf prüft vor dem Bau Haupt- und Live-Profil auf ihre jeweilige App-Kennung und die gemeinsame App Group. Für die Haupt-App bleiben HealthKit, Apple-Anmeldung und Production-Push ebenfalls Pflicht. Neun lokale Parser-/Pipe-Tests bestehen; der Lauf gegen die erneuerten Apple-Dateien ist noch offen.

## Trainingsort und Stammgym

- [x] PLACE-01 Pro Aktivität freiwillig einen Ort eintragen/auswählen; Name und bei gewählter Ankunftserinnerung eindeutige Koordinaten speichern.
- [x] PLACE-02 Im Profil ein freiwilliges Stammgym hinterlegen, ändern und entfernen können.
- [x] PLACE-03 Beim Planen/Starten einer Gym-Aktivität das Stammgym vorauswählen, ohne erneutes Tippen.
- [x] PLACE-04 Vor jeder Einheit abweichenden Ort wählen oder das Feld leeren; die einzelne Änderung überschreibt das Stammgym nur auf ausdrücklichen Wunsch.
- [x] PLACE-05 Standortdaten privat behandeln; nicht ungefragt an alle Freunde, in Exporte oder an Analyseanbieter senden. Bereits bewusst freigegebene Treffpunkte separat behandeln.

## Erinnerung bei Ankunft

- [x] ARRIVAL-01 Pro geplanter Einheit freiwillig „Bei Ankunft erinnern“ aktivieren/deaktivieren.
- [x] ARRIVAL-02 Verständlich erklären, welche Standort-/Mitteilungsfreigaben benötigt werden; ohne Freigabe funktioniert die übrige App weiter.
- [x] ARRIVAL-03 Bei Ankunft neutral daran erinnern, was für heute geplant ist, mit direktem Öffnen der richtigen Session in FYRUP.
- [x] ARRIVAL-04 Persönliche Übungsdetails auf gesperrtem Gerät nicht ungefragt offenlegen; Blind Workouts bleiben bis zur Freigabe verborgen.
- [x] ARRIVAL-05 Keine doppelte Erinnerung bei mehrfachem Betreten; keine Erinnerung für abgesagte/abgeschlossene Aktivitäten oder nach Abmelden/Accountwechsel.
- [x] ARRIVAL-06 Geänderten Ort, Termin, Stammgym und widerrufene Berechtigungen berücksichtigen; alte Ortserinnerungen aufräumen.
- [ ] ARRIVAL-07 Tatsächliches Verhalten auf dem iPhone prüfen, einschließlich Hintergrund, ungefährer Position, gesperrtem Gerät und verweigertem Zugriff. iOS-Zustellung nicht als garantiert oder sekundengenau darstellen.

## Dauerhafte Trainingsanzeige und Homescreen

- [x] LIVEUI-01 Native iOS-Live-Aktivität mit laufender aktiver Zeit und Pausenzustand sowie Dynamic-Island-Darstellung ist eingebettet und im signierten Build 46 kompiliert; echte Geräteanzeige bleibt unter RELEASE-LIVE-02 offen.
- [x] LIVEUI-02 Kleines Homescreen-Widget mit Einstieg, Zeit und Satzpause ist über die private App Group eingebettet; es wird nicht als Android-Dauerbenachrichtigung bezeichnet.
- [x] LIVEUI-03 Lebenszyklus ist an eine bestätigte eigene LIVE-Aktivität gebunden; Abschluss, Abbruch, Abmelden und Kontowechsel entfernen den Zustand, und eine geordnete Aktualisierung verhindert das Wiedererscheinen alter Anzeigen.
- [x] LIVEUI-04 Timerreferenz und Satzpause liegen im gemeinsam signierten App-Group-Zustand; App, Live-Aktivität und Widget verwenden dieselben absoluten Zeitpunkte statt eines bei Wiederöffnung neu gestarteten Zählers.
- [x] LIVEUI-05 Sperrbildschirm und Widget zeigen nur Sportart, aktive Zeit, Pause und die freiwillige Satzpause; Übungsnamen, Gewichte und Wiederholungen werden dort nicht veröffentlicht.

## Satzpausen und weitere Trainings-Timer

Lokaler Nachtrag: Für Laufen/Fahrrad/Schwimmen/Kampfsport/Andere ist ein frei konfigurierbarer Intervalltimer in Heute und LIVE vorbereitet. Er folgt der aktiven Session-Zeit einschließlich Pause/Fortsetzen und behält seinen Zustand kontogetrennt bei. Keine Hintergrundtöne/-hinweise für Intervalle und keine vorgetäuschte Widget-Integration. Satzpause jetzt auch im Blind Workout. Acht Timer-Einzeltests und ergänzte Bedienabläufe vorbereitet, native Abnahme noch ausstehend; siehe [gebündelten Arbeitsstand](LOCAL_CONTINUATION_2026-09-05.md).

- [x] TIMER-01 Pausendauer vorab wählbar, während des Workouts änderbar; schnell erreichbare Aktion „Satzpause“.
- [x] TIMER-02 Satzpause lässt sich über eine echte App-Intent-Aktion in Live-Aktivität und Homescreen-Widget starten oder beenden; die App übernimmt denselben Zustand.
- [x] TIMER-03 Der Ablauf kann freiwillig einmalig mit Mitteilung und optionalem Ton gemeldet werden; Start/Beenden ersetzt beziehungsweise entfernt die feste Anfragekennung und erzeugt keine Werbung.
- [x] TIMER-04 Satzpause, bewusst pausierte Session und laufende aktive Zeit eindeutig unterscheiden.
- [x] TIMER-05 Für passende Sportarten optionale Intervall-/Runden-/Belastungs- und Erholungstimer vorsehen. Dauer und Wiederholungen wählt der Nutzer; keine vermeintlich individuellen Empfehlungen erfinden.
- [ ] TIMER-06 Hintergrund, Prozessende, Uhrzeitänderung, Zeitzonenwechsel, mehrere Interaktionen und Offlinezustand testen.
- [x] TIMER-07 Zugängliche Beschriftungen, gut lesbare Zeit, reduzierte Bewegung und lokale Datenschutzregeln berücksichtigen.

## Auslieferungsprüfung

- [x] RELEASE-LIVE-01 App-/Widget-Erweiterungen, App-Intents, benötigte Entitlements und Signierungsprofile gemeinsam prüfen. *(Signierter Build 46: beide erneuerten App-Group-Profile angewendet, App und Erweiterung gebaut, IPA-Prüfung und Apple-Upload ohne Fehler.)*
- [ ] RELEASE-LIVE-02 Native Tests und echte iPhone-Abnahme durchführen; fehlende Voraussetzungen separat als offen ausweisen.
