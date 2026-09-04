# Release- und Beta-Checkliste

## Automatisch

- [x] `xcodegen generate` in Codemagic erfolgreich
- [x] Debug Build auf iPhone-17-Pro-Simulator
- [ ] Release Build mit `CODE_SIGNING_ALLOWED=NO`
- [x] Build 10: Unit- und 9 UI-Flows grün; finaler Regressionsbuild folgt
- [x] 30 pgTAP-Prüfungen im Produktionsprojekt bis `ok 30`
- [ ] Edge Functions lokal typgeprüft

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

- [ ] Eindeutige Bundle ID, Distribution Certificate und Profile
- [ ] Sign in with Apple + Push Capability in der App ID
- [ ] Production APNs Key als Supabase Secret
- [ ] App Privacy Questionnaire und Privacy Policy URL
- [ ] Support URL, Beschreibung, Keywords, Screenshots, Altersfreigabe
- [ ] Export-Compliance-Frage beantworten
- [ ] Interne Beta mit 2 Accounts, dann externe Gruppe mit 5–20 Personen
- [ ] Feedback-Kanal und Crash-Monitoring festlegen
