# Freiwillige Supplement-Erinnerungen

Zusatzauftrag vom 05.09.2026. In Bearbeitung, noch nicht ausgeliefert. Dies ist eine persönliche Erinnerungsfunktion, keine Empfehlung für bestimmte Produkte, Dosierungen oder Einnahmehäufigkeiten.

## Nachweisstand

Private Datenmodelle, vier Backend-Schnittstellen, kontogebundene Offline-Vormerkungen, Demo-Speicherung und begrenzte Erinnerungswarteschlange sind integriert. **124 neue lokale Datenbankprüfungen plus 836 bestehende Regressionen bestehen**. Build31 (`7910f6c`) hat alle382 Einzeltests einschließlich aller13 Supplement-Tests bestanden. Der in Build30 gefundene Sommerzeitfehler ist im nativen Nachtest korrigiert; zusätzliche Tageswechsel- und gesperrter-Speicher-Prüfungen bestehen. Die UI-Suite läuft noch.

Im aktuellen Arbeitsstand sind Startseiten-Karte, eigene Tage/Uhrzeiten, Pause, Rückgängig, Entfernen, Ruhezeiten, optionale Push-Freigabe und neutrale Vorschau an das Konto angebunden. Der Push-Dispatcher prüft jede Einnahme vor jedem Gerät erneut; APNS wird angewiesen, Hinweise nicht für eine verspätete Offlinezustellung aufzubewahren. „Genommen“ öffnet die App mit Geräteentsperrung, überprüft zuerst die autorisierte Mitteilung und lädt dann die tatsächliche heutige Einnahme. Kontoersatz erhält eine neue Push-Zuordnung; Abmelden meldet das bekannte Gerät ab. Bereits von APNS akzeptierte Hinweise lassen sich nicht zurückrufen.

57 lokale Versand-/Terminologieprüfungen bestehen, einschließlich erneuter Gerätezuordnung direkt vor jedem Versand nach Kontowechsel. Der native UI-Test für freiwillige Einrichtung → Bestätigung → Neustart → Rückgängig → Überspringen → Pause bestand in Build31 nach57,5 Sekunden. **Migration013 wurde produktiv eingespielt und separat überprüft**:13 Historieneinträge, exakter normalisierter Quelltext-Prüfwert, fünf geschützte Tabellen, keine direkten Client-Schreibrechte oder Zugriffe auf interne Belege. Es wurden keine Supplements/Einnahmen angelegt. Neuer Dispatcher frisch vom Server vollständig verglichen; automatische Aufrufe12:54–12:56 CEST mitHTTP200 ohne Timeout. Vollständiger nativer Build, visuelle Prüfung, reale Mehrgeräte-/Offline-Pushzustellung und iPhone-Abnahme stehen aus; daher bleiben die vollständigen Abnahmepunkte offen.

Technische Grundlagen: [Apple zu Benachrichtigungsaktionen](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) und [minutenerhaltende Kalenderauflösung](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/nexttimepreservingsmallercomponents). Quellen erläutern die Plattform, ersetzen aber keinen Gerätetest.

## Persönliche Auswahl und Startseite

- [ ] SUPP-01 Eigene Supplements mit frei eingegebenem Namen hinzufügen, bearbeiten, pausieren und entfernen; keinerlei vorgewählte Einnahme oder automatische Produktempfehlung.
- [ ] SUPP-02 Selbst bestimmen, welche Supplements an welchen Tagen vorgesehen sind; für jedes Supplement eine oder mehrere selbst gewählte Einnahmezeiten ermöglichen.
- [ ] SUPP-03 Auf Heute eine kompakte Karte mit den heutigen Einträgen und eindeutigem Zustand „Offen“, „Genommen“ oder „Übersprungen“ anzeigen; optionale Funktion ohne Pflicht zur Einrichtung.
- [ ] SUPP-04 Jede vorgesehene Einnahme separat mit „Genommen“ abhaken; Zeitpunkt speichern, Doppeltippen idempotent behandeln und versehentliche Bestätigung rückgängig machen können.
- [ ] SUPP-05 „Heute überspringen“ und zeitweises Pausieren anbieten, ohne Druck, Schuldtexte oder Auswirkung auf Trainings-Streak und Wochenziel.

## Einstellbare Erinnerungen

- [ ] SUPP-06 Erinnerungen freiwillig aktivieren; Zeiten, Wiederholungsabstand und maximale Anzahl pro noch offener Einnahme selbst einstellen können. Auch keine Wiederholung erlauben.
- [ ] SUPP-07 Nur erinnern, solange die betreffende Einnahme offen ist; „Genommen“, „Übersprungen“, Pausieren oder Entfernen löscht alle ausstehenden Erinnerungen dieser Einnahme.
- [ ] SUPP-08 Wiederholungen endlich begrenzen; Ruhezeiten berücksichtigen. Ausgelassene Einnahmen nicht automatisch auf den Folgetag übertragen oder zum Nachholen/zu einer zusätzlichen Einnahme auffordern.
- [ ] SUPP-09 Mitteilung öffnet den passenden heutigen Eintrag; eine native Aktion „Genommen“ nur eindeutig der richtigen Einnahme zuordnen und sicher gegen doppelte Verarbeitung machen.
- [ ] SUPP-10 Berechtigung erst bei Aktivierung erklären/anfragen. Bei verweigerter oder widerrufener Mitteilungsfreigabe bleibt die Startseiten-Liste nutzbar; keine garantierte oder sekundengenaue Zustellung versprechen.

## Speicherung, Datenschutz und Abnahme

- [ ] SUPP-11 Auswahl, Einstellungen und bestätigte Einnahmen kontogebunden dauerhaft speichern; offline abgehakte Einnahmen zuverlässig abgleichen, ohne wiederholte Benachrichtigungen oder Verlust durch Neustart.
- [ ] SUPP-12 Supplement-Namen und Einnahmen privat halten: keine automatische Veröffentlichung im Feed, in Profilen, Trainings-Exporten oder an Freunde. Neutrale Sperrbildschirm-Vorschau als Standard.
- [ ] SUPP-13 Abmelden/Accountwechsel, Kontolöschung, geänderte Zeiten und mehrere Geräte berücksichtigen; keine Erinnerungen für das falsche Konto oder eine bereits bestätigte Einnahme.
- [ ] SUPP-14 Tageswechsel, Zeitzonenwechsel und Sommer-/Winterzeit mit eindeutigen Einnahme-IDs prüfen; keine doppelte Einnahmeaufforderung wegen veränderter Uhrzeit.
- [ ] SUPP-15 Helles FYRUP-Design, gut erreichbare Schaltflächen, VoiceOver und reduzierte Bewegung berücksichtigen; Abhaken dezent animieren.
- [ ] SUPP-16 Automatisiert und auf einem echten iPhone prüfen: Auswahl → Startseiten-Anzeige → erste Erinnerung → begrenzte Wiederholung → Abhaken stoppt Erinnerungen; zusätzlich Überspringen, Pausieren, Widerruf, Offlinezustand und Neustart.

Nachweise getrennt führen: Code → Speicherung/Backend → automatisierte Tests → visuelle Prüfung → echte iPhone-Zustellung. „Aufgenommen“ bedeutet nicht „ausgeliefert“.
