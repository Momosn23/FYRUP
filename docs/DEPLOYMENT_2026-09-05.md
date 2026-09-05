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
