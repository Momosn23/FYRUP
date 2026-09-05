-- Disposable database only. Real authenticated role/RLS; all fixtures roll back.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values
 ('ac100000-0000-0000-0000-000000000001'),
 ('ac100000-0000-0000-0000-000000000002'),
 ('ac100000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,display_name) values
 ('ac100000-0000-0000-0000-000000000001','qa_copy_owner','Owner'),
 ('ac100000-0000-0000-0000-000000000002','qa_copy_friend','Friend'),
 ('ac100000-0000-0000-0000-000000000003','qa_copy_stranger','Stranger');
insert into public.friendships(requester_id,addressee_id,status) values
 ('ac100000-0000-0000-0000-000000000001','ac100000-0000-0000-0000-000000000002','accepted');
create temporary table qa_copy(key text primary key,value jsonb);
grant all on qa_copy to authenticated;

select ok(not has_function_privilege('anon','public.copy_workout_plan(uuid,uuid)','execute'),'anonymous cannot copy');
select ok(not has_function_privilege('authenticated','public.copy_workout_plan(uuid)','execute'),'old non-idempotent API is not callable');
select ok(has_function_privilege('authenticated','public.copy_workout_plan(uuid,uuid)','execute'),'authenticated can use request-bound API');
select ok(not has_table_privilege('authenticated','public.workout_plan_copy_requests','select'),'request receipts are not client-readable');
select ok(not has_table_privilege('authenticated','public.workout_plan_copy_requests','insert'),'caller cannot forge receipts');
select ok((select relrowsecurity from pg_class where oid='public.workout_plan_copy_requests'::regclass),'receipt table has RLS');
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')$$,'P0001','unauthorized','missing user cannot copy even through privileged test connection');

set local role authenticated;
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000001',true);
insert into qa_copy values('custom',public.save_exercise('{"id":"bc100000-0000-0000-0000-000000000001","name":"Prime Copy Press","primary_muscle_group":"chest","equipment":"machine","secondary_muscles":["triceps"]}'));
insert into qa_copy values('source',public.save_workout_plan(jsonb_build_object(
 'id','cc100000-0000-0000-0000-000000000001','name','Shared Push','visibility','private',
 'exercises',jsonb_build_array(
   jsonb_build_object('exercise',(select value from qa_copy where key='custom'),'target_sets',3,'target_reps_min',8,'target_reps_max',12,'target_weight',80),
   jsonb_build_object('exercise',(select value from qa_copy where key='custom'),'target_sets',2,'target_reps_min',10,'target_reps_max',12)))));
insert into qa_copy values('second_source',public.save_workout_plan(jsonb_build_object(
 'id','cc100000-0000-0000-0000-000000000002','name','Other Plan','visibility','friends',
 'exercises',jsonb_build_array(jsonb_build_object('exercise',(select value from qa_copy where key='custom'),'target_sets',3,'target_reps_min',8,'target_reps_max',12)))));
select throws_ok($$select public.copy_workout_plan(null,'ec100000-0000-0000-0000-000000000001')$$,'P0001','invalid_copy_request','missing source rejected');
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001',null)$$,'P0001','invalid_copy_request','missing request rejected');

select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')$$,'P0001','forbidden','accepted friend still needs private-plan share');
reset role;
select is((select count(*) from public.workout_plan_copy_requests),0::bigint,'failed authorization does not reserve a request');
set local role authenticated;
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000001',true);
select public.share_workout_plan('cc100000-0000-0000-0000-000000000001',array['ac100000-0000-0000-0000-000000000002']::uuid[]);
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000002',true);
insert into qa_copy values('first',public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001'));
select is((select value->>'owner_id' from qa_copy where key='first'),auth.uid()::text,'copy belongs to caller');
select is((select value->>'copy_request_id' from qa_copy where key='first'),'ec100000-0000-0000-0000-000000000001','response binds request ID');
select is((select value->>'visibility' from qa_copy where key='first'),'private','new copy starts private');
select isnt((select value->>'id' from qa_copy where key='first'),'cc100000-0000-0000-0000-000000000001','copy has independent plan ID');
select is((select value->'exercises'->0->'exercise'->>'id'=value->'exercises'->1->'exercise'->>'id' from qa_copy where key='first'),true,'repeated custom exercise copied once');
select isnt((select value->'exercises'->0->'exercise'->>'id' from qa_copy where key='first'),'bc100000-0000-0000-0000-000000000001','copied custom ID independent');
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001'),(select value from qa_copy where key='first'),'exact retry returns same complete receipt');
select is((select count(*) from public.workout_plans where owner_id=auth.uid()),1::bigint,'retry creates no extra plan');
select is((select count(*) from public.exercises where created_by=auth.uid()),1::bigint,'retry creates no extra custom exercises');
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000002','ec100000-0000-0000-0000-000000000001')$$,'P0001','copy_request_mismatch','a request cannot be rebound to another source');
insert into qa_copy values('second',public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000002'));
select isnt((select value->>'id' from qa_copy where key='second'),(select value->>'id' from qa_copy where key='first'),'new request intentionally creates another independent plan');
select is((select count(*) from public.workout_plans where owner_id=auth.uid()),2::bigint,'intentional second copy is the only additional plan');
select lives_ok($$select public.save_exercise((select value->'exercises'->0->'exercise' from qa_copy where key='first')||'{"name":"My Own Press"}')$$,'copy owner can change copied exercise');
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','My Own Press','retry returns current owned copy rather than stale snapshot');
select is(public.get_workout_plan('cc100000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','Prime Copy Press','source unaffected by copy edits');

-- Force a failure after all copy rows exist but before the receipt is inserted.
-- Its subtransaction must roll back the plan AND custom copies AND request.
reset role;
create function pg_temp.reject_copy_receipt() returns trigger language plpgsql as $$
begin
 if new.request_id='ec100000-0000-0000-0000-000000000009'::uuid then raise exception 'test_receipt_failure'; end if;
 return new;
end;
$$;
create trigger qa_reject_copy_receipt before insert on public.workout_plan_copy_requests for each row execute function pg_temp.reject_copy_receipt();
set local role authenticated;
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000009')$$,'P0001','test_receipt_failure','receipt failure aborts complete copy transaction');
select is((select count(*) from public.workout_plans where owner_id=auth.uid()),2::bigint,'receipt failure leaves no orphan plan');
select is((select count(*) from public.exercises where created_by=auth.uid()),2::bigint,'receipt failure leaves no orphan custom exercises');
reset role;
select is((select count(*) from public.workout_plan_copy_requests where request_id='ec100000-0000-0000-0000-000000000009'),0::bigint,'receipt failure leaves no false confirmed request');
drop trigger qa_reject_copy_receipt on public.workout_plan_copy_requests;
set local role authenticated;

select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000001',true);
insert into qa_copy values('owner_copy',public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001'));
select isnt((select value->>'id' from qa_copy where key='owner_copy'),(select value->>'id' from qa_copy where key='first'),'same request UUID on another account does not retrieve friend data');
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')$$,'P0001','forbidden','stranger cannot replay known request UUID');

-- Revocation does not revoke ownership of an already-independent copy.
reset role;
insert into public.blocks(blocker_id,blocked_id) values('ac100000-0000-0000-0000-000000000001','ac100000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000002',true);
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')->>'id',(select value->>'id' from qa_copy where key='first'),'lost-response retry works after a block');
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000003')$$,'P0001','forbidden','new copy after block is forbidden');
select public.archive_workout_plan((select (value->>'id')::uuid from qa_copy where key='second'));
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000002')$$,'P0001','copy_result_unavailable','archived receipt never silently creates replacement');
reset role;
delete from public.workout_plans where id=(select (value->>'id')::uuid from qa_copy where key='second');
set local role authenticated;
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000002')$$,'P0001','copy_result_unavailable','deleted receipt leaves tombstone, no replacement');
reset role;
delete from public.profiles where id='ac100000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','ac100000-0000-0000-0000-000000000002',true);
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')->>'id',(select value->>'id' from qa_copy where key='first'),'owned copy retry survives original account deletion');
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')->>'copied_from_plan_id',null::text,'deleted source is not fabricated in plan provenance');
select is(public.copy_workout_plan('cc100000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','My Own Press','independent custom survives original deletion');
reset role;
select is((select count(*) from public.workout_plan_copy_requests where user_id='ac100000-0000-0000-0000-000000000001'),0::bigint,'account deletion removes its request metadata');
select is((select count(*) from public.workout_plan_copy_requests where user_id='ac100000-0000-0000-0000-000000000002'),2::bigint,'other account receipts retain retry and tombstone');
delete from public.profiles where id='ac100000-0000-0000-0000-000000000002';
select is((select count(*) from public.workout_plan_copy_requests),0::bigint,'last owner deletion clears all receipts');
select * from finish();
rollback;
