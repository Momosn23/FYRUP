begin;

-- Separate target/actual tables: generic owner workout-log RLS must never reveal
-- the hidden remainder of a Blind Workout. All exercise content is server-frozen.
create table public.blind_workouts (
 id uuid primary key,
 creator_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 title text check(char_length(title)<=60),
 focus text not null check(focus in ('push','pull','legs','upper_body','lower_body','full_body','chest','back','arms','shoulders','cardio','custom')),
 estimated_duration_minutes integer not null check(estimated_duration_minutes between 5 and 180),
 exercise_count integer not null check(exercise_count between 1 and 12),
 required_equipment text[] not null default '{}',muscle_groups text[] not null default '{}',
 status text not null default 'sent' check(status in ('sent','accepted','planned','live','completed','declined','cancelled')),
 equipment_confirmed boolean not null default false,
 scheduled_at timestamptz,accepted_at timestamptz,started_at timestamptz,completed_at timestamptz,
 activity_id uuid unique references public.activities(id) on delete set null deferrable initially deferred,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 -- Private idempotency document contains the requested sequence; never SELECT-granted.
 send_request jsonb not null,
 check(creator_id<>recipient_id),
 check(status not in ('accepted','planned','live','completed') or equipment_confirmed),
 check(status<>'completed' or completed_at is not null)
);
create index blind_workouts_recipient on public.blind_workouts(recipient_id,created_at desc);
create index blind_workouts_creator on public.blind_workouts(creator_id,created_at desc);
create table public.blind_workout_exercises (
 id uuid primary key default gen_random_uuid(),
 blind_workout_id uuid not null references public.blind_workouts(id) on delete cascade,
 exercise_id uuid references public.exercises(id) on delete set null,
 exercise_snapshot jsonb not null,
 sort_order integer not null check(sort_order between 0 and 11),
 target_sets integer not null check(target_sets between 1 and 6),
 target_reps_min integer not null check(target_reps_min between 1 and 300),
 target_reps_max integer not null check(target_reps_max between target_reps_min and 300),
 target_weight numeric check(target_weight between 0 and 500),
 note text check(char_length(note)<=500),
 revealed_at timestamptz,completed boolean not null default false,completed_at timestamptz,
 unique(blind_workout_id,sort_order),
 check((exercise_snapshot->>'exercise_type') in ('strength','timed')),
 check((exercise_snapshot->>'exercise_type')='timed' or target_reps_max<=30),
 check(completed=(completed_at is not null)),
 check(not completed or revealed_at is not null)
);
create table public.blind_workout_sets (
 id uuid primary key default gen_random_uuid(),
 blind_workout_exercise_id uuid not null references public.blind_workout_exercises(id) on delete cascade,
 set_number integer not null check(set_number between 1 and 6),
 weight numeric check(weight between 0 and 500),reps integer check(reps between 0 and 300),
 completed boolean not null default false,completed_at timestamptz,
 unique(blind_workout_exercise_id,set_number),
 check(completed=(completed_at is not null))
);
create table public.blind_workout_copies (
 blind_workout_id uuid not null references public.blind_workouts(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 plan_id uuid references public.workout_plans(id) on delete set null,
 primary key(blind_workout_id,owner_id)
);
create table public.blind_workout_reactions (
 blind_workout_id uuid not null references public.blind_workouts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 reaction text not null check(reaction in ('🔥','💪','👏')),
 updated_at timestamptz not null default now(),primary key(blind_workout_id,user_id)
);
-- Deliberately persistent marker, not ON DELETE SET NULL: if a creator deletes
-- their account, a surviving recipient activity must not become a normal workout
-- that can bypass Blind completion validation. Safe cancellation remains possible.
alter table public.activities add column blind_workout_id uuid;
create unique index one_activity_per_blind_workout on public.activities(blind_workout_id) where blind_workout_id is not null;
create unique index blind_notification_once on public.notifications(recipient_id,type,(data->>'blind_workout_id'))
 where type in ('blind_workout_received','blind_workout_completed','blind_reaction') and data ? 'blind_workout_id';

create function public.can_read_blind_workout(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.blind_workouts b where b.id=p_id and auth.uid() in(b.creator_id,b.recipient_id)
   and public.are_friends(b.creator_id,b.recipient_id));
$$;
create function public.can_read_blind_exercise(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.blind_workout_exercises e join public.blind_workouts b on b.id=e.blind_workout_id
   where e.id=p_id and public.can_read_blind_workout(b.id) and
   (auth.uid()=b.creator_id or (auth.uid()=b.recipient_id and e.revealed_at is not null)));
$$;
create function public.can_read_blind_actuals(p_exercise uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.blind_workout_exercises e join public.blind_workouts b on b.id=e.blind_workout_id
   where e.id=p_exercise and auth.uid()=b.recipient_id and e.revealed_at is not null
   and public.are_friends(b.creator_id,b.recipient_id));
$$;
create function public.blind_summary_document(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select (to_jsonb(b)-'send_request'-'equipment_confirmed')||jsonb_build_object(
   'creator_name',c.display_name,'recipient_name',r.display_name,
   'completed_exercises',(select count(*) from public.blind_workout_exercises e where e.blind_workout_id=b.id and e.completed))
 from public.blind_workouts b join public.profiles c on c.id=b.creator_id join public.profiles r on r.id=b.recipient_id where b.id=p_id;
$$;
create function public.blind_exercise_document(p_id uuid,p_actuals boolean) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',e.id,'exercise',e.exercise_snapshot,'workout_plan_exercise_id',null,
   'sort_order',e.sort_order,'target_sets',e.target_sets,'target_reps_min',e.target_reps_min,'target_reps_max',e.target_reps_max,
   'target_weight',e.target_weight,'note',e.note,
   'completed',case when p_actuals then e.completed else false end,'completed_at',case when p_actuals then e.completed_at else null end,
   'sets',case when p_actuals then coalesce((select jsonb_agg(to_jsonb(s)-'blind_workout_exercise_id' order by s.set_number)
     from public.blind_workout_sets s where s.blind_workout_exercise_id=e.id),'[]'::jsonb) else '[]'::jsonb end)
 from public.blind_workout_exercises e where e.id=p_id;
$$;
create function public.blind_state_document(p_id uuid,p_cancelled_owner boolean default false) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_access boolean;
begin
 select * into v_blind from public.blind_workouts where id=p_id;
 if v_blind.id is null or auth.uid() is null or auth.uid() not in(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 v_access:=public.are_friends(v_blind.creator_id,v_blind.recipient_id);
 if not v_access and not (p_cancelled_owner and v_blind.status='cancelled') then raise exception 'forbidden'; end if;
 return jsonb_build_object('summary',public.blind_summary_document(p_id),
   'viewer_role',case when auth.uid()=v_blind.creator_id then 'creator' else 'recipient' end,
   'visible_exercises',case when not v_access then '[]'::jsonb else coalesce((select jsonb_agg(public.blind_exercise_document(e.id,auth.uid()=v_blind.recipient_id) order by e.sort_order)
     from public.blind_workout_exercises e where e.blind_workout_id=p_id and
       (auth.uid()=v_blind.creator_id or e.revealed_at is not null)),'[]'::jsonb) end,
   'activity',case when auth.uid()=v_blind.recipient_id then (select to_jsonb(a) from public.activities a where a.id=v_blind.activity_id) else null end,
   'reaction_counts',case when v_access then coalesce((select jsonb_agg(jsonb_build_object('reaction',reaction,'count',n) order by reaction)
     from (select reaction,count(*)n from public.blind_workout_reactions where blind_workout_id=p_id group by reaction)r),'[]'::jsonb) else '[]'::jsonb end,
   'my_reaction',case when v_access then (select reaction from public.blind_workout_reactions where blind_workout_id=p_id and user_id=auth.uid()) else null end);
end; $$;

create function public.react_to_blind_workout(p_id uuid,p_reaction text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_other uuid; v_previous text;
begin
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or not public.can_read_blind_workout(p_id) then raise exception 'forbidden'; end if;
 if v_blind.status<>'completed' then raise exception 'blind_invalid_state'; end if;
 if p_reaction is not null and p_reaction not in ('🔥','💪','👏') then raise exception 'invalid_reaction'; end if;
 select reaction into v_previous from public.blind_workout_reactions where blind_workout_id=p_id and user_id=auth.uid();
 if p_reaction is null then
   delete from public.blind_workout_reactions where blind_workout_id=p_id and user_id=auth.uid();
 elsif v_previous is distinct from p_reaction then
   insert into public.blind_workout_reactions(blind_workout_id,user_id,reaction) values(p_id,auth.uid(),p_reaction)
   on conflict(blind_workout_id,user_id) do update set reaction=excluded.reaction,updated_at=clock_timestamp();
   v_other:=case when auth.uid()=v_blind.creator_id then v_blind.recipient_id else v_blind.creator_id end;
   if coalesce((select reactions from public.notification_preferences where user_id=v_other),true) then
     insert into public.notifications(recipient_id,actor_id,type,title,body,data)
     values(v_other,auth.uid(),'blind_reaction','Dein Blind Workout verbindet',p_reaction,jsonb_build_object('blind_workout_id',p_id)) on conflict do nothing;
   end if;
 end if;
 return public.blind_state_document(p_id);
end; $$;
create function public.get_blind_workout(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$select public.blind_state_document(p_id);$$;
create function public.list_blind_workouts() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(public.blind_summary_document(b.id) order by b.created_at desc,b.id),'[]'::jsonb)
 from public.blind_workouts b where public.can_read_blind_workout(b.id);
$$;

create function public.send_blind_workout(p_draft jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_recipient uuid; v_item jsonb; v_exercise public.exercises; v_existing public.blind_workouts;
 v_request jsonb; v_rows jsonb:='[]'::jsonb; v_order integer:=0; v_seen uuid[]:='{}'; v_slot uuid;
 v_sets integer; v_min integer; v_max integer; v_weight numeric; v_note text;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if jsonb_typeof(p_draft) is distinct from 'object' or jsonb_typeof(p_draft->'exercises') is distinct from 'array'
   or jsonb_array_length(p_draft->'exercises') not between 1 and 12 then raise exception 'invalid_blind_workout'; end if;
 v_id:=(p_draft->>'id')::uuid; v_recipient:=(p_draft->>'recipient_id')::uuid;
 if v_id is null or v_recipient is null or not public.are_friends(auth.uid(),v_recipient) then raise exception 'forbidden'; end if;
 -- Each sender's request UUID is serialized even before its first row exists.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_id::text,7007));
 for v_item in select value from jsonb_array_elements(p_draft->'exercises') loop
   if jsonb_typeof(v_item) is distinct from 'object' or jsonb_typeof(v_item->'exercise') is distinct from 'object' then raise exception 'invalid_blind_exercise'; end if;
   v_slot:=(v_item->>'id')::uuid;
   if v_slot is null or v_slot=any(v_seen) then raise exception 'duplicate_blind_exercise'; end if;
   v_seen:=array_append(v_seen,v_slot);
   -- Only identity and structured targets are accepted from the client. Names,
   -- muscle groups, ownership and descriptions are resolved from the library.
   v_rows:=v_rows||jsonb_build_array(jsonb_build_object('slot',v_slot,'exercise_id',(v_item->'exercise'->>'id')::uuid,
     'target_sets',(v_item->>'target_sets')::integer,'target_reps_min',(v_item->>'target_reps_min')::integer,
     'target_reps_max',(v_item->>'target_reps_max')::integer,'target_weight',(v_item->>'target_weight')::numeric,
     'note',nullif(trim(v_item->>'note'),''),'sort_order',v_order));
   v_order:=v_order+1;
 end loop;
 v_request:=jsonb_build_object('recipient_id',v_recipient,'title',nullif(trim(p_draft->>'title'),''),'focus',p_draft->>'focus',
   'estimated_duration_minutes',(p_draft->>'estimated_duration_minutes')::integer,'exercises',v_rows);
 select * into v_existing from public.blind_workouts where id=v_id for update;
 if v_existing.id is not null then
   if v_existing.creator_id<>auth.uid() then raise exception 'forbidden'; end if;
   if v_existing.send_request is distinct from v_request then raise exception 'blind_request_conflict'; end if;
   return public.blind_state_document(v_id);
 end if;
 insert into public.blind_workouts(id,creator_id,recipient_id,title,focus,estimated_duration_minutes,exercise_count,send_request)
 values(v_id,auth.uid(),v_recipient,v_request->>'title',v_request->>'focus',(v_request->>'estimated_duration_minutes')::integer,jsonb_array_length(v_rows),v_request);
 for v_item in select value from jsonb_array_elements(v_rows) loop
   select * into v_exercise from public.exercises where id=(v_item->>'exercise_id')::uuid and not is_archived
     and (not is_custom or created_by=auth.uid()) for share;
   if v_exercise.id is null or v_exercise.exercise_type not in ('strength','timed') then raise exception 'exercise_not_available'; end if;
   v_sets:=(v_item->>'target_sets')::integer; v_min:=(v_item->>'target_reps_min')::integer; v_max:=(v_item->>'target_reps_max')::integer;
   v_weight:=(v_item->>'target_weight')::numeric; v_note:=v_item->>'note';
   if v_sets is null or v_sets not between 1 and 6 or v_min is null or v_max is null or v_min<1 or v_max<v_min
     or v_max>(case when v_exercise.exercise_type='timed' then 300 else 30 end)
     or (v_weight is not null and not(v_weight between 0 and 500)) or char_length(v_note)>500 then raise exception 'invalid_blind_targets'; end if;
   insert into public.blind_workout_exercises(blind_workout_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
   values(v_id,v_exercise.id,public.exercise_document(v_exercise.id),(v_item->>'sort_order')::integer,v_sets,v_min,v_max,v_weight,v_note);
 end loop;
 update public.blind_workouts b set
   required_equipment=array(select distinct e.exercise_snapshot->>'equipment' from public.blind_workout_exercises e where e.blind_workout_id=b.id order by 1),
   muscle_groups=array(select distinct muscle from (
     select e.exercise_snapshot->>'primary_muscle_group' muscle from public.blind_workout_exercises e where e.blind_workout_id=b.id
     union all select m from public.blind_workout_exercises e cross join jsonb_array_elements_text(e.exercise_snapshot->'secondary_muscles')m where e.blind_workout_id=b.id
   )muscles order by muscle) where b.id=v_id;
 if coalesce((select invitations from public.notification_preferences where user_id=v_recipient),true) then
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_recipient,auth.uid(),'blind_workout_received','Ein Blind Workout für dich 👀',
     jsonb_array_length(v_rows)||' Übungen · ca. '||(v_request->>'estimated_duration_minutes')||' Min.',jsonb_build_object('blind_workout_id',v_id)) on conflict do nothing;
 end if;
 return public.blind_state_document(v_id);
end; $$;

create function public.respond_blind_workout(p_id uuid,p_accept boolean,p_equipment_confirmed boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts;
begin
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or v_blind.recipient_id is distinct from auth.uid() or not public.are_friends(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 if p_accept is null then raise exception 'invalid_response'; end if;
 if p_accept and p_equipment_confirmed is distinct from true then raise exception 'equipment_confirmation_required'; end if;
 if (p_accept and v_blind.status in ('accepted','planned','live','completed')) or (not p_accept and v_blind.status='declined') then return public.blind_state_document(p_id); end if;
 if v_blind.status<>'sent' then raise exception 'blind_invalid_state'; end if;
 update public.blind_workouts set status=case when p_accept then 'accepted' else 'declined' end,
   equipment_confirmed=p_accept,accepted_at=case when p_accept then clock_timestamp() else null end,updated_at=clock_timestamp() where id=p_id;
 return public.blind_state_document(p_id);
end; $$;

create function public.guard_blind_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts;
begin
 if new.blind_workout_id is null then
   if tg_op='UPDATE' and old.blind_workout_id is not null then raise exception 'blind_activity_immutable'; end if;
   return new;
 end if;
 if tg_op='UPDATE' and new.blind_workout_id is distinct from old.blind_workout_id then raise exception 'blind_activity_immutable'; end if;
 select * into v_blind from public.blind_workouts where id=new.blind_workout_id;
 -- Preserve a safe exit even after creator account deletion removes the source.
 if v_blind.id is null and tg_op='UPDATE' and new.status='cancelled' then return new; end if;
 if v_blind.id is null or v_blind.recipient_id<>new.user_id or v_blind.activity_id is distinct from new.id
   or new.workout_plan_id is not null or new.planned_session_id is not null then raise exception 'invalid_blind_activity'; end if;
 if new.status='completed' and (v_blind.status<>'completed' or exists(select 1 from public.blind_workout_exercises where blind_workout_id=v_blind.id and not completed)) then
   raise exception 'blind_workout_finish_required';
 end if;
 if new.status='cancelled' and v_blind.status<>'cancelled' then raise exception 'blind_workout_cancel_required'; end if;
 if new.status='live' and v_blind.status<>'live' then raise exception 'blind_workout_start_required'; end if;
 return new;
end; $$;
create trigger activities_guard_blind before insert or update on public.activities for each row execute function public.guard_blind_activity();

create function public.plan_blind_workout(p_id uuid,p_starts_at timestamptz) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_activity uuid;
begin
 perform 1 from public.profiles where id=auth.uid() for no key update;
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or v_blind.recipient_id is distinct from auth.uid() or not public.are_friends(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 if v_blind.status not in ('accepted','planned') or not v_blind.equipment_confirmed then raise exception 'blind_invalid_state'; end if;
 if p_starts_at is null or not isfinite(p_starts_at) or p_starts_at<=clock_timestamp() then raise exception 'invalid_schedule'; end if;
 v_activity:=coalesce(v_blind.activity_id,gen_random_uuid());
 update public.blind_workouts set activity_id=v_activity,status='planned',scheduled_at=p_starts_at,updated_at=clock_timestamp() where id=p_id;
 insert into public.activities(id,user_id,sport,subtype,status,planned_at,planned_duration_minutes,exercise_count,blind_workout_id)
 values(v_activity,auth.uid(),'gym','Blind Workout','planned',p_starts_at,v_blind.estimated_duration_minutes,v_blind.exercise_count,p_id)
 on conflict(id) do update set planned_at=excluded.planned_at,updated_at=clock_timestamp();
 return public.blind_state_document(p_id);
end; $$;

create function public.start_blind_workout(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_activity uuid; v_now timestamptz; v_exercise public.blind_workout_exercises;
begin
 perform 1 from public.profiles where id=auth.uid() for no key update;
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or v_blind.recipient_id is distinct from auth.uid() or not public.are_friends(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 if v_blind.status in ('live','completed') then return public.blind_state_document(p_id); end if;
 if v_blind.status not in ('accepted','planned') or not v_blind.equipment_confirmed then raise exception 'blind_invalid_state'; end if;
 v_activity:=coalesce(v_blind.activity_id,gen_random_uuid());
 perform 1 from public.activities where id=v_activity for update;
 v_now:=clock_timestamp();
 update public.blind_workouts set activity_id=v_activity,status='live',started_at=v_now,updated_at=v_now where id=p_id;
 insert into public.activities(id,user_id,sport,subtype,status,started_at,planned_duration_minutes,exercise_count,blind_workout_id)
 values(v_activity,auth.uid(),'gym','Blind Workout','live',v_now,v_blind.estimated_duration_minutes,v_blind.exercise_count,p_id)
 on conflict(id) do update set status='live',started_at=v_now,updated_at=v_now;
 update public.blind_workout_exercises set revealed_at=v_now where blind_workout_id=p_id and sort_order=0 returning * into v_exercise;
 insert into public.blind_workout_sets(blind_workout_exercise_id,set_number) select v_exercise.id,n from generate_series(1,v_exercise.target_sets)n;
 return public.blind_state_document(p_id);
exception when unique_violation then raise exception 'already_live' using errcode='23505';
end; $$;

create function public.save_blind_workout_exercise(p_id uuid,p_exercise_id uuid,p_sets jsonb,p_complete boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_exercise public.blind_workout_exercises; v_next public.blind_workout_exercises;
 v_set jsonb; v_clean jsonb:='[]'::jsonb; v_existing jsonb; v_numbers int[]:='{}'; v_number integer;
 v_weight numeric; v_reps integer; v_completed boolean; v_now timestamptz;
begin
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or v_blind.recipient_id is distinct from auth.uid() or not public.are_friends(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 if v_blind.status not in ('live','completed') then raise exception 'blind_invalid_state'; end if;
 select * into v_exercise from public.blind_workout_exercises where id=p_exercise_id and blind_workout_id=p_id and revealed_at is not null for update;
 if v_exercise.id is null then raise exception 'forbidden'; end if;
 if p_complete is null or jsonb_typeof(p_sets) is distinct from 'array' or jsonb_array_length(p_sets)>6 then raise exception 'invalid_blind_sets'; end if;
 for v_set in select value from jsonb_array_elements(p_sets) loop
   if jsonb_typeof(v_set) is distinct from 'object' then raise exception 'invalid_blind_sets'; end if;
   v_number:=(v_set->>'set_number')::integer; v_weight:=(v_set->>'weight')::numeric; v_reps:=(v_set->>'reps')::integer;
   v_completed:=coalesce((v_set->>'completed')::boolean,false);
   if v_number is null or v_number not between 1 and 6 or v_number=any(v_numbers)
     or (v_weight is not null and not(v_weight between 0 and 500))
     or (v_reps is not null and (v_reps<0 or v_reps>case when v_exercise.exercise_snapshot->>'exercise_type'='timed' then 300 else 30 end)) then raise exception 'invalid_blind_sets'; end if;
   v_numbers:=array_append(v_numbers,v_number);
   v_clean:=v_clean||jsonb_build_array(jsonb_build_object('set_number',v_number,'weight',v_weight,'reps',v_reps,'completed',v_completed));
 end loop;
 select coalesce(jsonb_agg(value order by (value->>'set_number')::integer),'[]'::jsonb) into v_clean from jsonb_array_elements(v_clean);
 if v_exercise.completed then
   select coalesce(jsonb_agg(jsonb_build_object('set_number',set_number,'weight',weight,'reps',reps,'completed',completed) order by set_number),'[]'::jsonb)
     into v_existing from public.blind_workout_sets where blind_workout_exercise_id=p_exercise_id;
   if not p_complete or v_existing is distinct from v_clean then raise exception 'exercise_already_completed'; end if;
   return public.blind_state_document(p_id);
 end if;
 if v_blind.status<>'live' or exists(select 1 from public.blind_workout_exercises where blind_workout_id=p_id and sort_order<v_exercise.sort_order and not completed) then raise exception 'blind_invalid_state'; end if;
 v_now:=clock_timestamp();
 for v_set in select value from jsonb_array_elements(v_clean) loop
   insert into public.blind_workout_sets(blind_workout_exercise_id,set_number,weight,reps,completed,completed_at)
   values(p_exercise_id,(v_set->>'set_number')::integer,(v_set->>'weight')::numeric,(v_set->>'reps')::integer,(v_set->>'completed')::boolean,
     case when (v_set->>'completed')::boolean then v_now else null end)
   on conflict(blind_workout_exercise_id,set_number) do update set weight=excluded.weight,reps=excluded.reps,completed=excluded.completed,
     completed_at=case when excluded.completed then coalesce(blind_workout_sets.completed_at,v_now) else null end;
 end loop;
 delete from public.blind_workout_sets where blind_workout_exercise_id=p_exercise_id and not(set_number=any(v_numbers));
 if p_complete then
   update public.blind_workout_exercises set completed=true,completed_at=v_now where id=p_exercise_id;
   update public.blind_workout_exercises set revealed_at=coalesce(revealed_at,v_now)
   where blind_workout_id=p_id and sort_order=v_exercise.sort_order+1 returning * into v_next;
   if v_next.id is not null then
     insert into public.blind_workout_sets(blind_workout_exercise_id,set_number) select v_next.id,n from generate_series(1,v_next.target_sets)n on conflict do nothing;
   end if;
 end if;
 update public.blind_workouts set updated_at=v_now where id=p_id;
 return public.blind_state_document(p_id);
end; $$;

-- Dedicated finish is the sole bridge to the normal activity/week-credit path.
alter function public.complete_activity(uuid,integer) rename to complete_activity_before_blind;
revoke all on function public.complete_activity_before_blind(uuid,integer) from public,anon,authenticated;
create function public.complete_activity(p_activity_id uuid,p_distance_meters integer default null) returns public.activities
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.activities where id=p_activity_id and user_id=auth.uid() and blind_workout_id is not null) then raise exception 'blind_workout_finish_required'; end if;
 return public.complete_activity_before_blind(p_activity_id,p_distance_meters);
end; $$;
create function public.finish_blind_workout(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_activity public.activities;
begin
 perform 1 from public.profiles where id=auth.uid() for no key update;
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or v_blind.recipient_id is distinct from auth.uid() or not public.are_friends(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 if v_blind.status='completed' then return public.blind_state_document(p_id); end if;
 if v_blind.status<>'live' then raise exception 'blind_invalid_state'; end if;
 if exists(select 1 from public.blind_workout_exercises where blind_workout_id=p_id and not completed) then raise exception 'blind_exercises_remaining'; end if;
 update public.blind_workouts set status='completed',completed_at=clock_timestamp() where id=p_id;
 v_activity:=public.complete_activity_before_blind(v_blind.activity_id,null);
 update public.blind_workouts set completed_at=v_activity.ended_at,updated_at=v_activity.ended_at where id=p_id;
 if coalesce((select reactions from public.notification_preferences where user_id=v_blind.creator_id),true) then
   insert into public.notifications(recipient_id,actor_id,type,title,body,data)
   values(v_blind.creator_id,v_blind.recipient_id,'blind_workout_completed','Dein Blind Workout wurde geschafft 🔥',
     v_blind.exercise_count||' Übungen abgeschlossen.',jsonb_build_object('blind_workout_id',p_id)) on conflict do nothing;
 end if;
 return public.blind_state_document(p_id);
end; $$;

alter function public.cancel_activity(uuid) rename to cancel_activity_before_blind;
revoke all on function public.cancel_activity_before_blind(uuid) from public,anon,authenticated;
create function public.cancel_blind_workout(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_recipient uuid;
begin
 select recipient_id into v_recipient from public.blind_workouts where id=p_id and auth.uid() in(creator_id,recipient_id);
 if v_recipient is null then raise exception 'forbidden'; end if;
 perform 1 from public.profiles where id=v_recipient for no key update;
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if v_blind.id is null or auth.uid() not in(v_blind.creator_id,v_blind.recipient_id) then raise exception 'forbidden'; end if;
 -- No friendship check on cancellation: revocation must not trap a live timer.
 if v_blind.status='cancelled' then return public.blind_state_document(p_id,true); end if;
 if v_blind.status in ('completed','declined') or (auth.uid()=v_blind.creator_id and v_blind.status='live') then raise exception 'blind_invalid_state'; end if;
 update public.blind_workouts set status='cancelled',updated_at=clock_timestamp() where id=p_id;
 if v_blind.activity_id is not null then
   update public.activities set status='cancelled',updated_at=clock_timestamp()
   where id=v_blind.activity_id and status in ('planned','ready','live');
 end if;
 return public.blind_state_document(p_id,true);
end; $$;
create function public.cancel_activity(p_activity_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_blind uuid;
begin
 select blind_workout_id into v_blind from public.activities where id=p_activity_id and user_id=auth.uid();
 if v_blind is not null and exists(select 1 from public.blind_workouts where id=v_blind) then
   perform public.cancel_blind_workout(v_blind); return true;
 end if;
 return public.cancel_activity_before_blind(p_activity_id);
end; $$;

-- Generic log entry points expose only the already revealed recipient view.
-- Their mutation endpoint cannot bypass the ordered reveal/immutable completion.
alter function public.get_workout_log(uuid) rename to get_workout_log_before_blind;
alter function public.save_workout_log(jsonb) rename to save_workout_log_before_blind;
revoke all on function public.get_workout_log_before_blind(uuid),public.save_workout_log_before_blind(jsonb) from public,anon,authenticated;
create function public.get_workout_log(p_activity uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_blind uuid; v_state jsonb;
begin
 select blind_workout_id into v_blind from public.activities where id=p_activity and user_id=auth.uid();
 if v_blind is not null then
   v_state:=public.blind_state_document(v_blind);
   return jsonb_build_object('activity_id',p_activity,'plan_name','Blind Workout','exercises',v_state->'visible_exercises');
 end if;
 return public.get_workout_log_before_blind(p_activity);
end; $$;
create function public.save_workout_log(p_log jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.activities where id=(p_log->>'activity_id')::uuid and user_id=auth.uid() and blind_workout_id is not null) then raise exception 'blind_workout_tracking_required'; end if;
 return public.save_workout_log_before_blind(p_log);
end; $$;

create function public.copy_blind_workout(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_blind public.blind_workouts; v_plan uuid; v_exercise uuid; v_row public.blind_workout_exercises; v_map jsonb:='{}'::jsonb; v_name text;
begin
 select * into v_blind from public.blind_workouts where id=p_id for update;
 if not public.can_read_blind_workout(p_id) or (auth.uid()=v_blind.recipient_id and v_blind.status<>'completed') then raise exception 'forbidden'; end if;
 select c.plan_id into v_plan from public.blind_workout_copies c join public.workout_plans p on p.id=c.plan_id
 where c.blind_workout_id=p_id and c.owner_id=auth.uid() and not p.is_archived;
 if v_plan is not null then return public.workout_plan_document(v_plan); end if;
 v_plan:=gen_random_uuid();
 v_name:=coalesce(v_blind.title,'Blind Workout');
 if char_length(v_name)<2 then v_name:='Blind Workout · '||v_name; end if;
 insert into public.workout_plans(id,owner_id,name,category,visibility) values(v_plan,auth.uid(),v_name,v_blind.focus,'private');
 for v_row in select * from public.blind_workout_exercises where blind_workout_id=p_id order by sort_order loop
   v_exercise:=v_row.exercise_id;
   if (v_row.exercise_snapshot->>'is_custom')::boolean or v_exercise is null then
     v_exercise:=(v_map->>(v_row.exercise_snapshot->>'id'))::uuid;
     if v_exercise is null then
       v_exercise:=gen_random_uuid();
       perform public.save_exercise(v_row.exercise_snapshot||jsonb_build_object('id',v_exercise,'is_archived',false));
       v_map:=v_map||jsonb_build_object(v_row.exercise_snapshot->>'id',v_exercise);
     end if;
   end if;
   insert into public.workout_plan_exercises(workout_plan_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
   values(v_plan,v_exercise,public.exercise_document(v_exercise),v_row.sort_order,v_row.target_sets,v_row.target_reps_min,v_row.target_reps_max,v_row.target_weight,v_row.note);
 end loop;
 insert into public.blind_workout_copies(blind_workout_id,owner_id,plan_id) values(p_id,auth.uid(),v_plan)
 on conflict(blind_workout_id,owner_id) do update set plan_id=excluded.plan_id;
 return public.workout_plan_document(v_plan);
end; $$;

-- RLS applies to direct table access as well as the explicit RPC documents.
alter table public.blind_workouts enable row level security;
alter table public.blind_workout_exercises enable row level security;
alter table public.blind_workout_sets enable row level security;
alter table public.blind_workout_copies enable row level security;
alter table public.blind_workout_reactions enable row level security;
create policy blind_workouts_participants on public.blind_workouts for select to authenticated using(public.can_read_blind_workout(id));
create policy blind_exercises_reveal on public.blind_workout_exercises for select to authenticated using(public.can_read_blind_exercise(id));
create policy blind_actuals_recipient on public.blind_workout_sets for select to authenticated using(public.can_read_blind_actuals(blind_workout_exercise_id));
create policy blind_copies_owner on public.blind_workout_copies for select to authenticated using(owner_id=auth.uid());
create policy blind_reactions_participants on public.blind_workout_reactions for select to authenticated using(public.can_read_blind_workout(blind_workout_id));
revoke all on public.blind_workouts,public.blind_workout_exercises,public.blind_workout_sets,public.blind_workout_copies,public.blind_workout_reactions from public,anon,authenticated;
grant select(id,creator_id,recipient_id,title,focus,estimated_duration_minutes,exercise_count,required_equipment,muscle_groups,status,
 scheduled_at,accepted_at,started_at,completed_at,activity_id,created_at,updated_at) on public.blind_workouts to authenticated;
-- Target columns can be selected under reveal RLS; recipient tracking/reveal
-- timestamps stay RPC-only so a creator cannot inspect them through PostgREST.
grant select(id,blind_workout_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,target_weight,note)
 on public.blind_workout_exercises to authenticated;
grant select on public.blind_workout_sets,public.blind_workout_copies,public.blind_workout_reactions to authenticated;
revoke all on function public.blind_summary_document(uuid),public.blind_exercise_document(uuid,boolean),public.blind_state_document(uuid,boolean),public.guard_blind_activity() from public,anon,authenticated;
revoke all on function public.can_read_blind_workout(uuid),public.can_read_blind_exercise(uuid),public.can_read_blind_actuals(uuid),
 public.get_blind_workout(uuid),public.list_blind_workouts(),public.send_blind_workout(jsonb),public.respond_blind_workout(uuid,boolean,boolean),
 public.plan_blind_workout(uuid,timestamptz),public.start_blind_workout(uuid),public.save_blind_workout_exercise(uuid,uuid,jsonb,boolean),
 public.finish_blind_workout(uuid),public.cancel_blind_workout(uuid),public.copy_blind_workout(uuid),public.react_to_blind_workout(uuid,text),
 public.complete_activity(uuid,integer),public.cancel_activity(uuid),public.get_workout_log(uuid),public.save_workout_log(jsonb) from public,anon;
grant execute on function public.can_read_blind_workout(uuid),public.can_read_blind_exercise(uuid),public.can_read_blind_actuals(uuid),
 public.get_blind_workout(uuid),public.list_blind_workouts(),public.send_blind_workout(jsonb),public.respond_blind_workout(uuid,boolean,boolean),
 public.plan_blind_workout(uuid,timestamptz),public.start_blind_workout(uuid),public.save_blind_workout_exercise(uuid,uuid,jsonb,boolean),
 public.finish_blind_workout(uuid),public.cancel_blind_workout(uuid),public.copy_blind_workout(uuid),public.react_to_blind_workout(uuid,text),
 public.complete_activity(uuid,integer),public.cancel_activity(uuid),public.get_workout_log(uuid),public.save_workout_log(jsonb) to authenticated;

-- Nonparticipants can see an ordinary completed activity when its owner shares
-- activities with friends, but never a pre-completion Blind activity or sequence.
drop policy activities_read on public.activities;
create policy activities_read on public.activities for select to authenticated using(user_id=auth.uid() or
 (public.are_friends(user_id,auth.uid()) and exists(select 1 from public.profiles p where p.id=user_id and p.activity_visibility='friends')
 and (blind_workout_id is null or status='completed')));
alter function public.today_feed(text) rename to today_feed_before_blind;
revoke all on function public.today_feed_before_blind(text) from public,anon,authenticated;
create function public.today_feed(p_timezone text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_feed jsonb; v_member jsonb; v_activity jsonb; v_crew jsonb:='[]'::jsonb;
begin
 v_feed:=public.today_feed_before_blind(p_timezone);
 for v_member in select value from jsonb_array_elements(v_feed->'crew') loop
   v_activity:=v_member->'activity';
   if v_activity->>'blind_workout_id' is not null then
     if v_activity->>'status'<>'completed' then
       v_member:=jsonb_set(v_member,'{activity}','null'::jsonb);
     elsif not public.can_read_blind_workout((v_activity->>'blind_workout_id')::uuid) then
       v_member:=jsonb_set(v_member,'{activity}',v_activity-'blind_workout_id');
     end if;
   end if;
   v_crew:=v_crew||jsonb_build_array(v_member);
 end loop;
 return jsonb_set(v_feed,'{crew}',v_crew);
end; $$;
revoke all on function public.today_feed(text) from public,anon;
grant execute on function public.today_feed(text) to authenticated;

commit;
