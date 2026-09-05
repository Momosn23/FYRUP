-- Run against a disposable reset database only. All fixtures are rolled back.
-- Tests use actual authenticated role/RLS and RPCs, not service-role-only assertions.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values
 ('a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000002'),
 ('a0000000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,display_name) values
 ('a0000000-0000-0000-0000-000000000001','qa_plan_owner','Owner'),
 ('a0000000-0000-0000-0000-000000000002','qa_plan_friend','Friend'),
 ('a0000000-0000-0000-0000-000000000003','qa_plan_stranger','Stranger');
insert into public.friendships(requester_id,addressee_id,status) values
 ('a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','accepted');
create temporary table qa_workout_state(key text primary key,value jsonb);
grant all on qa_workout_state to authenticated;

select ok(not has_function_privilege('anon','public.list_exercises()','execute'),'anonymous cannot call catalog RPC');
select ok(not has_function_privilege('authenticated','public.exercise_document(uuid)','execute'),'internal exercise helper not exposed');
select ok(not has_function_privilege('authenticated','public.workout_plan_document(uuid)','execute'),'internal plan helper not exposed');
select ok(not has_table_privilege('authenticated','public.workout_plans','insert'),'direct plan inserts denied');
select ok(not has_table_privilege('authenticated','public.workout_set_logs','update'),'direct set writes denied');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is(jsonb_array_length(public.list_exercises()),122,'complete standard library available to owner');
insert into qa_workout_state values('custom',public.save_exercise('{
 "id":"b0000000-0000-0000-0000-000000000001","name":"Prime Chest Press","primary_muscle_group":"chest",
 "secondary_muscles":["triceps","shoulders"],"equipment":"machine","exercise_type":"strength","note":"Sitz 3"
}'));
select is((select value->>'created_by' from qa_workout_state where key='custom'),'a0000000-0000-0000-0000-000000000001','custom creator is authenticated account');
select throws_ok($$select public.save_exercise('{"name":"Bad metadata","primary_muscle_group":"chest","secondary_muscles":{}}')$$,'P0001','invalid_exercise','non-array secondary muscles rejected');
select is(jsonb_array_length(public.list_exercises()),123,'own custom exercise searchable with standards');
select throws_ok($$select public.save_exercise('{"id":"10000000-0000-0000-0000-000000000001","name":"Changed"}')$$,'P0001','forbidden','standard exercise immutable');
select lives_ok($$select public.set_exercise_favorite('b0000000-0000-0000-0000-000000000001',true)$$,'favorite can be saved');
select is(jsonb_array_length(public.list_exercise_favorites()),1,'favorites persisted per account');
insert into qa_workout_state values('plan',public.save_workout_plan(jsonb_build_object(
 'id','c0000000-0000-0000-0000-000000000001','name','Push Day','category','Push',
 'exercises',jsonb_build_array(
  jsonb_build_object('id','d0000000-0000-0000-0000-000000000001','exercise',(select value from qa_workout_state where key='custom'),'target_sets',3,'target_reps_min',8,'target_reps_max',12,'target_weight',80),
  jsonb_build_object('id','d0000000-0000-0000-0000-000000000002','exercise',jsonb_build_object('id','10000000-0000-0000-0000-000000000001'),'target_sets',3,'target_reps_min',8,'target_reps_max',12)
 ))));
select is((select value->>'visibility' from qa_workout_state where key='plan'),'private','new plan defaults private');
select is(jsonb_array_length(public.get_workout_plan('c0000000-0000-0000-0000-000000000001')->'exercises'),2,'plan persists full exercise list');
select throws_ok($$select public.save_workout_plan('{"name":"No exercises"}')$$,'P0001','invalid_plan','missing exercise array rejected');
select throws_ok($$select public.save_workout_plan((select value from qa_workout_state where key='plan') || jsonb_build_object('exercises',jsonb_build_array((select value->'exercises'->0 from qa_workout_state where key='plan'),(select value->'exercises'->0 from qa_workout_state where key='plan'))))$$,'P0001','duplicate_plan_exercise','duplicate plan row IDs rejected');
select lives_ok($$select public.save_workout_plan((select value from qa_workout_state where key='plan') || jsonb_build_object('exercises',jsonb_build_array((select value->'exercises'->1 from qa_workout_state where key='plan'),(select value->'exercises'->0 from qa_workout_state where key='plan'))))$$,'exercise order swap supported by deferred unique constraint');
select is(public.get_workout_plan('c0000000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'id','10000000-0000-0000-0000-000000000001','reordered plan survives read');
select lives_ok($$select public.save_workout_plan((select value from qa_workout_state where key='plan'))$$,'original order restored');
select throws_ok($$select public.save_workout_plan(jsonb_set((select value from qa_workout_state where key='plan'),'{exercises,0,target_weight}','"NaN"'))$$,'23514',null,'nonfinite target weight rejected by database');
select throws_ok($$select public.save_workout_plan(jsonb_set((select value from qa_workout_state where key='plan'),'{exercises,0,target_sets}','0'))$$,'23514',null,'zero target sets rejected');
select throws_ok($$select public.save_workout_plan(jsonb_set((select value from qa_workout_state where key='plan'),'{exercises,0,target_reps_max}','7'))$$,'23514',null,'reversed target rep range rejected');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
select is(jsonb_array_length(public.list_exercises()),122,'friend cannot list private custom library');
select is((select count(*) from public.exercises where id='b0000000-0000-0000-0000-000000000001'),0::bigint,'direct RLS hides private custom exercise');
select is(jsonb_array_length(public.list_exercise_favorites()),0,'favorites are account-isolated');
select throws_ok($$select public.get_workout_plan('c0000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','private plan hidden before invitation');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
insert into qa_workout_state values('session',to_jsonb(public.plan_workout('c0000000-0000-0000-0000-000000000001',now()+interval '1 hour',60,'Together','Gym',true,array['a0000000-0000-0000-0000-000000000002']::uuid[])));
select is((select value->>'exercise_count' from qa_workout_state where key='session'),'2','planned session includes exercise count');
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
select is(public.get_workout_plan('c0000000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','Prime Chest Press','normal invitation reveals full custom exercise before RSVP');
select is(jsonb_array_length(public.list_exercises()),122,'invitation does not expose creator private catalog');
select lives_ok($$select public.respond_to_invite((select (value->>'id')::uuid from qa_workout_state where key='session'),'accepted')$$,'friend can accept concrete plan');
select is((select workout_plan_id::text from public.activities where user_id=auth.uid() and planned_session_id=(select (value->>'id')::uuid from qa_workout_state where key='session')),'c0000000-0000-0000-0000-000000000001','legacy RSVP propagates plan metadata');
insert into qa_workout_state values('friend_activity',to_jsonb(public.start_activity('gym','ignored',null,(select (value->>'id')::uuid from qa_workout_state where key='session'))));
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'))->>'plan_name','Push Day','legacy session start initializes frozen workout log');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'))->'exercises'->0->'sets'->0->>'weight',null::text,'target weight is not fabricated actual weight');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'))->'exercises'->0->>'target_weight','80','target weight retained separately');
insert into qa_workout_state values('copy',public.copy_workout_plan('c0000000-0000-0000-0000-000000000001'));
select is((select value->>'owner_id' from qa_workout_state where key='copy'),'a0000000-0000-0000-0000-000000000002','copy owned by recipient');
select isnt((select value->'exercises'->0->'exercise'->>'id' from qa_workout_state where key='copy'),'b0000000-0000-0000-0000-000000000001','custom exercise deeply copied');
select is((select value->'exercises'->0->'exercise'->>'created_by' from qa_workout_state where key='copy'),'a0000000-0000-0000-0000-000000000002','custom copy owned by recipient');
select lives_ok($$select public.save_exercise((select value->'exercises'->0->'exercise' from qa_workout_state where key='copy') || '{"name":"My Independent Press"}')$$,'recipient can edit custom copy');
select is(public.get_workout_plan('c0000000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','Prime Chest Press','copy edits leave original unchanged');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.share_workout_plan('c0000000-0000-0000-0000-000000000001',array['a0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000002']::uuid[])$$,'explicit duplicate recipients safely deduplicated');
select lives_ok($$select public.share_workout_plan('c0000000-0000-0000-0000-000000000001',array['a0000000-0000-0000-0000-000000000002']::uuid[])$$,'share retry accepted');
select throws_ok($$select public.share_workout_plan('c0000000-0000-0000-0000-000000000001',array['a0000000-0000-0000-0000-000000000003']::uuid[])$$,'P0001','not_friends','share to stranger rejected');
insert into qa_workout_state values('owner_activity',to_jsonb(public.start_workout('c0000000-0000-0000-0000-000000000001',null,(select (value->>'id')::uuid from qa_workout_state where key='session'))));
insert into qa_workout_state values('owner_log',public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity')));
select isnt((select value->>'id' from qa_workout_state where key='owner_activity'),(select value->>'id' from qa_workout_state where key='friend_activity'),'co-training has independent activities');
select throws_ok($$select public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'))$$,'P0001','forbidden','host cannot read friend actual logs');
insert into qa_workout_state values('edited_log',public.save_workout_log(
 jsonb_set(jsonb_set(jsonb_set((select value from qa_workout_state where key='owner_log'),'{exercises,0,sets}',
 '[{"set_number":1,"weight":80,"reps":8,"completed":true},{"set_number":2,"weight":80,"reps":8,"completed":true},{"set_number":3,"weight":80,"reps":7,"completed":true}]'),'{exercises,0,completed}','true'),'{plan_name}','"Forged name"')));
select is((select value->>'plan_name' from qa_workout_state where key='edited_log'),'Push Day','forged plan name ignored');
select is((select value->'exercises'->0->'sets'->2->>'reps' from qa_workout_state where key='edited_log'),'7','third set actual reps persisted');
select is((select value->'exercises'->0->'sets'->0->>'weight' from qa_workout_state where key='edited_log'),'80','actual weight persisted');
select is(public.save_workout_log((select value from qa_workout_state where key='edited_log')),(select value from qa_workout_state where key='edited_log'),'retry preserves IDs and completion timestamps');
select throws_ok($$select public.save_workout_log(jsonb_set((select value from qa_workout_state where key='edited_log'),'{exercises}','[]'))$$,'P0001','incomplete_log','incomplete payload rejected');
select throws_ok($$select public.save_workout_log(jsonb_set((select value from qa_workout_state where key='edited_log'),'{exercises,0,sets}','[{"set_number":1},{"set_number":1}]'))$$,'P0001','duplicate_set_number','duplicate set numbers rejected atomically');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity')),(select value from qa_workout_state where key='edited_log'),'failed save does not erase existing logs');
select throws_ok($$select public.save_workout_log(jsonb_set((select value from qa_workout_state where key='edited_log'),'{exercises,0,sets,0,weight}','"Infinity"'))$$,'23514',null,'nonfinite actual weight rejected');
select is(public.save_workout_log(jsonb_set(jsonb_set((select value from qa_workout_state where key='edited_log'),'{exercises,0,exercise,name}','"Forged snapshot"'),'{exercises,0,target_sets}','30'))->'exercises'->0->'exercise'->>'name','Prime Chest Press','client cannot overwrite exercise snapshot');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity'))->'exercises'->0->>'target_sets','3','client cannot overwrite frozen targets');
select lives_ok($$select public.save_exercise((select value from qa_workout_state where key='custom') || '{"name":"Renamed Source Press"}')$$,'source custom can be renamed');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity'))->'exercises'->0->'exercise'->>'name','Prime Chest Press','live/historical snapshot not renamed');
select lives_ok($$select public.archive_exercise('b0000000-0000-0000-0000-000000000001')$$,'used custom archived instead of deleted');
select is(jsonb_array_length(public.list_exercises()),122,'archived custom omitted from picker');
select lives_ok($$select public.set_exercise_favorite('b0000000-0000-0000-0000-000000000001',false)$$,'archived exercise can still be removed from favorites');
select throws_ok($$select public.set_exercise_favorite('b0000000-0000-0000-0000-000000000001',true)$$,'P0001','forbidden','archived exercise cannot be newly favorited');
select is(public.get_workout_plan('c0000000-0000-0000-0000-000000000001')->'exercises'->0->'exercise'->>'name','Renamed Source Press','existing plan retains archived exercise');
select lives_ok($$select public.complete_activity((select (value->>'id')::uuid from qa_workout_state where key='owner_activity'),null)$$,'owner completes workout normally');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity'))->'exercises'->0->'exercise'->>'name','Prime Chest Press','completed history retains frozen exercise name');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.notifications where type='workout_plan_shared'),1::bigint,'share retry emits only one notification');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'))->'exercises'->0->'sets'->0->>'weight',null::text,'friend actual weights unaffected by owner tracking');
select throws_ok($$select public.save_exercise((select value from qa_workout_state where key='custom'))$$,'P0001','forbidden','recipient cannot modify original custom');
select throws_ok($$select public.save_workout_plan((select value from qa_workout_state where key='plan'))$$,'P0001','forbidden','recipient cannot modify original plan');
select throws_ok($$select public.archive_workout_plan('c0000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','recipient cannot archive original plan');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.workout_plans),0::bigint,'stranger RLS sees no private plans');
select is((select count(*) from public.workout_exercise_logs),0::bigint,'stranger RLS sees no exercise logs');
select is((select count(*) from public.workout_set_logs),0::bigint,'stranger RLS sees no set logs');
select throws_ok($$select public.start_activity('gym','guess',null,(select (value->>'id')::uuid from qa_workout_state where key='session'))$$,'P0001','invalid_session','guessed session cannot leak a private plan');
select throws_ok($$select public.copy_workout_plan('c0000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','stranger cannot copy plan');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.block_user('a0000000-0000-0000-0000-000000000001')$$,'friend blocks creator');
select throws_ok($$select public.get_workout_plan('c0000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','block immediately revokes shared source plan');
select is((select count(*) from public.workout_plan_shares),0::bigint,'block hides prior share metadata');
select is(public.get_workout_plan((select (value->>'id')::uuid from qa_workout_state where key='copy'))->'exercises'->0->'exercise'->>'name','My Independent Press','own independent copy remains after block');
select lives_ok($$select public.complete_activity((select (value->>'id')::uuid from qa_workout_state where key='friend_activity'),null)$$,'recipient can finish already-started workout after block');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.archive_workout_plan('c0000000-0000-0000-0000-000000000001')$$,'plan archived without deleting history');
select is(jsonb_array_length(public.list_workout_plans()),0,'archived plan absent from normal collection');
select throws_ok($$select public.start_workout('c0000000-0000-0000-0000-000000000001')$$,'P0001','plan_not_available','archived plan cannot start');
select is(public.get_workout_log((select (value->>'id')::uuid from qa_workout_state where key='owner_activity'))->'exercises'->0->'sets'->2->>'reps','7','archiving plan keeps actual history');

reset role;
select * from finish();
rollback;
