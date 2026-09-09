# Release- und Beta-Checkliste

Die abgehakten Build-/Backend-Punkte unten sind historische Bestandsnachweise. Für den nächsten Release gelten zusätzlich alle Schranken der [zentralen Produkt-Checkliste](PRODUCT_CHECKLIST.md), insbesondere neue Features, Design, Animationen, Datenschutz und getrennte Simulator-/Gerätenachweise. Keine alte Buildnummer als aktuell installierte Version ausgeben. Gültige bisherige Gerätetests bleiben Pflicht.

## Aktueller interner TestFlight-Prüfpunkt am 09.09.2026

- [x] [QA #71](REFERENCE_QA_71.md): 544/544 Unit- und 12/12 ausgewählte Referenz-UI-Tests PASS. Nutzer-ZIP und alle 33 Einzelbilder geprüft; keine vollständige Referenz-/Geräteabnahme.
- [x] Lokaler Preflight für die Paketvorbereitung 21/21 PASS; App-/Widget-Code unverändert gegenüber dem geprüften `b538d05`.
- [x] Ein [signiertes Paket](TESTFLIGHT_16_2026_09_09.md) aus `6d97776` nach 4m35s erfolgreich beendet, festes Neun-Minuten-Limit, `runTests: false`, keine parallelen oder automatischen Folgeläufe. Kosten 0,57 USD brutto, Reserve aufgelöst, siehe [Laufbuch](CI_BUDGET_2026_09.md).
- [x] Neun Signierungs-Prüffälle sowie tatsächliche App-/Live-Profile bestanden.
- [x] 15 IPA-Prüffälle und fertige IPA: eingebettete Produktionskonfiguration, Profile und tatsächliche signierte Berechtigungen bestanden.
- [x] Apple-Upload von **1.0.0 (16)** am 09.09.2026 03:11 CEST ohne Fehler, Verarbeitung abgeschlossen und Zuordnung zur vorhandenen Gruppe **FYRUP Intern** bestätigt.
- [ ] Echte Gerätefälle unten sowie HealthKit, WeatherKit, LIVE-Systemanzeige und Mailzustellung geprüft.

Neuester bei Apple verfügbarer interner Build **1.0.0 (16)**; eine Einladung, noch keine Installation von Build 16 angezeigt. Vorheriger installierter Stand war Build 15. Das interne Prüfpaket ist keine öffentliche Store-Einreichung oder vollständige Produktfreigabe. Eigene veröffentlichte FYRUP-Rechtslinks und verbleibende Designabweichungen sind weiterhin offen.

## Historischer Release-Kandidat am 06.09.2026

- [x] [Signierter TestFlight-Build 46](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9cdff81f365de10aeeec57) für den geprüften Commit `e317917` vollständig ausgeführt.
- [x] 459 von 459 Einzeltests und 33 von 33 Bedienabläufen im signierten Lauf bestanden; `TEST SUCCEEDED`.
- [x] Erneuerte App-/Live-Activity-Profile angewendet, eindeutige Buildnummer gesetzt und eingebettete produktive Backend-Konfiguration geprüft.
- [x] Signierte IPA als FYRUP `1.0.0` / Build `11` erzeugt und am 06.09.2026 um 06:11 CEST von App Store Connect ohne Uploadfehler angenommen (`UPLOAD SUCCEEDED with no errors`).
- [x] Apple-Verarbeitung von Build 11 abgeschlossen; Status „Bereit zur Übermittlung“, Gruppe „FYRUP Intern“, eine Einladung und 90 Tage Laufzeit am 06.09.2026 frisch geprüft.
- [ ] Build 11 auf echtem iPhone mit Apple-Login, HealthKit, Live-Aktivität, Push und den Kernabläufen geprüft.

Zusatzprüfung: Alle elf lokalen Backend-Prüfprogramme sowie 57 Versand-/Sprachtests liefen am 06.09.2026 ohne Fehler durch. Der vorhandene Apple-Schlüssel „FYRUP Push Production“ ist im Developer-Konto bestätigt; `APNS_PRIVATE_KEY` fehlt weiterhin in den Supabase-Secrets. Der Schlüsselinhalt wurde nicht über Zwischenablage, Protokoll oder Repository offengelegt. Das geschützte Hinterlegen bleibt deshalb ein eigener manueller/CLI-gestützter Schritt.

Frische App-Store-Connect-Kontrolle: Uploadstatus „Abgeschlossen“; Build 11 steht in der internen Gruppe bereit. Die Anzeige meldet noch keine Installation. Der folgende Abschnitt bleibt als Fehlerhistorie von Build 9 erhalten.

## Historischer Release-Kandidat am 05.09.2026

- [x] Signierter [TestFlight-Build 9](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c07536942048ebcb1f844) mit `codex/signing-profile-pipe` / `7472300` gestartet. Vorgänger 8 scheiterte vor dem App-Bau am inzwischen korrigierten Parser.
- [x] Sieben Parser-Prüfungen und das tatsächlich verwendete Apple-Profil auf HealthKit, Apple-Anmeldung und Production-Push geprüft; Ausgabe `Verified FYRUP profile: HealthKit, Apple sign-in and production push` im Lauf 9 gelesen.
- [x] Native Tests dieses signierten Laufs erfolgreich (`TEST SUCCEEDED`); insbesondere 27 UI-Abläufe, 0 Fehler, Ende 14:54 CEST.
- [ ] Tatsächliche signierte IPA auf Apple-Login, Push und HealthKit geprüft.
- [ ] Eingebettete Backend-Konfiguration erfolgreich geprüft.
- [ ] IPA von Apple angenommen und verarbeitet.
- [ ] Neue Version in der internen TestFlight-Gruppe sichtbar und installierbar.

**Build 9 beim Apple-Upload gescheitert**, 14:57 CEST: Fehler 90683 verlangt den fehlenden Health-Erklärungstext `NSHealthUpdateUsageDescription`. Die IPA ist gebaut, aber nicht als neue TestFlight-Version verfügbar. [Korrektur, Vorabprüfung und offener Nachtest](HEALTH_PURPOSE_RELEASE_FIX.md).

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
- [ ] Kurzer Offline-/Serverausfall bleibt bei automatischen Lesevorgängen ohne Hinweis; bestätigte Daten bleiben sichtbar und werden nach Reconnect aktualisiert. Nicht bestätigte Schreibaktionen und echte Auth-/Zugriffsfehler werden nicht als Erfolg verschwiegen.
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
