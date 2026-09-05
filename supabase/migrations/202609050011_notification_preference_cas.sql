-- Atomic compare-and-save prevents a second device's new opt-out from being
-- overwritten between a form's preflight read and its whole-record write.
begin;

create function public.save_notification_preferences_cas(p_expected jsonb,p_desired jsonb)
returns public.notification_preferences
language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid();
 v_row public.notification_preferences;
 v_current jsonb;
 v_keys text[]:=array['friend_starts','fyrup','invitations','reactions','friend_requests','reminders','weekly_goal','crew_goal'];
begin
 if v_user is null or not exists(select 1 from public.profiles where id=v_user) then raise exception 'forbidden'; end if;
 if p_expected is null or p_desired is null or jsonb_typeof(p_expected) is distinct from 'object'
   or jsonb_typeof(p_desired) is distinct from 'object' then raise exception 'invalid_notification_preferences'; end if;
 if not (p_expected ?& v_keys) or not (p_desired ?& v_keys)
   or exists(select 1 from jsonb_each(p_expected) where not (key=any(v_keys)) or jsonb_typeof(value)<>'boolean')
   or exists(select 1 from jsonb_each(p_desired) where not (key=any(v_keys)) or jsonb_typeof(value)<>'boolean')
   then raise exception 'invalid_notification_preferences'; end if;

 insert into public.notification_preferences(user_id) values(v_user) on conflict(user_id) do nothing;
 select * into v_row from public.notification_preferences where user_id=v_user for update;
 v_current:=jsonb_build_object('friend_starts',v_row.friend_starts,'fyrup',v_row.fyrup,
   'invitations',v_row.invitations,'reactions',v_row.reactions,'friend_requests',v_row.friend_requests,
   'reminders',v_row.reminders,'weekly_goal',v_row.weekly_goal,'crew_goal',v_row.crew_goal);
 -- An identical saved outcome is an idempotent retry, not another preference change.
 if v_current=p_desired then return v_row; end if;
 if v_current<>p_expected then raise exception 'notification_preferences_conflict'; end if;
 update public.notification_preferences set
   friend_starts=(p_desired->>'friend_starts')::boolean,
   fyrup=(p_desired->>'fyrup')::boolean,
   invitations=(p_desired->>'invitations')::boolean,
   reactions=(p_desired->>'reactions')::boolean,
   friend_requests=(p_desired->>'friend_requests')::boolean,
   reminders=(p_desired->>'reminders')::boolean,
   weekly_goal=(p_desired->>'weekly_goal')::boolean,
   crew_goal=(p_desired->>'crew_goal')::boolean,
   updated_at=clock_timestamp()
 where user_id=v_user returning * into v_row;
 return v_row;
end; $$;

-- Owner SELECT remains available. New clients cannot bypass CAS with a direct
-- table update; creation still happens inside the read/save security-definer RPCs.
revoke insert,update,delete on public.notification_preferences from public,anon,authenticated;
grant select on public.notification_preferences to authenticated;
revoke all on function public.save_notification_preferences_cas(jsonb,jsonb) from public,anon;
grant execute on function public.save_notification_preferences_cas(jsonb,jsonb) to authenticated;
revoke all on function public.get_notification_preferences(),
 public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.get_notification_preferences(),
 public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean) to authenticated;
-- The old eight-boolean RPC remains for previously installed versions. Only the
-- new required-expected RPC provides multi-device CAS; new clients never call it.
comment on function public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)
 is 'Legacy compatibility only; new clients must use save_notification_preferences_cas(expected,desired).';

commit;
