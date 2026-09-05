# Release- und Beta-Checkliste

Die abgehakten Build-/Backend-Punkte unten sind historische Bestandsnachweise. Für den nächsten Release gelten zusätzlich alle Schranken der [zentralen Produkt-Checkliste](PRODUCT_CHECKLIST.md), insbesondere neue Features, Design, Animationen, Datenschutz und getrennte Simulator-/Gerätenachweise. Keine alte Buildnummer als aktuell installierte Version ausgeben. Gültige bisherige Gerätetests bleiben Pflicht.

## Laufender Release-Kandidat am 05.09.2026

- [x] Signierter [TestFlight-Build 9](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c07536942048ebcb1f844) mit `codex/signing-profile-pipe` / `7472300` gestartet. Vorgänger 8 scheiterte vor dem App-Bau am inzwischen korrigierten Parser.
- [x] Sieben Parser-Prüfungen und das tatsächlich verwendete Apple-Profil auf HealthKit, Apple-Anmeldung und Production-Push geprüft; Ausgabe `Verified FYRUP profile: HealthKit, Apple sign-in and production push` im Lauf 9 gelesen.
- [ ] Vollständige Unit-/UI-Prüfung dieses signierten Laufs erfolgreich.
- [ ] Tatsächliche signierte IPA auf Apple-Login, Push und HealthKit geprüft.
- [ ] Eingebettete Backend-Konfiguration erfolgreich geprüft.
- [ ] IPA von Apple angenommen und verarbeitet.
- [ ] Neue Version in der internen TestFlight-Gruppe sichtbar und installierbar.

Simulator- und TestFlight-Buildnummern gehören zu getrennten Abläufen. Kandidat 9 enthält die dauerhaft sichtbaren Satzfeld-Beschriftungen und den stabilen Privatsphäre-Header aus `1a953af` sowie die Parser-Korrektur. Er enthält **nicht** die späteren bestätigten Sichtbarkeits-Speicherungen, Datumsauswahl und Supplement-Textkorrekturen aus `717472c`. Diese prüft GitHub 46 (396 Einzeltests bestanden, UI noch offen); Simulator 36 wartet. Das Fehlen des privaten Apple-Push-Schlüssels im Serverbereich blockiert echte Pushzustellung weiterhin; hierfür ist eine konkrete Freigabe angefragt.

## Automatisch

- [x] `xcodegen generate` in Codemagic erfolgreich
- [x] Debug Build auf iPhone-17-Pro-Simulator
- [x] Signierter Release-Build 6 mit App-Store-Provisioning
- [x] Build 11 (`487abd4`): Unit- und 9 UI-Flows grün, 0 Fehler, `TEST SUCCEEDED`
- [x] 30 pgTAP-Prüfungen im Produktionsprojekt bis `ok 30`
- [x] Edge Functions produktiv bereitgestellt; Dispatcher über Cron mit HTTP 200 aufgerufen

## Echte Geräte und Accounts

- [ ] E-Mail Registrierung, Bestätigung, Login, Restore und Logout
- [ ] Sign in with Apple inklusive erstem und erneutem Login
- [ ] Momo sendet Max Request; Max akzeptiert
- [ ] Max plant Gym · Pull, lädt Momo ein; Momo antwortet Dabei
- [ ] Beide sehen denselben Termin und eigene Activities
- [ ] Max startet; Momo erhält Inbox und Push; Momo startet ebenfalls
- [ ] Beide beenden; Feed und Wochenziel aktualisieren
- [ ] Momo FYR UPt Leon; zweiter Versuch am selben lokalen Tag wird abgewiesen
- [ ] Momo reagiert auf Sarahs DONE und ändert/entfernt die Reaktion
- [ ] Block entfernt Sichtbarkeit und verhindert neue Anfrage
- [ ] Offline-/Reconnect-Zustand zeigt verständliche Meldung
- [ ] Activity-Timer bleibt nach Hintergrund/App-Neustart korrekt
- [ ] Dynamische Schrift, VoiceOver, kleine und große aktuelle iPhones
- [ ] Account-Löschung entfernt Auth- und App-Daten

## Apple / TestFlight

- [x] Eindeutige Bundle ID, Distribution Certificate und App-Store-Profil
- [x] Sign in with Apple + Push Capability in der App ID
- [x] Build 6 ohne Uploadfehler verarbeitet und der Gruppe FYRUP Intern zugeordnet
- [ ] Production APNs Key als Supabase Secret
- [ ] App Privacy Questionnaire und Privacy Policy URL
- [ ] Support URL, Beschreibung, Keywords, Screenshots, Altersfreigabe
- [ ] Export-Compliance-Frage beantworten
- [ ] Interne Beta mit 2 Accounts, dann externe Gruppe mit 5–20 Personen
- [ ] Feedback-Kanal und Crash-Monitoring festlegen
