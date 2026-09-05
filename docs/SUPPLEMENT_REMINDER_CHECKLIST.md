# Freiwillige Supplement-Erinnerungen

Zusatzauftrag vom 05.09.2026. In Bearbeitung, noch nicht ausgeliefert. Dies ist eine persönliche Erinnerungsfunktion, keine Empfehlung für bestimmte Produkte, Dosierungen oder Einnahmehäufigkeiten.

## Nachweisstand

Private Datenmodelle, vier Backend-Schnittstellen, kontogebundene Offline-Vormerkungen, Demo-Speicherung und begrenzte Erinnerungswarteschlange sind vorbereitet. 113 neue lokale Datenbankprüfungen plus 836 bestehende Regressionen bestehen. Elf native Einzeltests sind geschrieben, aber noch nicht ausgeführt. Migration 013 ist **nicht** produktiv angewendet. Startseiten-Karte, Eingabemasken, App-Anbindung, Push-Versand/-Aktionen und Gerätekontrolle fehlen noch; deshalb bleiben die vollständigen Abnahmepunkte offen.

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
