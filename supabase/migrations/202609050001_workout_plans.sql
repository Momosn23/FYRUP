begin;

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null check(char_length(trim(name)) between 2 and 100),
  primary_muscle_group text not null check(primary_muscle_group in ('chest','back','shoulders','biceps','triceps','quads','hamstrings','glutes','calves','adductors','core','traps','forearms','full_body','other')),
  equipment text not null default 'other' check(equipment in ('barbell','dumbbell','cable','machine','smith','bodyweight','kettlebell','band','other')),
  exercise_type text not null default 'strength' check(exercise_type in ('strength','timed','cardio')),
  is_custom boolean not null default true,
  created_by uuid references public.profiles(id) on delete cascade,
  is_archived boolean not null default false,
  note text check(char_length(note)<=500),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check((is_custom and created_by is not null) or (not is_custom and created_by is null))
);
create table public.exercise_secondary_muscles (
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  muscle_group text not null check(muscle_group in ('chest','back','shoulders','biceps','triceps','quads','hamstrings','glutes','calves','adductors','core','traps','forearms','full_body','other')),
  primary key(exercise_id,muscle_group)
);
create table public.workout_plans (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check(char_length(trim(name)) between 2 and 60), category text check(char_length(category)<=60),
  description text check(char_length(description)<=1000), visibility text not null default 'private' check(visibility in ('private','friends')),
  copied_from_plan_id uuid references public.workout_plans(id) on delete set null,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.workout_plan_exercises (
  id uuid primary key default gen_random_uuid(), workout_plan_id uuid not null references public.workout_plans(id) on delete cascade,
  exercise_id uuid references public.exercises(id) on delete set null,
  exercise_snapshot jsonb not null,
  sort_order int not null check(sort_order between 0 and 39), target_sets int not null check(target_sets between 1 and 30),
  target_reps_min int not null check(target_reps_min between 1 and 999), target_reps_max int not null check(target_reps_max between target_reps_min and 999),
  target_weight numeric check(target_weight between 0 and 2000), note text check(char_length(note)<=500),
  unique(workout_plan_id,sort_order) deferrable initially deferred
);
create table public.workout_plan_shares (
  plan_id uuid not null references public.workout_plans(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(plan_id,recipient_id)
);
create table public.exercise_favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,exercise_id)
);
alter table public.activities add column workout_plan_id uuid references public.workout_plans(id) on delete set null, add column exercise_count int check(exercise_count between 1 and 40);
alter table public.planned_sessions add column workout_plan_id uuid references public.workout_plans(id) on delete set null, add column exercise_count int check(exercise_count between 1 and 40);

create table public.workout_records (
  activity_id uuid primary key references public.activities(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  plan_name text not null, created_at timestamptz not null default now()
);
create table public.workout_exercise_logs (
  id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.workout_records(activity_id) on delete cascade,
  exercise_id uuid references public.exercises(id) on delete set null,
  workout_plan_exercise_id uuid references public.workout_plan_exercises(id) on delete set null,
  exercise_snapshot jsonb not null,
  sort_order int not null check(sort_order between 0 and 39), target_sets int not null check(target_sets between 1 and 30),
  target_reps_min int not null check(target_reps_min between 1 and 999), target_reps_max int not null check(target_reps_max between target_reps_min and 999),
  target_weight numeric check(target_weight between 0 and 2000),
  note text check(char_length(note)<=500), completed boolean not null default false, completed_at timestamptz,
  unique(activity_id,sort_order)
);
create table public.workout_set_logs (
  id uuid primary key default gen_random_uuid(), workout_exercise_log_id uuid not null references public.workout_exercise_logs(id) on delete cascade,
  set_number int not null check(set_number between 1 and 30), weight numeric check(weight between 0 and 2000),
  reps int check(reps between 0 and 999), completed boolean not null default false, completed_at timestamptz,
  unique(workout_exercise_log_id,set_number)
);
create index workout_plans_owner_idx on public.workout_plans(owner_id);
create index workout_plan_exercise_idx on public.workout_plan_exercises(workout_plan_id);
create index exercise_creator_idx on public.exercises(created_by);
create index workout_logs_activity_idx on public.workout_exercise_logs(activity_id);
create index workout_sets_exercise_idx on public.workout_set_logs(workout_exercise_log_id);
create index workout_shares_recipient_idx on public.workout_plan_shares(recipient_id);

create function public.can_read_workout_plan(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.workout_plans p where p.id=p_id and (
   p.owner_id=auth.uid() or (not p.is_archived and public.are_friends(p.owner_id,auth.uid()) and (
     p.visibility='friends'
     or exists(select 1 from public.workout_plan_shares s where s.plan_id=p.id and s.recipient_id=auth.uid())
     or exists(select 1 from public.planned_sessions s join public.session_invites i on i.session_id=s.id
       where s.workout_plan_id=p.id and i.invitee_id=auth.uid() and i.status in ('pending','accepted','maybe') and s.status<>'cancelled')
   ))
 ));
$$;

alter table public.exercises enable row level security;
alter table public.exercise_secondary_muscles enable row level security;
alter table public.workout_plans enable row level security;
alter table public.workout_plan_exercises enable row level security;
alter table public.workout_plan_shares enable row level security;
alter table public.exercise_favorites enable row level security;
alter table public.workout_records enable row level security;
alter table public.workout_exercise_logs enable row level security;
alter table public.workout_set_logs enable row level security;
create policy exercises_read on public.exercises for select to authenticated using(not is_custom or created_by=auth.uid());
create policy exercise_muscles_read on public.exercise_secondary_muscles for select to authenticated using(exists(select 1 from public.exercises e where e.id=exercise_id));
create policy workout_plans_read on public.workout_plans for select to authenticated using(public.can_read_workout_plan(id));
create policy workout_plan_exercises_read on public.workout_plan_exercises for select to authenticated using(public.can_read_workout_plan(workout_plan_id));
create policy workout_shares_read on public.workout_plan_shares for select to authenticated using((recipient_id=auth.uid() and public.can_read_workout_plan(plan_id)) or exists(select 1 from public.workout_plans p where p.id=plan_id and p.owner_id=auth.uid()));
create policy exercise_favorites_read on public.exercise_favorites for select to authenticated using(user_id=auth.uid());
create policy workout_records_private on public.workout_records for select to authenticated using(owner_id=auth.uid());
create policy workout_logs_private on public.workout_exercise_logs for select to authenticated using(exists(select 1 from public.workout_records r where r.activity_id=workout_exercise_logs.activity_id and r.owner_id=auth.uid()));
create policy workout_sets_private on public.workout_set_logs for select to authenticated using(exists(select 1 from public.workout_exercise_logs l join public.workout_records r on r.activity_id=l.activity_id where l.id=workout_exercise_log_id and r.owner_id=auth.uid()));
revoke all on public.exercises,public.exercise_secondary_muscles,public.workout_plans,public.workout_plan_exercises,public.workout_plan_shares,public.exercise_favorites,public.workout_records,public.workout_exercise_logs,public.workout_set_logs from anon,authenticated;
grant select on public.exercises,public.exercise_secondary_muscles,public.workout_plans,public.workout_plan_exercises,public.workout_plan_shares,public.exercise_favorites,public.workout_records,public.workout_exercise_logs,public.workout_set_logs to authenticated;

-- Internal document helpers never exposed directly: they also serve archived history.
create function public.exercise_document(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(e) || jsonb_build_object('secondary_muscles',coalesce((select jsonb_agg(s.muscle_group order by s.muscle_group) from public.exercise_secondary_muscles s where s.exercise_id=e.id),'[]'::jsonb)) from public.exercises e where e.id=p_id;
$$;
create function public.workout_plan_document(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(p) || jsonb_build_object('exercises',coalesce((select jsonb_agg((to_jsonb(e)-'exercise_snapshot') || jsonb_build_object('exercise',coalesce(public.exercise_document(e.exercise_id),e.exercise_snapshot)) order by e.sort_order) from public.workout_plan_exercises e where e.workout_plan_id=p.id),'[]'::jsonb)) from public.workout_plans p where p.id=p_id;
$$;
create function public.list_exercises() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(public.exercise_document(id) order by name),'[]'::jsonb) from public.exercises where auth.uid() is not null and not is_archived and (not is_custom or created_by=auth.uid());
$$;
create function public.save_exercise(p_exercise jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid := coalesce((p_exercise->>'id')::uuid,gen_random_uuid());
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_exercise) is distinct from 'object' or jsonb_typeof(coalesce(p_exercise->'secondary_muscles','[]'::jsonb)) is distinct from 'array' then raise exception 'invalid_exercise'; end if;
 if jsonb_array_length(coalesce(p_exercise->'secondary_muscles','[]'::jsonb))>14 then raise exception 'invalid_exercise'; end if;
 if exists(select 1 from public.exercises where id=v_id and (created_by is distinct from auth.uid() or not is_custom)) then raise exception 'forbidden'; end if;
 insert into public.exercises(id,name,primary_muscle_group,equipment,exercise_type,is_custom,created_by,note)
 values(v_id,trim(p_exercise->>'name'),p_exercise->>'primary_muscle_group',coalesce(p_exercise->>'equipment','other'),coalesce(p_exercise->>'exercise_type','strength'),true,auth.uid(),nullif(trim(p_exercise->>'note'),''))
 on conflict(id) do update set name=excluded.name,primary_muscle_group=excluded.primary_muscle_group,equipment=excluded.equipment,note=excluded.note,exercise_type=excluded.exercise_type,updated_at=now()
 where exercises.created_by=auth.uid() and exercises.is_custom;
 if not found then raise exception 'forbidden'; end if;
 delete from public.exercise_secondary_muscles where exercise_id=v_id;
 insert into public.exercise_secondary_muscles(exercise_id,muscle_group) select v_id,value from jsonb_array_elements_text(coalesce(p_exercise->'secondary_muscles','[]'::jsonb)) where value<>p_exercise->>'primary_muscle_group' on conflict do nothing;
 return public.exercise_document(v_id);
end; $$;
create function public.archive_exercise(p_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin update public.exercises set is_archived=true,updated_at=now() where id=p_id and created_by=auth.uid() and is_custom; if not found then raise exception 'forbidden'; end if; return true; end; $$;
create function public.set_exercise_favorite(p_id uuid,p_favorite boolean) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if p_favorite is null then raise exception 'invalid_favorite'; end if;
 if not exists(select 1 from public.exercises where id=p_id and (not is_archived or not p_favorite) and (not is_custom or created_by=auth.uid())) or auth.uid() is null then raise exception 'forbidden'; end if;
 if p_favorite then insert into public.exercise_favorites(user_id,exercise_id) values(auth.uid(),p_id) on conflict do nothing;
 else delete from public.exercise_favorites where user_id=auth.uid() and exercise_id=p_id; end if;
 return true;
end; $$;
create function public.list_exercise_favorites() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(exercise_id),'[]'::jsonb) from public.exercise_favorites where user_id=auth.uid(); $$;
create function public.get_workout_plan(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin if not public.can_read_workout_plan(p_id) then raise exception 'forbidden'; end if; return public.workout_plan_document(p_id); end; $$;
create function public.list_workout_plans(p_owner uuid default null) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(public.workout_plan_document(p.id) order by p.updated_at desc),'[]'::jsonb) from public.workout_plans p
 where not p.is_archived and p.owner_id=coalesce(p_owner,auth.uid()) and (p.owner_id=auth.uid() or (p.visibility='friends' and public.are_friends(p.owner_id,auth.uid())));
$$;
create function public.save_workout_plan(p_plan jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid := coalesce((p_plan->>'id')::uuid,gen_random_uuid()); v_item jsonb; v_exercise_id uuid; v_row_id uuid; v_kept uuid[] := '{}'; v_position int := 0;
begin
 if auth.uid() is null then raise exception 'unauthorized'; end if;
 -- Every mutation/start/copy locks the plan row before touching its ordered children.
 perform 1 from public.workout_plans p where p.id=v_id for update;
 if exists(select 1 from public.workout_plans where id=v_id and owner_id<>auth.uid()) then raise exception 'forbidden'; end if;
 if exists(select 1 from public.workout_plans where id=v_id and is_archived) then raise exception 'plan_not_available'; end if;
 if jsonb_typeof(p_plan) is distinct from 'object' or jsonb_typeof(p_plan->'exercises') is distinct from 'array' then raise exception 'invalid_plan'; end if;
 if jsonb_array_length(p_plan->'exercises') not between 1 and 40 then raise exception 'invalid_plan'; end if;
 insert into public.workout_plans(id,owner_id,name,category,description,visibility) values(v_id,auth.uid(),trim(p_plan->>'name'),nullif(p_plan->>'category',''),nullif(p_plan->>'description',''),coalesce(p_plan->>'visibility','private'))
 on conflict(id) do update set name=excluded.name,category=excluded.category,description=excluded.description,visibility=excluded.visibility,updated_at=now()
 where workout_plans.owner_id=auth.uid() and not workout_plans.is_archived;
 if not found then raise exception 'forbidden'; end if;
 for v_item in select value from jsonb_array_elements(p_plan->'exercises') loop
   v_exercise_id := (v_item->'exercise'->>'id')::uuid; v_row_id := coalesce((v_item->>'id')::uuid,gen_random_uuid());
   if v_row_id=any(v_kept) then raise exception 'duplicate_plan_exercise'; end if;
   if not exists(select 1 from public.exercises e where e.id=v_exercise_id and (not e.is_custom or e.created_by=auth.uid()) and (not e.is_archived or exists(select 1 from public.workout_plan_exercises pe where pe.id=v_row_id and pe.workout_plan_id=v_id and pe.exercise_id=e.id))) then raise exception 'exercise_not_available'; end if;
   if exists(select 1 from public.workout_plan_exercises where id=v_row_id and workout_plan_id<>v_id) then raise exception 'forbidden'; end if;
   insert into public.workout_plan_exercises(id,workout_plan_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
   values(v_row_id,v_id,v_exercise_id,public.exercise_document(v_exercise_id),v_position,(v_item->>'target_sets')::int,(v_item->>'target_reps_min')::int,(v_item->>'target_reps_max')::int,(v_item->>'target_weight')::numeric,nullif(v_item->>'note',''))
   on conflict(id) do update set exercise_id=excluded.exercise_id,exercise_snapshot=excluded.exercise_snapshot,sort_order=excluded.sort_order,target_sets=excluded.target_sets,target_reps_min=excluded.target_reps_min,target_reps_max=excluded.target_reps_max,target_weight=excluded.target_weight,note=excluded.note;
   v_kept := array_append(v_kept,v_row_id); v_position := v_position+1;
 end loop;
 delete from public.workout_plan_exercises where workout_plan_id=v_id and not(id=any(v_kept));
 return public.workout_plan_document(v_id);
end; $$;
create function public.archive_workout_plan(p_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin update public.workout_plans set is_archived=true,updated_at=now() where id=p_id and owner_id=auth.uid(); if not found then raise exception 'forbidden'; end if; return true; end; $$;
create function public.share_workout_plan(p_id uuid,p_friends uuid[]) returns boolean language plpgsql security definer set search_path='' as $$
declare v_friend uuid; v_plan public.workout_plans;
begin
 select * into v_plan from public.workout_plans where id=p_id and owner_id=auth.uid() and not is_archived for share;
 if v_plan.id is null then raise exception 'forbidden'; end if;
 if cardinality(p_friends)>100 then raise exception 'too_many_recipients'; end if;
 foreach v_friend in array coalesce(p_friends,'{}') loop
   if not public.are_friends(auth.uid(),v_friend) then raise exception 'not_friends'; end if;
   insert into public.workout_plan_shares(plan_id,recipient_id) values(p_id,v_friend) on conflict do nothing;
   if found then
     insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(v_friend,auth.uid(),'workout_plan_shared','Ein Trainingsplan für dich',v_plan.name,jsonb_build_object('plan_id',p_id));
   end if;
 end loop;
 return true;
end; $$;
create function public.copy_workout_plan(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare source public.workout_plans; new_plan uuid := gen_random_uuid(); row record; new_exercise uuid; mapping jsonb := '{}'::jsonb; snapshot jsonb;
begin
 if not public.can_read_workout_plan(p_id) then raise exception 'forbidden'; end if;
 select * into source from public.workout_plans where id=p_id and not is_archived for share;
 if source.id is null then raise exception 'plan_not_available'; end if;
 insert into public.workout_plans(id,owner_id,name,category,description,visibility,copied_from_plan_id) values(new_plan,auth.uid(),source.name,source.category,source.description,'private',source.id);
 for row in select * from public.workout_plan_exercises where workout_plan_id=p_id order by sort_order loop
   snapshot := coalesce(public.exercise_document(row.exercise_id),row.exercise_snapshot); new_exercise := row.exercise_id;
   if (snapshot->>'is_custom')::boolean or new_exercise is null then
     new_exercise := (mapping->>(snapshot->>'id'))::uuid;
     if new_exercise is null then
       new_exercise := gen_random_uuid();
       perform public.save_exercise(snapshot || jsonb_build_object('id',new_exercise,'is_archived',false));
       mapping := mapping || jsonb_build_object(snapshot->>'id',new_exercise);
     end if;
   end if;
   insert into public.workout_plan_exercises(workout_plan_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
   values(new_plan,new_exercise,public.exercise_document(new_exercise),row.sort_order,row.target_sets,row.target_reps_min,row.target_reps_max,row.target_weight,row.note);
 end loop;
 return public.workout_plan_document(new_plan);
end; $$;

-- RSVP and legacy start paths must carry the same concrete plan as start_workout.
-- The hook also prevents a client from guessing a session UUID to obtain its plan.
create function public.attach_activity_workout() returns trigger language plpgsql security definer set search_path='' as $$
declare v_session public.planned_sessions; v_plan public.workout_plans;
begin
 if new.planned_session_id is not null then
   select * into v_session from public.planned_sessions where id=new.planned_session_id;
   if v_session.workout_plan_id is not null then
     new.workout_plan_id := v_session.workout_plan_id;
     new.exercise_count := v_session.exercise_count;
     if new.status in ('planned','ready','live') and
        (v_session.status in ('cancelled','completed') or
         (new.user_id<>v_session.host_id and (not public.are_friends(new.user_id,v_session.host_id) or not exists(
           select 1 from public.session_invites i where i.session_id=v_session.id and i.invitee_id=new.user_id and i.status='accepted'))))
     then raise exception 'invalid_session'; end if;
   end if;
 end if;
 if new.workout_plan_id is null then return new; end if;
 -- Cancelling/completing an existing log must remain possible after revocation/archive.
 if new.status<>'live' or exists(select 1 from public.workout_records r where r.activity_id=new.id) then return new; end if;
 if new.user_id is distinct from auth.uid() or not public.can_read_workout_plan(new.workout_plan_id) then raise exception 'forbidden'; end if;
 select * into v_plan from public.workout_plans where id=new.workout_plan_id and not is_archived for share;
 if v_plan.id is null then raise exception 'plan_not_available'; end if;
 new.sport := 'gym'; new.subtype := v_plan.name;
 new.exercise_count := (select count(*) from public.workout_plan_exercises where workout_plan_id=v_plan.id);
 return new;
end; $$;
create trigger activities_attach_workout before insert or update on public.activities for each row execute function public.attach_activity_workout();

create function public.initialize_activity_workout() returns trigger language plpgsql security definer set search_path='' as $$
declare v_row record; v_log_id uuid;
begin
 if new.status<>'live' or new.workout_plan_id is null then return new; end if;
 insert into public.workout_records(activity_id,owner_id,plan_name) values(new.id,new.user_id,new.subtype) on conflict do nothing;
 if not found then return new; end if;
 for v_row in select * from public.workout_plan_exercises where workout_plan_id=new.workout_plan_id order by sort_order loop
   insert into public.workout_exercise_logs(activity_id,exercise_id,workout_plan_exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
   values(new.id,v_row.exercise_id,v_row.id,coalesce(public.exercise_document(v_row.exercise_id),v_row.exercise_snapshot),v_row.sort_order,v_row.target_sets,v_row.target_reps_min,v_row.target_reps_max,v_row.target_weight,v_row.note) returning id into v_log_id;
   -- Targets are not measurements. Actual weights/reps are NULL until entered.
   insert into public.workout_set_logs(workout_exercise_log_id,set_number) select v_log_id,n from generate_series(1,v_row.target_sets) n;
 end loop;
 return new;
end; $$;
create trigger activities_initialize_workout after insert or update on public.activities for each row execute function public.initialize_activity_workout();

create function public.start_workout(p_plan uuid,p_linked uuid default null,p_session uuid default null) returns public.activities language plpgsql security definer set search_path='' as $$
declare v_plan public.workout_plans; v_activity public.activities;
begin
 if not public.can_read_workout_plan(p_plan) then raise exception 'forbidden'; end if;
 select * into v_plan from public.workout_plans where id=p_plan and not is_archived for share;
 if v_plan.id is null then raise exception 'plan_not_available'; end if;
 if p_session is not null and not exists(select 1 from public.planned_sessions s where s.id=p_session and s.workout_plan_id=p_plan and s.status in ('planned','ready','live') and not public.is_blocked(s.host_id,auth.uid()) and (s.host_id=auth.uid() or exists(select 1 from public.session_invites i where i.session_id=s.id and i.invitee_id=auth.uid() and i.status='accepted'))) then raise exception 'invalid_session'; end if;
 if p_linked is not null and not exists(select 1 from public.activities where id=p_linked and workout_plan_id=p_plan) then raise exception 'invalid_link'; end if;
 v_activity := public.start_activity('gym',v_plan.name,p_linked,p_session);
 update public.activities set workout_plan_id=p_plan,exercise_count=(select count(*) from public.workout_plan_exercises where workout_plan_id=p_plan) where id=v_activity.id returning * into v_activity;
 return v_activity;
end; $$;
create function public.plan_workout(p_plan uuid,p_starts_at timestamptz,p_duration int,p_note text,p_place text,p_friends_can_join boolean,p_friends uuid[]) returns public.planned_sessions language plpgsql security definer set search_path='' as $$
declare v_plan public.workout_plans; v_session public.planned_sessions; v_friend uuid;
begin
 select * into v_plan from public.workout_plans where id=p_plan and owner_id=auth.uid() and not is_archived for share;
 if v_plan.id is null then raise exception 'forbidden'; end if;
 if p_duration is null or p_duration not between 5 and 1440 or p_starts_at is null then raise exception 'invalid_schedule'; end if;
 if cardinality(p_friends)>100 then raise exception 'too_many_recipients'; end if;
 foreach v_friend in array coalesce(p_friends,'{}') loop
   if not public.are_friends(auth.uid(),v_friend) then raise exception 'not_friends'; end if;
 end loop;
 v_session := public.plan_session('gym',v_plan.name,p_starts_at,p_duration::smallint,p_note,p_place,p_friends_can_join,p_friends);
 update public.planned_sessions set workout_plan_id=p_plan,exercise_count=(select count(*) from public.workout_plan_exercises where workout_plan_id=p_plan) where id=v_session.id returning * into v_session;
 update public.activities set workout_plan_id=p_plan,exercise_count=v_session.exercise_count where planned_session_id=v_session.id;
 return v_session;
end; $$;
create function public.get_workout_log(p_activity uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.workout_records where activity_id=p_activity and owner_id=auth.uid()) then raise exception 'forbidden'; end if;
 return (select jsonb_build_object('activity_id',r.activity_id,'plan_name',r.plan_name,'exercises',coalesce((select jsonb_agg((to_jsonb(l)-'exercise_snapshot') || jsonb_build_object('exercise',l.exercise_snapshot,'sets',coalesce((select jsonb_agg(to_jsonb(s) order by s.set_number) from public.workout_set_logs s where s.workout_exercise_log_id=l.id),'[]'::jsonb)) order by l.sort_order) from public.workout_exercise_logs l where l.activity_id=r.activity_id),'[]'::jsonb)) from public.workout_records r where r.activity_id=p_activity);
end; $$;
create function public.save_workout_log(p_log jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_activity uuid := (p_log->>'activity_id')::uuid; v_item jsonb; v_entry jsonb; v_log_id uuid;
 v_seen uuid[] := '{}'; v_numbers int[]; v_number int; v_completed boolean; v_count int;
begin
 -- Serializes saves and makes duplicate retries stable; all authoritative snapshots
 -- and target values are read from the server, never replaced by a client payload.
 perform 1 from public.workout_records r join public.activities a on a.id=r.activity_id
 where r.activity_id=v_activity and r.owner_id=auth.uid() and a.status in ('live','completed') for update of r;
 if not found then raise exception 'forbidden'; end if;
 if jsonb_typeof(p_log) is distinct from 'object' or jsonb_typeof(p_log->'exercises') is distinct from 'array' then raise exception 'invalid_log'; end if;
 select count(*) into v_count from public.workout_exercise_logs where activity_id=v_activity;
 if jsonb_array_length(p_log->'exercises')<>v_count then raise exception 'incomplete_log'; end if;
 for v_item in select value from jsonb_array_elements(p_log->'exercises') loop
   v_log_id := (v_item->>'id')::uuid;
   if v_log_id=any(v_seen) then raise exception 'duplicate_log_exercise'; end if;
   if not exists(select 1 from public.workout_exercise_logs where id=v_log_id and activity_id=v_activity) then raise exception 'forbidden'; end if;
   v_seen := array_append(v_seen,v_log_id);
   v_completed := coalesce((v_item->>'completed')::boolean,false);
   update public.workout_exercise_logs set completed=v_completed,completed_at=case when v_completed then coalesce(completed_at,now()) else null end where id=v_log_id;
   if jsonb_typeof(v_item->'sets') is distinct from 'array' then raise exception 'invalid_sets'; end if;
   if jsonb_array_length(v_item->'sets')>30 then raise exception 'invalid_sets'; end if;
   v_numbers := '{}';
   for v_entry in select value from jsonb_array_elements(v_item->'sets') loop
     v_number := (v_entry->>'set_number')::int;
     if v_number=any(v_numbers) then raise exception 'duplicate_set_number'; end if;
     v_numbers := array_append(v_numbers,v_number);
     v_completed := coalesce((v_entry->>'completed')::boolean,false);
     insert into public.workout_set_logs(workout_exercise_log_id,set_number,weight,reps,completed,completed_at)
     values(v_log_id,v_number,(v_entry->>'weight')::numeric,(v_entry->>'reps')::int,v_completed,case when v_completed then now() else null end)
     on conflict(workout_exercise_log_id,set_number) do update set weight=excluded.weight,reps=excluded.reps,
       completed=excluded.completed,completed_at=case when excluded.completed then coalesce(workout_set_logs.completed_at,now()) else null end;
   end loop;
   delete from public.workout_set_logs where workout_exercise_log_id=v_log_id and not(set_number=any(v_numbers));
 end loop;
 return public.get_workout_log(v_activity);
end; $$;

revoke all on function public.exercise_document(uuid),public.workout_plan_document(uuid),public.attach_activity_workout(),public.initialize_activity_workout() from public,anon,authenticated;
revoke all on function public.can_read_workout_plan(uuid),public.list_exercises(),public.save_exercise(jsonb),public.archive_exercise(uuid),public.set_exercise_favorite(uuid,boolean),public.list_exercise_favorites(),public.get_workout_plan(uuid),public.list_workout_plans(uuid),public.save_workout_plan(jsonb),public.archive_workout_plan(uuid),public.share_workout_plan(uuid,uuid[]),public.copy_workout_plan(uuid),public.start_workout(uuid,uuid,uuid),public.plan_workout(uuid,timestamptz,int,text,text,boolean,uuid[]),public.get_workout_log(uuid),public.save_workout_log(jsonb) from public,anon;
grant execute on function public.can_read_workout_plan(uuid),public.list_exercises(),public.save_exercise(jsonb),public.archive_exercise(uuid),public.set_exercise_favorite(uuid,boolean),public.list_exercise_favorites(),public.get_workout_plan(uuid),public.list_workout_plans(uuid),public.save_workout_plan(jsonb),public.archive_workout_plan(uuid),public.share_workout_plan(uuid,uuid[]),public.copy_workout_plan(uuid),public.start_workout(uuid,uuid,uuid),public.plan_workout(uuid,timestamptz,int,text,text,boolean,uuid[]),public.get_workout_log(uuid),public.save_workout_log(jsonb) to authenticated;
commit;
