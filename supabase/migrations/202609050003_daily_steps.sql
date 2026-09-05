begin;

-- No HealthKit samples, source/device identifiers, location, or unrelated health
-- categories are stored. Only an explicitly shared local-day aggregate is accepted.
create table public.step_sharing_preferences (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 sharing_enabled boolean not null default false,
 sharing_revision bigint not null default 0 check(sharing_revision>=0),
 last_observed_at timestamptz,
 updated_at timestamptz not null default now()
);
create table public.daily_activity_metrics (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 local_date date not null,
 -- Needed only for local-midnight expiry; never exposed in friend responses.
 timezone text not null,
 steps int not null check(steps between 0 and 300000),
 steps_shared boolean not null default false,
 updated_at timestamptz not null default now(),
 unique(user_id,local_date)
);
-- Crossing time zones can change the owner's date. Old rows remain private history,
-- but cannot both appear as "today" because they each store a different zone.
create unique index one_shared_step_day_per_user on public.daily_activity_metrics(user_id) where steps_shared;
alter table public.step_sharing_preferences enable row level security;
alter table public.daily_activity_metrics enable row level security;

create function public.steps_are_shared(p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select sharing_enabled from public.step_sharing_preferences where user_id=p_user),false);
$$;

create function public.get_step_sharing(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_preference public.step_sharing_preferences;
begin
 if p_user is distinct from auth.uid() or auth.uid() is null then raise exception 'forbidden'; end if;
 select * into v_preference from public.step_sharing_preferences where user_id=p_user;
 return jsonb_build_object('user_id',p_user,'sharing_enabled',coalesce(v_preference.sharing_enabled,false),
   'sharing_revision',coalesce(v_preference.sharing_revision,0));
end; $$;

create function public.set_step_sharing(p_user uuid,p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if p_user is distinct from auth.uid() or auth.uid() is null then raise exception 'forbidden'; end if;
 if p_enabled is null then raise exception 'invalid_sharing_preference'; end if;
 -- UPSERT locks the same preference row that every uploader locks. Each real
 -- transition rotates the token, so an old upload cannot survive OFF -> ON.
 insert into public.step_sharing_preferences(user_id,sharing_enabled,sharing_revision)
 values(p_user,p_enabled,case when p_enabled then 1 else 0 end)
 on conflict(user_id) do update
 set sharing_enabled=excluded.sharing_enabled,
     sharing_revision=step_sharing_preferences.sharing_revision+
       case when step_sharing_preferences.sharing_enabled is distinct from excluded.sharing_enabled then 1 else 0 end,
     last_observed_at=case when step_sharing_preferences.sharing_enabled is distinct from excluded.sharing_enabled then null else step_sharing_preferences.last_observed_at end,
     updated_at=now();
 -- Revocation and its row flags commit atomically. Enabling does not republish
 -- any old values: a fresh, correctly versioned aggregate upload is required.
 if not p_enabled then
   update public.daily_activity_metrics set steps_shared=false where user_id=p_user and steps_shared;
 end if;
 return public.get_step_sharing(p_user);
end; $$;

create function public.sync_daily_steps(
 p_user uuid,p_date date,p_timezone text,p_steps int default null,p_sharing_revision bigint default null,p_observed_at timestamptz default null
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_preference public.step_sharing_preferences; v_now timestamptz; v_observed_at timestamptz;
begin
 if p_user is distinct from auth.uid() or auth.uid() is null then raise exception 'forbidden'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'invalid_timezone'; end if;
 if p_date is null or p_date<>(now() at time zone p_timezone)::date then raise exception 'stale_step_day'; end if;
 if p_steps is not null and p_steps not between 0 and 300000 then raise exception 'invalid_step_count'; end if;
 -- Hold this row lock through aggregate update/withdrawal. A completed OFF
 -- request wins over every upload with its previous token, including OFF -> ON.
 select * into v_preference from public.step_sharing_preferences where user_id=p_user for update;
 if v_preference.user_id is null or not v_preference.sharing_enabled
    or p_sharing_revision is null or p_sharing_revision<>v_preference.sharing_revision or p_observed_at is null then return false; end if;
 v_now := clock_timestamp();
 if p_date<>(v_now at time zone p_timezone)::date then raise exception 'stale_step_day'; end if;
 if p_observed_at>v_now+interval '5 minutes' or p_observed_at<v_now-interval '24 hours' then raise exception 'invalid_observation_time'; end if;
 if p_date<>(p_observed_at at time zone p_timezone)::date then raise exception 'stale_step_day'; end if;
 -- Small device clock skew cannot place the ordering cursor in the future.
 v_observed_at := least(p_observed_at,v_now);
 if v_preference.last_observed_at is not null then
   if v_observed_at<v_preference.last_observed_at then return false; end if;
   if v_observed_at=v_preference.last_observed_at then
     -- Identical retries are harmless; same-time conflicting values cannot win.
     return (p_steps is null and not exists(select 1 from public.daily_activity_metrics where user_id=p_user and steps_shared))
       or (p_steps is not null and exists(select 1 from public.daily_activity_metrics where user_id=p_user and local_date=p_date and timezone=p_timezone and steps=p_steps and steps_shared));
   end if;
 end if;

 -- Exactly one authoritative owner-local day is public, even when travelling
 -- across the date line. NULL data means withdraw, not a fabricated zero count.
 update public.daily_activity_metrics set steps_shared=false where user_id=p_user and steps_shared;
 if p_steps is not null then
   insert into public.daily_activity_metrics(user_id,local_date,timezone,steps,steps_shared)
   values(p_user,p_date,p_timezone,p_steps,true)
   on conflict(user_id,local_date) do update
   set steps=excluded.steps,timezone=excluded.timezone,steps_shared=true,updated_at=v_now;
 end if;
 update public.step_sharing_preferences set last_observed_at=v_observed_at where user_id=p_user;
 return true;
end; $$;

-- Friend callers can ask only about a metric row they can actually read; the
-- helper cannot be used to inspect another user's Health/permission settings.
create function public.can_read_daily_steps(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.daily_activity_metrics m where m.id=p_id and (
   m.user_id=auth.uid() or (
     m.steps_shared and public.steps_are_shared(m.user_id)
     and public.are_friends(m.user_id,auth.uid())
     and m.local_date=(now() at time zone m.timezone)::date
   )
 ));
$$;

create function public.friend_daily_steps() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'user_id',m.user_id,'local_date',m.local_date,'steps',m.steps,'updated_at',m.updated_at,
   'valid_until',least(((m.local_date+1)::timestamp at time zone m.timezone),now()+interval '120 seconds')
 ) order by m.user_id),'[]'::jsonb)
 from public.daily_activity_metrics m
 where m.steps_shared and public.steps_are_shared(m.user_id)
   and public.are_friends(m.user_id,auth.uid())
   and m.local_date=(now() at time zone m.timezone)::date;
$$;

create policy step_preferences_owner on public.step_sharing_preferences for select to authenticated using(user_id=auth.uid());
create policy daily_steps_read on public.daily_activity_metrics for select to authenticated using(public.can_read_daily_steps(id));

-- Authenticated updates go only through the narrowly validated RPCs. RLS also
-- protects direct SELECT; the owner's timezone is not among granted columns.
revoke all on public.step_sharing_preferences,public.daily_activity_metrics from anon,authenticated;
grant select on public.step_sharing_preferences to authenticated;
grant select(id,user_id,local_date,steps,steps_shared,updated_at) on public.daily_activity_metrics to authenticated;
revoke all on function public.steps_are_shared(uuid) from public,anon,authenticated;
revoke all on function public.can_read_daily_steps(uuid),public.get_step_sharing(uuid),
 public.set_step_sharing(uuid,boolean),public.sync_daily_steps(uuid,date,text,int,bigint,timestamptz),public.friend_daily_steps() from public,anon;
grant execute on function public.can_read_daily_steps(uuid),public.get_step_sharing(uuid),
 public.set_step_sharing(uuid,boolean),public.sync_daily_steps(uuid,date,text,int,bigint,timestamptz),public.friend_daily_steps() to authenticated;

commit;
