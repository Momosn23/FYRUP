begin;

create table public.weekly_commitments (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 week_id uuid not null unique references public.weekly_progress(id) on delete cascade,
 week_start_date date not null,
 weekly_goal integer not null check(weekly_goal between 3 and 7),
 called_at timestamptz not null,
 achieved boolean not null default false,achieved_at timestamptz,
 finalized boolean not null default false,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(user_id,week_start_date),
 check(achieved=(achieved_at is not null)),
 check(achieved_at is null or achieved_at>=called_at)
);
create table public.weekly_shot_reactions (
 commitment_id uuid not null references public.weekly_commitments(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 reaction text not null check(reaction in ('🔥','🎯','💪')),
 updated_at timestamptz not null default now(),primary key(commitment_id,user_id)
);
create unique index weekly_shot_notifications_once on public.notifications(recipient_id,type,(data->>'commitment_id'))
 where type in ('shot_called','shot_achieved') and data ? 'commitment_id';
create unique index weekly_shot_reaction_notification_once on public.notifications(recipient_id,actor_id,(data->>'commitment_id'))
 where type='shot_reaction' and data ? 'commitment_id' and actor_id is not null;

-- A commitment is a frozen declaration, never a second source of goal truth.
-- Updates can only mirror the already-authoritative week's achieved/finalized state.
create function public.guard_weekly_commitment() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress;
begin
 select * into v_week from public.weekly_progress where id=new.week_id;
 if v_week.id is null or not v_week.goal_confirmed or v_week.user_id<>new.user_id
   or v_week.week_start_date<>new.week_start_date or v_week.weekly_goal<>new.weekly_goal
   or new.called_at<v_week.starts_at or new.called_at>=v_week.ends_at
   or new.achieved is distinct from v_week.flame_earned
   or new.achieved_at is distinct from v_week.flame_earned_at
   or new.finalized is distinct from v_week.finalized then raise exception 'invalid_weekly_commitment'; end if;
 if tg_op='UPDATE' and (new.id<>old.id or new.user_id<>old.user_id or new.week_id<>old.week_id
   or new.week_start_date<>old.week_start_date or new.weekly_goal<>old.weekly_goal or new.called_at<>old.called_at) then
   raise exception 'weekly_commitment_immutable';
 end if;
 return new;
end; $$;
create trigger weekly_commitment_guard before insert or update on public.weekly_commitments for each row execute function public.guard_weekly_commitment();

create function public.weekly_commitment_document(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(c)||jsonb_build_object(
   'reaction_counts',coalesce((select jsonb_agg(jsonb_build_object('reaction',r.reaction,'count',r.n) order by r.reaction)
     from (select s.reaction,count(*)n from public.weekly_shot_reactions s where s.commitment_id=c.id
       and public.are_friends(c.user_id,s.user_id) group by s.reaction)r),'[]'::jsonb),
   'my_reaction',(select reaction from public.weekly_shot_reactions where commitment_id=c.id and user_id=auth.uid())
 ) from public.weekly_commitments c where c.id=p_id;
$$;

-- Optional friend notifications use each recipient's existing weekly-goal switch.
-- The owner's ordinary Flame push remains owned by 005, so there is no second
-- self-success push competing with the combined CALLED IT + Flame experience.
create function public.notify_weekly_commitment(p_id uuid,p_type text) returns void
language plpgsql security definer set search_path='' as $$
declare v_commitment public.weekly_commitments; v_friend uuid;
begin
 if p_type not in ('shot_called','shot_achieved') then raise exception 'invalid_notification_type'; end if;
 select * into v_commitment from public.weekly_commitments where id=p_id;
 if v_commitment.id is null then return; end if;
 for v_friend in select p.id from public.profiles p where public.are_friends(p.id,v_commitment.user_id)
   and coalesce((select weekly_goal from public.notification_preferences where user_id=p.id),true)
   order by p.id for key share loop
   -- Recheck access after a possible lock wait; removed friends get no new alert.
   if not public.are_friends(v_friend,v_commitment.user_id) then continue; end if;
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_friend,v_commitment.user_id,p_type,
     case when p_type='shot_called' then 'Deine Crew hat ihr Ziel gecallt 🎯' else 'CALLED IT. 🎯🔥' end,
     case when p_type='shot_called' then v_commitment.weekly_goal||' Trainings diese Woche.' else 'Wochenziel erreicht.' end,
     jsonb_build_object('commitment_id',p_id,'week_id',v_commitment.week_id,'user_id',v_commitment.user_id)) on conflict do nothing;
 end loop;
end; $$;

create function public.sync_weekly_commitment() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_commitment public.weekly_commitments; v_just_achieved boolean;
begin
 select * into v_commitment from public.weekly_commitments where week_id=new.id for update;
 if v_commitment.id is null then return new; end if;
 v_just_achieved:=new.flame_earned and not v_commitment.achieved;
 update public.weekly_commitments set achieved=new.flame_earned,achieved_at=new.flame_earned_at,finalized=new.finalized,updated_at=clock_timestamp()
 where id=v_commitment.id;
 if v_just_achieved then perform public.notify_weekly_commitment(v_commitment.id,'shot_achieved'); end if;
 return new;
end; $$;
create trigger weekly_progress_sync_commitment after update of flame_earned,finalized on public.weekly_progress
for each row execute function public.sync_weekly_commitment();

-- The displayed week is a consent precondition, never an override of goal/time.
-- Do not leave a legacy nullary overload that can bypass this boundary check.
drop function if exists public.call_my_shot();
create function public.call_my_shot(p_expected_week uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress; v_now timestamptz; v_id uuid;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 perform 1 from public.profiles where id=auth.uid() for no key update;
 v_now:=clock_timestamp();
 v_week:=public.ensure_weekly_period(auth.uid(),v_now);
 if not v_week.goal_confirmed then raise exception 'weekly_goal_not_confirmed'; end if;
 if p_expected_week is distinct from v_week.id then raise exception 'weekly_week_changed'; end if;
 if exists(select 1 from public.weekly_commitments where week_id=v_week.id) then raise exception 'weekly_commitment_exists'; end if;
 if v_week.flame_earned or v_week.completed_workouts>=v_week.weekly_goal then raise exception 'weekly_goal_already_reached'; end if;
 insert into public.weekly_commitments(user_id,week_id,week_start_date,weekly_goal,called_at)
 values(auth.uid(),v_week.id,v_week.week_start_date,v_week.weekly_goal,v_now) returning id into v_id;
 perform public.notify_weekly_commitment(v_id,'shot_called');
 return public.weekly_commitment_document(v_id);
end; $$;

create function public.set_shot_reaction(p_commitment uuid,p_reaction text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_commitment public.weekly_commitments; v_previous text;
begin
 select * into v_commitment from public.weekly_commitments where id=p_commitment for update;
 if v_commitment.id is null or not public.are_friends(v_commitment.user_id,auth.uid()) then raise exception 'forbidden'; end if;
 if p_reaction is not null and p_reaction not in ('🔥','🎯','💪') then raise exception 'invalid_reaction'; end if;
 select reaction into v_previous from public.weekly_shot_reactions where commitment_id=p_commitment and user_id=auth.uid();
 if p_reaction is null then
   delete from public.weekly_shot_reactions where commitment_id=p_commitment and user_id=auth.uid(); return true;
 end if;
 if v_previous=p_reaction then return true; end if;
 insert into public.weekly_shot_reactions(commitment_id,user_id,reaction) values(p_commitment,auth.uid(),p_reaction)
 on conflict(commitment_id,user_id) do update set reaction=excluded.reaction,updated_at=clock_timestamp();
 if coalesce((select reactions from public.notification_preferences where user_id=v_commitment.user_id),true) then
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_commitment.user_id,auth.uid(),'shot_reaction','Deine Crew glaubt an dich',p_reaction,
     jsonb_build_object('commitment_id',p_commitment,'week_id',v_commitment.week_id,'user_id',v_commitment.user_id)) on conflict do nothing;
 end if;
 return true;
end; $$;

-- Keep the exact existing Flame reaction/period payload; add a nullable commitment.
create or replace function public.weekly_period_document(p_week uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(w)||jsonb_build_object(
   'reaction_counts',coalesce((select jsonb_agg(jsonb_build_object('reaction',r.reaction,'count',r.n) order by r.reaction)
     from (select reaction,count(*) n from public.weekly_flame_reactions where week_id=w.id and public.are_friends(w.user_id,user_id) group by reaction) r),'[]'::jsonb),
   'my_reaction',(select reaction from public.weekly_flame_reactions where week_id=w.id and user_id=auth.uid()),
   'commitment',public.weekly_commitment_document((select id from public.weekly_commitments where week_id=w.id))
 ) from public.weekly_progress w where w.id=p_week;
$$;

alter table public.weekly_commitments enable row level security;
alter table public.weekly_shot_reactions enable row level security;
create policy weekly_commitments_read on public.weekly_commitments for select to authenticated using(public.can_read_weekly_progress(week_id));
create policy weekly_shot_reactions_read on public.weekly_shot_reactions for select to authenticated using(exists(
 select 1 from public.weekly_commitments c where c.id=commitment_id and public.can_read_weekly_progress(c.week_id) and public.are_friends(c.user_id,weekly_shot_reactions.user_id)));
revoke all on public.weekly_commitments,public.weekly_shot_reactions from public,anon,authenticated;
grant select on public.weekly_commitments,public.weekly_shot_reactions to authenticated;
revoke all on function public.guard_weekly_commitment(),public.weekly_commitment_document(uuid),public.notify_weekly_commitment(uuid,text),public.sync_weekly_commitment(),public.weekly_period_document(uuid) from public,anon,authenticated;
revoke all on function public.call_my_shot(uuid),public.set_shot_reaction(uuid,text) from public,anon;
grant execute on function public.call_my_shot(uuid),public.set_shot_reaction(uuid,text) to authenticated;

commit;
