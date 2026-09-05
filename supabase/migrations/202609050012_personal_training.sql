begin;

create table public.personal_training_routines (
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 revision integer not null default 1 check(revision > 0),
 goals jsonb not null default '[]' check(jsonb_typeof(goals)='array' and jsonb_array_length(goals)<=10),
 updated_at timestamptz not null default now()
);
create table public.personal_workout_feedback (
 activity_id uuid primary key references public.activities(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 revision integer not null default 1 check(revision>0),
 exercises jsonb not null default '[]' check(jsonb_typeof(exercises)='array' and jsonb_array_length(exercises)<=40),
 feeling text check(feeling in ('great','okay','tough')),
 note text check(char_length(note)<=500),
 updated_at timestamptz not null default now()
);
alter table public.personal_training_routines enable row level security;
alter table public.personal_workout_feedback enable row level security;
create policy personal_routine_owner on public.personal_training_routines for select to authenticated using(owner_id=auth.uid());
create policy personal_feedback_owner on public.personal_workout_feedback for select to authenticated using(owner_id=auth.uid());
revoke all on public.personal_training_routines,public.personal_workout_feedback from public,anon,authenticated;
grant select on public.personal_training_routines,public.personal_workout_feedback to authenticated;

create function public.get_training_routine() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 return coalesce((select jsonb_build_object('revision',revision,'goals',goals) from public.personal_training_routines where owner_id=auth.uid()),jsonb_build_object('revision',0,'goals','[]'::jsonb));
end; $$;

create function public.save_training_routine(p_routine jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_goal jsonb; v_days jsonb; v_seen text[]:='{}'; v_revision integer; v_current integer;
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_routine) is distinct from 'object' or jsonb_typeof(p_routine->'goals') is distinct from 'array'
 or jsonb_typeof(p_routine->'revision') is distinct from 'number' or coalesce(p_routine->>'revision','') !~ '^[0-9]{1,9}$' then raise exception 'invalid_routine'; end if;
 if jsonb_array_length(p_routine->'goals')>10 then raise exception 'invalid_routine'; end if;
 for v_goal in select value from jsonb_array_elements(p_routine->'goals') loop
  if jsonb_typeof(v_goal) is distinct from 'object' or coalesce(v_goal->>'sport','') not in ('gym','running','football','basketball','cycling','swimming','martial_arts','racket','yoga','other')
  or jsonb_typeof(v_goal->'sessions') is distinct from 'number' or coalesce(v_goal->>'sessions','') !~ '^[1-7]$' then raise exception 'invalid_routine'; end if;
  if v_goal->>'sport'=any(v_seen) then raise exception 'duplicate_sport'; end if;
  v_seen:=array_append(v_seen,v_goal->>'sport');
  if v_goal->'minutes' is not null and v_goal->'minutes'<>'null'::jsonb then
   if jsonb_typeof(v_goal->'minutes') is distinct from 'number' or (v_goal->>'minutes') !~ '^[0-9]{1,3}$' then raise exception 'invalid_duration'; end if;
   if (v_goal->>'minutes')::int not between 5 and 360 then raise exception 'invalid_duration'; end if;
  end if;
  v_days:=v_goal->'weekdays';
  if jsonb_typeof(v_days) is distinct from 'array' then raise exception 'invalid_weekdays'; end if;
  if jsonb_array_length(v_days)>(v_goal->>'sessions')::int or exists(select 1 from jsonb_array_elements(v_days) d where jsonb_typeof(d)<>'number' or d::text !~ '^[1-7]$')
   or (select count(distinct d) from jsonb_array_elements(v_days) d)<>jsonb_array_length(v_days) then raise exception 'invalid_weekdays'; end if;
  if exists(select 1 from jsonb_object_keys(v_goal) k where k not in ('sport','sessions','minutes','weekdays')) then raise exception 'unexpected_routine_data'; end if;
 end loop;
 perform 1 from public.profiles where id=auth.uid() for update;
 if not found then raise exception 'profile_required'; end if;
 v_revision:=(p_routine->>'revision')::int;
 select revision into v_current from public.personal_training_routines where owner_id=auth.uid();
 if coalesce(v_current,0)<>v_revision then raise exception 'routine_changed_reload'; end if;
 insert into public.personal_training_routines(owner_id,revision,goals) values(auth.uid(),v_revision+1,p_routine->'goals')
 on conflict(owner_id) do update set revision=excluded.revision,goals=excluded.goals,updated_at=now();
 return public.get_training_routine();
end; $$;

create function public.get_personal_training_week(p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start or p_end-p_start>interval '8 days' then raise exception 'invalid_week'; end if;
 return jsonb_build_object(
 'activities',coalesce((select jsonb_agg(to_jsonb(a) order by coalesce(a.ended_at,a.started_at,a.planned_at)) from public.activities a where a.user_id=auth.uid() and a.status<>'cancelled' and coalesce(a.ended_at,a.started_at,a.planned_at)>=p_start and coalesce(a.ended_at,a.started_at,a.planned_at)<p_end),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(to_jsonb(s) order by s.starts_at) from public.planned_sessions s where s.status in ('planned','ready') and s.starts_at>=p_start and s.starts_at<p_end
 and (s.host_id=auth.uid() or (public.are_friends(s.host_id,auth.uid()) and exists(select 1 from public.session_invites i where i.session_id=s.id and i.invitee_id=auth.uid() and i.status='accepted')))
 and not exists(select 1 from public.activities a where a.user_id=auth.uid() and a.planned_session_id=s.id and a.status in ('live','completed'))),'[]'::jsonb));
end; $$;

create function public.get_personal_workout_feedback(p_activity uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.activities where id=p_activity and user_id=auth.uid()) then raise exception 'forbidden'; end if;
 return coalesce((select jsonb_build_object('activity_id',activity_id,'revision',revision,'exercises',exercises,'feeling',feeling,'note',note) from public.personal_workout_feedback where activity_id=p_activity and owner_id=auth.uid()),
 jsonb_build_object('activity_id',p_activity,'revision',0,'exercises','[]'::jsonb,'feeling',null,'note',null));
end; $$;

create function public.save_personal_workout_feedback(p_feedback jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_activity public.activities; v_id uuid; v_entry jsonb; v_exercise uuid; v_seen uuid[]:='{}'; v_revision integer; v_current integer;
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_feedback) is distinct from 'object' or jsonb_typeof(p_feedback->'exercises') is distinct from 'array'
 or jsonb_typeof(p_feedback->'revision') is distinct from 'number' or coalesce(p_feedback->>'revision','') !~ '^[0-9]{1,9}$' then raise exception 'invalid_feedback'; end if;
 v_id:=(p_feedback->>'activity_id')::uuid;
 select * into v_activity from public.activities where id=v_id and user_id=auth.uid() for update;
 if not found or v_activity.status not in ('live','completed') then raise exception 'forbidden'; end if;
 if p_feedback->>'feeling' is not null and p_feedback->>'feeling' not in ('great','okay','tough') then raise exception 'invalid_feeling'; end if;
 if p_feedback->>'note' is not null and (jsonb_typeof(p_feedback->'note')<>'string' or char_length(p_feedback->>'note')>500) then raise exception 'invalid_note'; end if;
 if v_activity.status<>'completed' and (p_feedback->>'feeling' is not null or nullif(trim(p_feedback->>'note'),'') is not null) then raise exception 'finish_before_review'; end if;
 if jsonb_array_length(p_feedback->'exercises')>40 then raise exception 'invalid_feedback'; end if;
 for v_entry in select value from jsonb_array_elements(p_feedback->'exercises') loop
  if jsonb_typeof(v_entry) is distinct from 'object' or coalesce(v_entry->>'effort','') not in ('easy','medium','hardcore') then raise exception 'invalid_effort'; end if;
  v_exercise:=(v_entry->>'exercise_id')::uuid;
  if v_exercise is null or v_exercise=any(v_seen) then raise exception 'invalid_exercise'; end if;
  v_seen:=array_append(v_seen,v_exercise);
  if not exists(select 1 from public.workout_exercise_logs l where l.id=v_exercise and l.activity_id=v_id)
   and not exists(select 1 from public.blind_workout_exercises e join public.blind_workouts b on b.id=e.blind_workout_id where e.id=v_exercise and b.activity_id=v_id and b.recipient_id=auth.uid() and e.revealed_at is not null)
   then raise exception 'exercise_not_available'; end if;
  if exists(select 1 from jsonb_object_keys(v_entry) k where k not in ('exercise_id','effort')) then raise exception 'unexpected_feedback_data'; end if;
 end loop;
 select revision into v_current from public.personal_workout_feedback where activity_id=v_id;
 v_revision:=(p_feedback->>'revision')::int;
 if coalesce(v_current,0)<>v_revision then raise exception 'feedback_changed_reload'; end if;
 insert into public.personal_workout_feedback(activity_id,owner_id,revision,exercises,feeling,note)
 values(v_id,auth.uid(),v_revision+1,p_feedback->'exercises',p_feedback->>'feeling',nullif(trim(p_feedback->>'note'),''))
 on conflict(activity_id) do update set revision=excluded.revision,exercises=excluded.exercises,feeling=excluded.feeling,note=excluded.note,updated_at=now();
 return public.get_personal_workout_feedback(v_id);
end; $$;

revoke all on function public.get_training_routine(),public.save_training_routine(jsonb),public.get_personal_training_week(timestamptz,timestamptz),public.get_personal_workout_feedback(uuid),public.save_personal_workout_feedback(jsonb) from public,anon;
grant execute on function public.get_training_routine(),public.save_training_routine(jsonb),public.get_personal_training_week(timestamptz,timestamptz),public.get_personal_workout_feedback(uuid),public.save_personal_workout_feedback(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
