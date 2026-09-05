# Trainingsort, Stammgym, Ankunftserinnerung und Trainingstimer

Zusatzauftrag vom 05.09.2026: in die Checkliste aufnehmen. Teilweise lokal umgesetzt, noch nicht vollständig abgenommen; bestehende Standort-Textfelder allein erfüllen diese Anforderungen nicht.

Nachtrag: [Lokale Umsetzung und getrennte Nachweise](LOCAL_CONTINUATION_2026-09-05.md). Live-Aktivität, gemeinsame Satzpause sowie eigene Dauer und freiwillige einmalige Ablauf-Mitteilung sind in Arbeit. Cloud-Guthaben ist wieder vorhanden; auf ausdrücklichen Nutzerwunsch werden Änderungen zunächst lokal gebündelt und erst danach gemeinsam nativ geprüft. Die Haken unten bleiben bis zur jeweiligen Abnahme offen.

**Lokaler Stammgym-/Ankunftsstand:** Eigene Foto-Seite direkt im Profil und in der Einrichtung; freiwilliger Name, kontogetrennt im privaten Gerätespeicher, ändern/entfernen. Eine Apple-Karten-Suche kann zusätzlich eine eindeutige Koordinate für das Stammgym oder eine einzelne geplante Session auswählen. Die Koordinate und die lokale Erinnerung bleiben kontogetrennt auf dem Gerät; an Backend und Teilnehmer geht weiterhin nur der bewusst freigegebene Treffpunktname. Neue geplante Gym-Sessions übernehmen Name und – sofern vorhanden – den privaten Kartenort; bewusste Änderung oder Leeren bleiben erhalten. Pro geplanter eigener Session ist nach erklärter, optionaler Mitteilungs- und Standortfreigabe eine einmalige Eintrittserinnerung vorbereitet. Kennung, Konto, Sessionstatus, Zeit und Ort werden beim Erstellen, Bearbeiten, Starten, Absagen, Aktualisieren, Abmelden und Löschen abgeglichen; ein Tipp öffnet erst nach bestätigter Serverprüfung die richtige Session. Vier neue Modell-/Speichertests sind vorbereitet. Kein Standortfeld für sofort gestartete Aktivitäten, keine native Ausführung und keine echte Ankunftsfahrt geprüft; deshalb bleiben die Abnahmehaken offen.

## Trainingsort und Stammgym

- [ ] PLACE-01 Pro Training freiwillig einen Ort eintragen/auswählen; Name und bei gewählter Ankunftserinnerung eindeutige Koordinaten speichern.
- [ ] PLACE-02 Im Profil ein freiwilliges Stammgym hinterlegen, ändern und entfernen können.
- [ ] PLACE-03 Beim Planen/Starten eines Gym-Trainings das Stammgym vorauswählen, ohne erneutes Tippen.
- [ ] PLACE-04 Vor jeder Einheit abweichenden Ort wählen oder das Feld leeren; die einzelne Änderung überschreibt das Stammgym nur auf ausdrücklichen Wunsch.
- [ ] PLACE-05 Standortdaten privat behandeln; nicht ungefragt an alle Freunde, in Exporte oder an Analyseanbieter senden. Bereits bewusst freigegebene Treffpunkte separat behandeln.

## Erinnerung bei Ankunft

- [ ] ARRIVAL-01 Pro geplanter Einheit freiwillig „Bei Ankunft erinnern“ aktivieren/deaktivieren.
- [ ] ARRIVAL-02 Verständlich erklären, welche Standort-/Mitteilungsfreigaben benötigt werden; ohne Freigabe funktioniert das übrige Training weiter.
- [ ] ARRIVAL-03 Bei Ankunft neutral daran erinnern, was für heute geplant ist, mit direktem Öffnen des richtigen Trainings in FYRUP.
- [ ] ARRIVAL-04 Persönliche Übungsdetails auf gesperrtem Gerät nicht ungefragt offenlegen; Blind-Workouts bleiben bis zur Freigabe verborgen.
- [ ] ARRIVAL-05 Keine doppelte Erinnerung bei mehrfachem Betreten; keine Erinnerung für abgesagte/abgeschlossene Trainings oder nach Abmelden/Accountwechsel.
- [ ] ARRIVAL-06 Geänderten Ort, Termin, Stammgym und widerrufene Berechtigungen berücksichtigen; alte Ortserinnerungen aufräumen.
- [ ] ARRIVAL-07 Tatsächliches Verhalten auf dem iPhone prüfen, einschließlich Hintergrund, ungefährer Position, gesperrtem Gerät und verweigertem Zugriff. iOS-Zustellung nicht als garantiert oder sekundengenau darstellen.

## Dauerhafte Trainingsanzeige und Homescreen

- [ ] LIVEUI-01 Native iOS-Live-Aktivität mit aktivem Training, laufender Zeit und Pausenzustand auf dem Sperrbildschirm; Dynamic Island auf unterstützten Geräten.
- [ ] LIVEUI-02 Zusätzlich kleines Homescreen-Widget mit sinnvollem Einstieg ins laufende Training und Satzpause; nicht mit einer dauerhaft eingeblendeten Android-Benachrichtigung verwechseln.
- [ ] LIVEUI-03 Anzeigen starten erst bei tatsächlich begonnenem Training und enden bei Abschluss/Abbruch; keine verwaisten Timer nach Neustart oder Accountwechsel.
- [ ] LIVEUI-04 Timerzustand gemeinsam mit der App halten; App im Hintergrund oder beendet verursacht keinen Neustart der verstrichenen Zeit.
- [ ] LIVEUI-05 Keine automatische Anzeige privater Satzwerte/Übungsnamen auf dem Sperrbildschirm; Detailumfang freiwillig.

## Satzpausen und weitere Trainings-Timer

Lokaler Nachtrag: Für Laufen/Fahrrad/Schwimmen/Kampfsport/Andere ist ein frei konfigurierbarer Intervalltimer in Heute und LIVE vorbereitet. Er folgt der aktiven Session-Zeit einschließlich Pause/Fortsetzen und behält seinen Zustand kontogetrennt bei. Keine Hintergrundtöne/-hinweise für Intervalle und keine vorgetäuschte Widget-Integration. Satzpause jetzt auch im Blind Workout. Acht Timer-Einzeltests und ergänzte Bedienabläufe vorbereitet, native Abnahme noch ausstehend; siehe [gebündelten Arbeitsstand](LOCAL_CONTINUATION_2026-09-05.md).

- [ ] TIMER-01 Pausendauer vorab wählbar, während des Trainings änderbar; schnell erreichbare Aktion „Satzpause“.
- [ ] TIMER-02 Pause direkt über die zulässigen interaktiven Live-Aktivitäts-/Widget-Aktionen starten, fortsetzen, zurücksetzen oder beenden.
- [ ] TIMER-03 Ablauf der Satzpause mit optionalem Ton/Haptik/Mitteilung melden; keine Werbung und keine mehrfachen Alarme.
- [ ] TIMER-04 Satzpause, bewusst pausiertes Gesamttraining und laufende Trainingszeit eindeutig unterscheiden.
- [ ] TIMER-05 Für passende Sportarten optionale Intervall-/Runden-/Belastungs- und Erholungstimer vorsehen. Dauer und Wiederholungen wählt der Nutzer; keine vermeintlich individuellen Trainingsempfehlungen erfinden.
- [ ] TIMER-06 Hintergrund, Prozessende, Uhrzeitänderung, Zeitzonenwechsel, mehrere Interaktionen und Offlinezustand testen.
- [ ] TIMER-07 Zugängliche Beschriftungen, gut lesbare Zeit, reduzierte Bewegung und lokale Datenschutzregeln berücksichtigen.

## Auslieferungsprüfung

- [ ] RELEASE-LIVE-01 App-/Widget-Erweiterungen, App-Intents, benötigte Entitlements und Signierungsprofile gemeinsam prüfen.
- [ ] RELEASE-LIVE-02 Native Tests und echte iPhone-Abnahme durchführen; fehlende Voraussetzungen separat als offen ausweisen.
