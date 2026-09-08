# Produktiver Backend-Nachweis – 08.09.2026

Projekt `dwpuzcpnzldlnadfivcm`. Geprüft über den angemeldeten Supabase-SQL-Editor. Keine Testnutzer/Beispieldaten in der Produktion angelegt. Bestehende Profile, Wochenziele, Historien und Supplement-Einträge wurden nicht umgeschrieben.

## Ausgangszustand / Migration 016

Das Migrationsjournal endete bei `202609050015`, obwohl Funktion und Index aus 016 bereits existierten. Vor jeder Änderung wurden Funktionskörper, Signatur, Rückgabe, Sprache, STABLE, SECURITY DEFINER, leerer search_path, Zugriffsrechte und gültiger Index mit dem lokalen Stand abgeglichen. Normalisierte MD5 des Funktionskörpers: `ddb62533a271cb5ea1709fc6869a5480`.

`assembleExistingPerformanceReceipt` ergänzt nur bei vollständiger Übereinstimmung und exakt diesem Journalstand den fehlenden Beleg `202609060016`. Kein erneutes Ausführen der Funktion/Index-DDL. Die anschließende Leseprüfung bestätigte genau einen Beleg, unveränderten Funktionshash und weiterhin gesperrten anonymen Zugriff.

## Atomarer Block 017–019

`scripts/reference-deployment-bundle.mjs` assembliert die vorhandenen Migrationen unverändert ohne einzelne äußere Transaktionsgrenzen. Alle drei Änderungen und Journalbelege liegen in einer Transaktion; Locklimit 4 Sekunden, Statementlimit 60 Sekunden. Vorherige Funktionen/Policies wurden privat als `before-202609080017-019` gesichert. Falscher Ausgangsstand und wiederholte Anwendung werden abgelehnt.

Ausführung erfolgreich. Unabhängige Leseprüfung danach:

| Prüfung | Ergebnis |
| --- | --- |
| Journal 017 / normalisierter Quellhash | `6d803bcd9b03352882ae79614ec45d8f` – entspricht lokalem Migrationskörper |
| Journal 018 / normalisierter Quellhash | `85d63e00bc9d04a6cfe6ebd2ef0eb49e` – entspricht lokalem Migrationskörper |
| Journal 019 / normalisierter Quellhash | `f8b9a71ddc29efa0ffdb08383b263e23` – entspricht lokalem Migrationskörper |
| Vier Wochenziel-Constraints | 2 bis 7 |
| Neue Profile / activity_visibility | Default `nobody` |
| supplement_plans.amount | Optionales `jsonb`, vollständiger `supplement_amount_valid` mit positiver Zahl, zulässiger Einheit und COALESCE-false-Schutz |
| profiles / supplement_plans RLS | Weiterhin aktiviert |
| save_onboarding_state / save_supplement_plan / upsert_profile | authenticated erlaubt; anon und public gesperrt |
| Privater Vorher-Snapshot | Genau 1; SELECT für anon und authenticated gesperrt |

Beim Einfügen über Windows entstanden CRLF-Zeilenenden im Journal (017: 52, 018: 43, 019: 63 CR-Zeichen). Die obigen Hashes normalisieren ausschließlich CRLF zu LF; der Quelltext stimmt danach exakt überein. MD5 dient hier dem nicht geheimen Codevergleich, nicht der Speicherung von Passwörtern oder Sicherheits-Tokens.

## Lokale Sicherheitsnachweise / Grenzen

Isolierte PostgreSQL-Tests prüfen fehlenden 016-Beleg, Ablehnung eines abweichenden Funktionskörpers bzw. STABLE-Flags, Wiederholungsverbot, erfolgreiche 017–019-Anwendung und komplettes Rollback bei absichtlichem Fehler in 019. Bestehende Fixture-Profile bleiben bytegleich; private Snapshot-Rechte und alle 19 Journalbelege werden geprüft. Kein absichtlicher Fehler wurde auf produktive Nutzerdaten angewandt.

Migrationen 017–019 sind damit **produktiv angewendet und strukturell nachgeprüft**. Echte App-/Mehrkonten-Speicherversuche, parallele Last, iPhone und TestFlight bleiben separate Prüfungen. SMTP ist weiterhin nicht aktiviert; die bestätigte Rückkehradresse ist `fyrup://auth-callback`. Der FYRUP-Datenschutztext ist nur ein Entwurf, nicht veröffentlicht.
