begin;

create or replace function public.remove_friend(p_friend uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  delete from public.friendships
  where status='accepted'
    and ((requester_id=auth.uid() and addressee_id=p_friend) or (requester_id=p_friend and addressee_id=auth.uid()));
  if not found then return false; end if;

  update public.activities a set status='cancelled',updated_at=now()
  from public.session_invites i join public.planned_sessions s on s.id=i.session_id
  where a.planned_session_id=s.id and a.user_id=i.invitee_id and a.status in ('planned','ready')
    and s.status in ('planned','ready')
    and ((s.host_id=auth.uid() and i.invitee_id=p_friend) or (s.host_id=p_friend and i.invitee_id=auth.uid()));

  delete from public.session_invites i using public.planned_sessions s
  where i.session_id=s.id and s.status in ('planned','ready')
    and ((s.host_id=auth.uid() and i.invitee_id=p_friend) or (s.host_id=p_friend and i.invitee_id=auth.uid()));
  return true;
end; $$;

create or replace function public.block_user(p_blocked uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if p_blocked=auth.uid() then raise exception 'not_allowed'; end if;

  update public.activities a set status='cancelled',updated_at=now()
  from public.session_invites i join public.planned_sessions s on s.id=i.session_id
  where a.planned_session_id=s.id and a.user_id=i.invitee_id and a.status in ('planned','ready')
    and s.status in ('planned','ready')
    and ((s.host_id=auth.uid() and i.invitee_id=p_blocked) or (s.host_id=p_blocked and i.invitee_id=auth.uid()));

  delete from public.session_invites i using public.planned_sessions s
  where i.session_id=s.id and s.status in ('planned','ready')
    and ((s.host_id=auth.uid() and i.invitee_id=p_blocked) or (s.host_id=p_blocked and i.invitee_id=auth.uid()));

  insert into public.blocks values(auth.uid(),p_blocked,now()) on conflict do nothing;
  delete from public.friendships
  where (requester_id=auth.uid() and addressee_id=p_blocked) or (requester_id=p_blocked and addressee_id=auth.uid());
  return true;
end; $$;

create or replace function public.my_session_invites() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('session_id',i.session_id,'status',i.status,'session',to_jsonb(s),'host',to_jsonb(p)) order by s.starts_at),'[]'::jsonb)
  from public.session_invites i
  join public.planned_sessions s on s.id=i.session_id
  join public.profiles p on p.id=s.host_id
  where i.invitee_id=auth.uid()
    and s.status not in ('completed','cancelled')
    and s.starts_at>now()-interval '6 hours'
    and (i.status<>'pending' or s.starts_at>now())
    and not public.is_blocked(s.host_id,auth.uid());
$$;

commit;
