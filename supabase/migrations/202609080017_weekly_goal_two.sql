begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';

-- Expand the accepted range. Existing targets, credits and rewards do not change.
alter table public.profiles drop constraint profiles_current_weekly_goal_check,
 add constraint profiles_current_weekly_goal_check check (current_weekly_goal between 2 and 7);
alter table public.weekly_goal_changes drop constraint weekly_goal_changes_next_weekly_goal_check,
 add constraint weekly_goal_changes_next_weekly_goal_check check (next_weekly_goal between 2 and 7);
alter table public.weekly_progress drop constraint weekly_progress_weekly_goal_check,
 add constraint weekly_progress_weekly_goal_check check (weekly_goal between 2 and 7);
alter table public.weekly_commitments drop constraint weekly_commitments_weekly_goal_check,
 add constraint weekly_commitments_weekly_goal_check check (weekly_goal between 2 and 7);

create or replace function public.confirm_weekly_goal(p_goal integer,p_timezone text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles; v_week public.weekly_progress; v_now timestamptz;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if p_goal is null or p_goal not between 2 and 7 then raise exception 'invalid_weekly_goal'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'invalid_timezone'; end if;
 select * into v_profile from public.profiles where id=auth.uid() for no key update;
 if v_profile.id is null then raise exception 'profile_not_found'; end if;
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

create or replace function public.set_next_weekly_goal(p_goal integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_week public.weekly_progress; v_now timestamptz;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if p_goal is null or p_goal not between 2 and 7 then raise exception 'invalid_weekly_goal'; end if;
 perform 1 from public.profiles where id=auth.uid() for no key update;
 v_now:=clock_timestamp();
 v_week:=public.ensure_weekly_period(auth.uid(),v_now);
 if not v_week.goal_confirmed then raise exception 'weekly_goal_not_confirmed'; end if;
 insert into public.weekly_goal_changes(user_id,next_weekly_goal)
 values(auth.uid(),case when p_goal=v_week.weekly_goal then null else p_goal end)
 on conflict(user_id) do update set next_weekly_goal=excluded.next_weekly_goal;
 return public.weekly_state_document(auth.uid(),v_now);
end; $$;

notify pgrst, 'reload schema';
commit;
