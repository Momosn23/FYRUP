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

- Die ergänzenden Migrationen 010/011 sind lokal grün, aber hier noch nicht als gehostet bestätigt.
- Neuere App-Korrekturen (Mitteilungsrouting, private Wiederherstellung von Satzentwürfen, Widerruf geöffneter Freunddaten, visuelle Details) brauchen einen neuen nativen Cloud-Test.
- Edge-Function-Deployment, HealthKit-Signierung und neue signierte TestFlight-Version sind noch offen.
