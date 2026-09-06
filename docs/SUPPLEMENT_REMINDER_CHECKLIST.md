# Freiwillige Supplement-Erinnerungen

Zusatzauftrag vom 05.09.2026. Implementierung, Backend und Simulatorablauf sind geprüft; echte Pushzustellung und iPhone-Abnahme bleiben offen. Dies ist eine persönliche Erinnerungsfunktion, keine Empfehlung für bestimmte Produkte, Dosierungen oder Einnahmehäufigkeiten.

## Nachweisstand

Private Datenmodelle, vier Backend-Schnittstellen, kontogebundene Offline-Vormerkungen, Demo-Speicherung und begrenzte Erinnerungswarteschlange sind integriert. **124 neue lokale Datenbankprüfungen plus 836 bestehende Regressionen bestehen**. Build 31 (`7910f6c`) hat alle 382 Einzeltests einschließlich aller 13 Supplement-Tests sowie alle 27 UI-Abläufe bestanden. Sommerzeitkorrektur, Tageswechsel und gesperrter Speicher im nativen Nachtest bestätigt.

Im aktuellen Arbeitsstand sind Startseiten-Karte, eigene Tage/Uhrzeiten, Pause, Rückgängig, Entfernen, Ruhezeiten, optionale Push-Freigabe und neutrale Vorschau an das Konto angebunden. Der Push-Dispatcher prüft jede Einnahme vor jedem Gerät erneut; APNS wird angewiesen, Hinweise nicht für eine verspätete Offlinezustellung aufzubewahren. „Genommen“ öffnet die App mit Geräteentsperrung, überprüft zuerst die autorisierte Mitteilung und lädt dann die tatsächliche heutige Einnahme. Kontoersatz erhält eine neue Push-Zuordnung; Abmelden meldet das bekannte Gerät ab. Bereits von APNS akzeptierte Hinweise lassen sich nicht zurückrufen.

57 lokale Versand-/Terminologieprüfungen bestehen, einschließlich erneuter Gerätezuordnung direkt vor jedem Versand nach Kontowechsel. Einrichtung → Bestätigung → Neustart → Rückgängig → Überspringen → Pause bestand in Build 31 nach 57,5 Sekunden. **Migration 013 produktiv eingespielt und separat überprüft**: 13 Historieneinträge, exakter normalisierter Quelltext-Prüfwert, fünf geschützte Tabellen, keine direkten Client-Schreibrechte oder Zugriffe auf interne Belege. Keine Supplements/Einnahmen angelegt. Dispatcher frisch vom Server vollständig verglichen; Aufrufe 12:54–12:56 CEST mit HTTP 200 ohne Timeout. [Einzelbilder 65–67 geprüft](VISUAL_QA_BUILD31.md); gekürzter Einleitungstext im Folgestand korrigiert. **APNS_PRIVATE_KEY fehlt produktiv**, konkrete Freigabe zum geschützten Hinterlegen angefragt. Reale Mehrgeräte-/Offline-Pushzustellung und iPhone-Abnahme stehen aus; vollständige Abnahmepunkte bleiben offen.

Technische Grundlagen: [Apple zu Benachrichtigungsaktionen](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) und [minutenerhaltende Kalenderauflösung](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/nexttimepreservingsmallercomponents). Quellen erläutern die Plattform, ersetzen aber keinen Gerätetest.

## Persönliche Auswahl und Startseite

- [x] SUPP-01 Eigene Supplements mit frei eingegebenem Namen hinzufügen, bearbeiten, pausieren und entfernen; keinerlei vorgewählte Einnahme oder automatische Produktempfehlung.
- [x] SUPP-02 Selbst bestimmen, welche Supplements an welchen Tagen vorgesehen sind; für jedes Supplement eine oder mehrere selbst gewählte Einnahmezeiten ermöglichen.
- [x] SUPP-03 Auf Heute eine kompakte Karte mit den heutigen Einträgen und eindeutigem Zustand „Offen“, „Genommen“ oder „Übersprungen“ anzeigen; optionale Funktion ohne Pflicht zur Einrichtung.
- [x] SUPP-04 Jede vorgesehene Einnahme separat mit „Genommen“ abhaken; Zeitpunkt speichern, Doppeltippen idempotent behandeln und versehentliche Bestätigung rückgängig machen können.
- [x] SUPP-05 „Heute überspringen“ und zeitweises Pausieren anbieten, ohne Druck, Schuldtexte oder Auswirkung auf Deine Streak und Wochenziel.

## Einstellbare Erinnerungen

- [x] SUPP-06 Erinnerungen freiwillig aktivieren; Zeiten, Wiederholungsabstand und maximale Anzahl pro noch offener Einnahme selbst einstellen können. Auch keine Wiederholung erlauben.
- [x] SUPP-07 Nur erinnern, solange die betreffende Einnahme offen ist; „Genommen“, „Übersprungen“, Pausieren oder Entfernen löscht alle ausstehenden Erinnerungen dieser Einnahme.
- [x] SUPP-08 Wiederholungen endlich begrenzen; Ruhezeiten berücksichtigen. Ausgelassene Einnahmen nicht automatisch auf den Folgetag übertragen oder zum Nachholen/zu einer zusätzlichen Einnahme auffordern.
- [x] SUPP-09 Mitteilung öffnet den passenden heutigen Eintrag; eine native Aktion „Genommen“ nur eindeutig der richtigen Einnahme zuordnen und sicher gegen doppelte Verarbeitung machen.
- [x] SUPP-10 Berechtigung erst bei freiwilliger Aktivierung erklären/anfragen. Der aktuelle Systemstatus, der bewusste Freigabeknopf und der Weg in die iPhone-Einstellungen sind eingebaut; die Liste bleibt ohne Freigabe nutzbar und die Oberfläche weist auf mögliche Verzögerung oder Ausbleiben hin.

## Speicherung, Datenschutz und Abnahme

- [x] SUPP-11 Auswahl, Einstellungen und bestätigte Einnahmen kontogebunden dauerhaft speichern; offline abgehakte Einnahmen zuverlässig abgleichen, ohne wiederholte Benachrichtigungen oder Verlust durch Neustart.
- [x] SUPP-12 Supplement-Namen und Einnahmen privat halten: keine automatische Veröffentlichung im Feed, in Profilen, Workout-Exporten oder an Freunde. Neutrale Sperrbildschirm-Vorschau als Standard.
- [x] SUPP-13 Abmelden/Accountwechsel, Kontolöschung, geänderte Zeiten und mehrere Geräte berücksichtigen; keine Erinnerungen für das falsche Konto oder eine bereits bestätigte Einnahme.
- [x] SUPP-14 Tageswechsel, Zeitzonenwechsel und Sommer-/Winterzeit mit eindeutigen Einnahme-IDs prüfen; keine doppelte Einnahmeaufforderung wegen veränderter Uhrzeit.
- [x] SUPP-15 Helles FYRUP-Design, erreichbare Schaltflächen und VoiceOver-Kennungen sind umgesetzt; Statuswechsel werden kurz animiert und respektieren „Bewegung reduzieren“.
- [ ] SUPP-16 Automatisiert und auf einem echten iPhone prüfen: Auswahl → Startseiten-Anzeige → erste Erinnerung → begrenzte Wiederholung → Abhaken stoppt Erinnerungen; zusätzlich Überspringen, Pausieren, Widerruf, Offlinezustand und Neustart.

Nachweise getrennt führen: Code → Speicherung/Backend → automatisierte Tests → visuelle Prüfung → echte iPhone-Zustellung. „Aufgenommen“ bedeutet nicht „ausgeliefert“.
