# Geschätzter Kalorienverbrauch und persönliches Tagesziel

Zusatzauftrag vom 05.09.2026: in die Checkliste aufnehmen. Teilweise lokal implementiert, noch nicht nativ oder auf einem iPhone abgenommen. Keine exakte Messung, medizinische Beratung oder automatische Abnehm-/Ernährungsvorgabe daraus ableiten.

Nachtrag ab 17:45 CEST: [Einrichtung und erste Health-Energieanzeige](MODERN_SETUP_LIVE_CHECKLIST.md) in Umsetzung. Körperdaten/privates aktives Tagesziel/gesonderter Read-only-Energiepfad werden ergänzt; native Prüfung noch ausstehend. Der erste Datenpfad übernimmt Apple Health, addiert keine Schritte oder Workouts dazu und ersetzt ausdrücklich **nicht** die noch offene eigene Schritt-/Intensitätsrechnung oder den freiwilligen KI-Zielvorschlag. Die Abnahmehaken darunter bleiben bis zu Nachweisen offen.

**Neuer lokaler Rechenstand:** Apple Health bleibt die bevorzugte und alleinige Quelle, sobald ein gültiger Wert aktiver Energie vorliegt. Ohne Health-Energie kann FYRUP nun nur bei vorhandener Körpergröße **und** vorhandenem Gewicht grob aus echten heutigen Schritten schätzen. Dokumentierte Annahmen: Schrittlänge `0,414 × Körpergröße`, mittleres ebenes Gehen mit 4,8 km/h und 3,8 MET; bei MET-Werten wird der Ruheanteil von 1 MET abgezogen. Für abgeschlossene eigene Gym-Aktivitäten wird nur tatsächliche aktive Dauer und ausdrücklich gespeichertes Easy/Mittel/Hardcore-Feedback berücksichtigt (3,5/5/6 MET). Weil keine zeitaufgelösten Schritte vorliegen, werden Schritt- und Gym-Schätzung **nicht addiert**, sondern nur der größere Wert gezeigt. Geplante, abgebrochene, fremde, doppelte und nicht-heutige Aktivitäten zählen nicht. Das ist absichtlich konservativ und sichtbar als grobe FYRUP-Schätzung markiert.

Fachliche Grundlage für die MET-Klassifikation ist das [2024 Adult Compendium of Physical Activities](https://pacompendium.com/adult-compendium/); dessen eigene Hinweise betonen, dass Standard-METs keine präzise individuelle Messung sind. Die konkreten Gehannahmen orientieren sich an der dort geführten Kategorie für [moderates ebenes Gehen](https://pacompendium.com/walking/). Der Größenfaktor der Schrittlänge bleibt eine offengelegte Näherung, keine Messung.

Fünf deterministische Rechentests sind vorbereitet: Health-Vorrang, fehlende Körperdaten, feste Schrittberechnung, explizite Gym-Intensität ohne Addition/Doppel-ID und Ausschluss unzulässiger Aktivitäten. Native Ausführung steht aus.

## Einrichtung und Startseite

- [x] KCAL-01 Körpergröße und Gewicht während der Registrierung/Ersteinrichtung erfassen, Einheiten erklären und Eingaben validieren; persönliche Verbrauchsschätzung erst mit den benötigten Angaben aktivieren. Fehlende Daten nicht erfinden. *(Quellstand; native UI-Abnahme offen.)*
- [ ] KCAL-02 Körperdaten später privat ändern und löschen können; Bestandsnutzer erhalten eine verständliche Einrichtung statt eines erfundenen Standardgewichts. Gültigkeitszeitpunkt für spätere Berechnungen speichern.
- [x] KCAL-03 Auf Heute „Geschätzter Verbrauch heute“ mit kcal, Datenquelle, Aktualisierungszeitpunkt und verständlichem Unsicherheitshinweis anzeigen. *(Quellstand; Beschriftung lautet derzeit „Bewegung heute“.)*
- [ ] KCAL-04 Verbrauch bis jetzt und eine eventuelle Tagesprognose ausdrücklich unterscheiden. Keine geplante oder abgebrochene Einheit als bereits vollständig absolviert berechnen.
- [x] KCAL-05 Tagesziel selbst eingeben, ändern oder deaktivieren; passend dazu Fortschritt und noch verbleibende kcal anzeigen. Bei Erreichen neutral bestätigen, keine negative Restzahl und kein Druck zu zusätzlichem Training. *(Quellstand.)*
- [x] KCAL-06 Zielart eindeutig benennen: aktive Bewegungskalorien oder Gesamtverbrauch einschließlich Ruheverbrauch. Niemals den gesamten Tagesenergiebedarf als zusätzlich durch Sport zu verbrennendes Ziel darstellen. *(Quellstand: nur aktive Bewegungskalorien.)*

## Nachvollziehbare Schätzung

- [ ] KCAL-07 Vor Umsetzung eine dokumentierte, geeignete Rechenmethode auswählen und fachlich prüfen; benötigte Zusatzangaben erläutern. Größe und Gewicht allein ergeben keinen verlässlichen individuellen Tagesbedarf.
- [x] KCAL-08 Schrittzahl und vorhandene geeignete Bewegungsdaten berücksichtigen; Schrittlänge, Tempo und andere unbekannte Parameter nicht als gemessen ausgeben. *(Quellstand mit sichtbarer Näherungskennzeichnung.)*
- [ ] KCAL-09 Training nach Sportart, tatsächlicher aktiver Dauer und selbst angegebener Intensität berücksichtigen. „Easy / Mittel / Hardcore“ ist eine subjektive Angabe, kein exakter physiologischer Messwert.
- [x] KCAL-10 Überschneidungen auflösen: Lauf-/Gehschritte während eines Trainings und bereits von Apple Health gelieferte Trainingsenergie nicht zusätzlich doppelt zählen. *(Quellstand: Health exklusiv; sonst Maximum statt Addition.)*
- [ ] KCAL-11 Ruheverbrauch, aktive Energie und Gesamtverbrauch getrennt berechnen/ausweisen; beim Trainingsmodell gegebenenfalls bereits enthaltenen Ruheanteil berücksichtigen.
- [ ] KCAL-12 Fehlende oder verweigerte Daten als fehlend anzeigen, nicht als 0 kcal; bei zu wenig Information keine scheinpräzise Tagesprognose erzeugen. Quelle und Schätzmethode sichtbar halten.
- [ ] KCAL-13 Neue HealthKit-Energiedaten nur nach gesonderter freiwilliger Freigabe lesen; vorhandene Schrittfreigabe ist keine Zustimmung zum Lesen oder Teilen aller Gesundheitsdaten.

## Freiwilliger KI-Zielvorschlag

- [ ] KCAL-14 Aktion „Ziel vorschlagen lassen“ anbieten. Erst nach bewusster Auswahl die nötigen Angaben und gewünschte Zielart klären; Vorschlag vor Übernahme anzeigen und manuell änderbar lassen.
- [ ] KCAL-15 Berechnung mit überprüfbarer Rechenlogik durchführen; KI erklärt Ergebnis, Eingaben, Annahmen und Grenzen, erfindet aber keine Berechnungsgrundlage. Ohne gültige Grundlage keine Zahl vorschlagen.
- [ ] KCAL-16 Keine automatische Defizit-, Gewichtsverlust- oder kompensatorische Sportvorgabe. Ungeeignete/extreme Ziele nicht mit mehr Training, Schuldtexten oder Push-Druck verstärken.
- [ ] KCAL-17 Geltungsbereich und sichere Ausnahmen des gewählten Modells prüfen, insbesondere Minderjährige, Schwangerschaft/Stillzeit und individuelle gesundheitliche Einschränkungen; bei fehlender Eignung keine persönliche KI-Empfehlung vortäuschen.
- [ ] KCAL-18 Vor externer KI-Verarbeitung offenlegen, welche persönlichen Daten an welchen Anbieter gesendet werden; datensparsam, freiwillig und widerrufbar. Keine Gesundheitsdaten ungefragt an Dritte senden; Schlüssel ausschließlich serverseitig, Fehler- und Kostenbegrenzung vorsehen.

## Integration und Prüfung

- [ ] KCAL-19 Körperdaten, Verbrauch und Ziel privat speichern; keine automatische Crew-Rangliste, Profilveröffentlichung, Exporte oder Übertragung in Trainings-Streak/Wochencredits.
- [ ] KCAL-20 Helles Design mit dezenter Fortschrittsanimation, gut lesbaren Zahlen, VoiceOver und „Bewegung reduzieren“; Karte auch ohne Daten ehrlich und hilfreich darstellen.
- [ ] KCAL-21 Einheiten, Pause/Fortsetzen, Über-Mitternacht-Training, Tages-/Zeitzonenwechsel, nachträgliche Daten, korrigiertes Gewicht, Offlinezustand und Neustart testen.
- [ ] KCAL-22 Rechentests mit festgelegten Eingaben sowie Doppelzählungs-, Datenschutz- und KI-Fehlerfällen; anschließend echte HealthKit-Daten und TestFlight auf dem iPhone prüfen. Keine Behauptung, die physiologische Genauigkeit sei durch Softwaretests bewiesen.

## Fachliche Ausgangspunkte für die spätere Umsetzung

Apple unterscheidet [aktive Energie](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned) und [Ruheenergie](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/basalenergyburned). Diese Trennung ist auch für die Anzeige und Vermeidung von Doppelzählung relevant.

Der [NIDDK Body Weight Planner](https://www.niddk.nih.gov/health-information/weight-management/body-weight-planner) verwendet mehr als Größe/Gewicht und nennt Einschränkungen seines Geltungsbereichs. Er ist hier eine Prüfreferenz, nicht automatisch der Algorithmus der App; FYRUP erhält durch diesen Auftrag keinen Gewichtsverlustplan.
