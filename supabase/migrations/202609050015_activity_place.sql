-- Optional, human-readable location for both spontaneous and planned activities.
-- Exact map coordinates stay on the device and are never stored here.
begin;

alter table public.activities add column if not exists place_name text;

alter table public.activities drop constraint if exists activities_place_name_length;
alter table public.activities add constraint activities_place_name_length
  check (place_name is null or char_length(place_name) between 1 and 120);

update public.activities a
   set place_name=s.place_name
  from public.planned_sessions s
 where a.planned_session_id=s.id and a.place_name is null and s.place_name is not null;

create function public.start_activity(
  p_sport public.sport_kind,
  p_subtype text,
  p_linked_activity_id uuid,
  p_planned_session_id uuid,
  p_place_name text
) returns public.activities language plpgsql security definer set search_path='' as $$
declare
  v public.activities;
  v_place text := nullif(btrim(p_place_name), '');
begin
  if v_place is not null and char_length(v_place) > 120 then raise exception 'invalid_place'; end if;
  if p_linked_activity_id is not null and not exists(
    select 1 from public.activities a join public.profiles p on p.id=a.user_id
    where a.id=p_linked_activity_id and a.status='live' and p.activity_visibility='friends'
      and public.are_friends(a.user_id,auth.uid())
  ) then raise exception 'invalid_link'; end if;

  if p_planned_session_id is not null then
    update public.activities a
       set status='live', started_at=now(), updated_at=now(),
           place_name=coalesce(v_place,a.place_name,(
             select s.place_name from public.planned_sessions s where s.id=p_planned_session_id
           ))
     where a.user_id=auth.uid() and a.planned_session_id=p_planned_session_id
       and a.status in ('planned','ready')
     returning * into v;
  end if;

  if v.id is null then
    insert into public.activities(user_id,sport,subtype,status,started_at,linked_activity_id,planned_session_id,place_name)
    values(auth.uid(),p_sport,p_subtype,'live',now(),p_linked_activity_id,p_planned_session_id,
      coalesce(v_place,(select s.place_name from public.planned_sessions s where s.id=p_planned_session_id)))
    returning * into v;
  end if;

  if p_planned_session_id is not null and exists(
    select 1 from public.planned_sessions where id=p_planned_session_id and host_id=auth.uid()
  ) then
    update public.planned_sessions set status='live',updated_at=now() where id=p_planned_session_id;
    insert into public.notifications(recipient_id,actor_id,type,title,body,data)
      select i.invitee_id,auth.uid(),'session_started','Session ist LIVE 🔥','Du kannst jetzt ebenfalls loslegen.',
             jsonb_build_object('session_id',p_planned_session_id)
      from public.session_invites i where i.session_id=p_planned_session_id and i.status='accepted';
  end if;

  if p_linked_activity_id is not null then
    insert into public.notifications(recipient_id,actor_id,type,title,body,data)
      select a.user_id,auth.uid(),'joined_live','Jemand zieht mit dir durch 👊','Deine Crew ist jetzt ebenfalls LIVE.',
             jsonb_build_object('activity_id',v.id)
      from public.activities a where a.id=p_linked_activity_id;
  end if;
  return v;
exception when unique_violation then raise exception 'already_live' using errcode='23505';
end; $$;

create function public.start_workout(
  p_plan uuid,
  p_linked uuid,
  p_session uuid,
  p_place_name text
) returns public.activities language plpgsql security definer set search_path='' as $$
declare v_plan public.workout_plans; v_activity public.activities;
begin
  if not public.can_read_workout_plan(p_plan) then raise exception 'forbidden'; end if;
  select * into v_plan from public.workout_plans where id=p_plan and not is_archived for share;
  if v_plan.id is null then raise exception 'plan_not_available'; end if;
  if p_session is not null and not exists(
    select 1 from public.planned_sessions s where s.id=p_session and s.workout_plan_id=p_plan
      and s.status in ('planned','ready','live') and not public.is_blocked(s.host_id,auth.uid())
      and (s.host_id=auth.uid() or exists(
        select 1 from public.session_invites i where i.session_id=s.id
          and i.invitee_id=auth.uid() and i.status='accepted'
      ))
  ) then raise exception 'invalid_session'; end if;
  if p_linked is not null and not exists(
    select 1 from public.activities where id=p_linked and workout_plan_id=p_plan
  ) then raise exception 'invalid_link'; end if;

  v_activity := public.start_activity('gym',v_plan.name,p_linked,p_session,p_place_name);
  update public.activities
     set workout_plan_id=p_plan,
         exercise_count=(select count(*) from public.workout_plan_exercises where workout_plan_id=p_plan)
   where id=v_activity.id returning * into v_activity;
  return v_activity;
end; $$;

revoke all on function public.start_activity(public.sport_kind,text,uuid,uuid,text),
  public.start_workout(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.start_activity(public.sport_kind,text,uuid,uuid,text),
  public.start_workout(uuid,uuid,uuid,text) to authenticated;
commit;
