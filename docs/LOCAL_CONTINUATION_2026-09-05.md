# Weiterarbeit ohne Cloud-Guthaben – 05.09.2026

## Gebündelter externer Einladungsblock (lokal, noch ohne Upload)

- „Freunde“ enthält jetzt zwei getrennte native Teilen-Aktionen: eine allgemeine Einladung und den eigenen Profillink. Empfänger und Versand-App werden ausschließlich im iOS-Teilen-Menü gewählt.
- Die Texte behaupten keinen nicht verifizierten Store- oder TestFlight-Link, sondern weisen ehrlich auf den privaten iPhone-Test und separat nötigen Testzugang hin.
- Ein strikter `fyrup://profile/<username>`-Parser lehnt fremde Schemes, Zugangsdaten, Ports, Parameter, Fragmente, zusätzliche Pfade und ungültige Usernames ab. Der Pfad bleibt über Login/Einrichtung erhalten und wird danach über einen aktuell auffindbaren Serverdatensatz aufgelöst.
- Die Zielansicht zeigt nur freigegebene Profildaten und bietet eine bewusste Freundschaftsanfrage; keine Aktivitäten, Schritte, Körperdaten oder Kontakte werden über den Link transportiert.
- Zwei Parser-Tests sind vorbereitet. Telefonnummern/Kontakte bleiben bis zu Nummernverifizierung, Backend-Datenschutzregeln, Missbrauchsschutz, SMS-Konfiguration und einem tatsächlich nutzbaren Installationslink offen; es wurde kein externer Dienst oder Kostenposten eingerichtet.

## Gebündelter Kalorienblock (lokal, noch ohne Upload)

- Die Heute-Karte nutzt gültige aktive Energie aus Apple Health weiterhin exklusiv. Fehlt sie, steht nun eine offen erklärte, grobe FYRUP-Schätzung aus echten heutigen Schritten, privaten Körperdaten und ausdrücklich bewerteter tatsächlicher Gym-Dauer bereit.
- Die Rechnung addiert Schritt- und Gym-Energie nicht, sondern nimmt wegen fehlender Zeitstempel nur den größeren Wert. Geplante, abgebrochene, fremde, doppelte und nicht-heutige Aktivitäten sind ausgeschlossen.
- Neue Nutzer können die Ersteinrichtung nicht mehr abschließen, solange Körpergröße oder Gewicht für die gewünschte Verbrauchsschätzung fehlen. Beide Werte bleiben im privaten Gerätespeicher und lassen sich später ändern oder löschen.
- Quelle, Zeitpunkt, Zielrest und Unsicherheit sind auf Heute sichtbar; das Ziel bleibt ausdrücklich aktive Bewegung, kein Gesamtbedarf und keine Abnehm- oder Ernährungsvorgabe.
- Fünf deterministische `ActiveCalorieEstimateTests` sind vorbereitet. Native Swift-/UI-Ausführung und echte Health-Daten bleiben offen. Ein externer KI-Zielvorschlag ist nicht stillschweigend simuliert und bleibt ohne geprüften Anbieter, ausdrückliche Dateneinwilligung und Kostenbegrenzung offen.

## Gebündelter Standortblock nach `166f4bd` (lokal, noch ohne Upload)

- Geplante Sessions geben nach erfolgreichem Erstellen nun ihre echte Serverkennung zurück. Eine lokale Ankunftserinnerung wird damit nicht über unsichere Zeit-/Textvergleiche einer möglicherweise falschen Session zugeordnet.
- Apple-Karten-Suche für Gym, Adresse oder Ort ergänzt; Suchanfrage an Apple und lokale Datenschutzgrenze werden in der Oberfläche erklärt.
- Optionaler Kartenort für das Stammgym wird zusammen mit den übrigen privaten Einrichtungseinstellungen kontogetrennt gespeichert. Name und Koordinate müssen zusammenpassen; alte gespeicherte Einstellungen bleiben decodierbar.
- Pro eigener geplanter Session kann nach einer vorgeschalteten Erklärung die optionale Mitteilungs- und Standortfreigabe angefragt und eine einmalige Ankunftserinnerung im Umkreis von etwa 180 Metern gesetzt werden. Ohne Freigabe bleibt die Session planbar.
- Der Sperrbildschirmtext bleibt neutral und enthält keine Übung, Gewichte, Notiz, Personennamen oder Blind-Workout-Details. Beim Antippen werden Konto, lokaler Datensatz und der aktuell vom Server geladene Sessionstatus erneut geprüft, bevor die richtige Session geöffnet wird.
- Änderung von Zeit/Ort, Start, Absage, Logout, Kontolöschung und bestätigtes Verschwinden der Session entfernen alte Erinnerungen. Ein fehlgeschlagener Nebenabruf der gehosteten Sessions löscht lokale Erinnerungen nicht irrtümlich.
- Vier neue `ArrivalReminderTests` sowie erweiterte Stammgym-Tests sind im Quellstand vorbereitet. Auf Windows stehen Swift/Xcode/iOS-Simulator weiterhin nicht zur Verfügung; entsprechend noch kein nativer Testnachweis und keine echte Geräteprüfung.
- Seit Aktivierung des Codemagic-Guthabens weiterhin **kein neuer Upload und kein neuer Cloud-Build** durch diesen Arbeitsblock. Die Änderungen werden wie verlangt zuerst gebündelt.

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

## Gebündelter Sofortstart-Ortsblock (lokal, noch ohne Upload)

- Auch spontan gestartete Aktivitäten besitzen nun ein freiwilliges Ortsfeld. Gym übernimmt zunächst das private Stammgym; vor jedem Start lässt sich der Wert ändern, leeren oder über Apple Karten neu auswählen.
- Der App-/Demo-/RPC-Datenfluss umfasst freie Aktivitäten und Workout-Pläne. Beim Start einer geplanten Session wird ohne bewusste Überschreibung der vorhandene Treffpunkt übernommen.
- Neue Migration `202609050015_activity_place.sql` ergänzt den auf 120 Zeichen begrenzten Ortsnamen, übernimmt vorhandene Session-Treffpunkte und stellt kompatible neue RPC-Signaturen bereit. Alte App-Versionen behalten ihre bisherigen Signaturen.
- Exakte Suchkoordinaten werden beim Sofortstart nicht an den Server übertragen. Ankunftserinnerungen bleiben bewusst auf geplante eigene Sessions beschränkt.
- Ein Demo-Lebenszyklustest prüft Kürzung und Rückgabe des Orts; ein neuer Bedienablauf erfasst den spontanen Ort. Der lokale Wegwerf-Datenbanktest prüft die atomare Migration, Rücksetzung bei Fehler, Wiederholungssperre, Rechte, Kürzung und 120-Zeichen-Grenze. Sprachprüfung und lokale Release-Prüfung sind grün; native Swift-/UI-Ausführung, produktive Migration und visuelle Abnahme bleiben offen.

## Interaktive LIVE-/Homescreen-Anzeige (lokal, noch ohne Upload)

- Der frühere Sperrbildschirm-Link öffnete nur FYRUP. Er ist jetzt durch eine echte, nicht die App öffnende App-Intent-Aktion ersetzt, die eine Satzpause startet oder beendet und die Live-Anzeige sofort aktualisiert.
- Ein kleines Homescreen-Widget zeigt laufende Sessionzeit beziehungsweise Satzpause und bietet bei Gym dieselbe Start-/Beenden-Aktion; ohne LIVE-Session bleibt es neutral.
- App, Widget und Live-Anzeige teilen ausschließlich den aktuellen privaten Timerzustand über `group.app.fyrup.shared`. Bestehende lokale Dauer-/Erinnerungseinstellungen werden beim ersten Aktivieren übernommen. Keine Satzwerte, Übungsnamen, Gewichte, Health-Daten oder Fotos gelangen in den Widget-Zustand.
- Eine freiwillig bereits aktivierte Ablauf-Mitteilung wird auch bei einer im Widget gestarteten Satzpause eingeplant; ohne vorhandene Mitteilungsfreigabe wird keine Freigabe erzwungen.
- Zwei Speicher-/Rückkehrtests sind vorbereitet. Für eine echte Auslieferung fehlen noch die Apple-App-Group-Registrierung, Zuordnung zu beiden App-Kennungen, erneuerte Profile, nativer Swift-6-Lauf und Prüfung auf einem iPhone.

## Nächste Schritte

Nach der verlangten lokalen Bündelung den aktuellen Stand kontrolliert hochladen, Compilerkorrektur samt allen neuen Tests gemeinsam ausführen, echte neue Screenshots prüfen und anschließend den signierten TestFlight-Build erstellen. Vorher lokal an der Produktliste weiterarbeiten. Offene native Standort-/Ankunfts-, Kontakte-/Einladungs-, AppIntent-/Homescreen-, Intervall-, Kalorien-KI-, Design- und Geräteprüfungen bleiben offen; die jetzigen Ergänzungen ersetzen sie nicht.

Primärquellen für lokale Timer-Hinweise: [Apple: lokale Mitteilungen](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app), [Apple: Zeitintervall-Trigger](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger).
