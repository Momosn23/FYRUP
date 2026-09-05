begin;

-- User-authored, private checklist. No products, doses or medical advice are seeded.
create table public.supplement_settings (
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 revision integer not null default 1 check(revision>0),
 timezone text not null,
 quiet_enabled boolean not null default true,
 quiet_start integer not null default 1320 check(quiet_start between 0 and 1439),
 quiet_end integer not null default 480 check(quiet_end between 0 and 1439),
 last_reminder_check timestamptz not null default '-infinity',
 check(not quiet_enabled or quiet_start<>quiet_end)
);
create table public.supplement_plans (
 id uuid primary key,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 revision integer not null default 1 check(revision>0),
 name text not null check(char_length(name) between 1 and 60),
 weekdays integer[] not null,
 slots jsonb not null,
 is_paused boolean not null default false,
 is_archived boolean not null default false,
 reminders_enabled boolean not null default false,
 repeat_minutes integer not null default 60 check(repeat_minutes in (15,30,60,120,180)),
 repeat_count integer not null default 0 check(repeat_count between 0 and 3),
 updated_at timestamptz not null default now(),
 unique(owner_id,id)
);
create index supplement_plans_owner on public.supplement_plans(owner_id) where not is_archived;
create table public.supplement_doses (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 plan_id uuid not null,
 slot_id uuid not null,
 day date not null,
 due_at timestamptz not null,
 plan_revision integer not null,
 status text not null default 'open' check(status in ('open','taken','skipped')),
 revision integer not null default 1 check(revision>0),
 changed_at timestamptz,
 foreign key(owner_id,plan_id) references public.supplement_plans(owner_id,id) on delete cascade,
 unique(owner_id,plan_id,slot_id,day),
 check((status='open')=(changed_at is null))
);
create index supplement_doses_owner_day on public.supplement_doses(owner_id,day);
create table public.supplement_receipts (
 owner_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null,
 dose_id uuid not null references public.supplement_doses(id) on delete cascade,
 payload jsonb not null,
 primary key(owner_id,request_id)
);
create table public.supplement_reminder_jobs (
 dose_id uuid not null references public.supplement_doses(id) on delete cascade,
 plan_revision integer not null,
 settings_revision integer not null,
 ordinal integer not null check(ordinal between 0 and 3),
 notification_id uuid not null references public.notifications(id) on delete cascade,
 expires_at timestamptz not null,
 primary key(dose_id,plan_revision,settings_revision,ordinal),
 unique(notification_id)
);

alter table public.supplement_settings enable row level security;
alter table public.supplement_plans enable row level security;
alter table public.supplement_doses enable row level security;
alter table public.supplement_receipts enable row level security;
alter table public.supplement_reminder_jobs enable row level security;
create policy supplement_settings_owner on public.supplement_settings for select to authenticated using(owner_id=auth.uid());
create policy supplement_plans_owner on public.supplement_plans for select to authenticated using(owner_id=auth.uid());
create policy supplement_doses_owner on public.supplement_doses for select to authenticated using(owner_id=auth.uid());
revoke all on public.supplement_settings,public.supplement_plans,public.supplement_doses,public.supplement_receipts,public.supplement_reminder_jobs from public,anon,authenticated;
grant select on public.supplement_settings,public.supplement_plans,public.supplement_doses to authenticated;

create function public.supplement_is_quiet(p_minute integer,p_enabled boolean,p_start integer,p_end integer)
returns boolean language sql immutable set search_path='' as $$
 select p_enabled and case when p_start<p_end then p_minute>=p_start and p_minute<p_end else p_minute>=p_start or p_minute<p_end end
$$;

-- The saved timezone is fixed: travel/system clock changes never manufacture a second dose.
-- This helper accepts a clock for deterministic DST tests, but is NOT callable by app clients.
create function public.materialize_supplement_day(p_owner uuid,p_now timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare s public.supplement_settings; d date;
begin
 if p_now is null or not isfinite(p_now) then raise exception 'invalid_supplement_time'; end if;
 select * into s from public.supplement_settings where owner_id=p_owner;
 if not found then return; end if;
 d:=(p_now at time zone s.timezone)::date;
 insert into public.supplement_doses(owner_id,plan_id,slot_id,day,due_at,plan_revision)
 select p.owner_id,p.id,(slot->>'id')::uuid,d,(d+make_interval(mins=>(slot->>'minute')::integer)) at time zone s.timezone,p.revision
 from public.supplement_plans p cross join lateral jsonb_array_elements(p.slots) slot
 where p.owner_id=p_owner and not p.is_archived and not p.is_paused and extract(isodow from d)::integer=any(p.weekdays)
 on conflict(owner_id,plan_id,slot_id,day) do update set due_at=excluded.due_at,plan_revision=excluded.plan_revision;
end; $$;

create function public.get_supplements(p_timezone text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_settings public.supplement_settings; v_day date;
begin
 if v_owner is null then raise exception 'unauthorized'; end if;
 if not exists(select 1 from pg_timezone_names where name=p_timezone) then raise exception 'invalid_timezone'; end if;
 perform 1 from public.profiles where id=v_owner for update;
 if not found then raise exception 'profile_required'; end if;
 insert into public.supplement_settings(owner_id,timezone) values(v_owner,p_timezone) on conflict(owner_id) do nothing;
 select * into v_settings from public.supplement_settings where owner_id=v_owner;
 perform public.materialize_supplement_day(v_owner,now());
 v_day:=(now() at time zone v_settings.timezone)::date;
 return jsonb_build_object('owner_id',v_owner,'server_now',now(),'day',v_day,'settings',to_jsonb(v_settings),
 'plans',(select coalesce(jsonb_agg(to_jsonb(p) order by p.name,p.id),'[]') from public.supplement_plans p where p.owner_id=v_owner and not p.is_archived),
 'doses',(select coalesce(jsonb_agg(to_jsonb(d) order by d.due_at,d.id),'[]') from public.supplement_doses d join public.supplement_plans p on p.id=d.plan_id
 where d.owner_id=v_owner and d.day=v_day and not p.is_archived and not p.is_paused and extract(isodow from v_day)::integer=any(p.weekdays)
 and exists(select 1 from jsonb_array_elements(p.slots) slot where (slot->>'id')::uuid=d.slot_id)));
end; $$;

create function public.save_supplement_plan(p_plan jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_id uuid; v_old public.supplement_plans; v_saved public.supplement_plans; v_slot jsonb; v_days integer[]; v_ids uuid[]:='{}'; v_minutes integer[]:='{}';
begin
 if v_owner is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_plan) is distinct from 'object' or lower(p_plan->>'owner_id') is distinct from v_owner::text
 or coalesce(p_plan->>'id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
 or jsonb_typeof(p_plan->'revision') is distinct from 'number' or coalesce(p_plan->>'revision','') !~ '^[0-9]{1,9}$'
 or jsonb_typeof(p_plan->'name') is distinct from 'string' or char_length(btrim(p_plan->>'name')) not between 1 and 60
 or jsonb_typeof(p_plan->'weekdays') is distinct from 'array' or jsonb_typeof(p_plan->'slots') is distinct from 'array'
 or jsonb_typeof(p_plan->'is_paused') is distinct from 'boolean' or jsonb_typeof(p_plan->'is_archived') is distinct from 'boolean'
 or jsonb_typeof(p_plan->'reminders_enabled') is distinct from 'boolean'
 or jsonb_typeof(p_plan->'repeat_minutes') is distinct from 'number' or coalesce(p_plan->>'repeat_minutes','') not in ('15','30','60','120','180')
 or jsonb_typeof(p_plan->'repeat_count') is distinct from 'number' or coalesce(p_plan->>'repeat_count','') !~ '^[0-3]$' then raise exception 'invalid_supplement'; end if;
 if jsonb_array_length(p_plan->'weekdays') not between 1 and 7 or exists(select 1 from jsonb_array_elements(p_plan->'weekdays') d where jsonb_typeof(d)<>'number' or d::text !~ '^[1-7]$') then raise exception 'invalid_supplement'; end if;
 select array_agg((d::text)::integer order by (d::text)::integer) into v_days from jsonb_array_elements(p_plan->'weekdays') d;
 if cardinality(v_days)<>(select count(distinct d) from unnest(v_days) d) or jsonb_array_length(p_plan->'slots') not between 1 and 4 then raise exception 'invalid_supplement'; end if;
 for v_slot in select value from jsonb_array_elements(p_plan->'slots') loop
  if jsonb_typeof(v_slot) is distinct from 'object' or coalesce(v_slot->>'id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
  or jsonb_typeof(v_slot->'minute') is distinct from 'number' or coalesce(v_slot->>'minute','') !~ '^[0-9]{1,4}$' then raise exception 'invalid_supplement'; end if;
  if (v_slot->>'minute')::integer>1439 or (v_slot->>'id')::uuid=any(v_ids) or (v_slot->>'minute')::integer=any(v_minutes) then raise exception 'invalid_supplement'; end if;
  v_ids:=array_append(v_ids,(v_slot->>'id')::uuid); v_minutes:=array_append(v_minutes,(v_slot->>'minute')::integer);
 end loop;
 perform 1 from public.profiles where id=v_owner for update;
 if not found then raise exception 'profile_required'; end if;
 if not exists(select 1 from public.supplement_settings where owner_id=v_owner) then raise exception 'settings_required'; end if;
 v_id:=(p_plan->>'id')::uuid;
 select * into v_old from public.supplement_plans where id=v_id;
 if found and v_old.owner_id<>v_owner then raise exception 'unauthorized'; end if;
 if coalesce(v_old.revision,0)<>(p_plan->>'revision')::integer then raise exception 'supplement_conflict'; end if;
 if not (p_plan->>'is_archived')::boolean and (select count(*) from public.supplement_plans where owner_id=v_owner and not is_archived and id<>v_id)>=20 then raise exception 'supplement_limit'; end if;
 insert into public.supplement_plans(id,owner_id,name,weekdays,slots,is_paused,is_archived,reminders_enabled,repeat_minutes,repeat_count)
 values(v_id,v_owner,btrim(p_plan->>'name'),v_days,p_plan->'slots',(p_plan->>'is_paused')::boolean,(p_plan->>'is_archived')::boolean,(p_plan->>'reminders_enabled')::boolean,(p_plan->>'repeat_minutes')::integer,(p_plan->>'repeat_count')::integer)
 on conflict(id) do update set revision=public.supplement_plans.revision+1,name=excluded.name,weekdays=excluded.weekdays,slots=excluded.slots,is_paused=excluded.is_paused,is_archived=excluded.is_archived,reminders_enabled=excluded.reminders_enabled,repeat_minutes=excluded.repeat_minutes,repeat_count=excluded.repeat_count,updated_at=now()
 returning * into v_saved;
 update public.notifications n set push_sent_at=now() from public.supplement_reminder_jobs j join public.supplement_doses d on d.id=j.dose_id
 where n.id=j.notification_id and d.plan_id=v_id and n.push_sent_at is null;
 perform public.materialize_supplement_day(v_owner,now());
 return to_jsonb(v_saved);
end; $$;

create function public.save_supplement_settings(p_settings jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); s public.supplement_settings;
begin
 if v_owner is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_settings) is distinct from 'object' or jsonb_typeof(p_settings->'revision') is distinct from 'number' or coalesce(p_settings->>'revision','') !~ '^[0-9]{1,9}$'
 or jsonb_typeof(p_settings->'quiet_enabled') is distinct from 'boolean' or jsonb_typeof(p_settings->'timezone') is distinct from 'string'
 or jsonb_typeof(p_settings->'quiet_start') is distinct from 'number' or coalesce(p_settings->>'quiet_start','') !~ '^[0-9]{1,4}$'
 or jsonb_typeof(p_settings->'quiet_end') is distinct from 'number' or coalesce(p_settings->>'quiet_end','') !~ '^[0-9]{1,4}$' then raise exception 'invalid_supplement_settings'; end if;
 if (p_settings->>'quiet_start')::integer>1439 or (p_settings->>'quiet_end')::integer>1439
 or ((p_settings->>'quiet_enabled')::boolean and p_settings->>'quiet_start'=p_settings->>'quiet_end') then raise exception 'invalid_supplement_settings'; end if;
 perform 1 from public.profiles where id=v_owner for update;
 select * into s from public.supplement_settings where owner_id=v_owner;
 if not found then raise exception 'settings_required'; end if;
 if s.revision<>(p_settings->>'revision')::integer then raise exception 'supplement_conflict'; end if;
 if s.timezone is distinct from p_settings->>'timezone' then raise exception 'supplement_timezone_fixed'; end if;
 update public.supplement_settings set revision=revision+1,quiet_enabled=(p_settings->>'quiet_enabled')::boolean,quiet_start=(p_settings->>'quiet_start')::integer,quiet_end=(p_settings->>'quiet_end')::integer where owner_id=v_owner returning * into s;
 update public.notifications n set push_sent_at=now() from public.supplement_reminder_jobs j join public.supplement_doses d on d.id=j.dose_id
 where n.id=j.notification_id and d.owner_id=v_owner and n.push_sent_at is null;
 return to_jsonb(s);
end; $$;

create function public.set_supplement_dose(p_change jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_request uuid; v_dose uuid; v_receipt public.supplement_receipts; d public.supplement_doses;
begin
 if v_owner is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_change) is distinct from 'object' or coalesce(p_change->>'request_id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
 or coalesce(p_change->>'dose_id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
 or jsonb_typeof(p_change->'expected_revision') is distinct from 'number' or coalesce(p_change->>'expected_revision','') !~ '^[0-9]{1,9}$'
 or coalesce(p_change->>'status','') not in ('open','taken','skipped') then raise exception 'invalid_supplement_change'; end if;
 v_request:=(p_change->>'request_id')::uuid; v_dose:=(p_change->>'dose_id')::uuid;
 perform 1 from public.profiles where id=v_owner for update;
 select * into d from public.supplement_doses where id=v_dose and owner_id=v_owner for update;
 if not found then raise exception 'unauthorized'; end if;
 select * into v_receipt from public.supplement_receipts where owner_id=v_owner and request_id=v_request;
 if found then
  if v_receipt.payload<>p_change then raise exception 'supplement_request_conflict'; end if;
  return to_jsonb(d); -- Current state, never an old receipt snapshot after a later undo.
 end if;
 if d.status<>p_change->>'status' then
  if d.revision<>(p_change->>'expected_revision')::integer then raise exception 'supplement_conflict'; end if;
  update public.supplement_doses set status=p_change->>'status',revision=revision+1,changed_at=case when p_change->>'status'='open' then null else now() end where id=v_dose returning * into d;
 end if;
 insert into public.supplement_receipts(owner_id,request_id,dose_id,payload) values(v_owner,v_request,v_dose,p_change);
 if d.status<>'open' then
  update public.notifications n set push_sent_at=now(),read_at=coalesce(read_at,now()) from public.supplement_reminder_jobs j where n.id=j.notification_id and j.dose_id=d.id and n.push_sent_at is null;
 end if;
 return to_jsonb(d);
end; $$;

-- Revalidated immediately before every APNS send. No client can authorize a push.
create function public.can_dispatch_supplement(p_notification uuid,p_now timestamptz default now()) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.supplement_reminder_jobs j join public.notifications n on n.id=j.notification_id
 join public.supplement_doses d on d.id=j.dose_id join public.supplement_plans p on p.id=d.plan_id join public.supplement_settings s on s.owner_id=d.owner_id
 where n.id=p_notification and n.type='supplement_reminder' and n.recipient_id=d.owner_id and n.push_sent_at is null
 and n.data->>'dose_id'=d.id::text and p_now>=d.due_at+make_interval(mins=>j.ordinal*p.repeat_minutes)
 and d.status='open' and not p.is_paused and not p.is_archived and p.reminders_enabled
 and p.revision=j.plan_revision and s.revision=j.settings_revision and p_now<j.expires_at
 and d.day=(p_now at time zone s.timezone)::date and extract(isodow from d.day)::integer=any(p.weekdays)
 and exists(select 1 from jsonb_array_elements(p.slots) slot where (slot->>'id')::uuid=d.slot_id)
 and not public.supplement_is_quiet(extract(hour from p_now at time zone s.timezone)::integer*60+extract(minute from p_now at time zone s.timezone)::integer,s.quiet_enabled,s.quiet_start,s.quiet_end))
$$;

create function public.process_supplement_reminders(p_now timestamptz default now()) returns integer language plpgsql security definer set search_path='' as $$
declare v_owner uuid; d record; v_ordinal integer; v_due timestamptz; v_id uuid; total integer:=0;
begin
 if p_now is null or not isfinite(p_now) then raise exception 'invalid_supplement_time'; end if;
 -- Same lock order as client mutations. Concurrent invocations cannot enqueue twice.
 for v_owner in select pr.id from public.profiles pr join public.supplement_settings ss on ss.owner_id=pr.id where exists(select 1 from public.supplement_plans p where p.owner_id=pr.id and p.reminders_enabled and not p.is_paused and not p.is_archived) order by ss.last_reminder_check,pr.id limit 200 for update of pr skip locked loop
  perform public.materialize_supplement_day(v_owner,p_now);
  for d in select sd.*,p.repeat_minutes,p.repeat_count,p.revision as current_plan_revision,s.revision as settings_revision,s.timezone,s.quiet_enabled,s.quiet_start,s.quiet_end
   from public.supplement_doses sd join public.supplement_plans p on p.id=sd.plan_id join public.supplement_settings s on s.owner_id=sd.owner_id
   where sd.owner_id=v_owner and sd.status='open' and sd.day=(p_now at time zone s.timezone)::date
   and p.reminders_enabled and not p.is_paused and not p.is_archived and extract(isodow from sd.day)::integer=any(p.weekdays)
   and exists(select 1 from jsonb_array_elements(p.slots) slot where (slot->>'id')::uuid=sd.slot_id)
  loop
   -- At most the most recent due reminder, and never a catch-up burst after an outage.
   select max(i) into v_ordinal from generate_series(0,d.repeat_count) i where d.due_at+make_interval(mins=>i*d.repeat_minutes)<=p_now;
   if v_ordinal is null then continue; end if;
   v_due:=d.due_at+make_interval(mins=>v_ordinal*d.repeat_minutes);
   if v_due<=p_now-interval '5 minutes' or (v_due at time zone d.timezone)::date<>d.day
    or public.supplement_is_quiet(extract(hour from p_now at time zone d.timezone)::integer*60+extract(minute from p_now at time zone d.timezone)::integer,d.quiet_enabled,d.quiet_start,d.quiet_end)
    or exists(select 1 from public.supplement_reminder_jobs where dose_id=d.id and plan_revision=d.current_plan_revision and settings_revision=d.settings_revision and ordinal=v_ordinal) then continue; end if;
   insert into public.notifications(recipient_id,type,title,body,data) values(v_owner,'supplement_reminder','Deine Erinnerung','Ein Eintrag auf deiner heutigen Liste ist noch offen.',jsonb_build_object('dose_id',d.id)) returning id into v_id;
   insert into public.supplement_reminder_jobs(dose_id,plan_revision,settings_revision,ordinal,notification_id,expires_at)
   values(d.id,d.current_plan_revision,d.settings_revision,v_ordinal,v_id,least(v_due+interval '5 minutes',(d.day+1)::timestamp at time zone d.timezone));
   total:=total+1;
  end loop;
  update public.supplement_settings set last_reminder_check=p_now where owner_id=v_owner;
 end loop;
 return total;
end; $$;

revoke all on function public.supplement_is_quiet(integer,boolean,integer,integer),public.materialize_supplement_day(uuid,timestamptz),public.can_dispatch_supplement(uuid,timestamptz),public.process_supplement_reminders(timestamptz) from public,anon,authenticated;
grant execute on function public.can_dispatch_supplement(uuid,timestamptz),public.process_supplement_reminders(timestamptz) to service_role;
revoke all on function public.get_supplements(text),public.save_supplement_plan(jsonb),public.save_supplement_settings(jsonb),public.set_supplement_dose(jsonb) from public,anon;
grant execute on function public.get_supplements(text),public.save_supplement_plan(jsonb),public.save_supplement_settings(jsonb),public.set_supplement_dose(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
