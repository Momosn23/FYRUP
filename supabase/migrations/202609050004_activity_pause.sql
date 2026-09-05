begin;

-- Persist pause state so foreground/relaunch/another device sees the same timer.
-- Clients cannot write activity rows or these counters directly.
alter table public.activities
  add column paused_at timestamptz,
  add column paused_seconds integer not null default 0 check(paused_seconds>=0),
  add constraint activities_pause_only_live check(paused_at is null or status='live');

create function public.set_activity_paused(p_activity uuid,p_paused boolean)
returns public.activities language plpgsql security definer set search_path='' as $$
declare v_activity public.activities; v_now timestamptz := now();
begin
  if p_paused is null then raise exception 'invalid_pause'; end if;
  select * into v_activity from public.activities
  where id=p_activity and user_id=auth.uid() and status='live' for update;
  if v_activity.id is null then raise exception 'activity_not_live'; end if;

  if p_paused and v_activity.paused_at is null then
    update public.activities set paused_at=v_now,updated_at=v_now
    where id=v_activity.id returning * into v_activity;
  elsif not p_paused and v_activity.paused_at is not null then
    update public.activities
    set paused_seconds=paused_seconds+greatest(0,floor(extract(epoch from(v_now-paused_at)))::integer),
        paused_at=null,updated_at=v_now
    where id=v_activity.id returning * into v_activity;
  end if;
  return v_activity;
end; $$;

-- Completion keeps the established owner/live guard and distance semantics.
-- A paused finish consumes the final interval once; normal finish is unchanged.
create or replace function public.complete_activity(p_activity_id uuid,p_distance_meters integer default null)
returns public.activities language plpgsql security definer set search_path='' as $$
declare v_activity public.activities; v_now timestamptz := now();
begin
  update public.activities
  set status='completed',ended_at=v_now,distance_meters=p_distance_meters,updated_at=v_now,
      paused_seconds=paused_seconds+case when paused_at is null then 0
        else greatest(0,floor(extract(epoch from(v_now-paused_at)))::integer) end,
      paused_at=null
  where id=p_activity_id and user_id=auth.uid() and status='live'
  returning * into v_activity;
  if v_activity.id is null then raise exception 'activity_not_live'; end if;
  return v_activity;
end; $$;

-- All existing cancellation paths (including session/account cleanup) remain valid.
create function public.finalize_activity_pause() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.status<>'live' and new.paused_at is not null then
    new.paused_seconds := new.paused_seconds+greatest(0,floor(extract(epoch from(now()-new.paused_at)))::integer);
    new.paused_at := null;
  end if;
  return new;
end; $$;
create trigger activities_finalize_pause before update of status on public.activities
for each row execute function public.finalize_activity_pause();

revoke all on function public.set_activity_paused(uuid,boolean),public.complete_activity(uuid,integer) from public,anon;
revoke all on function public.finalize_activity_pause() from public,anon,authenticated;
grant execute on function public.set_activity_paused(uuid,boolean),public.complete_activity(uuid,integer) to authenticated;

commit;
