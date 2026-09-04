begin;
alter table public.planned_sessions add column reminder_sent_at timestamptz;

create or replace function public.process_scheduled_sessions() returns integer language plpgsql security definer set search_path='' as $$
declare affected integer := 0;
begin
  update public.planned_sessions set status='ready',updated_at=now() where status='planned' and starts_at<=now();
  insert into public.notifications(recipient_id,type,title,body,data)
  select recipient_id,'session_reminder','Training in 30 Minuten 🔥',sport::text||coalesce(' · '||subtype,''),jsonb_build_object('session_id',id)
  from (
    select s.id,s.host_id recipient_id,s.sport,s.subtype from public.planned_sessions s where s.status in ('planned','ready') and s.reminder_sent_at is null and s.starts_at between now() and now()+interval '30 minutes'
    union all
    select s.id,i.invitee_id,s.sport,s.subtype from public.planned_sessions s join public.session_invites i on i.session_id=s.id and i.status='accepted' where s.status in ('planned','ready') and s.reminder_sent_at is null and s.starts_at between now() and now()+interval '30 minutes'
  ) due;
  get diagnostics affected = row_count;
  update public.planned_sessions set reminder_sent_at=now() where reminder_sent_at is null and starts_at between now() and now()+interval '30 minutes';
  return affected;
end; $$;

-- In hosted Supabase call process_scheduled_sessions every five minutes via Cron.
-- Kept out of pg_cron here so local reset and projects without the extension stay reproducible.
commit;
