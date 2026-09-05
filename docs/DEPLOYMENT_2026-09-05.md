# Erweiterungs-Deployment 5. September 2026

## Tatsächlich geprüft

- Cloud Build 25 (`559b6f7`): 247 native Unit-Tests und 22 UI-Abläufe bestanden. Simulator; kein physisches iPhone und keine echte HealthKit-/APNs-Abnahme.
- Lokale Datenbankprüfung einschließlich Kopier-Idempotenz und atomarer Mitteilungseinstellungen: 770 Assertions bestanden. Zusätzlich 31 Dispatcher-Tests und Bibliotheksprüfung (122 eindeutige Übungen, 127 geforderte Muskelzuordnungen) bestanden.
- Das Deploymentpaket 001–009 wurde lokal mit erfolgreichem Durchlauf, absichtlichem Fehler/komplettem Rollback, Schutz der Schema-Sicherung und Abweisung eines zweiten Deployments getestet.

## Gehosteter Server

Projekt `dwpuzcpnzldlnadfivcm`, am 5. September im angemeldeten Dashboard geprüft:

- Migrationen `202609050001` bis `202609050009` stehen vollständig in der Versionshistorie.
- 122 Standardübungen sind vorhanden.
- Keine Tabelle in `public`, `supabase_migrations` oder `fyrup_deployment` ist ohne aktivierten Row-Level-Zugriffsschutz.
- Eine private Schema-Sicherung ist vorhanden; weder `anon` noch `authenticated` haben Schema-Zugriff darauf. Sie enthält ausschließlich Routinen und Richtlinien, keine Nutzerdaten.
- Profilanzahl vor/nach Update: 0. Keine Profile gelöscht oder Testbenutzer angelegt.

Der zusätzliche Dashboard-Befehl „Run and enable RLS“ meldete nach dem Commit eine nicht mehr existierende temporäre Seed-Tabelle. Danach wurde **nicht** blind erneut deployt: unabhängige Nur-Lese-Abfragen bestätigten alle neun Versionen, Tabellen, Bibliothek und Zugriffsschutz. Die Meldung betraf den zusätzlichen Schutzbefehl für die bereits automatisch aufgeräumte temporäre Tabelle, nicht ein fehlendes App-Schema.

## Noch nicht als ausgeliefert markieren

- Die ergänzenden Migrationen 010/011 wurden inzwischen erfolgreich eingespielt und danach separat kontrolliert: 11 Versionen, geschützte Kopierbelege, alte unsichere Kopierfunktion für Clients gesperrt, neue auftragsgebundene Kopierfunktion freigegeben, atomare Mitteilungsfunktion freigegeben, direkte Tabellenänderung gesperrt. Bibliothek weiterhin 122 Übungen.
- Cloud Build 26 (`a94fb6e`): 346 native Unit-Tests und 23/24 UI-Abläufe bestanden. Laufzeit 25m04s. Die Teilen-Vorschau scheiterte: der Button lag laut aufgezeichneter UI-Hierarchie bei y739,5 hinter dem festen unteren Bereich, obwohl iOS ihn als antippbar meldete. Beide Abschlussaktionen stehen im Korrekturstand gemeinsam sichtbar im unteren Bereich; ein neuer Test prüft ihre Lage und den vollständigen Vorschauablauf.
- 58 Simulatorbilder von Build 26 lokal vorhanden. Weitere Korrekturen: Blind-Workout-Kopfzeile/Sortieren, unerwünschte Unschärfekante auf dem Anmeldebildschirm und Nutzerwunsch „Deine Streak“ statt „Deine Flames“. Nativer Nachtest steht aus.
- `dispatch-notifications` wurde aktualisiert. Der anschließend vom Server heruntergeladene ZIP-Inhalt enthält exakt die beiden getesteten Quelldateien. Automatische Aufrufe nach Deployment liefern HTTP 200, u. a. 09:18, 09:22 und 09:33–09:35 CEST. Das belegt Laufzeit/Import, noch keinen Empfang einer echten Push-Nachricht auf dem iPhone.
- HealthKit ist für `app.fyrup.ios` bei Apple aktiviert. Nach ausdrücklicher Bestätigung wurde das bestehende App-Store-Profil mit dem bestehenden Zertifikat erneuert; Apple bietet das neue Profil zum Download an. Übernahme in den Build-Dienst und signierter IPA-Nachweis sind noch zu prüfen.
- Neue signierte TestFlight-Version und echte HealthKit-/APNs-Abnahme sind weiterhin offen.

## Nachtrag ab10:30 CEST

- Build27 (`63047cb`) erfolgreich, alle24 Bedienabläufe bestanden. Vier Original-Simulatorbilder separat kontrolliert: [visueller Nachweis](VISUAL_QA_BUILD27.md).
- Das bei Apple erneuerte App-Store-Profil wurde über die bestehende Integration abgerufen und in Codemagic unter `fyrup_app_store_healthkit` gespeichert. Die Oberfläche bestätigt `app.fyrup.ios`, passenden Teamnamen und Übereinstimmung mit dem vorhandenen Zertifikat `FYRUP Apple Distribution`. Das bisherige Profil wurde nicht gelöscht.
- Der vorbereitete signierte Workflow referenziert ausschließlich das neue Profil und das bestehende Zertifikat. Vor dem eigentlichen Build prüft er dessen App-ID, HealthKit, Apple-Anmeldung und Produktions-Push-Entitlements. Diese Prüfung ist noch nicht ausgeführt und ersetzt nicht den IPA-/Gerätenachweis.
- Die Referenzsyntax wurde anhand der [offiziellen Codemagic-Signierungsdokumentation](https://docs.codemagic.io/yaml-code-signing/signing-ios/) geprüft; nicht mit der automatischen Bundle-ID-/Distribution-Auswahl vermischt.
- Persönlicher Wochenplan/Bewertung: Code `f10d61a`, Cloud-Build28 angelaufen;66 zusätzliche lokale DB-Prüfungen. Migration012 noch nicht produktiv. Eigenes transaktionales Paket mit11-Versions-Vorabprüfung, atomarem Fehler-Rollback und wahrheitsgemäßem12. Historieneintrag lokal erfolgreich geprüft.

## Nachtrag ab10:49 CEST

- Build28 erfolgreich:360 Unit-Tests,25/25 UI-Abläufe, `TEST SUCCEEDED`. [Sechs Originalbilder geprüft](VISUAL_QA_BUILD28.md).
- Migration012 mit exakt geprüftem Transaktionspaket über das angemeldete Projektdashboard installiert. „Success. No rows returned“; anschließende unabhängige Abfrage bestätigt12 Versionen bis202609050012, zwei neue RLS-Tabellen und fünf nur für angemeldete Nutzer erreichbare Funktionen. Direkte Tabellen-Schreibrechte jeweilsfalse; weiterhin122 Standardübungen und0 Profile. Keine Bestandsdaten gelöscht und keine Testkonten erzeugt.
- Interaktive Muskelgrafik im Folgestand vorbereitet; deren native/visuelle Tests sind noch offen. Neue signierte TestFlight-Version bleibt offen.
