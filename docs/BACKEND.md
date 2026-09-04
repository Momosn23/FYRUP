# Backend

## Schema und Zuständigkeiten

- `profiles`: Identität, Sportpräferenzen, Ziel, Sichtbarkeit; 1:1 zu `auth.users`.
- `friendships`: gerichtete Anfrage mit beidseitigem Accepted-Zustand; ein kanonischer Paar-Index verhindert Duplikate.
- `blocks`: einseitige Sperre. Die Helper `is_blocked` und `are_friends` werden von Feed, Suche und Mutationen genutzt.
- `planned_sessions`: gemeinsamer Termin des Hosts einschließlich optionalem Treffpunkt und Beitrittsfreigabe.
- `session_invites`: Antwort je eingeladenem Nutzer (`pending`, `accepted`, `maybe`, `declined`).
- `activities`: persönliche Aktivität jedes Teilnehmers; optionale `planned_session_id` hält den Zusammenhang.
- `fyrups`: Motivation mit eindeutigem `(sender, recipient, sender_local_date)`.
- `activity_reactions`: genau eine änder-/löschbare Reaktion je Nutzer und Aktivität.
- `notifications`: interne Inbox und zuverlässige Push-Outbox in einer Tabelle.
- `device_tokens`: eigene APNs-Tokens je User und Umgebung.
- `analytics_events`: austauschbare, sparsame Produkt-Events.

## Activity Lifecycle

Sofort: `live → completed | cancelled`. Geplant: `planned → ready → live → completed | cancelled`. `NOT YET` wird nie gespeichert, sondern im `today_feed` aus dem Fehlen einer heutigen relevanten Activity abgeleitet. Der partielle Unique Index `one_live_activity_per_user` schützt auch bei zwei Geräten vor parallelem LIVE.

`start_activity`, `complete_activity` und `cancel_activity` prüfen `auth.uid()` und ändern atomar. Der Timer schreibt nicht pro Sekunde; die UI berechnet ihn aus `started_at`.

## Planned Sessions

`plan_session` erzeugt Termin, Host-Activity, Einladungen und Inbox-Ereignisse in einer Transaktion. `respond_to_invite` verwaltet Antworten und legt bei `accepted` eine eigene verknüpfte Activity an; `maybe` bleibt bewusst unverbindlich. `my_hosted_sessions` liefert dem Host die Status Wartet/Dabei/Vielleicht/Kann nicht. `update_planned_session` ändert Uhrzeit, Dauer, Notiz, Treffpunkt und Beitrittsfreigabe atomar, setzt die Erinnerung zurück, aktualisiert noch nicht gestartete Teilnehmer-Activities und informiert Betroffene. Startet der Host die Session, werden Accepted-Teilnehmer benachrichtigt; jeder startet seine Activity selbst. `cancel_session` storniert noch nicht gestartete Activities und informiert Eingeladene.

`process_scheduled_sessions` markiert erreichte Termine als Ready und legt 30-Minuten-Erinnerungen idempotent an. Die Migration `202609040008_scheduled_session_cron.sql` plant diese Funktion idempotent alle fünf Minuten via Supabase Cron. `202609040009_notification_dispatch_cron.sql` ruft den Push-Dispatcher minütlich über `pg_net` auf. Projekt-URL und Cron-Secret liegen dabei ausschließlich verschlüsselt als `fyrup_project_url` und `fyrup_cron_secret` in Supabase Vault; kein Secret steht im SQL oder Repository.

## Friendship und FYR UP

Suche läuft über eine begrenzte Security-Definer-Funktion, weil Profile sonst nur für sich und Accepted Friends lesbar sind. Request, Answer, Remove und Block sind serverseitige RPCs. Entfernen oder Blockieren räumt offene gemeinsame Session-Einladungen und geplante Teilnehmer-Activities auf, sodass die frühere Freundschaft keinen weiteren Lesezugriff vermittelt. Ein Block verhindert außerdem neue Social-Aktionen.

`send_fyrup` akzeptiert ausschließlich Accepted Friends und berechnet das Datum serverseitig in der Client-Zeitzone. Der Unique Constraint verhindert Retries und Doppeltaps zuverlässig.

## RLS

Direkte Mutationen sicherheitskritischer Tabellen sind für Clients nicht freigegeben; sie laufen über schmale RPCs. Eigentümer können ihr Profil ändern. Activities sind für Eigentümer sowie nicht blockierte Freunde sichtbar, sofern Visibility `friends` ist. Invites sehen nur Host und Invitee. Notifications und Tokens sieht ausschließlich der Empfänger/Eigentümer.

Security-Definer-Funktionen setzen `search_path=''` und qualifizieren Objekte vollständig, um Search-Path-Injection zu vermeiden. Service Role wird ausschließlich in Edge Functions verwendet.

## Push Flow

1. Das Gerät registriert den APNs Token über `register_device_token`.
2. Social-RPCs schreiben eine Notification/Outbox-Zeile.
3. Ein Scheduler ruft `dispatch-notifications` mit eigenem Cron-Secret auf.
4. Die Function signiert ein kurzlebiges APNs-JWT, sendet und setzt `push_sent_at`.
5. APNs Status 410 entfernt den veralteten Token.

## Account-Löschung

Die App ruft `delete-account` mit dem aktuellen Bearer Token auf. Die Function validiert den User und löscht ihn über Admin Auth. Foreign-Key-Cascades entfernen Profil, Freundschaften, Aktivitäten, Einladungen, Notifications und Device Tokens. Danach wird der lokale Keychain-Eintrag entfernt.
