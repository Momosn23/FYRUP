begin;

alter table public.planned_sessions
  add column if not exists place_name text;

alter table public.planned_sessions
  drop constraint if exists planned_sessions_place_name_length;
alter table public.planned_sessions
  add constraint planned_sessions_place_name_length check (char_length(place_name) <= 120);

create or replace function public.plan_session(
  p_sport public.sport_kind,
  p_subtype text,
  p_starts_at timestamptz,
  p_duration_minutes smallint,
  p_note text,
  p_place_name text,
  p_friends_can_join boolean,
  p_invitees uuid[]
) returns public.planned_sessions
language plpgsql security definer set search_path='' as $$
declare v public.planned_sessions; invitee uuid;
begin
  if p_starts_at < now() then raise exception 'start_in_past'; end if;
  insert into public.planned_sessions(host_id,sport,subtype,starts_at,duration_minutes,note,place_name,friends_can_join)
  values(auth.uid(),p_sport,p_subtype,p_starts_at,p_duration_minutes,nullif(trim(p_note),''),nullif(trim(p_place_name),''),coalesce(p_friends_can_join,true))
  returning * into v;

  insert into public.activities(user_id,sport,subtype,status,planned_at,planned_duration_minutes,note,planned_session_id)
  values(auth.uid(),p_sport,p_subtype,'planned',p_starts_at,p_duration_minutes,nullif(trim(p_note),''),v.id);

  foreach invitee in array coalesce(p_invitees,'{}') loop
    if public.are_friends(auth.uid(),invitee) then
      insert into public.session_invites(session_id,invitee_id) values(v.id,invitee) on conflict do nothing;
      insert into public.notifications(recipient_id,actor_id,type,title,body,data)
      values(invitee,auth.uid(),'session_invite','Trainingseinladung 🔥',p_sport::text||' · '||to_char(p_starts_at at time zone 'UTC','DD.MM. HH24:MI'),jsonb_build_object('session_id',v.id));
    end if;
  end loop;
  return v;
end; $$;

create or replace function public.update_planned_session(
  p_session uuid,
  p_starts_at timestamptz,
  p_duration_minutes smallint,
  p_note text,
  p_place_name text,
  p_friends_can_join boolean
) returns public.planned_sessions
language plpgsql security definer set search_path='' as $$
declare v public.planned_sessions;
begin
  if p_starts_at < now() then raise exception 'start_in_past'; end if;
  update public.planned_sessions
  set starts_at=p_starts_at,
      duration_minutes=p_duration_minutes,
      note=nullif(trim(p_note),''),
      place_name=nullif(trim(p_place_name),''),
      friends_can_join=coalesce(p_friends_can_join,true),
      reminder_sent_at=null,
      updated_at=now()
  where id=p_session and host_id=auth.uid() and status in ('planned','ready')
  returning * into v;
  if v.id is null then raise exception 'session_not_editable'; end if;

  update public.activities
  set planned_at=v.starts_at,planned_duration_minutes=v.duration_minutes,note=v.note,updated_at=now()
  where planned_session_id=v.id and status in ('planned','ready');

  insert into public.notifications(recipient_id,actor_id,type,title,body,data)
  select invitee_id,auth.uid(),'session_updated','Training wurde aktualisiert',
         v.sport::text||' · '||to_char(v.starts_at at time zone 'UTC','DD.MM. HH24:MI'),
         jsonb_build_object('session_id',v.id)
  from public.session_invites where session_id=v.id and status in ('pending','accepted','maybe');
  return v;
end; $$;

create or replace function public.my_hosted_sessions() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'session',to_jsonb(s),
    'participants',coalesce((
      select jsonb_agg(jsonb_build_object('status',i.status,'profile',to_jsonb(p)) order by p.display_name)
      from public.session_invites i join public.profiles p on p.id=i.invitee_id
      where i.session_id=s.id
    ),'[]'::jsonb)
  ) order by s.starts_at),'[]'::jsonb)
  from public.planned_sessions s
  where s.host_id=auth.uid() and s.status not in ('completed','cancelled') and s.starts_at>now()-interval '6 hours';
$$;

revoke execute on function public.plan_session(public.sport_kind,text,timestamptz,smallint,text,text,boolean,uuid[]) from public,anon;
revoke execute on function public.update_planned_session(uuid,timestamptz,smallint,text,text,boolean) from public,anon;
revoke execute on function public.my_hosted_sessions() from public,anon;
grant execute on function public.plan_session(public.sport_kind,text,timestamptz,smallint,text,text,boolean,uuid[]) to authenticated;
grant execute on function public.update_planned_session(uuid,timestamptz,smallint,text,text,boolean) to authenticated;
grant execute on function public.my_hosted_sessions() to authenticated;

commit;
