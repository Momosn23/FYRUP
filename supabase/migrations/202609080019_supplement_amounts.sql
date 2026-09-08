-- Optional, user-authored amounts. No dosage recommendations or public sharing.
begin;
alter table public.supplement_plans add column if not exists amount jsonb;
do $$ begin
 if not exists(select 1 from pg_constraint where conrelid='public.supplement_plans'::regclass and conname='supplement_amount_valid') then
  alter table public.supplement_plans add constraint supplement_amount_valid check (
   amount is null or coalesce((
    jsonb_typeof(amount)='object' and jsonb_typeof(amount->'value')='number'
    and jsonb_typeof(amount->'unit')='string'
    and (amount->>'value')::numeric > 0 and (amount->>'value')::numeric <= 1000000
    and amount->>'unit' in ('g','mg','mcg','ml','iu','capsule','tablet','drop','portion','piece')
    and amount ? 'value' and amount ? 'unit'),false));
 end if;
end $$;

create or replace function public.save_supplement_plan(p_plan jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_id uuid; v_old public.supplement_plans; v_saved public.supplement_plans; v_slot jsonb; v_days integer[]; v_ids uuid[]:='{}'; v_minutes integer[]:='{}'; v_amount jsonb;
begin
 if v_owner is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_plan) is distinct from 'object' or lower(p_plan->>'owner_id') is distinct from v_owner::text
 or coalesce(p_plan->>'id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
 or jsonb_typeof(p_plan->'revision') is distinct from 'number' or coalesce(p_plan->>'revision','') !~ '^[0-9]{1,9}$'
 or jsonb_typeof(p_plan->'name') is distinct from 'string' or char_length(btrim(p_plan->>'name')) not between 1 and 60
 or jsonb_typeof(p_plan->'weekdays') is distinct from 'array' or jsonb_typeof(p_plan->'slots') is distinct from 'array'
 or jsonb_typeof(p_plan->'is_paused') is distinct from 'boolean' or jsonb_typeof(p_plan->'is_archived') is distinct from 'boolean'
 or jsonb_typeof(p_plan->'reminders_enabled') is distinct from 'boolean'
 or jsonb_typeof(p_plan->'repeat_minutes') is distinct from 'number' or coalesce(p_plan->>'repeat_minutes','') not in ('15','30','60','120','180')
 or jsonb_typeof(p_plan->'repeat_count') is distinct from 'number' or coalesce(p_plan->>'repeat_count','') !~ '^[0-3]$' then raise exception 'invalid_supplement'; end if;
 if jsonb_array_length(p_plan->'weekdays') not between 1 and 7 or exists(select 1 from jsonb_array_elements(p_plan->'weekdays') d where jsonb_typeof(d)<>'number' or d::text !~ '^[1-7]$') then raise exception 'invalid_supplement'; end if;
 select array_agg((d::text)::integer order by (d::text)::integer) into v_days from jsonb_array_elements(p_plan->'weekdays') d;
 if cardinality(v_days)<>(select count(distinct d) from unnest(v_days) d) or jsonb_array_length(p_plan->'slots') not between 1 and 4 then raise exception 'invalid_supplement'; end if;
 for v_slot in select value from jsonb_array_elements(p_plan->'slots') loop
  if jsonb_typeof(v_slot) is distinct from 'object' or coalesce(v_slot->>'id','') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
  or jsonb_typeof(v_slot->'minute') is distinct from 'number' or coalesce(v_slot->>'minute','') !~ '^[0-9]{1,4}$' then raise exception 'invalid_supplement'; end if;
  if (v_slot->>'minute')::integer>1439 or (v_slot->>'id')::uuid=any(v_ids) or (v_slot->>'minute')::integer=any(v_minutes) then raise exception 'invalid_supplement'; end if;
  v_ids:=array_append(v_ids,(v_slot->>'id')::uuid); v_minutes:=array_append(v_minutes,(v_slot->>'minute')::integer);
 end loop;
 perform 1 from public.profiles where id=v_owner for update;
 if not found then raise exception 'profile_required'; end if;
 if not exists(select 1 from public.supplement_settings where owner_id=v_owner) then raise exception 'settings_required'; end if;
 v_id:=(p_plan->>'id')::uuid;
 select * into v_old from public.supplement_plans where id=v_id;
 if found and v_old.owner_id<>v_owner then raise exception 'unauthorized'; end if;
 v_amount:=case when p_plan ? 'amount' then nullif(p_plan->'amount','null'::jsonb) else v_old.amount end;
 if v_amount is not null then
  if jsonb_typeof(v_amount) is distinct from 'object'
   or jsonb_typeof(v_amount->'value') is distinct from 'number'
   or jsonb_typeof(v_amount->'unit') is distinct from 'string' then raise exception 'invalid_supplement_amount'; end if;
  if (v_amount->>'value')::numeric <= 0 or (v_amount->>'value')::numeric > 1000000
   or v_amount->>'unit' not in ('g','mg','mcg','ml','iu','capsule','tablet','drop','portion','piece') then raise exception 'invalid_supplement_amount'; end if;
 end if;
 if coalesce(v_old.revision,0)<>(p_plan->>'revision')::integer then raise exception 'supplement_conflict'; end if;
 if not (p_plan->>'is_archived')::boolean and (select count(*) from public.supplement_plans where owner_id=v_owner and not is_archived and id<>v_id)>=20 then raise exception 'supplement_limit'; end if;
 insert into public.supplement_plans(id,owner_id,name,weekdays,slots,is_paused,is_archived,reminders_enabled,repeat_minutes,repeat_count,amount)
 values(v_id,v_owner,btrim(p_plan->>'name'),v_days,p_plan->'slots',(p_plan->>'is_paused')::boolean,(p_plan->>'is_archived')::boolean,(p_plan->>'reminders_enabled')::boolean,(p_plan->>'repeat_minutes')::integer,(p_plan->>'repeat_count')::integer,v_amount)
 on conflict(id) do update set revision=public.supplement_plans.revision+1,name=excluded.name,weekdays=excluded.weekdays,slots=excluded.slots,is_paused=excluded.is_paused,is_archived=excluded.is_archived,reminders_enabled=excluded.reminders_enabled,repeat_minutes=excluded.repeat_minutes,repeat_count=excluded.repeat_count,amount=excluded.amount,updated_at=now()
 returning * into v_saved;
 update public.notifications n set push_sent_at=now() from public.supplement_reminder_jobs j join public.supplement_doses d on d.id=j.dose_id
 where n.id=j.notification_id and d.plan_id=v_id and n.push_sent_at is null;
 perform public.materialize_supplement_day(v_owner,now());
 return to_jsonb(v_saved);
end; $$;

revoke all on function public.save_supplement_plan(jsonb) from public,anon;
grant execute on function public.save_supplement_plan(jsonb) to authenticated;
commit;
