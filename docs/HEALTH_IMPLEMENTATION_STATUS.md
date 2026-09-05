# Optionale Schritte – Implementierungs- und Prüfnachweis

Stand: 5. September 2026, in Arbeit. **Nicht mit einer bereits installierten TestFlight-Version gleichsetzen.**

## Eingebaut

- Eigene Schrittanzeige in Heute; Einstieg über Profil → Privatsphäre → Schritte und Einstellungen → Privatsphäre → Schritte.
- Erklärungsseite, ausdrücklicher Apple-Health-Dialog, „Nicht jetzt“ ohne Einschränkung anderer Funktionen.
- Nur `stepCount` lesen, HealthKit-Statistikaggregat ohne Rohsamples, Geräteinformationen oder andere Health-Kategorien.
- Getrennte Freigabe: standardmäßig aus; unbekannter Serverzustand wird ausdrücklich nicht als bestätigtes AUS dargestellt.
- Optionales, ausschließlich lokales Schrittziel; dezente Fortschrittsanimation berücksichtigt „Bewegung reduzieren“.
- Bestätigte Freunde sehen ausschließlich den aktuellen freigegebenen Tageswert. Fehlende/private Daten erzeugen keine erfundene Null oder Ablehnungsbehauptung.
- Kontowechsel, Aus-/Einschalten, verspätete Uploads, fehlende Daten, Zeitzonen und Tageswechsel abgesichert.
- Server-Upload nur mit aktueller Freigaberevision und Beobachtungszeit. Widerruf sperrt alte Uploads auch nach erneutem Einschalten.
- Eigene Präferenzen bei Kontolöschung entfernt; HealthKit-Daten selbst werden nicht gelöscht oder geschrieben.
- HealthKit-Entitlement und notwendiger Lese-Erklärungstext im XcodeGen-Projekt vorbereitet. **Apple-App-ID und signiertes Profil noch gesondert aktualisieren/prüfen.**

## Tatsächlich ausgeführt

`node supabase/tests/run_step_tests.mjs`: **96 PostgreSQL-/pgTAP-Tests bestanden**, zusammen mit den vorhandenen Trainingsplan- und Pausenmigrationen geladen. Kein echter Supabase-Cloud-Test.

`node supabase/tests/run_workout_tests.mjs`: **105 bestehende Trainingsplan-/Pausenprüfungen weiterhin bestanden**.

`node scripts/validate-exercise-catalog.mjs`: **122 eindeutige Übungen / 127 geforderte Gruppenzuordnungen bestanden**.

## Noch zu prüfen

- Neue native Unit- und zwei UI-Flows: geschrieben, bis zum grünen eigenen Cloud-Build **NICHT AUSGEFÜHRT**.
- Das UI-Testargument `--demo --steps-demo` liefert ausdrücklich kontrollierte 8.421 Beispielschritte ohne Systemdialog. Es belegt weder echte Berechtigungen noch die Zusammenführung von iPhone/Apple-Watch-Daten.
- Cloud-Migration/PostgREST, echter Zweikonten-Widerruf und produktives Signing.
- Reale Health-Daten und Berechtigung außerhalb FYRUP widerrufen auf physischem iPhone.
- Visueller Abgleich der neu erzeugten Screenshots 34–36 mit der hellen Designsprache.
- Optionale Rangliste, Schrittreaktionen und spätere Health-Erweiterungen sind nicht als fertig markiert.

Die aktuelle vollständige Abnahme bleibt [PRODUCT_CHECKLIST.md](PRODUCT_CHECKLIST.md).
