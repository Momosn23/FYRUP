# FYRUP – vollständige Übungskatalog-Abnahme

Anhang zu [LIB-01 der zentralen Checkliste](PRODUCT_CHECKLIST.md). Quelle: Trainingsplan-Auftrag vom 05.09.2026, §§5–19 und 21. Ein Haken setzt voraus, dass **jede** unten genannte Übung in App und Backend vorhanden, suchbar und unter der passenden Muskelgruppe auffindbar ist. Ein vorhandener Dateieintrag allein reicht nicht.

Arbeitsdatei: [exercise-library.tsv](../FYRUP/Resources/exercise-library.tsv). Der Entwurf enthält 122 eindeutige Übungen; die Quelle nennt 127 Gruppenzuordnungen. Wiederholte Übungen dürfen dieselbe stabile ID besitzen, müssen aber über alle verlangten Haupt-/Nebenmuskel-Zuordnungen auffindbar bleiben. „Bulgarian Split Squat“ und „Bulgarian Split Squats“ bezeichnen dieselbe Übung; beide Schreibweisen bei der Suche berücksichtigen. Keine anderen Varianten unbemerkt zusammenlegen.

## Brust – T §6, 14 Einträge

- [x] CAT-01 Bankdrücken Langhantel; Bankdrücken Kurzhantel; Schrägbankdrücken Langhantel; Schrägbankdrücken Kurzhantel; Negativbankdrücken; Brustpresse Maschine; Schrägbrustpresse; Butterfly / Pec Deck; Kabel Flys; Low-to-High Cable Fly; High-to-Low Cable Fly; Kurzhantel Flys; Dips Brustfokus; Liegestütze.

## Rücken – T §7, 15 Einträge

- [x] CAT-02 Klimmzüge; Latzug breit; Latzug eng; Neutraler Latzug; Langhantelrudern; Kurzhantelrudern; T-Bar Row; Kabelrudern; Rudermaschine; Chest-Supported Row; High Row; Low Row; Straight-Arm Pulldown; Pullover Maschine; Kurzhantel Pullover.

## Schulter – T §8, 13 Einträge

- [x] CAT-03 Schulterdrücken Langhantel; Schulterdrücken Kurzhantel; Schulterpresse Maschine; Arnold Press; Frontheben; Seitheben Kurzhantel; Seitheben Kabel; Seitheben Maschine; Lean-Away Cable Lateral Raise; Reverse Fly Maschine; Reverse Fly Kurzhantel; Reverse Cable Fly; Face Pulls.

## Bizeps – T §9, 13 Einträge

- [x] CAT-04 Langhantelcurls; SZ-Curls; Kurzhantelcurls; Alternierende Curls; Incline Dumbbell Curls; Preacher Curls; Maschine Preacher Curl; Kabelcurls; Bayesian Cable Curl; Konzentrationscurls; Hammer Curls; Rope Hammer Curls; Reverse Curls.

## Trizeps – T §10, 12 Einträge

- [x] CAT-05 Trizeps Pushdown Seil; Trizeps Pushdown Stange; Overhead Cable Extension; Overhead Kurzhantel Extension; Skull Crushers; French Press; Enges Bankdrücken; Dips; Trizepsmaschine; Einarmiges Cable Pushdown; Einarmige Overhead Extension; Kickbacks.

## Quadrizeps – T §11, 11 Einträge

- [x] CAT-06 Kniebeugen; Front Squats; Hack Squat; Beinpresse; Bulgarian Split Squats; Ausfallschritte; Walking Lunges; Beinstrecker; Smith Machine Squat; Goblet Squat; Step-Ups.

## Beinbeuger – T §12, 7 Einträge

- [x] CAT-07 Romanian Deadlift; Stiff-Leg Deadlift; Lying Leg Curl; Seated Leg Curl; Standing Leg Curl; Nordic Hamstring Curl; Good Mornings.

## Gesäß – T §13, 9 Einträge

- [x] CAT-08 Hip Thrust; Glute Bridge; Bulgarian Split Squat; Romanian Deadlift; Reverse Lunges; Cable Kickbacks; Glute Maschine; Step-Ups; Abduktorenmaschine.

## Waden – T §14, 5 Einträge

- [x] CAT-09 Standing Calf Raise; Seated Calf Raise; Calf Press an der Beinpresse; Single-Leg Calf Raise; Smith Machine Calf Raise.

## Adduktoren – T §15, 4 Einträge

- [x] CAT-10 Adduktorenmaschine; Cable Hip Adduction; Sumo Squat; Copenhagen Plank.

## Bauch / Core – T §16, 13 Einträge

- [x] CAT-11 Crunches; Cable Crunch; Hanging Leg Raises; Knee Raises; Ab Wheel; Plank; Side Plank; Russian Twist; Decline Crunch; Machine Crunch; Reverse Crunch; Pallof Press; Dead Bug.

## Trapez / Nacken – T §17, 5 Einträge

- [x] CAT-12 Shrugs Langhantel; Shrugs Kurzhantel; Shrugs Maschine; Upright Row; Farmer's Walk.

## Unterarme / Griff – T §18, 6 Einträge

- [x] CAT-13 Wrist Curls; Reverse Wrist Curls; Reverse Curls; Farmer's Walk; Dead Hang; Plate Pinch.

## Zuordnung, Varianten und Metadaten

- [x] CAT-14 Bankdrücken: Hauptmuskel Brust, Nebenmuskeln Trizeps/vordere Schulter. Klimmzüge: Rücken, Bizeps/Unterarme. Kniebeugen: Quadrizeps, Gesäß/Beinbeuger/Core. Schulterfokus darf im UI nicht verlorengehen.
- [x] CAT-15 Geteilte Katalogeinträge in allen vorgegebenen Filtern sichtbar: Bulgarian Split Squat(s), Romanian Deadlift, Step-Ups, Reverse Curls und Farmer's Walk.
- [x] CAT-16 Ganzkörper/Sonstiges als zusätzliche Custom-Hauptmuskelgruppen verfügbar, auch wenn die Quelle dafür keine feste Standardliste vorgibt.
- [x] CAT-17 Equipment vollständig: Langhantel, Kurzhantel, Kabelzug, Maschine, Smith Machine, Körpergewicht, Kettlebell, Widerstandsband, Sonstiges.
- [x] CAT-18 Dauer-/Halteübungen korrekt typisieren; Zielvorgaben, Einheiten, Freitextsuche und deutscher Anzeigename konsistent.
- [x] CAT-19 Kein Katalog-ID-Wechsel beim Hinzufügen/Umsortieren einer Datei; App, Seed, SQL und bestehende Planreferenzen prüfen.
- [x] CAT-20 Automatischen Abgleich aller Namen und erforderlichen Muskelzuordnungen ergänzen; anschließend Such-/Auswahltest in der App. Fehlerliste und Ergebnis als Nachweis ablegen.

Status 06.09.2026: Der automatische Abgleich bestätigt alle 122 stabilen App-/Backend-Einträge und 127 geforderten Muskelzuordnungen. Der gebündelte native Katalogtest prüft jede geforderte Zeile auf ID, Namen-/Aliassuche, Haupt-/Nebenmuskel, Metadaten und Validität; er bestand in Codemagic 45 und im signierten Lauf 46. Der Übungsbibliothek-Bedienablauf mit echter Suche/Auswahl bestand ebenfalls. Die frische lokale PostgreSQL-Suite bestand alle 82 Plan-/Katalog- und 23 Pausenprüfungen; App-TSV und SQL-Seed sind identisch. Damit ist diese Katalogliste auf Code-, Backend- und Simulator-Ebene abgenommen. Echte iPhone-Darstellung und vollständige visuelle Prüfung bleiben als übergeordnete Geräte-/Designpunkte offen.
