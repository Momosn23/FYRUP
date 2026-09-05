# FYRUP – zentrale Produkt- und Abnahmecheckliste

Stand: 05.09.2026. Verbindliche Arbeitsliste für die vier letzten Erweiterungsaufträge und deren Integration in das helle Design mit dezenten Animationen. Sie ersetzt widersprüchliche alte Umfangsangaben, nicht die ursprünglichen Anforderungen.

## 1. Status und Abnahmeregel

Aktualisierung 15:03 CEST: GitHub 46 ist nach 29 min 4 s fehlgeschlagen; der Datumsknopf-Fehler ist als lokale Korrektur `a56f89d` gesichert. Zusätzlich hat Apple den älteren signierten Build 9 nach erfolgreichem App-Bau mit 90683 wegen fehlendem Health-Erklärungstext abgewiesen. [Ergänzter Text und IPA-Vorabprüfung](HEALTH_PURPOSE_RELEASE_FIX.md), sieben lokale Tests bestanden. **Noch kein neuer Apple-Upload erfolgreich.** Die bisherigen erfolgreichen Einzelnachweise bleiben gültig, beweisen aber keine erfolgreiche Auslieferung.

Neuester Nachtrag, 14:54 CEST: `717472c` ist auf `main`. GitHub 46 hat **396 Einzeltests, den erweiterten Privatsphäre-Bedientest und den Supplement-Bedientest bestanden**. Beim neuen Datumsknopf scheitert dagegen die Button-Erkennung; [gezielte Korrektur und zusätzlicher Diagnosenachweis](SESSION_DATE_BUTTON_FIX.md) sind lokal vorbereitet, noch nicht nativ nachgeprüft. Die [sieben einzeln betrachteten Bilder aus Build 35](VISUAL_QA_BUILD35.md) bestätigen die Satzfeld-Beschriftungen, zeigen aber weiterhin Abweichungen bei Onboarding und Home-Gewichtung. Kein pixelgleicher oder vollständiger Produktabschluss.

Der ältere signierte Build 9 (`7472300`) hat inzwischen alle **27 Bedienabläufe mit 0 Fehlern** bestanden, `TEST SUCCEEDED`. Profilprüfung bestanden; eigentliche IPA-Erstellung, eingebettete Konfiguration und Apple-Verarbeitung bleiben noch offen. Er enthält nicht `717472c` oder die jüngste Datumsknopf-Korrektur. Ältere Standangaben darunter sind historische Nachweise.

Aktueller Nachtrag, 14:29 CEST: [GitHub-Lauf 45](https://github.com/Momosn23/FYRUP/actions/runs/33964666140/job/101302561364) für `1a953af` ist vollständig erfolgreich nach 28 min 39 s: **383 Einzeltests und 27 UI-Abläufe, jeweils 0 Fehler**. Codemagic 35 ist ebenfalls vollständig erfolgreich, einschließlich aller 27 UI-Abläufe und Artefakte. Damit sind die dokumentierten GitHub-Compiler-/Headerfehler nativ nachgeprüft. Der signierte Build 8 scheiterte hingegen vor dem App-Bau an einem [Einlesefehler im Signierungsprüfskript](SIGNING_PROFILE_PIPE_FIX.md); **keine IPA, kein Apple-Upload**. Die separat getestete Skriptkorrektur `7472300` ist hochgeladen. [Signierter Build 9](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c07536942048ebcb1f844) hat inzwischen die sieben Parser-Tests und Prüfung des echten Apple-Profils bestanden; native Tests laufen, IPA/Upload noch offen.

Die [vier gezielten Bilder aus Build 34](VISUAL_QA_BUILD34.md) bestätigen den erreichbaren Abschlussknopf nach Scrollen, aber noch abgeschnittenes Datum und Supplements-Einleitung. Weitere lokale Korrekturen samt Bediennachtests sind vorbereitet. Zusätzlich ist der [fehlerhafte Sichtbarkeits-Speicherpfad](ACTIVITY_PRIVACY_SAVE_FIX.md) lokal auf bestätigte, kontogeschützte Einzeländerungen umgestellt: **975 lokale Datenbankprüfungen bestanden**, 13 neue native Einzeltests und erweiterter UI-Test noch offen. Diese neuen Änderungen sind **nicht** im grünen `1a953af` oder angeforderten TestFlight 9 enthalten. Ältere laufend/offen-Angaben darunter sind Historie.

Neuester Zusatzauftrag: [gesamte sichtbare Sprache überarbeiten](TERMINOLOGY_CHECKLIST.md). Die [neue Terminologie](TERMINOLOGY.md) ist ab sofort auch für zukünftige Features verbindlich: Aktivität / Session / Workout / Einheit nach Kontext. Technische Namen und Daten nicht blind ersetzen.

Aktualisierung ab 13:20 CEST: Build 31 (`7910f6c`) ist vollständig erfolgreich: **382 Einzeltests und 27 UI-Abläufe**. [Bildschirmaufnahmen einzeln mit der Referenz verglichen](VISUAL_QA_BUILD31.md); drei Layout-Nachbesserungen sind in `6e79a31` enthalten. Sprachüberarbeitung und private Supplement-Liste integriert; 960 lokale Datenbank- und 57 Versand-/Terminologieprüfungen bestehen. Backend 001–013 ausgerollt und unabhängig geprüft; Push-Dienst beantwortete automatische Aufrufe 12:54–12:56 CEST mit HTTP 200. **Privater Apple-Push-Schlüssel fehlt noch im Serverbereich; konkrete Freigabe zum Hinterlegen angefragt.** Keine echte Zustellung oder neue TestFlight-Version behauptet. [GitHub-Kompatibilitätsprobleme separat nachverfolgt](GITHUB_CI_2026-09-05.md); Build 34 / GitHub-Lauf 44 prüfen den neuesten Stand. Nachfolgende ältere Build-Angaben bleiben Historie.

Aktualisierung 13:55 CEST: **Codemagic-Build 34 (`6e79a31`) vollständig erfolgreich, 27 UI-Abläufe ohne Fehler.** GitHub-Lauf 44 hat 383 Einzeltests und 26/27 UI-Abläufe bestanden; allein die Erkennung einer Datenschutz-Überschrift scheiterte. Dafür ist eine separate Korrektur mit unverändertem Textnachweis vorbereitet. Der **signierte TestFlight-Build 8** mit `6e79a31` läuft inzwischen, noch kein Apple-Upload. Alle 70 einzelnen App-Aufnahmen aus Build 31 sind im [Bildschirmbericht](VISUAL_QA_BUILD31.md) erfasst. Dauerhafte Feldbeschriftungen für Gewicht/Wiederholungen sind anschließend lokal ergänzt, einschließlich Entwurfs-/Neustart-Prüfung; **noch nicht Teil von `6e79a31` oder TestFlight 8**, nativer Nachtest offen.

Zusätzlicher offener Sicherheitsbefund bei dieser Codeprüfung: Die ältere Sichtbarkeits-Auswahl in `PrivacyView` ignoriert gegenwärtig einen fehlgeschlagenen Speichervorgang und ändert anschließend trotzdem die lokale Profilanzeige. Vor einer vollständigen Datenschutz-Abnahme auf bestätigtes Speichern, sichtbare Fehler und Schutz bei Kontowechsel umstellen. Der oben korrigierte Header-Test ist kein Nachweis dafür.

Historie: Build27 (`63047cb`) wurde am05.09.2026 nach21m22s erfolgreich beendet; alle24 UI-Abläufe bestanden, einschließlich korrigierter Teilen-Vorschau. Build26 hatte zuvor346 Unit-Tests und23/24 UI-Abläufe bestanden. Der neue Wochenrhythmus-/Bewertungsblock war noch nicht Teil von Build27; sein [separater Prüfstand](PERSONAL_TRAINING_IMPLEMENTATION_STATUS.md) weist836 lokale Datenbankprüfungen aus. Produktive Migrationen001–011 und Benachrichtigungsdienst wurden ausgerollt und separat überprüft: [Deploymentnachweis](DEPLOYMENT_2026-09-05.md). Die nachfolgenden älteren Bereichstabellen sind historische Zwischenstände, nicht der aktuelle Release-Stand.

Neu hinzugekommen am 05.09.: sichtbare Bezeichnung „Deine Streak“; freiwilliger sportbezogener Trainingsrhythmus mit Häufigkeit, Dauer, frei gewählten Wochentagen und einer Wochenleiste auf Heute. Die zusätzlichen Anforderungen werden in [WEEKLY_ROUTINE_CHECKLIST.md](WEEKLY_ROUTINE_CHECKLIST.md) separat geführt und ersetzen nicht die Abnahmeregeln dieser Liste.

Weitere Ergänzungen desselben Tages: private Trainings-/Übungsbewertung und Animationen in der Wochenplanliste; [Einladungslinks und freiwillige Kontakte-Suche](FRIEND_INVITES_CHECKLIST.md); [Trainingsort, Stammgym, Ankunftserinnerung, Live-Aktivität, Homescreen-Widget und Satzpausentimer](LOCATION_LIVE_ACTIVITY_CHECKLIST.md). Alle Zusatzlisten sind Bestandteil dieser zentralen Liste; „aufgenommen“ bedeutet nicht „ausgeliefert“.

Ebenfalls aufgenommen: [freiwillige Supplement-Liste auf Heute mit Abhaken und begrenzt wiederholbaren Erinnerungen](SUPPLEMENT_REMINDER_CHECKLIST.md). Auswahl, Zeiten und Erinnerungshäufigkeit bestimmt der Nutzer; keine Dosierungs- oder Produkteempfehlungen.

Zusätzlich: [geschätzter Kalorienverbrauch auf Heute, Körperdaten bei der Einrichtung, Tagesziel und freiwilliger KI-Zielvorschlag](CALORIE_ESTIMATE_CHECKLIST.md). Aktive Energie und Gesamtverbrauch unterscheiden, Überlappungen vermeiden und keine Schätzung als exakte Messung ausgeben.

Neueste Bildreferenz: [moderne Bildsprache auf allen Seiten und interaktive Körperfigur mit aufleuchtenden Muskelgruppen](MODERN_VISUALS_CHECKLIST.md). Die Funktionsidee wird in das helle FYRUP-Design integriert; konkrete visuelle und funktionale Abnahmepunkte bleiben bis zum Nachweis offen.

`[ ]` = noch nicht vollständig abgenommen. `[x]` = umgesetzt und durch einen konkreten Prüfnachweis belegt. Vorbereiteter Code, ein grüner Build oder ein einzelner Screenshot bedeuten jeweils noch keine vollständige Funktionsabnahme.

Nachweise werden getrennt geführt: **Code integriert → Backend geprüft/ausgerollt → automatisierte Tests → manuell bedient/visuell verglichen → echtes iPhone/TestFlight**. Nicht zutreffende Schritte begründen. Nicht ausgeführte oder fehlgeschlagene Tests bleiben offen.

| Bereich | Belegter Stand | Noch nicht abgenommen |
| --- | --- | --- |
| Trainingspläne / Bibliothek | 105 lokale PostgreSQL-Tests; native Unit-Tests bestanden. Build24: alle4 Workout-UI-Flows einschließlich Einfach/Tracken/Neustart bestanden. [Arbeitsnachweis](WORKOUT_IMPLEMENTATION_STATUS.md) | Frische visuelle/manuelle Abnahme, produktives Backend und iPhone |
| Apple Health / Schritte | 100 lokale PostgreSQL-Tests,32 native Unit-Tests bestanden. Build25: beide Schritte-UI-Tests einschließlich bestätigtem ON/OFF bestanden. [Arbeitsnachweis](HEALTH_IMPLEMENTATION_STATUS.md) | Visuelle Nachkontrolle, produktives Backend/Signing und Gerätetest |
| Neues Wochenziel-/Flammensystem | 183 Weekly-DB- plus50 Onboardingprüfungen bestanden; Build25:30 Store- und12 Repository-Tests bestanden, Zielwechsel-/Neustart-UI bestanden. [Arbeitsnachweis](WEEKLY_IMPLEMENTATION_STATUS.md) | Produktive Migration, manuelle und iPhone-Abnahme |
| Blind Workout / Call My Shot | Server, Modelle, Speicherung und helle UI integriert. 678 gemeinsame lokale DB-Prüfungen; Build25:87 native Unit-Tests und beide neuen UI-Abläufe bestanden. [Arbeitsnachweis](SOCIAL_EXTENSIONS_IMPLEMENTATION_STATUS.md) | Produktiv-Backend, visuelle Abnahme, Push und iPhone |
| Helles Grunddesign | Bestehende SwiftUI-Seiten und Referenzliste vorhanden | Vergleich jeder Seite und Integration der neuen Funktionen |

Bestandsnachweis: Cloud-Build17 (`4311282`),11 UI-Tests bestanden. Build18 (`f461c1b`) erfolgreich; Einzelbilder visuell geprüft, Abweichungen in VISUAL_QA_BUILD18.md und VISUAL_QA_BUILD18_DETAILS.md dokumentiert. Feature-Builds19/20 scheiterten beim Kompilieren;21 an einer Schritte-Zeitgrenzenprüfung, jeweils korrigiert. **Build22 (`b899685`):117 native Unit-Tests bestanden;19 UI-Tests tatsächlich ausgeführt,15 bestanden und4 fehlgeschlagen.** Kein grüner Feature-Gesamtlauf. Echte iPhone-/HealthKit-Abnahme und TestFlight-Auslieferung der neuen Funktionen weiterhin **NICHT AUSGEFÜHRT**.

Dokumentenprüfung am 05.09.2026: 230 eindeutige Hauptlisten-IDs, alle 41 Auftragstests, alle 127 verlangten Übungs-Gruppeneinträge im Katalog-Anhang und 16 lokale Dokumentlinks geprüft. Die 127 Einträge sind nach benannter Singular-/Plural-Zuordnung in den 122 Übungsnamen des Dateientwurfs enthalten. Das prüft Vollständigkeit der Liste/Namen, nicht Muskelmetadaten, App-Verhalten oder Datenbankfunktion.

## 2. Quellen und Vorrang

Aktualisierung Build24 (`bb03c6f`):159 Unit-Tests ausgeführt,158 bestanden;20 UI-Tests ausgeführt,18 bestanden. Alle4 Trainingsplan-Bedienabläufe und Weekly-Zielwechsel/Neustart bestanden. Drei Korrekturen für den nächsten Lauf: fehlendes Testprofil, inzwischen umbenannter Feed-Button sowie gezieltes Antippen des inneren nativen Schritte-Schalters. Produktive Strukturprüfung: Erweiterungen noch nicht ausgerollt. Der neuere Stand ergänzt die historische Build22-Bilanz oben.

Originale: jeweils `pasted-text.txt` im genannten Unterordner von `C:/Users/Momo/.codex/attachments/`.

| Kürzel | Auftrag / Dateiordner | Abdeckung |
| --- | --- | --- |
| T | Trainingspläne / Bibliothek / eigene Übungen – `3c09e199-56cd-4331-9346-4261b021aea5` | §§1–5 PLAN/LIB; §§6–19 Katalog-Anhang; §§20–27 CUSTOM/LIB; §28 PLAN/QA; §§29–42 SHARE/TRACK; §§43–44 DATA/SEC; §§45–46 DESIGN; §47 Ausschlüsse; §§48–49 QA/BASE |
| H | Apple Health / HealthKit – `01f4eff2-5894-40fd-92ce-fa92b08f5dd3` | §§1–16 HEALTH/DATA/SEC; §17 HEALTH/Optionen; §18 Zukunft; §19 DESIGN; §20 QA-HEALTH |
| F | Wochenziel / Flammen – `a2edda18-8cea-4752-940e-03225c0e60c9` | §§1–20 WEEK; §21 ANIM; §§22–25 WEEK/BASE; §26 Optionen; §27 WEEK; §§28–33 DATA/SEC/WEEK; §§34–38 DESIGN/WEEK; §39 QA-FLAME; §§40–41 Integration |
| B | Blind Workout / Call My Shot – `897fdd10-0407-44eb-85a7-34135f31e6d5` | §§1–13 BLIND; §§14–30 SHOT; §31 Integration; §§32–33 DESIGN/ANIM; §§34–35 QA-BLIND/QA-SHOT; §36 BASE/Release |

Design: [helles 24-Seiten-Storyboard](reference/FYRUP-light-storyboard.png), [Einzelseiten-Abnahme](LIGHT_STORYBOARD_CHECKLIST.md). Die [alte Master-Checkliste](MASTER_CHECKLIST.md) bewahrt historische Bestandsnachweise; sie belegt nicht diese Erweiterungen.

Verbindliche Regeln bei Überschneidungen:

- Hell/Weiß/Grau/Grün ersetzt die frühere dunkle Designrichtung.
- Trainingspläne, optionale Satzdaten und HealthKit-Schritte sind jetzt beauftragt, nicht länger ausgeschlossen.
- Neues Wochenziel **3–7** statt 1–7. Erhöhung und Senkung gelten beide erst nächste Woche.
- Normale Einladungen zeigen den vollständigen Plan vor der Antwort. Blind Workouts zeigen nur die sichere Zusammenfassung; „Ansehen“ öffnet diese Zusammenfassung, keine versteckte vollständige Übungsliste.
- „Privat“ bedeutet keine automatische Freigabe an alle Freunde. Eine bewusste Einzel-Einladung/-Freigabe autorisiert nur ihre Empfänger.
- Flamme sofort bei Zielerreichung; Wochen-Streak aus abgeschlossenen Wochen; Schritte zählen für keines von beiden.
- „Optional für den Nutzer“ ist eine echte App-Auswahl, kein Weglassen bei der Umsetzung. Nur ausdrücklich optionale Produkterweiterungen stehen separat in Abschnitt 13.

## 3. Bestehenden Social-Kern erhalten

- [ ] BASE-01 Heute bleibt der Einstieg: Crew, eigener Status, Wochenfortschritt und Social-Aktionen vor detaillierten Trainingszahlen.
- [ ] BASE-02 NOT YET / PLANNED / LIVE / DONE inklusive Sortierung, Tageswechsel und echten Leerzuständen erhalten.
- [ ] BASE-03 Apple-/E-Mail-Login, Registrierung, Logout und Session-Wiederherstellung erneut testen; abgeschlossenes Onboarding führt nach Neustart nach Heute.
- [ ] BASE-04 Unvollständiges Onboarding richtig fortsetzen; optionales Profilfoto, Profilfelder, Sportarten und Gym-Körpergruppen dauerhaft speichern.
- [ ] BASE-05 Freunde suchen/anfragen/annehmen/ablehnen/entfernen/blockieren; private Gruppen erstellen und beim Planen auswählen.
- [ ] BASE-06 Planen, Einladungen, Dabei / Vielleicht / Kann nicht, Mitziehen, FYR UP und Reaktionen mit und ohne Trainingsplan erhalten.
- [ ] BASE-07 Eine eigene LIVE-Aktivität gleichzeitig; parallele Trainings verschiedener Freunde unabhängig. Bestehende Notifications und Einstellungen erhalten.
- [ ] BASE-08 Jede sichtbare Aktion tatsächlich anschließen; keine funktionslosen Einstellungszeilen, Dummy-Schalter oder erfundenen Messwerte.
- [ ] BASE-09 Kein HealthKit, keine Schrittfreigabe, kein Satztracking und kein Call My Shot dürfen übrige Kernfunktionen blockieren.

## 4. Trainingspläne, Bibliothek und eigene Übungen

### Pläne – T §§1–4, 28–30

- [ ] PLAN-01 Gym-Auswahl: „Meine Trainingspläne“, „Freies Training“, „Neuen Trainingsplan erstellen“; alle Wege bis LIVE/DONE bedienbar.
- [ ] PLAN-02 Eigene Pläne anzeigen, erstellen, öffnen, bearbeiten und speichern; leere Sammlung erklären; Persistenz nach Neustart/erneuter Anmeldung.
- [ ] PLAN-03 Name verpflichtend; Kategorie/Beschreibung optional. Kategorien: Push, Pull, Legs, Upper Body, Lower Body, Full Body, Chest, Back, Arms, Shoulders, Cardio, Custom.
- [ ] PLAN-04 Pro Übung Ziel-Sätze und Wiederholungen/-bereich; Gewicht/Notiz optional. Pflichtfelder und unzulässige Werte verständlich validieren.
- [ ] PLAN-05 Übungen hinzufügen/entfernen, per Drag & Drop umsortieren und Reihenfolge speichern; zugängliche Alternative zum Ziehen.
- [ ] PLAN-06 Vorlagenänderungen verändern keine abgeschlossenen Protokolle; laufende Trainings nutzen konsistente Momentaufnahmen.
- [ ] PLAN-07 Direktstart und Terminplanung verwenden denselben Plan; Name, Fokus, Übungsanzahl und Dauer konsistent.
- [ ] PLAN-08 Beispiel „Push Day“ mit sechs Übungen und Zielvorgaben aus dem Auftrag anlegen können; keine vorgetäuschten Nutzerpläne in Produktion.

### Bibliothek – T §§5–19, 26, 46

- [ ] LIB-01 Jede verlangte Übung anhand der [vollständigen Katalog-Checkliste](EXERCISE_CATALOG_CHECKLIST.md) prüfen; eine Gesamtanzahl allein genügt nicht.
- [ ] LIB-02 Stabile IDs, Name, Haupt-/Nebenmuskeln, Equipment, Übungstyp, Standard/Custom, Ersteller vollständig; App- und Backend-Katalog identisch.
- [ ] LIB-03 Filter: Brust, Rücken, Schulter, Bizeps, Trizeps, Quadrizeps, Beinbeuger, Gesäß, Waden, Adduktoren, Bauch/Core, Trapez, Unterarme, Ganzkörper, Sonstiges.
- [ ] LIB-04 Standard- und eigene Übungen gemeinsam suchen; Suchtext und Muskelgruppenfilter kombinieren; auch Nebenmuskel-Zuordnungen auffindbar.
- [ ] LIB-05 „Alle“, „Favoriten“, „Eigene“; Favoriten hinzufügen/entfernen und kontogebunden dauerhaft speichern.
- [ ] LIB-06 Kompakte Karten mit Name, Muskel, Equipment, Auswahl- und Favoritenaktion; Halte-/Zeitübungen ohne falsche Wiederholungsbeschriftung darstellen.

### Eigene Übungen – T §§20–27, 35

- [ ] CUSTOM-01 „+ Eigene Übung“ in allen Übungsauswahlen einschließlich Blind Workout und leerer Suche erreichbar.
- [ ] CUSTOM-02 Name/Hauptmuskel verpflichtend; Nebenmuskeln/Equipment/Notiz optional; alle vorgegebenen Equipment-Optionen anbieten.
- [ ] CUSTOM-03 Erstellen fügt die Übung unmittelbar in den gerade bearbeiteten Plan/das Blind Workout ein; kein erneutes Suchen nötig.
- [ ] CUSTOM-04 Eigene Übungen bleiben unter „Eigene“ und Suche vorhanden; nur Eigentümer darf Name/Muskeln/Equipment/Notiz bearbeiten.
- [ ] CUSTOM-05 Ähnliche/gleiche Namen: sanfter Hinweis „Vorhandene verwenden“ oder „Trotzdem erstellen“, keine erzwungene Zusammenführung.
- [ ] CUSTOM-06 Verwendete Übungen archivieren statt hart löschen; aus normaler Auswahl entfernen, historische Namen/Satzdaten und bestehende Pläne erhalten.
- [ ] CUSTOM-07 Standardübungen nicht für alle Nutzer veränderbar; private Custom-Übungen nur über ausdrücklich autorisierte Freigaben zugänglich.
- [ ] CUSTOM-08 Fremde Pläne einschließlich eigener Custom-Kopien kopieren; anschließende Bearbeitung/Archivierung auf beiden Seiten unabhängig.

### Gemeinsam planen, teilen und kopieren – T §§30–37, 42, 44

- [ ] SHARE-01 Konkreten Plan mit Datum/Uhrzeit/Dauer und Freunden/Gruppen planen; Ort, Notiz und Beitrittseinstellungen erhalten.
- [ ] SHARE-02 Vor Dabei / Vielleicht / Kann nicht sieht der Empfänger Planname, vollständige Übungen und Dauer; Antwort gehört zur richtigen Session.
- [ ] SHARE-03 Mittrainieren: „Für dieses Workout verwenden“ oder „In meine Sammlung kopieren“; keine erzwungene dauerhafte Kopie.
- [ ] SHARE-04 Gleiche Vorlage, aber pro Person eigene Aktivität, Uhr, Übungsabschlüsse und Satzdaten.
- [ ] SHARE-05 Gezielt an akzeptierten Freund teilen; Mitteilung mit „Ansehen“/„In meine Pläne speichern“; Wiederholung ohne ungewollte Duplikate.
- [ ] SHARE-06 Kopie mit eigenem Eigentümer und unabhängigen Inhalten einschließlich Custom-Übungen; optionale Herkunftsreferenz.
- [ ] SHARE-07 Neue Pläne privat; Sichtbarkeit „Freunde“ bewusst wählen; Freundesprofil zeigt nur autorisierte Pläne.
- [ ] SHARE-08 Blockierte/entfernte Freunde ohne neue Abruf-/Freigaberechte; bereits rechtmäßig gespeicherte unabhängige Kopien bleiben eigene Daten, Grenze transparent erklären.

### Live-Training und Protokoll – T §§38–42

- [ ] TRACK-01 Live-Kopf: Gym, Planname, LIVE, Dauer, aktuelle Übung und Fortschritt, z. B. 2/6; Social-Aktionen erreichbar.
- [ ] TRACK-02 „Einfach“: Übung/Ziel-Sätze/Ziel-Reps/Abhaken; Abschluss ohne tatsächliche Gewichte oder Wiederholungen möglich.
- [ ] TRACK-03 „Tracken“: tatsächliche Gewichte, Wiederholungen, Sätze und einzelne Satz-Häkchen; Zielwerte getrennt von tatsächlichen Werten speichern.
- [ ] TRACK-04 Optionale leere Angaben nicht als Messwert Null ausgeben; Abschluss-/Eingabestand über Hintergrund und Neustart wiederherstellen.
- [ ] TRACK-05 Pause hält Zeit wirklich an, Fortsetzen/Stop/Abbrechen funktionieren; nicht nur Pause-Icon umschalten.
- [ ] TRACK-06 Abschluss mit Dauer, Übungen, optional Sätzen/Trainingspartner; „Fertig“ und „Mit Freunden teilen“ funktionieren.
- [ ] TRACK-07 Feed nur mit freigegebener Zusammenfassung, nicht automatisch Gewichte/Wiederholungen/komplette Satzprotokolle veröffentlichen.
- [ ] TRACK-08 Historische Übungsnamen/Zielvorgaben/Satzdaten trotz späterer Änderungen erhalten; Speichern/Retry erzeugt keine Duplikate oder doppelten Wochen-Credits.

## 5. Apple Health und Schritte – H §§1–19

- [ ] HEALTH-01 Capability, Nutzungsbeschreibung und passende Signierung/Provisionierung im gebauten iOS-Target prüfen.
- [ ] HEALTH-02 Vor Systemdialog „Deine tägliche Bewegung“ erklären: Lesen, eigene Kontrolle, Freunde nur separat freigeben; „Mit Apple Health verbinden“ / „Nicht jetzt“.
- [ ] HEALTH-03 Nur `stepCount` lesen, keine Schreibrechte oder anderen Gesundheits-/Standortdaten anfordern.
- [ ] HEALTH-04 Heutige HealthKit-Statistik im lokalen Tagesintervall; iPhone-/Watch-Quellen nicht selbst aufsummieren; überlappende Quellen prüfen.
- [ ] HEALTH-05 Dialog-Erfolg nicht als bewiesene Lesefreigabe ausgeben; fehlende Daten nicht als „verweigert“ interpretieren; unbekannt/fehlend/echte Null unterscheiden.
- [ ] HEALTH-06 Profil → Einstellungen → Privatsphäre → Schritte: Verbindung/erneut verbinden, „Meine Schritte anzeigen“, „Schritte mit Freunden teilen“ getrennt bedienen.
- [ ] HEALTH-07 Social-Sharing standardmäßig AUS, auch nach HealthKit-Verbindung; vor Aktivierung Sichtbarkeit heutiger Schritte für akzeptierte Freunde erklären.
- [ ] HEALTH-08 Eigene Heute-Karte „Dein Tag“ mit Schritten/dezentem Fortschritt; eigene Anzeige unabhängig von Social-Freigabe schaltbar.
- [ ] HEALTH-09 Erst nach bestätigtem Opt-in Tagesaggregat hochladen; keine Samples, Schritt-Zeitpunkte, Geräte-/Bewegungsprofile oder anderen Health-Daten.
- [ ] HEALTH-10 Freigegebene heutige Schritte im Feed/Freundesprofil auch bei NOT YET; sonst Wert auslassen oder neutral „Schritte privat“.
- [ ] HEALTH-11 Freundesansichten verraten nicht, ob HealthKit fehlt/abgelehnt wurde/keine Daten liefert oder Sharing aus ist.
- [ ] HEALTH-12 Ausschalten sperrt weitere Serverabrufe sofort; paralleler/veralteter Upload darf nicht erneut freigeben. Friend-Cache bei Aktualisierung verwerfen.
- [ ] HEALTH-13 App-Start, Heute öffnen, Vordergrund und Tageswechsel aktualisieren; drosseln statt sekündlich abfragen.
- [ ] HEALTH-14 Datensatz eindeutig pro Nutzer/lokalem Datum; Mitternacht/Zeitzonenwechsel zeigen gestern nicht als heute.
- [ ] HEALTH-15 Fehlende/widerrufene Daten blockieren nichts; veraltete Werte nicht als frisch ausgeben. Fehlgeschlagenes Abschalten niemals als „Sharing AUS“ bestätigen.
- [ ] HEALTH-16 Kontoabhängige Einstellungen und Cache isolieren; Logout/Kontowechsel verwirft verspätete Antworten des alten Kontos.
- [ ] HEALTH-17 Persönliches Schrittziel optional: 5.000 / 7.500 / 10.000 / 12.500 / eigener Wert; privat und unabhängig vom Trainingsziel.
- [ ] HEALTH-18 Schritte erzeugen keine Workout-Credits/Flammen/Call-Erfolge; kleine Schrittänderungen lösen keine Push-Flut aus.

## 6. Wochenziel und Flammen – F §§1–41

- [ ] WEEK-01 Pflichtauswahl im Onboarding: 3/4/5/6/7 Trainings; Vorschlag nur nach bewusster Bestätigung speichern, nicht heimlich vorbelegen.
- [ ] WEEK-02 Zielschritt sinnvoll nach Sportarten einfügen; Fortschrittsanzeige an tatsächliche Schritte anpassen, nach Neustart richtigen Stand wiederherstellen.
- [ ] WEEK-03 Bestehende Nutzer/Ziele 1–2 behutsam auf die neue Auswahl migrieren; abgeschlossene Historie nicht nachträglich umschreiben oder bestehende Konten blockieren.
- [ ] WEEK-04 Nur echte, in FYRUP abgeschlossene Trainings zählen; alle zulässigen Sportarten gleich behandeln.
- [ ] WEEK-05 PLANNED, LIVE, abgebrochene Trainings, Logins, Schritte, Kalorien, Likes oder Freunde erzeugen keine Credits; Dauer allein verdient keine Flamme.
- [ ] WEEK-06 Mehrere echte Trainings am selben Tag zählen jeweils; einfache serverseitige Regel gegen künstliche Kurz-/Sofort-Abschlussserien festlegen, dokumentieren und testen. Kein komplexes Anti-Cheat-System.
- [ ] WEEK-07 Jede Activity höchstens einmal gutschreiben, auch bei Doppeltap, Retry, gleichzeitigem Abschluss oder Wiederverbindung; keine Client-Zähler akzeptieren.
- [ ] WEEK-08 Lokale Woche Montag 00:00 bis nächsten Montag 00:00, Zeitpunkte in UTC; Sommer-/Winterzeit, Jahreswechsel und Reisen berücksichtigen.
- [ ] WEEK-09 Zuordnung einer Activity zu ihrer Woche stabil festhalten; Zeitzonenwechsel darf sie nicht doppelt zählen oder zwischen abgeschlossenen Wochen verschieben.
- [ ] WEEK-10 Aktuelles Wochenziel und Ziel ab nächster Woche getrennt speichern; jede Änderung innerhalb 3–7, Erhöhung wie Senkung erst nächste Woche.
- [ ] WEEK-11 „Aktuell 4, ab nächster Woche 5“ sichtbar erklären; Änderung löst keine rückwirkende Flamme und keinen Call-My-Shot-Trick aus.
- [ ] WEEK-12 Fortschritt wie 3/4 prominent auf Heute, Freunde, eigenem Profil und Freundesprofil; Wochenziel-Detailseite erreichbar.
- [ ] WEEK-13 Beim ersten Erreichen sofort genau eine Flamme verdienen und anzeigen; Ereignis serverseitig atomar mit Abschluss/Fortschritt erzeugen.
- [ ] WEEK-14 Erfolgsmeldung/Animation/Haptik einmalig pro verdientem Wochenereignis; Neustart und weitere Workouts lösen sie nicht erneut aus.
- [ ] WEEK-15 Übererfüllung ehrlich als 5/4 bzw. 6/4 und optional „+2 über Ziel“; keine zweite Flamme.
- [ ] WEEK-16 Geschlossene Wochen mit Ziel, Trainingsanzahl, Erfolg, Flame-Zeitpunkt und Finalisierungsstatus dauerhaft speichern; wiederholte Finalisierung idempotent.
- [ ] WEEK-17 Neue Woche startet mit 0 und gültigem nächstem Ziel; vorherige Erfolge/Historie bleiben erhalten, auch nach längerer App-Abwesenheit.
- [ ] WEEK-18 Streak nur aus aufeinanderfolgenden abgeschlossenen erfolgreichen Wochen; laufende Woche nicht vorzeitig mitzählen; Lücken/erfolglose Wochen setzen ihn auf 0.
- [ ] WEEK-19 Flame-Historie, aktueller Streak und Best Streak korrekt; nach Unterbrechung neue erfolgreiche Woche = 1, Bestwert bleibt erhalten.
- [ ] WEEK-20 Akzeptierte Freunde sehen Ziel/Fortschritt/Flamme/Streak; Blockierte/Fremde nicht. Reaktionen 🔥 / 💪 / 👏 auf verdiente Flammen.
- [ ] WEEK-21 Motivierende, neutrale Texte je Fortschritt; kein täglicher Trainingszwang, Schamtext, negativer Score oder dominantes Ranking.

Offene Implementierungsentscheidung zu WEEK-06: konkrete, nachvollziehbare Kurztraining-Regel inklusive Grenzwerten vor Umsetzung festlegen. Ein willkürlicher Mindestwert ist noch nicht als Nutzeranforderung beschlossen. Zu WEEK-09: die verbindliche Zeit-/Zuordnungsregel für über Mitternacht laufende Trainings vor Migration dokumentieren und durch Grenzfalltests absichern.

## 7. Blind Workout – B §§1–13, 31–36

- [ ] BLIND-01 Einstieg im Freundesprofil/Social-Bereich; ausschließlich gültigen akzeptierten Freund als Empfänger wählen.
- [ ] BLIND-02 Fokusauswahl wie bei Plänen; Standard- und zulässige eigene Übungen; Ziel-Sätze/-Reps, Gewicht/Notiz optional, Reihenfolge bearbeitbar.
- [ ] BLIND-03 Private Custom-Übungen korrekt freigeben/referenzieren bzw. kopieren, ohne Zugriff auf die übrige private Bibliothek des Erstellers.
- [ ] BLIND-04 Vor Annahme sichtbar: Ersteller, Fokus, Anzahl, geschätzte Dauer, benötigtes Equipment und grobe Muskelgruppen; keine konkreten Übungen oder Reihenfolge.
- [ ] BLIND-05 „Equipment verfügbar“ bestätigen; Zusammenfassung ansehen/ablehnen. Fehlendes Equipment erzwingt kein Training.
- [ ] BLIND-06 „BLIND WORKOUT SENDEN“ erzeugt passende In-App-Mitteilung und Push „Max hat dir ein Blind Workout gebaut 👀“ mit funktionierendem Zielbildschirm.
- [ ] BLIND-07 Empfänger kann annehmen/ablehnen; Status und Zeitpunkte korrekt. Optionaler Terminweg ist separat in Abschnitt 13 erfasst.
- [ ] BLIND-08 Beim Start nur Übung 1 und Fortschritt 1/N zeigen; zukünftige Inhalte bleiben serverseitig verborgen, nicht nur unscharf im UI.
- [ ] BLIND-09 Erst nach Abschluss der aktuellen Übung die nächste freigeben; Server validiert Reihenfolge und Eigentümer. Kein Überspringen durch manipulierte Anfrage.
- [ ] BLIND-10 Kleine Reveal-Animation; kommende Karten nur Platzhalter. Netzwerkantworten, VoiceOver, lokale Logs und versteckte Views verraten keine künftigen Übungen.
- [ ] BLIND-11 „Einfach“ und „Tracken“ wie bei normalen Plänen; tatsächliche Gewichte/Reps nicht verpflichtend.
- [ ] BLIND-12 Freigabestand, Eingaben und laufende Aktivität über Neustart/Verbindungsverlust erhalten; wiederholter Abschluss schaltet nicht mehrere Übungen frei.
- [ ] BLIND-13 Jederzeit abbrechen: `cancelled`, kein negativer Score oder öffentliches „versagt“. Keine Abschlussflamme für Abbruch.
- [ ] BLIND-14 Nach vollständigem Training `completed`, Dauer und N/N Übungen; „Fertig“, Reaktion an Ersteller, „Workout speichern“ funktionieren.
- [ ] BLIND-15 Ersteller bekommt Abschluss-Mitteilung; 🔥 / 💪 / 👏 reagieren. Optional freigegebene Social-Zusammenfassung verrät nicht automatisch alle Übungen.
- [ ] BLIND-16 Speichern als eigener Plan erzeugt unabhängige Kopie einschließlich eigener Custom-Übungen; ursprünglicher Ersteller kann die Kopie nicht verändern.
- [ ] BLIND-17 Nur strukturierte Standard-/zulässige Custom-Übungen, validierte Werte; keine Freitext-Strafaufgaben, Schmerz-/gefährlichen Challenges oder absurden Wiederholungsmengen.
- [ ] BLIND-18 `sent → accepted/planned → live → completed` sowie `declined/cancelled` serverseitig erlauben/begrenzen; nur Ersteller/Empfänger bekommen jeweils erlaubte Daten.
- [ ] BLIND-19 Ein gültig abgeschlossenes Blind Workout erzeugt genau einen normalen Workout-Credit; keine separate zweite Activity-/Flammen-Gutschrift.

## 8. Call My Shot – B §§14–36

- [ ] SHOT-01 Optionaler Einstieg „CALL MY SHOT 🎯“ auf der Wochenziel-Seite; keine Verpflichtung im Onboarding.
- [ ] SHOT-02 Vor Aktivierung Bestätigung „Willst du dich festlegen?“ mit aktuellem Ziel und erklärter Sichtbarkeit für Freunde; „SHOT CALLEN“ / „Abbrechen“.
- [ ] SHOT-03 Ausschließlich serverseitig gültiges Ziel der aktuellen Woche verwenden; keine separate Zielhöhe im Call-Dialog akzeptieren.
- [ ] SHOT-04 Zu Wochenbeginn und während der laufenden Woche erlaubt, solange Ziel noch nicht erreicht; nach Zielerreichung kein rückwirkendes Callen.
- [ ] SHOT-05 Genau einmal pro Nutzer/Woche; mehrfacher Request oder Deaktivieren/Reaktivieren darf keine zweite Aktivierung erzeugen.
- [ ] SHOT-06 Heute-Feed und Profile zeigen angekündigtes Ziel und tatsächlichen Fortschritt getrennt: „Called: 4/4“, „Aktuell: 2/4“, Status „Noch offen“.
- [ ] SHOT-07 Bei Zielerreichung automatisch `achieved`/Zeitpunkt setzen und „CALLED IT ✓“ zeigen; kein manueller Client-Erfolg.
- [ ] SHOT-08 Flamme bleibt zentral. Bei aktivem Call eine gemeinsame Erfolgserfahrung „CALLED IT. 🎯🔥“ statt zwei nacheinander störenden Belohnungsdialogen.
- [ ] SHOT-09 Erfolglos geschlossene Woche neutral: „Diese Woche nicht geschafft. Neue Woche, neue Chance.“; keine roten Warnungen/Strafen oder aggressives Failed-Badge.
- [ ] SHOT-10 Freundesreaktionen 🔥 / 🎯 / 💪; akzeptierte Freunde dürfen lesen/reagieren, Fremde/Blockierte nicht.
- [ ] SHOT-11 PLANNED kann als Planungshinweis erscheinen, zählt aber nicht zum tatsächlichen Fortschritt oder zum Call-Erfolg.
- [ ] SHOT-12 Commitment enthält Nutzer, Woche, damaliges Wochenziel, Aktivierungs-/Erfolgszeit, achieved/finalized; genau ein Eintrag pro Nutzer/Woche; Historie nicht durch Zielwechsel verfälschen.
- [ ] SHOT-13 Aktivierung gegen gleichzeitig eintreffenden Workout-Abschluss und Wochenwechsel absichern; keine unzulässigen rückwirkenden Calls durch Rennen zwischen Requests.

## 9. Daten, Zugriffsschutz und robuste Integration

- [ ] DATA-01 Normalisierte Plan-/Übungstabellen: `workout_plans`, `exercises`, `exercise_secondary_muscles`, `workout_plan_exercises`, `exercise_favorites`, eigene Freigaben und Protokollzuordnung.
- [ ] DATA-02 `workout_exercise_logs` / `workout_set_logs` mit Eigentümerbezug, stabiler Reihenfolge und unveränderlicher historischer Momentaufnahme; Activity/Session sauber mit Plan verknüpfen.
- [ ] DATA-03 `daily_activity_metrics`: Nutzer, lokales Datum, Schritte, Freigabe, Aktualisierung; eindeutiger Nutzer/Tag; zentrale Freigabe widerspruchsfrei.
- [ ] DATA-04 `current_weekly_goal`, `next_weekly_goal`, `weekly_progress` und eindeutige Activity-Credits; Constraints, Indexe, Zeit-/Wochenzuordnung und Finalisierung nachvollziehbar.
- [ ] DATA-05 `blind_workouts`, geordnete `blind_workout_exercises`, Empfängerprotokoll/Freigabestand und validierte Statuswechsel.
- [ ] DATA-06 `weekly_commitments`: eindeutige Nutzer/Woche-Kombination und atomare Verbindung zum bestehenden Wochenfortschritt/Flammenereignis.
- [ ] DATA-07 Migrationen auf sauberer Testdatenbank und als Upgrade bestehender Daten ausführen; bestehende Profile, Gruppen, Sessions, Fotos und Aktivitäten bewahren.
- [ ] DATA-08 Modelle/Repository/State/SwiftUI für echte und Demo-Daten konsistent anschließen; neue Dateien tatsächlich im Build/Bundle enthalten; App-/Backend-Katalog identische stabile IDs.
- [ ] SEC-01 RLS für jede neue Tabelle; anonym, Eigentümer, akzeptierter Freund, ausstehender Freund, Fremder und Blockierter getrennt testen.
- [ ] SEC-02 Nur Eigentümer bearbeitet eigene Pläne/Custom-Übungen/Protokolle; detaillierte Satzdaten nicht über Feed, fremde Profile oder generische RPCs auslesbar.
- [ ] SEC-03 Schrittfreigabe immer serverseitig prüfen; Widerruf sperrt Direktabfrage, RPC und Folge-Upload. Keine Rohdaten oder Health-/Auth-Geheimnisse in Logs.
- [ ] SEC-04 Blind-Empfänger kann vor Start und vor Freischaltung auch über direkte Tabellen-/API-Abfragen keine zukünftigen Übungen lesen; Erstellerzugriff getrennt.
- [ ] SEC-05 Wochen-Credits, earned, achieved, Week-ID und Statusübergänge serverseitig validieren; kein Überschreiben durch manipulierte Client-Werte.
- [ ] SEC-06 Freigaben, Blockierung und Freundschaftsänderungen gelten auch für neue Reaktionen, Mitteilungen und Deep Links.
- [ ] SEC-07 Atomare Mutationen mit festen Berechtigungen; Wiederholungen, Parallelität und ungültige Werte prüfen; kein beliebiger Fremdzugriff über Helper-Funktionen.
- [ ] SEC-08 Logout/Kontowechsel löscht fremden Cache; Account-Löschung berücksichtigt neue persönliche Daten, Freigaben und Notification-Bezüge.
- [ ] SEC-09 Fehler-/Offlinezustände mit Wiederholung ohne Datenverlust; kein vorgetäuschter Speicher-/Freigabe-Erfolg. Serverseitige Bestätigung ist für Rewards maßgeblich.

## 10. Design: jede Seite und jeder neue Ablauf

Alle 24 bestehenden Referenzseiten werden einzeln in der [Storyboard-Abnahme](LIGHT_STORYBOARD_CHECKLIST.md) geführt. Kein Sammelhaken „Design fertig“, solange einzelne Seiten nicht geprüft sind. Neue Funktionen ohne eigene Bildvorlage übernehmen dieselben Gestaltungselemente; sie werden nicht als bereits pixelgenau vorgegeben ausgegeben.

- [ ] DESIGN-01 Heller Hintergrund, weiße/dezent graue Karten, schwarze gut lesbare Schrift, grüne Akzente, konsistente Rundungen/Schatten/Abstände.
- [ ] DESIGN-02 Jede Referenzseite auf passender iPhone-Größe vergleichen: Aufbau, Bildausschnitt, Typografie, Weißraum, Kartengrößen, Buttonposition und Navigation.
- [ ] DESIGN-03 Neue Funktionen in bestehende Navigation einbauen; große Abläufe als gut lesbare Seiten, kleine Entscheidungen als klar strukturierte Dialoge; keine gequetschten Overlays.
- [ ] DESIGN-04 Hochwertige vorhandene Sport-/Hero-Bilder und Profilfotos sinnvoll verwenden, ohne Text zu verdecken; Bildausfall/kein Avatar sauber darstellen.
- [ ] DESIGN-05 Einheitliche Übungskarten, Muskelchips, Suchfelder, Auswahlzustände und primäre grüne Aktionen; Freigabe/Privatsphäre klar beschriftet.
- [ ] DESIGN-06 Heute bleibt Social-zentriert: Wochenfortschritt sichtbar, Schritte kompakt, Satzdetails erst im Training; Blind-/Call-Badges nicht alles überlagern.
- [ ] DESIGN-07 Kleine und große iPhones, Safe Areas, Bildschirmtastatur, lange Namen, größere Schrift und scrollende Formulare prüfen; Aktionen bleiben erreichbar.
- [ ] DESIGN-08 VoiceOver-Beschriftung/Fokus, verständliche Fehler und Status zusätzlich zur Farbe; keine Geheimnisse aus Blind-Karten vorlesen.
- [ ] DESIGN-09 Lade-, Leer-, Fehler-, Offline-, gesperrte und erfolgreiche Zustände visuell prüfen; alle sichtbaren Aktionen manuell bedienen.
- [ ] DESIGN-10 Apple-Anmeldung und Foto-/Health-Berechtigungen bleiben echte iOS-Systemansichten. Kein nachgebauter Apple-Dialog mit erfundenen Systemoptionen; systemabhängige Abweichungen zur Illustration dokumentieren.

Integrationskarte – Zielorte der neuen Funktionen:

| Bestehender Ort / neue Seite | Einzubauen und zu prüfen |
| --- | --- |
| Profil-Onboarding / Sportarten / Gym-Fokus | Optionales Foto, persistente Auswahl, neuer bestätigter Wochenzielschritt; korrekte Schrittanzeige |
| Heute / eigener Status | Deine Woche, Flamme, Call-Badge, optionale „Dein Tag“-Schritte |
| Heute / Freundeskarten | LIVE/PLANNED/DONE/NOT YET, Wochenstand, freigegebene Schritte, Call/Reaktionen; keine privaten Satzdaten |
| Plus / Gym-Auswahl | Freies Training, eigene Pläne, neuen Plan erstellen |
| Meine Pläne / Plan-Detail / Editor | Name, Kategorie, Beschreibung, Übungen, Zielvorgaben, Reihenfolge, Freigabe, Start/Planen |
| Übungsauswahl / eigene Übung | Suche, Muskelgruppen, Alle/Favoriten/Eigene, Inline-Erstellen und Duplikathinweis |
| Planung / normale Einladung / geplante Session | Konkreter Plan, Freunde/Gruppen, vollständige Planvorschau, Antworten und gemeinsamer Start |
| Live / Training beenden / Verlauf | Einfach/Tracken, Satz-/Übungsabschluss, echter Timer/Pause, gespeicherte Zusammenfassung |
| Freunde / Freundesprofil | Wochenstand/Flamme, erlaubte Schritte/Pläne, Blind Workout erstellen, Call-Reaktionen |
| Eigenes Profil / Wochenziel / Historie | Aktuelles/nächstes Ziel, Flame-Historie, Streak/Bestwert und Call-Aktivierung/-Status |
| Crew-Ziel | Bestehende Beiträge erhalten; persönliche Ziele und Crew-Ziel nicht verwechseln |
| Blind erstellen / Vorschau / Empfang | Fokus, Equipment, Anzahl, Dauer; sichere Zusammenfassung, Annehmen/Ablehnen |
| Blind LIVE / Ergebnis | Verdeckte nächste Karten, schrittweises Reveal, Abschluss, Reaktion, unabhängige Plankopie |
| Call-Bestätigung / gemeinsamer Erfolg | Sichtbarkeit vor Aktivierung, festes Wochenziel, CALLED IT zusammen mit Flamme |
| Einstellungen / Privatsphäre / Schritte | Health-Erklärung, getrennte Schalter, optionales privates Schrittziel |
| Mitteilungen / Push-Einstellungen | Neue Ereignisse, gültige Deep Links, Lesestatus, vorhandene und neue optierbare Kategorien |

### Kleine Animationen, nicht nur dekorative Effekte

- [ ] ANIM-01 Dezente Seiten-/Kartenübergänge ohne springendes Layout oder blockierte Navigation.
- [ ] ANIM-02 Sport-/Muskel-/Freund-Auswahl mit kurzem Auswahlfeedback und sichtbarem Haken; schnelles Tippen bleibt zuverlässig.
- [ ] ANIM-03 Plan-Reihenfolge und Satz-/Übungs-Häkchen mit ruhigem Feedback; Animation ersetzt keine bestätigte Speicherung.
- [ ] ANIM-04 Fortschrittsbalken zwischen echtem altem/neuem Wert animieren; keine erfundenen Zwischen-Erfolge.
- [ ] ANIM-05 Blind-Reveal erst nach bestätigter Freigabe, kurz und klar; nächster Platzhalter enthält keine vorab geladenen Geheimdaten.
- [ ] ANIM-06 Wochenflamme mit kleiner Erfolgsanimation/dezenter Haptik genau einmal pro Ereignis; keine Endlosschleife oder erneute Feier beim Öffnen.
- [ ] ANIM-07 Aktiver Call kombiniert 🎯 und 🔥 in einem einmaligen „CALLED IT“-Erfolg; normales Training ohne neues Wochenereignis feiert nur seinen eigenen Abschluss.
- [ ] ANIM-08 „Bewegung reduzieren“ respektieren: sanfte/sofortige Alternative; kein wichtiges Feedback nur über Bewegung/Haptik/Farbe; VoiceOver erhält den neuen Status.
- [ ] ANIM-09 Animationen auf echten Geräten auf Ruckeln, Hintergrundwechsel und schnelle Eingaben prüfen; keine Timer-/Netzwerk-Dauerschleifen für Effekte.

## 11. Verbindliche Tests aus den vier Aufträgen

**Alle nachstehenden neuen Abnahmetests sind derzeit NICHT AUSGEFÜHRT.** Ein UI-Test mit Demo-Daten belegt Bedienung, aber nicht Supabase/RLS oder echte Push-/HealthKit-Funktion. Für einen Haken müssen die jeweils betroffenen Ebenen nachgewiesen sein.

### Trainingspläne – T §48, A–I

- [ ] QA-PLAN-A Momo erstellt Push Day mit Bankdrücken, Schrägbank Kurzhantel, Schulterdrücken, Seitheben, Trizeps Pushdown, Overhead Extension; speichern/neustarten: vollständig vorhanden.
- [ ] QA-PLAN-B „Prime Chest Press“, Hauptmuskel Brust, Nebenmuskeln Trizeps + Schulter erstellen; unter Eigene und über Suche auffindbar.
- [ ] QA-PLAN-C Prime Chest Press in Push Day aufnehmen; nach Speichern/Neustart weiterhin enthalten.
- [ ] QA-PLAN-D Gym / Push Day / heute 19:00 planen, Max einladen; Max sieht Name, Übungen, Dauer vor Antwort und akzeptiert.
- [ ] QA-PLAN-E Momo startet Push Day LIVE; Max zieht mit demselben Plan mit; Eingaben/Abschlüsse beider Konten unabhängig.
- [ ] QA-PLAN-F Bankdrücken 80 × 8, 80 × 8, 80 × 7 erfassen; nach Abschluss und erneutem Öffnen unverändert gespeichert.
- [ ] QA-PLAN-G Prime Chest Press archivieren: normale Auswahl ohne Übung; alte Workouts zeigen weiterhin korrekten Namen und Satzdaten.
- [ ] QA-PLAN-H Momo teilt Push Day, Max speichert eigene Kopie und bearbeitet sie; Momos Original unverändert.
- [ ] QA-PLAN-I Kopie enthält eigene Prime-Chest-Press-Custom-Übung; Umbenennen bei Max verändert Momos Übung nicht.

### HealthKit – H §20, A–G

- [ ] QA-HEALTH-A 8.421 heutige HealthKit-Schritte → FYRUP zeigt 8.421. Simulator-Fixture und echte HealthKit-Daten separat belegen.
- [ ] QA-HEALTH-B Sharing AUS: Momo sieht 8.421, Max weder im UI noch per Serverabruf.
- [ ] QA-HEALTH-C Sharing EIN: akzeptierter Freund Max sieht „Momo · 8.421 Schritte“.
- [ ] QA-HEALTH-D Sharing wieder AUS: Max kann Wert nicht mehr abrufen; paralleler Upload setzt Freigabe nicht zurück.
- [ ] QA-HEALTH-E Keine HealthKit-Daten: neutrale Ansicht, übrige App ohne Fehler bedienbar.
- [ ] QA-HEALTH-F App schließen, neue Schritte, App öffnen: heutiger Wert aktualisiert.
- [ ] QA-HEALTH-G Lokaler Mitternachtswechsel: neuer Tag, gestrige Werte niemals als heutige Schritte angezeigt.

### Wochenziel / Flammen – F §39, A–O

- [ ] QA-FLAME-A Im Onboarding 4 Trainings wählen; nach Neustart weiterhin Ziel 4.
- [ ] QA-FLAME-B Erstes gültig abgeschlossenes Training → 1/4.
- [ ] QA-FLAME-C Zweites/drittes Training → 2/4 und 3/4, keine Flamme.
- [ ] QA-FLAME-D Viertes Training → 4/4, Flame earned, Erfolg exakt einmal.
- [ ] QA-FLAME-E Fünftes Training → 5/4 🔥, keine zweite Flamme/Animation.
- [ ] QA-FLAME-F Akzeptierter Freund Max sieht Momo 5/4 🔥.
- [ ] QA-FLAME-G Ziel von 4 auf 5 ändern: aktuelle Woche bleibt 4, nächste wird 5.
- [ ] QA-FLAME-H Neue Woche → 0/5, vergangene verdiente Flamme in Historie erhalten.
- [ ] QA-FLAME-I Drei erfolgreiche abgeschlossene Wochen in Folge → Streak 3.
- [ ] QA-FLAME-J Vierte abgeschlossene Woche erfolglos → Streak 0, Best Streak 3.
- [ ] QA-FLAME-K Danach eine neue erfolgreiche abgeschlossene Woche → Streak 1, Best Streak 3.
- [ ] QA-FLAME-L 10.000 Schritte ohne DONE-Training → unveränderter Wochenfortschritt.
- [ ] QA-FLAME-M PLANNED ohne Abschluss → unveränderter Wochenfortschritt.
- [ ] QA-FLAME-N LIVE → kein Credit; erst DONE erhöht Fortschritt.
- [ ] QA-FLAME-O Dieselbe Activity zweimal verarbeitet → genau ein Credit.

### Blind Workout – B §34, A–E

- [ ] QA-BLIND-A Max erstellt Push Blind Workout mit 6 Übungen für Momo; Momo sieht nur Absender, Fokus, Anzahl, Dauer, Equipment/Muskelübersicht, keine Einzelübungen.
- [ ] QA-BLIND-B Momo akzeptiert/startet: nur Übung 1 sichtbar und abrufbar.
- [ ] QA-BLIND-C Übung 1 abschließen: Übung 2 wird sichtbar, zukünftige Übungen bleiben verborgen.
- [ ] QA-BLIND-D Alle Übungen abschließen: completed; Max bekommt Abschluss-Mitteilung, Push separat prüfen.
- [ ] QA-BLIND-E Als eigenen Plan speichern: unabhängige Kopie einschließlich Custom-Übungen.

### Call My Shot – B §35, F–J

- [ ] QA-SHOT-F Momo mit Wochenziel 4 aktiviert Call My Shot; akzeptierte Freunde sehen das angekündigte 4/4-Ziel.
- [ ] QA-SHOT-G Bei zwei abgeschlossenen Trainings tatsächlich 2/4 anzeigen, nicht behaupten das Ziel sei erreicht.
- [ ] QA-SHOT-H Viertes Training → Flamme + achieved + „CALLED IT ✓“; gemeinsamer Erfolg genau einmal.
- [ ] QA-SHOT-I Zweite Aktivierung in derselben Woche ablehnen, auch bei parallelen Requests.
- [ ] QA-SHOT-J Nach bereits erreichtem Wochenziel erste Aktivierung ablehnen.

## 12. Zusätzliche End-to-End-, Sicherheits- und Geräteabnahme

- [ ] QA-CROSS-01 Kernkombination: Momo 3/4 mit aktivem Call → Max sendet Blind Workout → Momo absolviert alle Übungen → genau 4/4, eine Flamme, ein CALLED IT, Max-Mitteilung.
- [ ] QA-CROSS-02 Dasselbe mit Abbruch → keine Abschlussflamme/Call-Erfüllung; Schritte oder noch geplante Sessions ändern daran nichts.
- [ ] QA-CROSS-03 Zweimaliges echtes Training an einem Tag zählt zweimal; künstliche Kurzserien entsprechend dokumentierter Regel; Doppeltaps zählen niemals doppelt.
- [ ] QA-CROSS-04 Wochenwechsel, ISO-Jahreswechsel, Sommer-/Winterzeit, Reise und Training über Mitternacht mit steuerbarer Testuhr prüfen; verspätete/gleichzeitige Requests korrekt.
- [ ] QA-CROSS-05 Ziel senken wirkt ebenfalls erst nächste Woche; aktive Calls/verdiente Flammen/Historie bleiben unverfälscht.
- [ ] QA-CROSS-06 Fremder, ausstehender Freund und Blockierter: kein unerlaubter Zugriff auf Pläne, Custom-Bibliothek, Satzdaten, Schritte, Wochenwerte, Blind-Inhalte oder Calls.
- [ ] QA-CROSS-07 Direkte API-/Tabellenabfrage kann keine zukünftige Blind-Übung, fremde Detaildaten oder selbst gesetzte Credits/achieved-Werte erzwingen.
- [ ] QA-CROSS-08 Neustart im Planeditor, LIVE, Blind-Reveal und unvollständigen Onboarding; offline → online; Konto wechseln: kein Datenverlust, falsches Konto oder doppelte Mutation.
- [ ] QA-CROSS-09 Normale Einladung zeigt alle Übungen, Blind-Einladung nicht; kontrollierte Einzel-Freigabe veröffentlicht keinen gesamten privaten Katalog.
- [ ] QA-CROSS-10 Original/Custom-Übung ändern oder archivieren: fremde Kopien und abgeschlossene Trainings bleiben unverändert.
- [ ] QA-UI-01 Alle 24 Referenzseiten plus neue Seiten manuell bedienen und nebeneinander vergleichen; Abweichungen mit Screenshot/Seiten-ID festhalten und beheben.
- [ ] QA-UI-02 Alle Schaltflächen, Zurück/Abbrechen, Tastatur, leere Listen, langsames Netz, lange Texte und kleine Displays prüfen.
- [ ] QA-UI-03 Dynamic Type, VoiceOver, Bewegung reduzieren, Kontrast und bedienbare Touch-Flächen; kein Informationsleck im Accessibility-Baum.
- [ ] QA-UI-04 Animationen als Ablauf/Video prüfen, nicht nur als Standbild; Persistenz des einmaligen Erfolgs nach Neustart kontrollieren.
- [ ] QA-DEVICE-01 Echten Apple-Login sowie optionales Profilfoto auswählen/hochladen/erneut anzeigen, inklusive abgebrochener Systemdialoge.
- [ ] QA-DEVICE-02 HealthKit mit echten Schritten, überlappenden iPhone-/Watch-Quellen, fehlenden Daten und Widerruf prüfen; Simulator allein reicht nicht.
- [ ] QA-DEVICE-03 Zwei getrennte echte Konten: Einladung, Teilen/Kopieren, Mitziehen, Blind-Sendung, Call, Freigabe und Blockieren durchspielen.
- [ ] QA-DEVICE-04 Echte Push-Zustellung, Opt-out, Tap zum richtigen Inhalt und gelöschte/abgelaufene Inhalte prüfen; In-App-Mitteilung ist kein Push-Nachweis.
- [ ] QA-DEVICE-05 Hintergrund, Sperrbildschirm, Wiederöffnung und Pause/Fortsetzen während Training prüfen; keine dauernden unnötigen Abfragen oder auffälliger Akkuverbrauch.

Nachweisformat pro abgeschlossenem Punkt/Test: `ID | Commit | Datenbankstand | Build/Version | Umgebung/Gerät/Konten | Datum | Ergebnis | Screenshot/Log/Testname | Restabweichung`. Keine echten Namen, Tokens oder Health-Rohdaten in Testartefakten veröffentlichen. Testdaten und produktive Nutzerdaten strikt trennen.

## 13. Ausdrücklich optionale Ergänzungen und bewusste Grenzen

Diese Produktoptionen nicht vergessen, aber nicht stillschweigend als umgesetzt abhaken. Vor dem Release jeweils als „eingebaut + getestet“ oder „bewusst zurückgestellt“ dokumentieren. Datenschutz und Abschaltbarkeit gelten auch für optionale Funktionen.

- [ ] OPT-01 Wochen-Schrittansicht und kleine Freundes-Schritt-Rangliste nur für freigebende Freunde; kein zentrales Leistungsranking. Zusätzliche Historienfreigabe bewusst klären, nicht aus Tagesfreigabe ableiten.
- [ ] OPT-02 Ein-Tap-Schrittreaktionen; keine Pushs für jede kleine Schrittänderung.
- [ ] OPT-03 Wochen-Pushs: fast erreicht, erreicht, Freund erreicht, Wochenstart; feingranular abschaltbar und ohne Schuld-/Schamtexte.
- [ ] OPT-04 Blind Workout „Später planen“ mit Datum/Uhrzeit → PLANNED; Status/Start korrekt, ohne vorzeitigen Credit.
- [ ] OPT-05 Neutraler Abbruchhinweis für Blind-Ersteller und optionale für Freunde sichtbare Abschluss-Zusammenfassung; niemals automatisch vollständige Übungen teilen.
- [ ] OPT-06 Call-Reaktion „Ich glaub an dich“, abschaltbare Call-/Erfolgs-Pushs, optionale geplante Workout-Anzahl.
- [ ] OPT-07 Private Shot-Historie/Erfolgsquote ohne aggressive Rangwertung; nicht gecallte und nicht erreichte Wochen unterscheiden.
- [ ] OPT-08 Dunkler Modus nur optional; helle Referenz bleibt Standard und darf dadurch nicht verwässert werden.

Nicht jetzt beauftragt: KI-Trainingsplanung, automatische Progression, RPE/RIR, komplexe Periodisierung, Übungsvideos, öffentliche Plan-/Workout-Datenbank, Coach Marketplace, Premium-Pläne, 1RM-Rechner. Auch keine GPS-Karte, öffentliche Community, DMs/Chat, Ernährung, Payments oder eigenständige Apple-Watch-App aus diesen Aufträgen ableiten.

Nur Erweiterbarkeit vorbereiten: Schritt-/Freunde-Challenges, 100.000 Schritte als Crew, Wochen-Schrittziele, Walking Sessions, Watch-App sowie Walking-/Running-Distanz. Keine zusätzlichen Health-Berechtigungen vorsorglich anfordern.

## 14. Arbeitsreihenfolge und Release-Schranken

1. Bestehende Regeln mit dieser Liste abgleichen; Bibliotheksvollständigkeit und stabile IDs sichern; offene Wochen-/Kurztraining-Regeln dokumentieren.
2. Datenmodelle/Migrationen/RLS prüfen, Bestandsdatenmigration absichern; Pläne, eigene Übungen und Protokolle durchgängig anschließen.
3. Normale Einladungen, Teilen/Kopieren und gemeinsames Training inklusive separater Logs fertigstellen.
4. Neue Wochenlogik/Flammen mit Zeit- und Idempotenztests integrieren; anschließend Call My Shot an genau diese Ereignisse anschließen.
5. Blind Workout auf Plan-/Protokollbasis integrieren, serverseitiges Reveal und Kombinationsflow testen.
6. Schritte mit getrenntem Privacy-Opt-in, Heute-/Profil-/Einstellungsintegration fertigstellen.
7. Jede Seite an Referenz ausrichten, Animationen und Fehler-/Leerzustände ergänzen, alle Kernfunktionen erneut prüfen.
8. Cloud-Simulator, Datenbanktests, visuelle/manuelle Abnahme und echte Gerätetests getrennt nachweisen; erst danach die jeweilige Freigabe erklären.

- [ ] RELEASE-01 Alle Pflichtanforderungen umgesetzt; alle 41 Auftragstests plus relevante Zusatz-/Regressionstests bestanden oder offen mit konkretem Blocker dokumentiert. Offene Pflichtfehler verhindern die Behauptung „alles funktioniert“.
- [ ] RELEASE-02 Migrationen, RLS, Constraints und produktionskompatibles Upgrade nachgewiesen; keine ungeprüften Entwürfe ungeplant ausrollen.
- [ ] RELEASE-03 Tatsächlichen Cloud-Buildstatus frisch prüfen; alte Browsertimer nicht als laufenden/hängenden Build interpretieren; Testartefakte sichern.
- [ ] RELEASE-04 Signierten Build mit eindeutiger Version/Buildnummer/Commit erstellen; installierte App zeigt identifizierbaren Stand, damit alte Registrierung/neues Design unterscheidbar sind.
- [ ] RELEASE-05 Health-/Privacy-Angaben, neue Datenarten, Freigabetexte und erforderliche Capabilities überprüfen; keine Geheimnisse in App oder Repository.
- [ ] RELEASE-06 TestFlight-Verarbeitung und Zuordnung zur Testergruppe bestätigen; konkret sagen, welcher Build welche Erweiterungen enthält. Simulator-Build ist kein iPhone-Update.
- [ ] RELEASE-07 Auf dem tatsächlich installierten TestFlight-Build Kernabläufe mit zwei Konten abnehmen; verbleibende Gerätetests ausdrücklich offen nennen.
- [ ] RELEASE-08 Checkliste, Storyboard-Abnahme und Release-Notizen mit realen Nachweisen aktualisieren. App-Store-Veröffentlichung ist ein separater Schritt, kein automatischer Effekt der Checkliste.
