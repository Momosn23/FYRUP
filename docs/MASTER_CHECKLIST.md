# FYRUP Master-Checkliste

Diese Checkliste übersetzt den Masterauftrag in prüfbare Liefergegenstände. Sie ist die verbindliche V1-Abnahme und wird nach jedem Build aktualisiert.

**Status:** ✅ implementiert und automatisiert geprüft · 🧪 implementiert, Cloud-/Gerätetest offen · ⚠️ teilweise · ⬜ offen · 🚫 bewusst nicht Teil der V1

## 1. Foundation, Plattform und Architektur

- [x] ✅ Native iPhone-App mit Swift und SwiftUI, kein WebView-Wrapper
- [x] ✅ MVVM-nahe Trennung in Models, Views, AppStore, Repository und REST-Client
- [x] ✅ Zentrale Fehlerdarstellung ohne technische Backend-Texte
- [x] ✅ Produktions- und Demo-Konfiguration getrennt; keine Secrets im Repository
- [x] ✅ Reproduzierbares XcodeGen-Projekt und Codemagic-Workflows
- [x] ✅ Dark-Mode-Designsystem mit Karten, Akzentfarben, Haptics und SF Symbols
- [x] ✅ Nur iPhone als Zielplattform, Mindestversion iOS 17
- [x] ✅ V2-Erweiterungen werden durch typisierte Models und Repository-Schicht nicht verbaut

## 2. Branding, Welcome und Navigation

- [x] ✅ FYRUP-Wortmarke, Flame-Symbol, Splash-Hero und App-Icon
- [x] ✅ Hochwertiger Splash-/Login-Screen entsprechend Referenz
- [x] ✅ Apple-, E-Mail-Login und Account-erstellen-Aktionen sichtbar
- [x] ✅ Vier Hauptziele: Home, Planen, Entdecken/Freunde und Profil
- [x] ✅ Schnellzugriff zum Planen/Starten und Benachrichtigungsglocke
- [ ] 🧪 Sichtprüfung aller zehn Referenzansichten im Cloud-iPhone-Simulator

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

## 6. Freundesystem

- [x] ✅ Beidseitige Freundschaften statt Follow-System
- [x] ✅ Username-/Namenssuche
- [x] ✅ Anfrage senden, annehmen, ablehnen und Freund entfernen
- [x] ✅ Blockieren und serverseitiges Verhindern weiterer Interaktionen
- [x] ✅ Doppelte Anfragen werden serverseitig verhindert
- [x] ✅ Freunde-Screen mit Anfragen, Profil, Tagesstatus und Wochenanzahl
- [ ] 🧪 End-to-End-Abnahme mit zwei echten TestFlight-Konten

## 7. Heute-Feed und eigener Status

- [x] ✅ Home ist das Zentrum der App
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
- [x] ✅ Kein GPS, keine Sätze, keine Gewichte und keine Kalorienerfassung
- [x] ✅ Mitziehen kann eine verknüpfte eigene Aktivität starten
- [ ] 🧪 Hintergrund/App-Neustart während LIVE auf echtem iPhone

## 9. Planung und Einladungen

- [x] ✅ Datum, Uhrzeit, geplante Dauer, Notiz und mehrere Freunde
- [x] ✅ Geplante Session und individuelle Activity sind getrennt modelliert
- [x] ✅ Einladungen werden atomar serverseitig erstellt
- [x] ✅ Status pending, accepted, maybe und declined im Datenmodell
- [x] ✅ Annehmen/Ablehnen in der App
- [ ] ⚠️ „Vielleicht“-Button in der Empfänger-UI ergänzen
- [x] ✅ Host kann Session stornieren; Teilnehmer kann beitreten
- [x] ✅ Geplante Session wechselt serverseitig auf READY
- [x] ✅ 30-Minuten-Erinnerung ist serverseitig vorbereitet
- [ ] 🧪 Cron-Zeitplan und Erinnerungs-Push im Produktionsprojekt verifizieren

## 10. Social Motivation

- [x] ✅ FYR UP als Ein-Tap-Aktion
- [x] ✅ Maximal ein FYR UP pro Sender/Empfänger/lokalem Tag serverseitig
- [x] ✅ Reaktionen 🔥, 💪 und 👏 im Datenmodell und Backend
- [ ] ⚠️ Reaktionsauswahl im Home-Feed von einem Emoji auf alle drei erweitern
- [x] ✅ Mitziehen verknüpft die neue Activity mit der LIVE-Activity des Freundes
- [x] ✅ In-App-Notifications für Freundschaft, Training, Einladung und FYR UP
- [ ] 🧪 Push-Zustellung für alle Social-Ereignisse auf zwei echten Geräten

## 11. Ziele und Profile

- [x] ✅ Persönliches Wochenziel 1–7
- [x] ✅ Wochenziel-Streak statt täglichem Zwang
- [x] ✅ Automatisch berechnetes Crew-Ziel
- [x] ✅ Eigenes Profil mit Name, Username, Sportarten, Ziel, Freunden und Statistiken
- [x] ✅ Profilbearbeitung inklusive Foto
- [x] ✅ Freundesprofil mit Status und Wochenfortschritt
- [ ] ⚠️ Minimalistische MO–SO-Wochenleiste ergänzen
- [ ] ⚠️ Letzte Aktivitäten im eigenen Profil ergänzen

## 12. Notifications und Push

- [x] ✅ In-App-Mitteilungsfeed mit Alle/Einladungen/Reaktionen
- [x] ✅ Unread-/Read-Unterstützung
- [x] ✅ APNs-Device-Token-Registrierung
- [x] ✅ Serverseitiger APNs-Dispatcher; keine APNs-Schlüssel im Client
- [x] ✅ Ungültige APNs-Tokens werden entfernt
- [x] ✅ Systemweite Mitteilungsfreigabe kann im Profil angefordert werden
- [ ] ⚠️ Feingranulare Einstellungen nach Ereignistyp ergänzen
- [ ] ⚠️ Deep Links aus Push-Mitteilungen ergänzen
- [ ] 🧪 APNs-Key, Cron-Secret und Production-Topic im Supabase-Projekt verifizieren

## 13. Datenschutz, Sicherheit und Account

- [x] ✅ Aktivitäten nur für akzeptierte Freunde oder niemanden
- [x] ✅ Kein öffentlicher Feed, keine Karte, kein Live-Standort
- [x] ✅ RLS für Profile, Freundschaften, Aktivitäten, Einladungen, FYR UP, Reaktionen, Notifications und Tokens
- [x] ✅ Private Avatar-Bucket-Policies für Eigentümer und Freunde
- [x] ✅ Blockierung wird in zentralen DB-Helpern berücksichtigt
- [x] ✅ Account-Löschung über authentifizierte Edge Function
- [x] ✅ Datenschutzansicht und Sichtbarkeit Freunde/Niemand
- [ ] 🧪 Remote-RLS- und Account-Löschtest im Produktionsprojekt

## 14. Fehlerfälle, Offline und UX

- [x] ✅ Verständliche Fehler für Netzwerk, Auth, Konflikt und Serverfehler
- [x] ✅ Ladeindikator blockiert Doppeltaps während Mutationen
- [x] ✅ Feed-Cache bei Netzwerkausfall
- [x] ✅ Timer basiert auf Startzeit statt Sekundenwrites
- [x] ✅ Doppelte LIVE-Aktivität, Freundschaftsanfrage und FYR UP serverseitig geschützt
- [x] ✅ Leere Freunde-, Notification- und Feed-Zustände
- [ ] ⚠️ Skeleton-Loading statt ausschließlich Spinner ergänzen
- [ ] 🧪 Offline → Reconnect auf echtem Gerät

## 15. Accessibility, Lokalisierung und Qualität

- [x] ✅ VoiceOver-Labels für zentrale Icon-Aktionen und Status
- [x] ✅ Status wird nicht ausschließlich über Farbe vermittelt
- [x] ✅ Große Touch-Flächen und überwiegend skalierende Systemschriften
- [ ] ⚠️ Vollständiger VoiceOver-/Dynamic-Type-Audit aller Screens
- [ ] ⚠️ Harte deutsche UI-Texte vollständig nach `Localizable.strings` verschieben
- [x] ✅ Austauschbare Analytics-Schicht und zentrale Produkt-Events
- [x] ✅ Keine sichtbaren Produktions-Mockdaten
- [ ] ⚠️ No-op-Aktionen und unvollständige Sekundäraktionen restlos entfernen

## 16. Datenbank und Backend

- [x] ✅ Reproduzierbare SQL-Migrationen, Enums, Tabellen, Indizes und Constraints
- [x] ✅ Profile, Sportkatalog, User-Sports, Friendships, Blocks, Activities, Sessions, Invites, Reactions, FYR UP, Notifications und Tokens
- [x] ✅ Security-Definer-RPCs mit festem `search_path`
- [x] ✅ Lokale Seed-Daten für Momo, Max, Sarah, Leon und Tim
- [x] ✅ pgTAP-Schema-/Policy-Prüfungen
- [ ] 🧪 Neue Avatar-Migration in das Produktionsprojekt ausrollen
- [ ] ⚠️ pgTAP um Storage-Policies und weitere Negativtests erweitern

## 17. Automatisierte Tests

- [x] ✅ Auth-Repository: Registrierung, Login, Restore, Logout
- [x] ✅ Activity-Lifecycle und Single-LIVE-Constraint
- [x] ✅ Planung, Datumslogik, Feed-Priorität und Streak
- [x] ✅ FYR-UP-Tageslimit
- [x] ✅ Auth-URL-Regressionstest
- [x] ✅ UI: Start → LIVE → DONE
- [x] ✅ UI: Planen, FYR UP, Abbrechen, Freunde/Details, Profil/Datenschutz/Logout
- [ ] ⚠️ UI: vollständiges Onboarding und optionale Profilfelder
- [ ] ⚠️ UI: zwei Benutzer, Einladung, Vielleicht, Mitziehen und Reaktionswechsel
- [ ] 🧪 Sämtliche Tests im neuesten Codemagic-Build grün

## 18. TestFlight und Store-Vorbereitung

- [x] ✅ Bundle ID `app.fyrup.ios`, Versionierung, Icon, Launch Screen und Entitlements
- [x] ✅ Sign in with Apple und Push Capability
- [x] ✅ Signierter IPA-Build über Codemagic
- [x] ✅ Upload zu App Store Connect/TestFlight erfolgreich
- [x] ✅ Release-Build enthält geprüfte Supabase-Konfiguration
- [ ] 🧪 Neuesten korrigierten Build hochladen und auf dem iPhone installieren
- [ ] ⬜ App-Privacy-Angaben, Support-/Privacy-URL, Beschreibung, Keywords und Altersfreigabe vervollständigen
- [ ] ⬜ App-Store-Screenshots in erforderlichen Größen erstellen
- [ ] ⬜ Interne Beta mit zwei Konten, danach 5–20 externe Tester

## 19. Bewusst nicht Teil der V1

- [x] 🚫 Android, Web-App, öffentliche Community und öffentliche Gruppen
- [x] 🚫 Karte, GPS-Live-Tracking, HealthKit, Apple Watch und Fitness-Import
- [x] 🚫 Workout-Pläne, Sätze, Wiederholungen, Gewichte, Kalorien und Ernährung
- [x] 🚫 DMs, Chat, Videos, öffentliche Posts und Stories
- [x] 🚫 Abos, Premium, Werbung und Payments

## Nächste Reihenfolge

1. Neuen Code im Cloud-iPhone-Simulator kompilieren und alle UI-Flows grün bekommen.
2. Avatar-Migration ausrollen und Upload/Download mit RLS prüfen.
3. Sichtprüfung aller Referenzscreens und verbleibende UI-Abweichungen korrigieren.
4. „Vielleicht“, alle Reaktionen, Wochenleiste, Notification-Einstellungen und Deep Links schließen.
5. Neuen signierten TestFlight-Build erzeugen.
6. Zwei-Konten-Endabnahme auf echten iPhones durchführen.
