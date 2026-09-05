# FYRUP Master-Checkliste

Diese Checkliste bewahrt den ursprünglichen Masterauftrag und historische Bestandsnachweise. Die aktuelle Arbeits- und Abnahmeliste für die vier Erweiterungsaufträge ist die [zentrale Produkt-Checkliste](PRODUCT_CHECKLIST.md). Gültige bisherige Funktionen bleiben Pflicht; alte Haken belegen keine erneute Abnahme nach den Erweiterungen.

Aktualisierung 05.09.2026: Helles Design, Trainingspläne, optionale Satzdaten, HealthKit-Schritte, Wochenziel 3–7/Flammen, Blind Workout und Call My Shot sind beauftragt. Widersprüchliche frühere Umfangsangaben sind unten ersetzt. Buildangaben bleiben historische Nachweise, keine Aussage über die aktuell installierte TestFlight-Version.

**Status:** ✅ implementiert und automatisiert geprüft · 🧪 implementiert, Cloud-/Gerätetest offen · ⚠️ teilweise · ⬜ offen · 🚫 bewusst nicht Teil der V1

## 1. Foundation, Plattform und Architektur

- [x] ✅ Native iPhone-App mit Swift und SwiftUI, kein WebView-Wrapper
- [x] ✅ MVVM-nahe Trennung in Models, Views, AppStore, Repository und REST-Client
- [x] ✅ Zentrale Fehlerdarstellung ohne technische Backend-Texte
- [x] ✅ Produktions- und Demo-Konfiguration getrennt; keine Secrets im Repository
- [x] ✅ Reproduzierbares XcodeGen-Projekt und Codemagic-Workflows
- [ ] Helles Referenz-Designsystem mit Karten, Akzenten, Haptik und SF Symbols; jede Seite nach der [Storyboard-Abnahme](LIGHT_STORYBOARD_CHECKLIST.md) prüfen. Dunkler Modus nur optional.
- [x] ✅ Nur iPhone als Zielplattform, Mindestversion iOS 17
- [x] ✅ V2-Erweiterungen werden durch typisierte Models und Repository-Schicht nicht verbaut

## 2. Branding, Welcome und Navigation

- [x] ✅ FYRUP-Wortmarke, Flame-Symbol, Splash-Hero und App-Icon
- [x] ✅ Hochwertiger Splash-/Login-Screen entsprechend Referenz
- [x] ✅ Apple-, E-Mail-Login und Account-erstellen-Aktionen sichtbar
- [x] ✅ Vier Hauptziele: Home, Planen, Entdecken/Freunde und Profil
- [x] ✅ Schnellzugriff zum Planen/Starten und Benachrichtigungsglocke
- [x] ✅ Vier originale Sport-Hero-Motive für Gym, Running, Kampfsport und Outdoor in Auswahl, Planung und Details
- [x] ✅ Aktivitätsauswahl und Planung als eigenständiger Fullscreen-Flow statt kleinem Standard-Overlay
- [x] ✅ 13 Referenzansichten wurden in Codemagic Build 11 als PNG erfasst und zu einem Kontaktblatt zusammengeführt
- [x] ✅ Visueller Layoutvergleich des Build-15-Kontaktblatts mit den gelieferten Referenzen durchgeführt

## 3. Authentifizierung und Session

- [x] ✅ Sign in with Apple mit kryptografischem Nonce
- [x] ✅ Fehlerhafte `%3Fgrant_type`-URL behoben und per Unit Test abgesichert
- [x] ✅ E-Mail-Registrierung, Login und Passwort-zurücksetzen
- [x] ✅ Sichere Session-Ablage im iOS-Keychain
- [x] ✅ Token-Refresh und Session-Wiederherstellung nach App-Neustart
- [x] ✅ Logout löscht lokale Sitzung und Feed-Cache
- [ ] 🧪 Erster und erneuter Apple-Login im neuesten TestFlight-Build
- [ ] 🧪 E-Mail-Bestätigung und Passwort-Mail im Produktionsprojekt

## 4. Profil-Onboarding

- [x] ✅ Klarer Ablauf mit Fortschritt 1/3, 2/3 und 3/3
- [x] ✅ Anzeigename und eindeutiger Username mit Client- und DB-Validierung
- [x] ✅ Apple-Name wird beim ersten Login vorausgefüllt, wenn Apple ihn liefert
- [x] ✅ Optionales Geburtsjahr, Stadt, Bio und Profilfoto
- [x] ✅ Sportarten als Mehrfachauswahl; später bearbeitbar
- [x] ✅ Optionale private Profilbilder in Supabase Storage unter dem eigenen Benutzerordner
- [x] ✅ Profilbilder werden komprimiert und bei fehlendem Bild durch Initialen ersetzt
- [x] ✅ Bestehende unvollständige Einrichtung wird nach Neustart fortgesetzt
- [ ] 🧪 Fotoauswahl, Upload und Anzeige auf zwei echten Konten

## 5. Sportarten und Unterkategorien

- [x] ✅ Gym, Laufen, Fußball, Basketball, Fahrrad, Schwimmen, Kampfsport, Tennis/Padel, Yoga, Sonstiges
- [x] ✅ Typisierte Sportarten und flexible optionale Unterkategorien
- [x] ✅ Alle im Masterauftrag genannten V1-Unterkategorien vorhanden
- [x] ✅ Unterkategorie kann übersprungen werden
- [x] ✅ Sportarten können im Profil geändert werden
- [x] ✅ Gym-Presets Push, Pull, Beine und Full Body mit automatisch vorgeschlagenen Muskelgruppen
- [x] ✅ Einzelne Körpergruppen Brust, Rücken, Schultern, Bizeps, Trizeps, Core, Po, Quadrizeps, Beinbeuger und Waden frei kombinierbar

## 6. Freundesystem

- [x] ✅ Beidseitige Freundschaften statt Follow-System
- [x] ✅ Username-/Namenssuche
- [x] ✅ Anfrage senden, annehmen, ablehnen und Freund entfernen
- [x] ✅ Blockieren und serverseitiges Verhindern weiterer Interaktionen
- [x] ✅ Doppelte Anfragen werden serverseitig verhindert
- [x] ✅ Freunde-Screen mit Anfragen, Profil, Tagesstatus und Wochenanzahl
- [x] ✅ Private Trainingsgruppen erstellen, ansehen und löschen
- [x] ✅ Gruppen bestehen ausschließlich aus akzeptierten Freunden und sind per RLS geschützt
- [ ] 🧪 End-to-End-Abnahme mit zwei echten TestFlight-Konten

## 7. Heute-Feed und eigener Status

- [x] ✅ Home ist das Zentrum der App
- [x] ✅ Aktuelles lokales Datum und HEUTE-Überschrift
- [x] ✅ Eigener Status: NOT YET, PLANNED, LIVE und DONE
- [x] ✅ Relevanzsortierung LIVE → PLANNED → DONE → NOT YET
- [x] ✅ Story-/Crew-Leiste und kompakte Social-Cards
- [x] ✅ Hochwertiger echter Leerzustand ohne Produktions-Fakedaten
- [x] ✅ Heute-Feed berücksichtigt lokale Zeitzone und Tageswechsel
- [x] ✅ Offline-Fallback aus lokalem Feed-Cache
- [ ] 🧪 Sichtprüfung gegen Referenzbild mit leerem und gefülltem Feed

## 8. Aktivitäten

- [x] ✅ Aktivität in wenigen Taps auswählen und sofort starten
- [x] ✅ LIVE-Aktivität mit lokal berechnetem Timer
- [x] ✅ Server verhindert mehrere gleichzeitige LIVE-Aktivitäten
- [x] ✅ Training beenden und DONE-Status mit Dauer
- [x] ✅ Training abbrechen mit Sicherheitsabfrage
- [x] ✅ Optionale manuelle Distanz für Laufen, Fahrrad und Schwimmen
- [ ] Historischer MVP-Ausschluss durch spätere Aufträge aufgehoben: optionale Satzwerte und Gewichte sind beauftragt; Ortserinnerungen und Kalorienschätzung ebenfalls. Den jeweiligen Umsetzungs- und Abnahmestand in der [zentralen Produktliste](PRODUCT_CHECKLIST.md) und ihren Zusatzlisten prüfen, nicht weiterhin als Ausschluss abhaken.
- [x] ✅ Mitziehen kann eine verknüpfte eigene Aktivität starten
- [ ] 🧪 Hintergrund/App-Neustart während LIVE auf echtem iPhone

## 9. Planung und Einladungen

- [x] ✅ Datum, Uhrzeit, geplante Dauer, Notiz und mehrere Freunde
- [x] ✅ Optionaler Ort/Treffpunkt ohne Adress- oder GPS-Erfassung
- [x] ✅ Geplante Session und individuelle Activity sind getrennt modelliert
- [x] ✅ Einladungen werden atomar serverseitig erstellt
- [x] ✅ Status pending, accepted, maybe und declined im Datenmodell
- [x] ✅ Annehmen/Ablehnen in der App
- [x] ✅ „Vielleicht“-Antwort in der Empfänger-UI
- [x] ✅ Host kann Session stornieren; Teilnehmer kann beitreten
- [x] ✅ Host sieht Wartet/Dabei/Vielleicht/Kann-nicht je eingeladenem Freund
- [x] ✅ Host kann Uhrzeit, Dauer, Notiz, Treffpunkt und Beitrittsfreigabe nachträglich ändern
- [x] ✅ Sichtbarer Schalter „Freunde dürfen sich anschließen“ beim Planen
- [x] ✅ Sichtbare Freundesuche, Einzel- und Gruppenauswahl direkt im Planungsflow
- [x] ✅ Geplante Session wechselt serverseitig auf READY
- [x] ✅ 30-Minuten-Erinnerung ist serverseitig vorbereitet
- [x] ✅ Supabase-Cron ruft `process_scheduled_sessions` alle fünf Minuten im Produktionsprojekt auf
- [ ] 🧪 Erinnerungs-Push mit echtem APNs-Key und zwei Geräten verifizieren

## 10. Social Motivation

- [x] ✅ FYR UP als Ein-Tap-Aktion
- [x] ✅ Maximal ein FYR UP pro Sender/Empfänger/lokalem Tag serverseitig
- [x] ✅ Reaktionen 🔥, 💪 und 👏 im Datenmodell und Backend
- [x] ✅ Reaktionsauswahl 🔥, 💪 und 👏 im Home-Feed und in Details
- [x] ✅ Mitziehen verknüpft die neue Activity mit der LIVE-Activity des Freundes
- [x] ✅ In-App-Notifications für Freundschaft, Training, Einladung und FYR UP
- [ ] 🧪 Push-Zustellung für alle Social-Ereignisse auf zwei echten Geräten

## 11. Ziele und Profile

- [ ] Persönliches Wochenziel 3–7 bewusst bestätigen; Änderungen erst nächste Woche, siehe WEEK in der zentralen Liste.
- [ ] Neues Flammen-/Wochen-Streak-System statt täglichem Zwang vollständig abnehmen; frühere Ziellogik reicht als Nachweis nicht aus.
- [x] ✅ Automatisch berechnetes Crew-Ziel
- [x] ✅ Eigenes Profil mit Name, Username, Sportarten, Ziel, Freunden und Statistiken
- [x] ✅ Profilbearbeitung inklusive Foto
- [x] ✅ Freundesprofil mit Status und Wochenfortschritt
- [x] ✅ Minimalistische MO–SO-Wochenleiste mit DONE und gelbem PLANNED-Status
- [x] ✅ Letzte Aktivitäten im eigenen Profil mit Datum und Dauer

## 12. Notifications und Push

- [x] ✅ In-App-Mitteilungsfeed mit Alle/Einladungen/Reaktionen
- [x] ✅ Unread-/Read-Unterstützung
- [x] ✅ APNs-Device-Token-Registrierung
- [x] ✅ Serverseitiger APNs-Dispatcher; keine APNs-Schlüssel im Client
- [x] ✅ Ungültige APNs-Tokens werden entfernt
- [x] ✅ Systemweite Mitteilungsfreigabe kann im Profil angefordert werden
- [x] ✅ Acht feingranulare Push-Einstellungen mit serverseitiger Filterung
- [x] ✅ Push-Taps öffnen abhängig vom Ereignis Freunde oder Mitteilungsfeed
- [x] ✅ Push-Dispatcher als Edge Function im Produktionsprojekt veröffentlicht
- [x] ✅ Reproduzierbarer minütlicher Dispatcher-Cron mit verschlüsselten Vault-Secrets
- [x] ✅ Produktions-Cron und Edge-Aufruf verifiziert: Job erfolgreich, HTTP 200, keine wartenden Pushs
- [x] ✅ APNs-Key `ZAYGWU8U3P` für Sandbox und Produktion erstellt und sicher heruntergeladen
- [x] ✅ APNs-Team-ID, Key-ID, Topic und Cron-Secret als verschlüsselte Supabase-Secrets gespeichert
- [ ] 🧪 APNs-Private-Key einmalig manuell als verschlüsseltes Supabase-Secret einfügen

## 13. Datenschutz, Sicherheit und Account

- [x] ✅ Aktivitäten nur für akzeptierte Freunde oder niemanden
- [x] ✅ Kein öffentlicher Feed, keine Karte, kein Live-Standort
- [x] ✅ RLS für Profile, Freundschaften, Aktivitäten, Einladungen, FYR UP, Reaktionen, Notifications und Tokens
- [x] ✅ RLS und Security-Definer-RPCs für private Trainingsgruppen im Produktionsprojekt aktiv
- [x] ✅ Private Avatar-Bucket-Policies für Eigentümer und Freunde
- [x] ✅ Blockierung wird in zentralen DB-Helpern berücksichtigt
- [x] ✅ Account-Löschung über authentifizierte Edge Function
- [x] ✅ Account-Löschfunktion im Produktionsprojekt veröffentlicht und mit eigener Token-Prüfung geschützt
- [x] ✅ Datenschutzansicht und Sichtbarkeit Freunde/Niemand
- [ ] 🧪 Remote-RLS- und Account-Löschtest im Produktionsprojekt

## 14. Fehlerfälle, Offline und UX

- [x] ✅ Verständliche Fehler für Netzwerk, Auth, Konflikt und Serverfehler
- [x] ✅ Ladeindikator blockiert Doppeltaps während Mutationen
- [x] ✅ Feed-Cache bei Netzwerkausfall
- [x] ✅ Timer basiert auf Startzeit statt Sekundenwrites
- [x] ✅ Doppelte LIVE-Aktivität, Freundschaftsanfrage und FYR UP serverseitig geschützt
- [x] ✅ Leere Freunde-, Notification- und Feed-Zustände
- [x] ✅ Skeleton-Loading für den initialen Heute-Feed, Spinner für Mutationen
- [ ] 🧪 Offline → Reconnect auf echtem Gerät

## 15. Accessibility, Lokalisierung und Qualität

- [x] ✅ VoiceOver-Labels für zentrale Icon-Aktionen und Status
- [x] ✅ Status wird nicht ausschließlich über Farbe vermittelt
- [x] ✅ Große Touch-Flächen und überwiegend skalierende Systemschriften
- [ ] ⚠️ Vollständiger VoiceOver-/Dynamic-Type-Audit aller Screens
- [ ] ⚠️ Harte deutsche UI-Texte vollständig nach `Localizable.strings` verschieben
- [x] ✅ Austauschbare Analytics-Schicht und zentrale Produkt-Events
- [x] ✅ Keine sichtbaren Produktions-Mockdaten
- [x] ✅ Sichtbare Activity-Detail-Aktionen sind mit Öffnen, Mitziehen, Beitreten oder Reagieren verbunden

## 16. Datenbank und Backend

- [x] ✅ Reproduzierbare SQL-Migrationen, Enums, Tabellen, Indizes und Constraints
- [x] ✅ Profile, Sportkatalog, User-Sports, Friendships, Blocks, Activities, Sessions, Invites, Reactions, FYR UP, Notifications und Tokens
- [x] ✅ Security-Definer-RPCs mit festem `search_path`
- [x] ✅ Lokale Seed-Daten für Momo, Max, Sarah, Leon und Tim
- [x] ✅ pgTAP-Schema-/Policy-Prüfungen
- [x] ✅ Notification-Preferences-Migration im Produktionsprojekt ausgerollt und Tabelle/RLS/RPCs/Trigger geprüft
- [x] ✅ Private Avatar-Migration im Produktionsprojekt ausgerollt und Bucket/Policies geprüft
- [x] ✅ Migration 010 für private Trainingsgruppen im Produktionsprojekt ausgerollt
- [x] ✅ pgTAP auf 37 Schema-/Policy-/RPC-Prüfungen einschließlich Trainingsgruppen erweitert
- [x] ✅ pgTAP-Suite im Produktionsprojekt bis `ok 37` ausgeführt

## 17. Automatisierte Tests

- [x] ✅ Auth-Repository: Registrierung, Login, Restore, Logout
- [x] ✅ Activity-Lifecycle und Single-LIVE-Constraint
- [x] ✅ Planung, Datumslogik, Feed-Priorität und Streak
- [x] ✅ FYR-UP-Tageslimit
- [x] ✅ Auth-URL-Regressionstest
- [x] ✅ UI: Start → LIVE → DONE
- [x] ✅ UI: Planen, FYR UP, Abbrechen, Freunde/Details, Profil/Datenschutz/Logout
- [x] ✅ UI: vollständiges dreistufiges Onboarding mit optionalen Profilfeldern
- [x] ✅ UI: konkrete Gym-Körpergruppen und Erstellen einer Trainingsgruppe automatisiert abgedeckt
- [ ] ⚠️ UI: zwei Benutzer, Einladung, Vielleicht, Mitziehen und Reaktionswechsel
- [x] ✅ Codemagic Build 11 (`487abd4`): 9 UI-Flows inklusive Planung/Host-Details und Profilbearbeitung, 0 Fehler, TEST SUCCEEDED
- [x] ✅ Codemagic Build 15 (`8b7043f`): 11 UI-Flows inklusive Gym-Körpergruppen und Trainingsgruppen, 0 Fehler, TEST SUCCEEDED
- [x] ✅ Visuelles QA-Kontaktblatt wird bei jedem Cloud-Testbuild erzeugt

## 18. TestFlight und Store-Vorbereitung

- [x] ✅ Bundle ID `app.fyrup.ios`, Versionierung, Icon, Launch Screen und Entitlements
- [x] ✅ Sign in with Apple und Push Capability
- [x] ✅ Signierter IPA-Build über Codemagic
- [x] ✅ Upload zu App Store Connect/TestFlight erfolgreich
- [x] ✅ Release-Build enthält geprüfte Supabase-Konfiguration
- [x] ✅ FYRUP 1.0.0 Build 7 signiert, von Apple verarbeitet und automatisch FYRUP Intern zugeordnet
- [ ] 🧪 Build 7 aus TestFlight auf dem iPhone installieren und visuell abnehmen
- [ ] ⬜ App-Privacy-Angaben, Support-/Privacy-URL, Beschreibung, Keywords und Altersfreigabe vervollständigen
- [ ] ⬜ App-Store-Screenshots in erforderlichen Größen erstellen
- [ ] ⬜ Interne Beta mit zwei Konten, danach 5–20 externe Tester

## 19. Aktualisierter Umfang nach den Erweiterungsaufträgen

- [x] 🚫 Android, Web-App, öffentliche Community und öffentliche Gruppen
- [x] 🚫 Karte, GPS-Live-Tracking, eigenständige Apple-Watch-App und allgemeiner Fitness-Import bleiben ausgeschlossen. HealthKit-Schritte sind jetzt beauftragt.
- [ ] Trainingspläne, eigene Übungen, optionales Satz-/Wiederholungs-/Gewichtstracking, Teilen und Kopieren gemäß zentraler Liste umsetzen und prüfen.
- [ ] Optionale HealthKit-Schritte, Wochenziel/Flammen, Blind Workout und Call My Shot gemäß zentraler Liste umsetzen und prüfen.
- [x] 🚫 Kalorien-/Ernährungstracking bleibt ausgeschlossen.
- [x] 🚫 DMs, Chat, Videos, öffentliche Posts und Stories
- [x] 🚫 Abos, Premium, Werbung und Payments

## Nächste Reihenfolge

Die aktuelle Reihenfolge und alle Release-Schranken stehen in Abschnitt 14 der [zentralen Produkt-Checkliste](PRODUCT_CHECKLIST.md). Vor einem iPhone-Test die tatsächliche TestFlight-Buildnummer bestätigen; Build 7 oben ist ein historischer Nachweis. Offene Bestands-Push-/Zwei-Konten-Tests bleiben erhalten.
