begin;

-- Keep a small owner-bound receipt even if the original or resulting plan is
-- deleted. A retry must never silently become a different mutation.
create table public.workout_plan_copy_requests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  source_plan_id uuid not null,
  copy_plan_id uuid references public.workout_plans(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(user_id,request_id),
  unique(copy_plan_id),
  check(copy_plan_id is null or copy_plan_id<>source_plan_id)
);
alter table public.workout_plan_copy_requests enable row level security;
revoke all on table public.workout_plan_copy_requests from public,anon,authenticated;

create function public.copy_workout_plan(p_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 v_user uuid := auth.uid();
 v_request public.workout_plan_copy_requests;
 v_copy public.workout_plans;
 v_result jsonb;
begin
 if v_user is null then raise exception 'unauthorized'; end if;
 if p_id is null or p_request_id is null then raise exception 'invalid_copy_request'; end if;
 -- Same caller/request serializes before checking the receipt; first copy and
 -- receipt commit together. Different callers cannot claim one another's key.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text || ':' || p_request_id::text,10010));
 select * into v_request from public.workout_plan_copy_requests
 where user_id=v_user and request_id=p_request_id;
 if found then
   if v_request.source_plan_id<>p_id then raise exception 'copy_request_mismatch'; end if;
   select * into v_copy from public.workout_plans
   where id=v_request.copy_plan_id and owner_id=v_user and not is_archived for share;
   if v_copy.id is null then raise exception 'copy_result_unavailable'; end if;
   -- Already-owned, independent data stays readable after source revocation.
   return public.workout_plan_document(v_copy.id) || jsonb_build_object('copy_request_id',p_request_id);
 end if;

 -- The legacy helper still owns the deep-copy implementation (including one
 -- independent custom exercise per original ID). It is no longer public API.
 -- Lock ordered source children against save/archive before authorizing and
 -- copying. Authorization is never replaced with caller-provided snapshots.
 perform 1 from public.workout_plans where id=p_id for share;
 if not public.can_read_workout_plan(p_id) then raise exception 'forbidden'; end if;
 v_result := public.copy_workout_plan(p_id);
 insert into public.workout_plan_copy_requests(user_id,request_id,source_plan_id,copy_plan_id)
 values(v_user,p_request_id,p_id,(v_result->>'id')::uuid);
 return v_result || jsonb_build_object('copy_request_id',p_request_id);
end;
$$;

-- Never permit a legacy client to bypass retry identity. Existing builds without
-- the new contract must update instead of accidentally creating another copy.
revoke all on function public.copy_workout_plan(uuid) from public,anon,authenticated;
revoke all on function public.copy_workout_plan(uuid,uuid) from public,anon;
grant execute on function public.copy_workout_plan(uuid,uuid) to authenticated;

commit;
