# Release- und Beta-Checkliste

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
