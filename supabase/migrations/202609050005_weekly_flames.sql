begin;

-- Goal selection is separate from profile editing. The legacy field remains a
-- read-compatible mirror, not an alternate way to change this week's target.
alter table public.profiles
 add column current_weekly_goal integer not null default 4 check(current_weekly_goal between 3 and 7),
 add column weekly_goal_confirmed_at timestamptz,
 add column weekly_timezone text not null default 'Europe/Berlin';
update public.profiles p
set current_weekly_goal=greatest(3,p.weekly_goal),
    weekly_goal_confirmed_at=case when p.weekly_goal>=3 then now() else null end,
    weekly_timezone=case when exists(select 1 from pg_catalog.pg_timezone_names z where z.name=p.timezone) then p.timezone else 'Europe/Berlin' end,
    weekly_goal=greatest(3,p.weekly_goal);

-- Pending personal changes are not profile columns: existing friend/profile
-- RPCs return profile composites and must never leak next week's private intent.
create table public.weekly_goal_changes (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 next_weekly_goal integer check(next_weekly_goal between 3 and 7),
 next_weekly_timezone text
);

create table public.weekly_progress (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 week_start_date date not null check(extract(isodow from week_start_date)=1),
 timezone text not null, starts_at timestamptz not null, ends_at timestamptz not null check(ends_at>starts_at),
 weekly_goal integer not null check(weekly_goal between 3 and 7), goal_confirmed boolean not null,
 completed_workouts integer not null default 0 check(completed_workouts>=0),
 flame_earned boolean not null default false, flame_earned_at timestamptz,
 finalized boolean not null default false, finalized_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(user_id,week_start_date),
 check(flame_earned=(flame_earned_at is not null)),
 check(not flame_earned or (goal_confirmed and completed_workouts>=weekly_goal)),
 check(finalized=(finalized_at is not null))
);
create unique index one_open_week_per_user on public.weekly_progress(user_id) where not finalized;
create index weekly_progress_owner_history on public.weekly_progress(user_id,week_start_date desc);

create table public.weekly_activity_credits (
 activity_id uuid primary key references public.activities(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 week_id uuid not null references public.weekly_progress(id) on delete cascade,
 completed_at timestamptz not null, active_seconds integer not null check(active_seconds>=0),
 eligible boolean not null, rule_version integer not null default 1,
 reason text not null check(reason in ('completed_workout','active_duration_under_60_seconds','outside_open_period')),
 created_at timestamptz not null default now()
);
create index weekly_credits_period on public.weekly_activity_credits(week_id) where eligible;
create table public.weekly_flame_reactions (
 week_id uuid not null references public.weekly_progress(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 reaction text not null check(reaction in ('🔥','💪','👏')), updated_at timestamptz not null default now(),
 primary key(week_id,user_id)
);
create table public.weekly_flame_celebrations (
 week_id uuid primary key references public.weekly_progress(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 claimed_at timestamptz not null default now()
);
create unique index weekly_earned_notification_once on public.notifications(recipient_id,(data->>'week_id'))
 where type='weekly_goal' and data ? 'week_id';
create unique index weekly_reaction_notification_once on public.notifications(recipient_id,actor_id,(data->>'week_id'))
 where type='flame_reaction' and data ? 'week_id' and actor_id is not null;

-- Internal clock-taking helpers are deliberately NOT executable by app clients.
-- Production entry points always pass server time. Tests may use the database
-- administrator to exercise DST, travel and long-absence boundaries without sleeps.
create function public.ensure_weekly_period(p_user uuid,p_now timestamptz)
returns public.weekly_progress language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles; v_change public.weekly_goal_changes; v_week public.weekly_progress; v_date date; v_zone text; v_goal integer;
begin
 select * into v_profile from public.profiles where id=p_user for no key update;
 if v_profile.id is null then raise exception 'profile_not_found'; end if;
 select * into v_change from public.weekly_goal_changes where user_id=p_user;
 select * into v_week from public.weekly_progress where user_id=p_user order by week_start_date desc limit 1 for update;
 if v_week.id is null then
   v_date := date_trunc('week',p_now at time zone v_profile.weekly_timezone)::date;
   insert into public.weekly_progress(user_id,week_start_date,timezone,starts_at,ends_at,weekly_goal,goal_confirmed)
   values(p_user,v_date,v_profile.weekly_timezone,v_date::timestamp at time zone v_profile.weekly_timezone,
     (v_date+7)::timestamp at time zone v_profile.weekly_timezone,v_profile.current_weekly_goal,v_profile.weekly_goal_confirmed_at is not null)
   returning * into v_week;
 end if;
 while v_week.ends_at<=p_now loop
   update public.weekly_progress set finalized=true,finalized_at=coalesce(finalized_at,p_now),updated_at=p_now
   where id=v_week.id returning * into v_week;
   v_date := v_week.week_start_date+7;
   v_zone := coalesce(v_change.next_weekly_timezone,v_week.timezone);
   v_goal := coalesce(v_change.next_weekly_goal,v_week.weekly_goal);
   -- Contiguous UTC intervals. The END uses nominal next-Monday label + 7,
   -- not the nearest Monday after the instant (which could create a 6-hour week).
   insert into public.weekly_progress(user_id,week_start_date,timezone,starts_at,ends_at,weekly_goal,goal_confirmed)
   values(p_user,v_date,v_zone,v_week.ends_at,(v_date+7)::timestamp at time zone v_zone,v_goal,
     v_profile.weekly_goal_confirmed_at is not null) returning * into v_week;
   update public.profiles set current_weekly_goal=v_goal,weekly_goal=v_goal,
     weekly_timezone=v_zone,timezone=v_zone where id=p_user returning * into v_profile;
   delete from public.weekly_goal_changes where user_id=p_user;
   v_change := null;
 end loop;
 return v_week;
end; $$;

-- Multi-person summaries acquire all profile locks in one canonical order.
-- This avoids A->B / B->A deadlocks between simultaneous crew refreshes.
create function public.lock_weekly_people() returns uuid[] language plpgsql security definer set search_path='' as $$
declare v_user uuid; v_people uuid[]:='{}';
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 -- NO KEY UPDATE still serializes our mutations, but permits ordinary FK
 -- KEY SHARE checks from activity/notification inserts in other transactions.
 for v_user in select p.id from public.profiles p where p.id=auth.uid() or public.are_friends(p.id,auth.uid()) order by p.id for no key update loop
   v_people:=array_append(v_people,v_user);
 end loop;
 return v_people;
end; $$;

-- Preserve completion's owner/live guard, distance and final pause calculation.
-- Capture the completion clock AFTER locks, so a request crossing Monday while
-- waiting cannot insert an old timestamp into an already finalized period.
create or replace function public.complete_activity(p_activity_id uuid,p_distance_meters integer default null)
returns public.activities language plpgsql security definer set search_path='' as $$
declare v_activity public.activities; v_now timestamptz;
begin
 perform 1 from public.profiles where id=auth.uid() for no key update;
 select * into v_activity from public.activities where id=p_activity_id and user_id=auth.uid() and status='live' for update;
 if v_activity.id is null then raise exception 'activity_not_live'; end if;
 v_now:=clock_timestamp();
 update public.activities
 set status='completed',ended_at=v_now,distance_meters=p_distance_meters,updated_at=v_now,
     paused_seconds=paused_seconds+case when paused_at is null then 0
       else greatest(0,floor(extract(epoch from(v_now-paused_at)))::integer) end,
     paused_at=null
 where id=v_activity.id returning * into v_activity;
 return v_activity;
end; $$;

create function public.award_weekly_flame(p_week uuid,p_earned_at timestamptz,p_notify boolean default true)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress;
begin
 update public.weekly_progress set flame_earned=true,flame_earned_at=p_earned_at,updated_at=now()
 where id=p_week and not finalized and goal_confirmed and not flame_earned and completed_workouts>=weekly_goal
 returning * into v_week;
 if v_week.id is null then return false; end if;
 if p_notify and coalesce((select weekly_goal from public.notification_preferences where user_id=v_week.user_id),true) then
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_week.user_id,v_week.user_id,'weekly_goal','Deine Wochenflamme gehört dir 🔥',
     v_week.completed_workouts||' / '||v_week.weekly_goal||' Trainings. Wochenziel geschafft.',jsonb_build_object('week_id',v_week.id))
   on conflict do nothing;
 end if;
 return true;
end; $$;

create function public.credit_weekly_activity(p_activity uuid,p_notify boolean default true)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_activity public.activities; v_week public.weekly_progress; v_seconds integer; v_eligible boolean; v_reason text;
begin
 select * into v_activity from public.activities where id=p_activity and status='completed';
 if v_activity.id is null or v_activity.ended_at is null then return false; end if;
 if exists(select 1 from public.weekly_activity_credits where activity_id=p_activity) then return false; end if;
 v_week := public.ensure_weekly_period(v_activity.user_id,v_activity.ended_at);
 v_seconds := greatest(0,floor(extract(epoch from(v_activity.ended_at-v_activity.started_at)))::integer-coalesce(v_activity.paused_seconds,0));
 v_eligible := v_seconds>=60 and not v_week.finalized and v_activity.ended_at>=v_week.starts_at and v_activity.ended_at<v_week.ends_at;
 v_reason := case when v_activity.ended_at<v_week.starts_at or v_week.finalized then 'outside_open_period'
   when v_seconds<60 then 'active_duration_under_60_seconds' else 'completed_workout' end;
 insert into public.weekly_activity_credits(activity_id,user_id,week_id,completed_at,active_seconds,eligible,rule_version,reason)
 values(v_activity.id,v_activity.user_id,v_week.id,v_activity.ended_at,v_seconds,v_eligible,1,v_reason) on conflict do nothing;
 if not found then return false; end if;
 if v_eligible then
   update public.weekly_progress set completed_workouts=(select count(*) from public.weekly_activity_credits where week_id=v_week.id and eligible),updated_at=now()
   where id=v_week.id;
   perform public.award_weekly_flame(v_week.id,v_activity.ended_at,p_notify);
 end if;
 return v_eligible;
end; $$;
create function public.on_activity_weekly_credit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='completed' then perform public.credit_weekly_activity(new.id); end if;
 return new;
end; $$;
create trigger activities_weekly_credit after insert or update of status,ended_at on public.activities
for each row execute function public.on_activity_weekly_credit();

create function public.can_read_weekly_progress(p_week uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.weekly_progress w where w.id=p_week and
   (w.user_id=auth.uid() or (w.goal_confirmed and public.are_friends(w.user_id,auth.uid()))));
$$;
create function public.weekly_period_document(p_week uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(w)||jsonb_build_object(
   'reaction_counts',coalesce((select jsonb_agg(jsonb_build_object('reaction',r.reaction,'count',r.n) order by r.reaction)
     from (select reaction,count(*) n from public.weekly_flame_reactions where week_id=w.id and public.are_friends(w.user_id,user_id) group by reaction) r),'[]'::jsonb),
   'my_reaction',(select reaction from public.weekly_flame_reactions where week_id=w.id and user_id=auth.uid())
 ) from public.weekly_progress w where w.id=p_week;
$$;
create function public.weekly_state_document(p_user uuid,p_now timestamptz,p_history boolean default true)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_week public.weekly_progress; v_profile public.profiles; v_change public.weekly_goal_changes; v_row record; v_streak integer:=0; v_best integer:=0; v_previous date;
begin
 select * into v_profile from public.profiles where id=p_user;
 select * into v_change from public.weekly_goal_changes where user_id=p_user;
 select * into v_week from public.weekly_progress where user_id=p_user order by week_start_date desc limit 1;
 for v_row in select * from public.weekly_progress where user_id=p_user and finalized order by week_start_date loop
   if v_previous is not null and v_row.week_start_date<>v_previous+7 then v_streak:=0; end if;
   if v_row.flame_earned then v_streak:=v_streak+1; v_best:=greatest(v_best,v_streak); else v_streak:=0; end if;
   v_previous:=v_row.week_start_date;
 end loop;
 if v_previous is null or v_previous<>v_week.week_start_date-7 then v_streak:=0; end if;
 return jsonb_build_object('user_id',p_user,'server_now',p_now,
   'goal_confirmed',v_profile.weekly_goal_confirmed_at is not null,
   'suggested_weekly_goal',v_profile.current_weekly_goal,
   'next_weekly_goal',case when p_user=auth.uid() then v_change.next_weekly_goal else null end,
   'next_timezone',case when p_user=auth.uid() then v_change.next_weekly_timezone else null end,
   'current_week',case when v_week.goal_confirmed then public.weekly_period_document(v_week.id) else null end,
   'current_streak',v_streak,'best_streak',v_best,
   'history',case when p_history then coalesce((select jsonb_agg(public.weekly_period_document(h.id) order by h.week_start_date desc)
     from (select id,week_start_date from public.weekly_progress where user_id=p_user and finalized and goal_confirmed order by week_start_date desc limit 52) h),'[]'::jsonb) else '[]'::jsonb end);
end; $$;

create function public.get_weekly_state(p_user uuid default null,p_timezone text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=coalesce(p_user,auth.uid()); v_now timestamptz; v_week public.weekly_progress;
begin
 -- Authorization happens BEFORE finalization or timezone writes.
 if auth.uid() is null or (v_user<>auth.uid() and not public.are_friends(v_user,auth.uid())) then raise exception 'forbidden'; end if;
 perform 1 from public.profiles where id=v_user for no key update;
 if v_user<>auth.uid() and not public.are_friends(v_user,auth.uid()) then raise exception 'forbidden'; end if;
 v_now:=clock_timestamp();
 if p_timezone is not null then
   if v_user<>auth.uid() then raise exception 'forbidden'; end if;
   if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'invalid_timezone'; end if;
   if not exists(select 1 from public.weekly_progress where user_id=v_user) then
     update public.profiles set weekly_timezone=p_timezone,timezone=p_timezone where id=v_user;
   end if;
 end if;
 v_week:=public.ensure_weekly_period(v_user,v_now);
 if p_timezone is not null then
   insert into public.weekly_goal_changes(user_id,next_weekly_timezone)
   values(v_user,case when p_timezone=v_week.timezone then null else p_timezone end)
   on conflict(user_id) do update set next_weekly_timezone=excluded.next_weekly_timezone;
 end if;
 return public.weekly_state_document(v_user,v_now);
end; $$;
create function public.get_friends_weekly_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_friend uuid; v_people uuid[]; v_now timestamptz; v_result jsonb:='[]'::jsonb;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 v_people:=public.lock_weekly_people();
 v_now:=clock_timestamp();
 for v_friend in select id from unnest(v_people)id where public.are_friends(id,auth.uid()) order by id loop
   perform public.ensure_weekly_period(v_friend,v_now);
   v_result:=v_result||jsonb_build_array(public.weekly_state_document(v_friend,v_now,false));
 end loop;
 return v_result;
end; $$;
create function public.confirm_weekly_goal(p_goal integer,p_timezone text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles; v_week public.weekly_progress; v_now timestamptz;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if p_goal is null or p_goal not between 3 and 7 then raise exception 'invalid_weekly_goal'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'invalid_timezone'; end if;
 select * into v_profile from public.profiles where id=auth.uid() for no key update;
 if v_profile.id is null then raise exception 'profile_not_found'; end if;
 -- Resolve a due pending change before deciding whether reconfirmation matches.
 perform public.get_weekly_state(auth.uid(),p_timezone);
 select * into v_profile from public.profiles where id=auth.uid();
 if v_profile.weekly_goal_confirmed_at is not null then
   if v_profile.current_weekly_goal<>p_goal then raise exception 'weekly_goal_already_confirmed'; end if;
   return public.get_weekly_state(auth.uid(),p_timezone);
 end if;
 v_now:=clock_timestamp();
 v_week:=public.ensure_weekly_period(auth.uid(),v_now);
 update public.profiles set current_weekly_goal=p_goal,weekly_goal=p_goal,weekly_goal_confirmed_at=v_now where id=auth.uid();
 update public.weekly_progress set weekly_goal=p_goal,goal_confirmed=true,updated_at=v_now where id=v_week.id;
 perform public.award_weekly_flame(v_week.id,v_now);
 return public.weekly_state_document(auth.uid(),v_now);
end; $$;
create function public.set_next_weekly_goal(p_goal integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress; v_now timestamptz;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if p_goal is null or p_goal not between 3 and 7 then raise exception 'invalid_weekly_goal'; end if;
 perform 1 from public.profiles where id=auth.uid() for no key update;
 v_now:=clock_timestamp();
 v_week:=public.ensure_weekly_period(auth.uid(),v_now);
 if not v_week.goal_confirmed then raise exception 'weekly_goal_not_confirmed'; end if;
 insert into public.weekly_goal_changes(user_id,next_weekly_goal)
 values(auth.uid(),case when p_goal=v_week.weekly_goal then null else p_goal end)
 on conflict(user_id) do update set next_weekly_goal=excluded.next_weekly_goal;
 return public.weekly_state_document(auth.uid(),v_now);
end; $$;
create function public.claim_flame_celebration(p_week uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.weekly_progress where id=p_week and user_id=auth.uid() and flame_earned) then raise exception 'forbidden'; end if;
 insert into public.weekly_flame_celebrations(week_id,user_id) values(p_week,auth.uid()) on conflict do nothing;
 return found;
end; $$;
create function public.set_flame_reaction(p_week uuid,p_reaction text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress; v_previous text;
begin
 select * into v_week from public.weekly_progress where id=p_week and flame_earned for update;
 if v_week.id is null or not public.are_friends(v_week.user_id,auth.uid()) then raise exception 'forbidden'; end if;
 if p_reaction is not null and p_reaction not in ('🔥','💪','👏') then raise exception 'invalid_reaction'; end if;
 select reaction into v_previous from public.weekly_flame_reactions where week_id=p_week and user_id=auth.uid();
 if p_reaction is null then
   delete from public.weekly_flame_reactions where week_id=p_week and user_id=auth.uid(); return true;
 end if;
 if v_previous=p_reaction then return true; end if;
 insert into public.weekly_flame_reactions(week_id,user_id,reaction) values(p_week,auth.uid(),p_reaction)
 on conflict(week_id,user_id) do update set reaction=excluded.reaction,updated_at=now();
 if coalesce((select reactions from public.notification_preferences where user_id=v_week.user_id),true) then
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_week.user_id,auth.uid(),'flame_reaction','Deine Crew feiert deine Flamme',p_reaction,jsonb_build_object('week_id',p_week)) on conflict do nothing;
 end if;
 return true;
end; $$;

-- Keep legacy clients profile-compatible but ignore their p_weekly_goal input.
create or replace function public.upsert_profile(p_username citext,p_display_name text,p_avatar_path text default null,p_birth_year smallint default null,p_city text default null,p_bio text default null,p_sports public.sport_kind[] default '{}',p_weekly_goal smallint default 4,p_activity_visibility text default 'friends')
returns public.profiles language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if lower(p_username::text) in ('admin','administrator','fyrup','support','help','system','moderator','root') then raise exception 'reserved_username'; end if;
 insert into public.profiles(id,username,display_name,avatar_path,birth_year,city,bio,sports,activity_visibility)
 values(auth.uid(),lower(p_username::text),p_display_name,p_avatar_path,p_birth_year,p_city,p_bio,p_sports,p_activity_visibility)
 on conflict(id) do update set username=excluded.username,display_name=excluded.display_name,avatar_path=excluded.avatar_path,
 birth_year=excluded.birth_year,city=excluded.city,bio=excluded.bio,sports=excluded.sports,activity_visibility=excluded.activity_visibility,updated_at=now()
 returning * into v_profile;
 return v_profile;
end; $$;
revoke insert,update on public.profiles from authenticated,anon;
grant insert(id,username,display_name,avatar_path,birth_year,city,bio,sports,activity_visibility),
 update(username,display_name,avatar_path,birth_year,city,bio,sports,activity_visibility) on public.profiles to authenticated;

alter table public.weekly_progress enable row level security;
alter table public.weekly_activity_credits enable row level security;
alter table public.weekly_flame_reactions enable row level security;
alter table public.weekly_flame_celebrations enable row level security;
alter table public.weekly_goal_changes enable row level security;
create policy weekly_changes_private on public.weekly_goal_changes for select to authenticated using(user_id=auth.uid());
create policy weekly_progress_read on public.weekly_progress for select to authenticated using(public.can_read_weekly_progress(id));
create policy weekly_credits_private on public.weekly_activity_credits for select to authenticated using(user_id=auth.uid());
create policy weekly_reactions_read on public.weekly_flame_reactions for select to authenticated using(public.can_read_weekly_progress(week_id)
 and exists(select 1 from public.weekly_progress w where w.id=week_id and public.are_friends(w.user_id,weekly_flame_reactions.user_id)));
create policy weekly_celebrations_private on public.weekly_flame_celebrations for select to authenticated using(user_id=auth.uid());
revoke all on public.weekly_progress,public.weekly_activity_credits,public.weekly_flame_reactions,public.weekly_flame_celebrations,public.weekly_goal_changes from authenticated,anon;
grant select on public.weekly_progress,public.weekly_activity_credits,public.weekly_flame_reactions,public.weekly_flame_celebrations,public.weekly_goal_changes to authenticated;
revoke all on function public.ensure_weekly_period(uuid,timestamptz),public.award_weekly_flame(uuid,timestamptz,boolean),
 public.credit_weekly_activity(uuid,boolean),public.on_activity_weekly_credit(),public.weekly_period_document(uuid),public.weekly_state_document(uuid,timestamptz,boolean),public.lock_weekly_people() from public,anon,authenticated;
revoke all on function public.can_read_weekly_progress(uuid),public.get_weekly_state(uuid,text),public.get_friends_weekly_state(),
 public.confirm_weekly_goal(integer,text),public.set_next_weekly_goal(integer),public.claim_flame_celebration(uuid),public.set_flame_reaction(uuid,text) from public,anon;
grant execute on function public.can_read_weekly_progress(uuid),public.get_weekly_state(uuid,text),public.get_friends_weekly_state(),
 public.confirm_weekly_goal(integer,text),public.set_next_weekly_goal(integer),public.claim_flame_celebration(uuid),public.set_flame_reaction(uuid,text) to authenticated;

-- Initialize only the current migration week from actual existing activities.
-- Do not invent historical goals/flames, or send notifications for backfill.
do $$ declare v_user uuid; v_activity uuid;
begin
 for v_user in select id from public.profiles order by id loop
   perform public.ensure_weekly_period(v_user,now());
   for v_activity in select a.id from public.activities a join public.weekly_progress w on w.user_id=a.user_id and not w.finalized
     where a.user_id=v_user and a.status='completed' and a.ended_at>=w.starts_at and a.ended_at<w.ends_at order by a.ended_at,a.id loop
     perform public.credit_weekly_activity(v_activity,false);
   end loop;
 end loop;
end $$;

-- Existing surfaces must use the same credited weekly count as the new cards.
alter function public.today_feed(text) rename to today_feed_before_weekly_flames;
revoke all on function public.today_feed_before_weekly_flames(text) from public,anon,authenticated;
create function public.today_feed(p_timezone text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_feed jsonb; v_member jsonb; v_state jsonb; v_people uuid[]; v_user uuid; v_crew jsonb:='[]'::jsonb;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 v_people:=public.lock_weekly_people();
 perform public.get_weekly_state(auth.uid(),p_timezone);
 v_feed:=public.today_feed_before_weekly_flames(p_timezone);
 for v_member in select value from jsonb_array_elements(v_feed->'crew') loop
   v_user:=(v_member->'profile'->>'id')::uuid;
   -- Newly accepted friends appear next refresh, avoiding a late unordered lock.
   if not (v_user=any(v_people)) or not public.are_friends(v_user,auth.uid()) then continue; end if;
   v_state:=public.get_weekly_state(v_user,null);
   v_member:=jsonb_set(v_member,'{weekly_count}',to_jsonb(coalesce((v_state->'current_week'->>'completed_workouts')::integer,0)));
   v_member:=jsonb_set(v_member,'{profile,weekly_goal}',to_jsonb((v_state->>'suggested_weekly_goal')::integer));
   v_crew:=v_crew||jsonb_build_array(v_member);
 end loop;
 return jsonb_set(v_feed,'{crew}',v_crew);
end; $$;
create or replace function public.goal_summary(p_timezone text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_state jsonb; v_friend jsonb; v_people uuid[]; v_user uuid; v_count integer; v_goal integer; v_crew integer; v_target integer; v_month integer;
begin
 v_people:=public.lock_weekly_people();
 v_state:=public.get_weekly_state(auth.uid(),p_timezone);
 v_count:=coalesce((v_state->'current_week'->>'completed_workouts')::integer,0);
 v_goal:=(v_state->>'suggested_weekly_goal')::integer;
 v_crew:=v_count; v_target:=v_goal;
 for v_user in select id from unnest(v_people)id where public.are_friends(id,auth.uid()) order by id loop
   v_friend:=public.get_weekly_state(v_user,null);
   v_crew:=v_crew+coalesce((v_friend->'current_week'->>'completed_workouts')::integer,0);
   v_target:=v_target+(v_friend->>'suggested_weekly_goal')::integer;
 end loop;
 select count(*) into v_month from public.activities where user_id=auth.uid() and status='completed'
   and ended_at>=date_trunc('month',now() at time zone p_timezone) at time zone p_timezone;
 return jsonb_build_object('weekly_count',v_count,'weekly_goal',v_goal,'streak',(v_state->>'current_streak')::integer,
   'month_count',v_month,'crew_count',v_crew,'crew_target',v_target);
end; $$;
revoke all on function public.today_feed(text),public.goal_summary(text) from public,anon;
grant execute on function public.today_feed(text),public.goal_summary(text) to authenticated;

commit;
