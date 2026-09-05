# Weiterarbeit ohne Cloud-Guthaben – 05.09.2026

## Aktueller Nachtrag: Codemagic wieder freigegeben

Der Nutzer hat die kostenpflichtige Codemagic-Nutzung selbst aktiviert und anschließend ausdrücklich angewiesen, entsprechend weiterzuarbeiten. Frisch verifiziert: „Manage subscription“, aktueller Betrag $0, nächste Rechnung 01.10.2026. Die 500/500 Freiminuten bleiben als verbrauchtes Freikontingent stehen. GitHub Actions hat weiterhin ein $0-Budget mit Nutzungsstopp. Die frühere Upload-/Cloud-Pause unten ist damit für die jetzt beauftragte Codemagic-Prüfung aufgehoben.

**Neuere Kostenanweisung:** Anschließend verlangte der Nutzer, Änderungen zuerst fertig zu bündeln und nicht alle paar Minuten hochzuladen. Deshalb wurde der vorbereitete Prüfzweig noch nicht hochgeladen und kein neuer Build gestartet. Zunächst lokal an den offenen Punkten weiterarbeiten, anschließend eine gemeinsame Prüfung; zusätzliche Läufe nur für konkret gefundene Fehler. Keine bestehenden Workflows verändern. Native Endergebnisse und Bildschirmkontrolle bleiben bis zum tatsächlichen Nachweis offen.

Nutzer hat zweimal ausdrücklich angewiesen, trotz erschöpftem GitHub-Guthaben lokal weiterzuarbeiten; er füllt später auf. Keine kostenpflichtige Abrechnung aktivieren, keine weiteren Pushes/Cloud-Teststarts bis zur Klärung. Bereits vorhandene Workflows bleiben unverändert aktiviert. Keine neue Automatisierung eingerichtet.

## Verifizierter Ausgangspunkt

- `9e1a54a`: neue Einrichtung, private Körperdaten/Health-Energie, Foto-/LIVE-Oberflächen, ActivityKit-Erweiterung und gruppierte Muskelflächen hochgeladen. GitHub 48 scheiterte an zwei Swift-6-Nebenläufigkeitsfehlern beim Senden von ActivityKit-Handles aus dem MainActor.
- `08c9bc3`: Handles werden innerhalb nichtisolierter Hilfsaufrufe bezogen/verbraucht, nur Sendable-Zustand kreuzt die Grenze; ungespeicherte Körperdaten lassen sich verwerfen und werden beim Navigieren geschützt. Hochgeladen **vor** der Nutzeranweisung zum Guthaben.
- GitHub 49 (`33979664611`) wurde gar nicht gestartet: Konto-Zahlungen fehlgeschlagen oder Ausgabenlimit erreicht, 7 Sekunden Gesamtzeit. Damit ist die Compilerkorrektur **noch nicht nativ bestätigt**. Keine Behauptung eines neuen erfolgreichen iOS-Builds.
- Codemagic: 500/500 Freiminuten verbraucht. Das neue Live-Profil `fyrup_live_app_store` ist korrekt importiert und im signierten Workflow neben dem HealthKit-Profil eingetragen. Keine Abrechnung aktiviert.

## Profil-Datenschutzkorrektur

- Neue Migration `202609050014_profile_privacy_preservation.sql`: Profil-Metadaten dürfen eine vorhandene Sichtbarkeit weder ein- noch ausschalten. Bestehende RPC-Signatur bleibt kompatibel; nur die Erstellung verwendet den übergebenen Initialwert. Bewusste Änderungen erfolgen weiterhin über den separaten gefilterten Sichtbarkeits-PATCH.
- Lokal 991/991 Datenbankprüfungen grün, davon 16 neue direkte Regressionen. Die alte Wochenziel-Testvorbereitung verwendet nun bewusst den separaten Sichtbarkeitswechsel statt eines Profil-Updates. Fachliche Testaussage unverändert.
- Atomare Deployment- und Rollback-Tests grün: alte Funktionsdefinition bleibt bei Fehlern erhalten, Schnappschuss/Migrationshistorie rollen mit zurück, doppelte Anwendung wird abgewiesen.
- **Produktiv angewendet** in Supabase `dwpuzcpnzldlnadfivcm`. Frische Kontrollabfrage bestätigte fünfmal `true`: Migration vorhanden, altes Sichtbarkeits-Replay entfernt, Wiederherstellungs-Schnappschuss vorhanden, anonymer Aufruf gesperrt, authentifizierter Aufruf verfügbar. Keine Nutzer-Testdatensätze angelegt oder bestehende Profilwerte geändert.
- Der SQL-Editor führte bei einem Kontrollversuch noch die vorherige Abfrage aus; die Wiederholsperre verhinderte eine zweite Migration. Eine neue reine Kontrollabfrage in frischem Editor bestätigte anschließend den obigen Stand. Nicht erneut migrieren.
- App-/Demo-Code übernimmt bei Metadatenänderung jetzt den bestätigten Profilstand und nicht den veralteten Formularwert. Zusätzliche Swift-Tests vorbereitet, noch nicht ausgeführt.

## Satzpause – weiterer lokaler Code

- Eigene Dauer 15–600 ganze Sekunden, gespeicherte Dauer vor neuer Pause änderbar; laufende Pause wird nicht durch Bearbeiten heimlich neu gestartet.
- Reminder und Ton getrennt, pro Konto standardmäßig aus. Explizite iOS-Mitteilungsfreigabe wird erläutert; keine automatische Systemzustimmung.
- Ein lokaler Hinweis pro Pause, feste eigene Kennung, keine Wiederholungen oder nachgeholten verpassten Alarmen. Keine privaten Übungsnamen, Gewichte, Health-Daten oder Fotos im Hinweis.
- Serialisierter Abgleich bei neuer Pause, Ende, Abmelden, Wechsel, Widerruf und bestätigtem Session-Ende. Verspätete Einplanung wird durch den neuesten Zustand ersetzt/entfernt.
- Antippen prüft eigene Konto-ID, tatsächliche LIVE-Session und die konkrete Pause vor Öffnen. Keine Freigabe fremder Inhalte durch Mitteilungsdaten.
- Sechs neue Swift-Tests für Eingaben, Opt-in, verspätete Antworten, Konto-Wechsel, Fehler und Rückweg sowie zusätzlicher Bedientest vorbereitet. **Nicht nativ ausgeführt.** Kein Nachweis echter iPhone-Zustellung oder Sperrbildschirm-Funktion.
- Sprachprüfung: 98 App-Textdateien grün. IPA-Prüfskript: 10/10 lokale Tests grün. Das ist kein gebautes neues IPA.

## Stammgym – weiterer lokaler Code

- Foto-Seite „Stammgym“ direkt im Profil und in der Einrichtungsübersicht, mit lesbarem Foto-Verlauf. Freiwilligen Namen speichern, bearbeiten, entfernen; ungespeicherte Änderungen bewusst verwerfen. Schutz vor versehentlichem Speichern eines alten Formulars in ein anderes Konto.
- Kontogetrennt im vorhandenen privaten Keychain-Speicher, nicht im öffentlichen Profil oder Health. Optionales neues Feld bleibt mit älteren Einstellungsdaten kompatibel. Höchstens 120 Zeichen, keine Steuerzeichen/Zeilenumbrüche. Keine Standortberechtigung oder GPS-Zugriffe dafür.
- Neue geplante Gym-Sessions füllen den Ort vor. Eigene Änderung oder bewusstes Leeren werden bei erneutem Anzeigen oder geändertem Stammgym nicht überschrieben. „Stammgym übernehmen“ setzt es nur auf ausdrücklichen Wunsch wieder ein; eine neue Session startet wieder mit der gespeicherten Vorgabe. Sichtbarkeit als Session-Treffpunkt wird vor dem Bestätigen erläutert.
- Sieben neue Swift-Einzeltests für Alt-Daten, Werteprüfung, private Kontotrennung, Entfernen und Formularverhalten sowie ein neuer UI-Ablauf vorbereitet. **Nicht nativ ausgeführt.** Keine neuen Screenshots oder TestFlight-Auslieferung behauptet.
- Zusätzlich Demo-Satzpausen-Einstellungen pro Teststart isoliert; ausdrücklich persistente Demo-Läufe verwenden ihren eigenen übergebenen Speicher. Zwei Regressionstests vorbereitet. Verhindert, dass etwa die 123-Sekunden-Eingabe einen späteren Test unbemerkt verändert.
- Grenzen: noch kein Ort bei sofort gestarteten Aktivitäten, keine Koordinaten/Ortssuche und keine Ankunftserinnerung. Diese Punkte bleiben in der Standortliste offen.
- Nach dieser Ergänzung: Sprachprüfung für 100 App-Textdateien bestanden, alle 10 lokalen Tests des IPA-Prüfskripts bestanden, keine Whitespace-Fehler in der Änderungsprüfung. Keine dieser Prüfungen ersetzt einen Swift-Build oder eine iPhone-Abnahme.

## Gebündelte lokale Ergänzung nach der Kostenanweisung

- Intervalltimer auf Heute und in der LIVE-Ansicht für Laufen, Fahrrad, Schwimmen, Kampfsport und Andere. Eigene Belastungs-/Erholungszeiten und Rundenzahl; keine unbestätigten Belastungsvorgaben. Letzte Runde ohne zusätzliche Erholung. Technische Grenzen 5–3.600 s Belastung, 0–3.600 s Erholung, 1–99 Runden, höchstens sechs Stunden insgesamt.
- Timer verwendet aktive Session-Zeit: Pause/Fortsetzen bleiben synchron, ein Hintergrundprozess ist nicht erforderlich. Kontoabhängig gespeichert; nach Neustart wird der Stand aus der aktiven Zeit berechnet. Ende/Abbruch und Kontowechsel räumen den passenden Zustand auf, ein Netzfehler allein löscht ihn nicht. Abschluss der Intervalle beendet keine Aktivität und erzeugt keine Wochen-Credits.
- Grenzen ausdrücklich in der Oberfläche: keine Intervall-Töne oder Hintergrundhinweise, keine Intervall-Phasen im Sperrbildschirm-Widget. Die bereits vorhandene freiwillige Satzpausen-Mitteilung ist davon getrennt.
- Satzpause auch im Blind Workout eingebaut; der bestehende Blind-Bedientest prüft dabei weiter, dass die nächste Übung verborgen bleibt. Bestätigte Start-/End-/Abbruchantworten halten App, Cache und Satzpause konsistent, auch wenn das anschließende Laden des Feeds scheitert.
- Bestätigter Abschluss oder Abbruch kann nicht mehr durch einen älteren LIVE-Cache zurückgesetzt werden. Offline-Kaltstart wird als gespeicherter Stand gekennzeichnet; daraus wird keine neue native Live-Anzeige und kein neuer Pausentimer gestartet. Erfolgreiche Statusänderungen aktualisieren unmittelbar den eigenen Cache.
- Unvollständige private Einrichtung setzt am gespeicherten Schritt fort. Abschluss löscht den Fortsetzungsmarker; erneutes Öffnen einer bereits abgeschlossenen Einrichtung startet ihre Übersicht regulär bei Schritt 1. Keine automatische Health-/Mitteilungsfreigabe.
- 13 zusätzliche native Einzeltests vorbereitet: acht Intervall-/Speicherprüfungen, drei Cache-/Netzfehlerprüfungen und zwei Einrichtungsprüfungen. Ein neuer Intervall-Bedientest plus erweiterter Blind-Test, drei neue geplante Bildschirmnachweise. **Noch nicht ausgeführt.**
- Lokale Sprachprüfung: 103 App-Textdateien bestanden. Lokales Release-Prüfskript: 10/10 Tests bestanden. Kein neuer iOS-Build, kein Upload und keine neuen kostenpflichtigen Läufe durch diese Arbeitsrunde.

## Nächste Schritte

Nach der verlangten lokalen Bündelung den aktuellen Stand kontrolliert hochladen, Compilerkorrektur samt allen neuen Tests gemeinsam ausführen, echte neue Screenshots prüfen und anschließend den signierten TestFlight-Build erstellen. Vorher lokal an der Produktliste weiterarbeiten. Offene vollständige Standort-/Stammgym-/Ankunfts-, Kontakte-/Einladungs-, AppIntent-/Homescreen-, Intervall-, Kalorienformel-/KI- und Design-/Geräteprüfungen bleiben offen; die jetzigen Ergänzungen ersetzen sie nicht.

Primärquellen für lokale Timer-Hinweise: [Apple: lokale Mitteilungen](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app), [Apple: Zeitintervall-Trigger](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger).
