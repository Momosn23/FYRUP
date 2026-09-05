# Trainingsort, Stammgym, Ankunftserinnerung und Trainingstimer

Zusatzauftrag vom 05.09.2026: in die Checkliste aufnehmen. Noch nicht implementiert oder abgenommen; bestehende Standort-Textfelder allein erfüllen diese Anforderungen nicht.

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
