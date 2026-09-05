create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
set local time zone 'UTC';
select no_plan();
insert into auth.users(id) select ('a7000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,7)n;
insert into public.profiles(id,username,display_name)
select id,'qa_blind_'||right(id::text,2),'Blind '||right(id::text,2) from auth.users where id::text like 'a7000000%';
insert into public.friendships(requester_id,addressee_id,status) values
 ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000002','accepted'),
 ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000004','pending'),
 ('a7000000-0000-0000-0000-000000000002','a7000000-0000-0000-0000-000000000003','accepted'),
 ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000005','accepted'),
 ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000006','accepted');
create temporary table qa_blind_state(key text primary key,value jsonb);
grant all on qa_blind_state to authenticated;
select ok(not has_function_privilege('anon','public.get_blind_workout(uuid)','execute'),'anonymous blind read denied');
select ok(not has_function_privilege('authenticated','public.blind_state_document(uuid,boolean)','execute'),'raw state helper inaccessible');
select ok(not has_function_privilege('authenticated','public.blind_exercise_document(uuid,boolean)','execute'),'raw actuals document helper inaccessible');
select ok(not has_function_privilege('authenticated','public.complete_activity_before_blind(uuid,integer)','execute'),'old completion cannot bypass dedicated finish');
select ok(not has_function_privilege('authenticated','public.save_workout_log_before_blind(jsonb)','execute'),'old log writer not exposed');
select ok(not has_column_privilege('authenticated','public.blind_workouts','send_request','select'),'idempotency request sequence is private');
select ok(not has_table_privilege('authenticated','public.blind_workout_exercises','update'),'no direct reveal/completion write');
select ok(not has_table_privilege('authenticated','public.blind_workout_sets','insert'),'no direct actual set write');
select ok(not has_column_privilege('authenticated','public.blind_workout_exercises','completed_at','select'),'private exercise completion timestamps are RPC-only');
select ok(not has_column_privilege('authenticated','public.blind_workout_exercises','revealed_at','select'),'private reveal timestamps are not exposed to creator');

select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
set local role authenticated;
insert into qa_blind_state values('custom',public.save_exercise(jsonb_build_object('id','b7000000-0000-0000-0000-000000000001','name','Private frozen press',
 'primary_muscle_group','chest','secondary_muscles',jsonb_build_array('triceps'),'equipment','dumbbell','exercise_type','strength')));
insert into qa_blind_state values('timed',public.save_exercise(jsonb_build_object('id','b7000000-0000-0000-0000-000000000002','name','Private timed hold',
 'primary_muscle_group','core','secondary_muscles','[]'::jsonb,'equipment','bodyweight','exercise_type','timed')));
insert into qa_blind_state values('draft',jsonb_build_object('id','c7000000-0000-0000-0000-000000000001',
 'recipient_id','a7000000-0000-0000-0000-000000000002','title','Push surprise','focus','push','estimated_duration_minutes',55,
 'exercises',jsonb_build_array(
 jsonb_build_object('id','d7000000-0000-0000-0000-000000000001','exercise',jsonb_build_object('id','10000000-0000-0000-0000-000000000001','name','FORGED LIBRARY NAME'),'target_sets',3,'target_reps_min',8,'target_reps_max',12,'target_weight',20,'sort_order',99),
 jsonb_build_object('id','d7000000-0000-0000-0000-000000000002','exercise',(select value from qa_blind_state where key='custom'),'target_sets',2,'target_reps_min',10,'target_reps_max',12,'sort_order',-10),
 jsonb_build_object('id','d7000000-0000-0000-0000-000000000003','exercise',(select value from qa_blind_state where key='timed'),'target_sets',1,'target_reps_min',30,'target_reps_max',60,'sort_order',2))));
insert into qa_blind_state values('sent',public.send_blind_workout((select value from qa_blind_state where key='draft')));
select is((select value->'summary'->>'status' from qa_blind_state where key='sent'),'sent','creator sends structured workout');
select is((select jsonb_array_length(value->'visible_exercises') from qa_blind_state where key='sent'),3,'creator sees full target structure');
select is((select value->'visible_exercises'->0->'exercise'->>'name' from qa_blind_state where key='sent'),'Bankdrücken Langhantel','forged snapshot name ignored in favor of canonical library');
select is((select value->'visible_exercises'->0->>'sort_order' from qa_blind_state where key='sent'),'0','array order authoritative instead of forged sort number');
select is((select value->'visible_exercises'->0->'sets' from qa_blind_state where key='sent'),'[]'::jsonb,'creator never receives recipient actual slots');
select is((select value->'activity' from qa_blind_state where key='sent'),'null'::jsonb,'creator receives no recipient activity payload');
select is(public.send_blind_workout((select value from qa_blind_state where key='draft'))->'summary'->>'id','c7000000-0000-0000-0000-000000000001','same draft UUID retry returns same invitation');
select throws_ok($$select public.send_blind_workout(jsonb_set((select value from qa_blind_state where key='draft'),'{estimated_duration_minutes}','60'))$$,'P0001','blind_request_conflict','same send UUID cannot silently replace existing request');
select lives_ok($$select public.save_exercise((select value from qa_blind_state where key='custom')||jsonb_build_object('name','Changed after sending','equipment','machine'))$$,'creator may later edit own exercise');
select is(public.get_blind_workout('c7000000-0000-0000-0000-000000000001')->'visible_exercises'->1->'exercise'->>'name','Private frozen press','blind target snapshot unaffected by later source edit');

select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.confirm_weekly_goal(3,'UTC')$$,'recipient confirms weekly goal');
insert into qa_blind_state values('recipient_sent',public.get_blind_workout('c7000000-0000-0000-0000-000000000001'));
select is((select value->'visible_exercises' from qa_blind_state where key='recipient_sent'),'[]'::jsonb,'recipient gets no exercise before starting');
select is((select value->'summary'->>'exercise_count' from qa_blind_state where key='recipient_sent'),'3','recipient can see exercise count');
select ok((select value->'summary'->'required_equipment' ? 'dumbbell' from qa_blind_state where key='recipient_sent'),'needed equipment is visible before accepting');
select ok((select value->'summary'->'muscle_groups' ? 'chest' from qa_blind_state where key='recipient_sent'),'coarse muscle groups are visible before accepting');
select ok(not((select value->'summary' from qa_blind_state where key='recipient_sent') ? 'send_request'),'summary never serializes private request sequence');
select is((select count(*) from public.blind_workout_exercises),0::bigint,'direct RLS hides every future exercise');
select is((select count(*) from public.blind_workout_sets),0::bigint,'direct RLS hides every future actual slot');
select is((select count(*) from public.exercises where id='b7000000-0000-0000-0000-000000000001'),0::bigint,'blind invitation does not expose creators custom exercise library');
select is((select count(*) from public.notifications where type='blind_workout_received'),1::bigint,'send retry generated one received notification');
select throws_ok($$select public.copy_blind_workout('c7000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','recipient cannot copy hidden exercises before completion');
select throws_ok($$select public.start_blind_workout('c7000000-0000-0000-0000-000000000001')$$,'P0001','blind_invalid_state','start before acceptance rejected');
select throws_ok($$select public.respond_blind_workout('c7000000-0000-0000-0000-000000000001',true,false)$$,'P0001','equipment_confirmation_required','equipment confirmation is required');
select is(public.respond_blind_workout('c7000000-0000-0000-0000-000000000001',true,true)->'summary'->>'status','accepted','recipient accepts with equipment confirmation');
select is(public.respond_blind_workout('c7000000-0000-0000-0000-000000000001',true,true)->'visible_exercises','[]'::jsonb,'repeat acceptance remains hidden and idempotent');
select is(public.plan_blind_workout('c7000000-0000-0000-0000-000000000001',now()+interval '2 hours')->'summary'->>'status','planned','accepted workout can be planned later');
insert into qa_blind_state values('planned',public.get_blind_workout('c7000000-0000-0000-0000-000000000001'));
select is((select value->'activity'->>'status' from qa_blind_state where key='planned'),'planned','planned blind creates real planned activity');
select is((select value->'activity'->'workout_plan_id' from qa_blind_state where key='planned'),'null'::jsonb,'planned blind has no generic source plan leak');
select is((select value->'visible_exercises' from qa_blind_state where key='planned'),'[]'::jsonb,'planned still returns no exercise');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','0','planned blind grants no weekly credit');
insert into qa_blind_state values('started',public.start_blind_workout('c7000000-0000-0000-0000-000000000001'));
select is((select jsonb_array_length(value->'visible_exercises') from qa_blind_state where key='started'),1,'only first exercise is revealed at start');
select is((select value->'activity'->>'id' from qa_blind_state where key='started'),(select value->'activity'->>'id' from qa_blind_state where key='planned'),'starting reuses exactly one planned activity');
select is((select value->'visible_exercises'->0->'sets'->0->'weight' from qa_blind_state where key='started'),'null'::jsonb,'target weight is never a fabricated actual weight');
select is((select value->'visible_exercises'->0->'sets'->0->'reps' from qa_blind_state where key='started'),'null'::jsonb,'target reps are never fabricated actual reps');
select is(public.start_blind_workout('c7000000-0000-0000-0000-000000000001')->'summary'->>'started_at',(select value->'summary'->>'started_at' from qa_blind_state where key='started'),'start retry does not reset start clock');
select is((select count(*) from public.blind_workout_exercises),1::bigint,'direct RLS exposes exactly one exercise at start');
select is((select count(*) from public.blind_workout_sets),3::bigint,'direct RLS only exposes first exercise blank sets');
select is(jsonb_array_length(public.get_workout_log((select (value->'activity'->>'id')::uuid from qa_blind_state where key='started'))->'exercises'),1,'generic read cannot leak hidden future rows');
select is((select count(*) from public.workout_exercise_logs),0::bigint,'generic workout log table has no hidden rows to leak');
select throws_ok($$select public.save_workout_log(jsonb_build_object('activity_id',(select value->'activity'->>'id' from qa_blind_state where key='started'),'exercises','[]'::jsonb))$$,'P0001','blind_workout_tracking_required','generic log mutation cannot bypass ordered reveal');
select throws_ok($$select public.complete_activity((select (value->'activity'->>'id')::uuid from qa_blind_state where key='started'),null)$$,'P0001','blind_workout_finish_required','generic completion cannot bypass blind checks');
select throws_ok($$select public.finish_blind_workout('c7000000-0000-0000-0000-000000000001')$$,'P0001','blind_exercises_remaining','finish blocked while exercises remain');
select throws_ok($$select public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')$$,'P0001','blind_invalid_state','feedback requires completed workout');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->2->>'id')::uuid from qa_blind_state where key='sent'),'[]',true)$$,'P0001','forbidden','guessed hidden future exercise cannot be completed');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[{"set_number":7}]',false)$$,'P0001','invalid_blind_sets','actual set number seven rejected');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[{"set_number":1,"reps":31}]',false)$$,'P0001','invalid_blind_sets','actual strength reps above thirty rejected');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[{"set_number":1,"weight":"NaN"}]',false)$$,'P0001','invalid_blind_sets','nonfinite actual weight rejected');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[{"set_number":1},{"set_number":1}]',false)$$,'P0001','invalid_blind_sets','duplicate actual set numbers rejected');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[]',null)$$,'P0001','invalid_blind_sets','missing exercise completion intent rejected');
insert into qa_blind_state values('sets',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'set_number',1,'weight',17.5,'reps',10,'completed',true,'completed_at','1999-01-01T00:00:00Z')));
select is(public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),(select value from qa_blind_state where key='sets'),false)->'summary'->>'completed_exercises','0','tracking actual values alone does not reveal next exercise');
insert into qa_blind_state values('second',public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),(select value from qa_blind_state where key='sets'),true));
select is((select jsonb_array_length(value->'visible_exercises') from qa_blind_state where key='second'),2,'completing first reveals only next exercise');
select is((select value->'visible_exercises'->0->'sets'->0->>'weight' from qa_blind_state where key='second'),'17.5','recipient actual weight persisted');
select ok((select (value->'visible_exercises'->0->'sets'->0->>'completed_at')::timestamptz>=now() from qa_blind_state where key='second'),'actual completion timestamp is server-authored');
select is(public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),(select value from qa_blind_state where key='sets'),true)->'summary'->>'completed_exercises','1','identical completion retry does not reveal twice');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='started'),'[]',true)$$,'P0001','exercise_already_completed','completed actual data immutable to conflicting retry');
select is(public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->1->>'id')::uuid from qa_blind_state where key='second'),'[]',true)->'summary'->>'completed_exercises','2','simple mode can complete without invented actual values');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->2->>'id')::uuid from qa_blind_state where key='sent'),'[{"set_number":1,"reps":301}]',false)$$,'P0001','invalid_blind_sets','timed actual seconds above three hundred rejected');
select is(public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->2->>'id')::uuid from qa_blind_state where key='sent'),'[]',true)->'summary'->>'completed_exercises','3','last revealed exercise can complete');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','0','exercise completion alone does not create workout credit');
reset role;
-- Only the fixture administrator advances elapsed training; public APIs cannot.
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a7000000-0000-0000-0000-000000000002','running','completed',clock_timestamp()-interval '15 minutes',clock_timestamp() from generate_series(1,2);
update public.activities set started_at=clock_timestamp()-interval '10 minutes' where blind_workout_id='c7000000-0000-0000-0000-000000000001';
set local role authenticated;
insert into qa_blind_state values('done',public.finish_blind_workout('c7000000-0000-0000-0000-000000000001'));
select is((select value->'summary'->>'status' from qa_blind_state where key='done'),'completed','dedicated finish completes blind');
select is((select value->'activity'->>'status' from qa_blind_state where key='done'),'completed','dedicated finish completes same FYRUP activity');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','3','finished blind adds one credit to two previous real workouts');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','true','Blind finish can earn the final weekly flame in the same transaction');
select is((select count(*) from public.weekly_activity_credits where activity_id=(select (value->'activity'->>'id')::uuid from qa_blind_state where key='done')),1::bigint,'Blind activity has exactly one explicit weekly credit relation');
select is(public.finish_blind_workout('c7000000-0000-0000-0000-000000000001')->'summary'->>'completed_at',(select value->'summary'->>'completed_at' from qa_blind_state where key='done'),'finish retry returns same completion instant');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','3','finish retry cannot add second credit');
select is((select count(*) from public.notifications where type='weekly_goal'),1::bigint,'Blind finish retry cannot repeat weekly flame notification');
insert into qa_blind_state values('copy',public.copy_blind_workout('c7000000-0000-0000-0000-000000000001'));
select is((select value->>'visibility' from qa_blind_state where key='copy'),'private','completed blind copies into private plan');
select is((select value->>'owner_id' from qa_blind_state where key='copy'),auth.uid()::text,'copy belongs to recipient');
select is(public.copy_blind_workout('c7000000-0000-0000-0000-000000000001')->>'id',(select value->>'id' from qa_blind_state where key='copy'),'copy retry avoids duplicate plans');
select isnt((select value->'exercises'->1->'exercise'->>'id' from qa_blind_state where key='copy'),'b7000000-0000-0000-0000-000000000001','custom copy has independent exercise ID');
select is((select value->'exercises'->1->'exercise'->>'name' from qa_blind_state where key='copy'),'Private frozen press','custom copy preserves frozen original rather than later source edit');
select is((select value->'exercises'->1->'exercise'->>'created_by' from qa_blind_state where key='copy'),auth.uid()::text,'copied custom exercise belongs to new owner');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='blind_workout_completed'),1::bigint,'creator gets exactly one completion notification');
select is(public.get_blind_workout('c7000000-0000-0000-0000-000000000001')->'visible_exercises'->0->'sets','[]'::jsonb,'creator cannot read actual sets even after completion');
select is(public.get_blind_workout('c7000000-0000-0000-0000-000000000001')->'visible_exercises'->0->>'completed','false','creator target view does not export per-exercise actual state');
select is((select count(*) from public.blind_workout_sets),0::bigint,'creator direct RLS cannot access recipient sets');

-- Optional two-way feedback preserves actual-data privacy and notification mute.
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')->>'my_reaction','🔥','creator can congratulate recipient');
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')->'reaction_counts'->0->>'count','1','same creator reaction retry remains single');
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','💪')->>'my_reaction','💪','creator can replace reaction');
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001',null)->>'my_reaction',null::text,'explicit null clears feedback');
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')->'visible_exercises'->0->'sets','[]'::jsonb,'reaction response never discloses recipient actuals');
select lives_ok($$select public.save_notification_preferences(false,true,true,false,true,true,true,true)$$,'creator mutes optional feedback notifications');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.notifications where type='blind_reaction'),1::bigint,'reaction changes and retries do not spam other participant');
select is(public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')->'reaction_counts'->0->>'count','2','recipient can thank creator independently');
select throws_ok($$select public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','👎')$$,'P0001','invalid_reaction','unsupported feedback rejected');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='blind_reaction'),0::bigint,'creator reaction mute suppresses notification but retains in-app feedback');

-- Build fresh request UUIDs for independent cancellation/privacy fixtures.
reset role;
create function pg_temp.qa_draft(p_id uuid,p_recipient uuid default 'a7000000-0000-0000-0000-000000000002') returns jsonb language sql as $$
 select value||jsonb_build_object('id',p_id,'recipient_id',p_recipient) from qa_blind_state where key='draft';
$$;
grant execute on function pg_temp.qa_draft(uuid,uuid) to authenticated;
set local role authenticated;
select throws_ok($$select public.send_blind_workout(pg_temp.qa_draft(gen_random_uuid(),'a7000000-0000-0000-0000-000000000001'))$$,'P0001','forbidden','creator cannot send to self');
select throws_ok($$select public.send_blind_workout(pg_temp.qa_draft(gen_random_uuid(),'a7000000-0000-0000-0000-000000000003'))$$,'P0001','forbidden','sending to stranger rejected');
select throws_ok($$select public.send_blind_workout(pg_temp.qa_draft(gen_random_uuid(),'a7000000-0000-0000-0000-000000000004'))$$,'P0001','forbidden','pending friendship cannot receive Blind Workout');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises}','[]'))$$,'P0001','invalid_blind_workout','empty workout rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,0,target_sets}','7'))$$,'P0001','invalid_blind_targets','target sets above six rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,0,target_reps_max}','31'))$$,'P0001','invalid_blind_targets','strength target reps above thirty rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,2,target_reps_max}','301'))$$,'P0001','invalid_blind_targets','timed target above three hundred seconds rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,0,target_weight}','"NaN"'))$$,'P0001','invalid_blind_targets','nonfinite target weight rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,0,target_weight}','501'))$$,'P0001','invalid_blind_targets','target weight above product limit rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,0,exercise,id}',to_jsonb(gen_random_uuid())))$$,'P0001','exercise_not_available','arbitrary freetext exercise identity cannot bypass library');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises,1,id}','"d7000000-0000-0000-0000-000000000001"'))$$,'P0001','duplicate_blind_exercise','duplicate draft slot IDs rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{estimated_duration_minutes}','4'))$$,'23514',null,'duration below five rejected by constraint');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{estimated_duration_minutes}','181'))$$,'23514',null,'duration above one hundred eighty rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{title}',to_jsonb(repeat('x',61))))$$,'23514',null,'overlong title rejected');
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid()),'{exercises}',(select jsonb_agg((value->'exercises'->0)||jsonb_build_object('id',gen_random_uuid())) from qa_blind_state cross join generate_series(1,13) where key='draft')))$$,'P0001','invalid_blind_workout','thirteen exercises rejected');
select is((select count(*) from public.blind_workouts),1::bigint,'all rejected requests roll back fully');

select lives_ok($$select public.send_blind_workout(pg_temp.qa_draft('c7000000-0000-0000-0000-000000000002'))$$,'second invitation sent for cancellation');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.respond_blind_workout('c7000000-0000-0000-0000-000000000002',true,true)$$,'second invitation accepted');
insert into qa_blind_state values('cancel_live',public.start_blind_workout('c7000000-0000-0000-0000-000000000002'));
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000003',true);
select is(jsonb_array_length(public.list_blind_workouts()),0,'unrelated accepted friend sees no Blind Workouts');
select throws_ok($$select public.get_blind_workout('c7000000-0000-0000-0000-000000000002')$$,'P0001','forbidden','unrelated friend cannot guess Blind ID');
select is((select count(*) from public.blind_workout_exercises),0::bigint,'unrelated friend direct exercise read denied');
select is((select count(*) from public.blind_workout_sets),0::bigint,'unrelated friend direct actual read denied');
select is((select count(*) from public.activities where blind_workout_id='c7000000-0000-0000-0000-000000000002'),0::bigint,'unrelated friend cannot inspect pre-completion Blind activity');
select is(public.today_feed('UTC')->'crew'->0->'activity','null'::jsonb,'existing security-definer feed also hides pre-completion Blind activity');
select throws_ok($$select public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','🔥')$$,'P0001','forbidden','unrelated friend cannot react even after completion');
select is((select count(*) from public.activities where blind_workout_id='c7000000-0000-0000-0000-000000000001'),1::bigint,'ordinary completed activity may be visible to accepted friends');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.activities where blind_workout_id='c7000000-0000-0000-0000-000000000002'),0::bigint,'creator also has no generic live recipient activity access');
select is((select value->'activity' from jsonb_array_elements(public.today_feed('UTC')->'crew') where value->'profile'->>'id'='a7000000-0000-0000-0000-000000000002'),'null'::jsonb,'creator feed gets safe Blind summary only through dedicated API');
select throws_ok($$select public.cancel_blind_workout('c7000000-0000-0000-0000-000000000002')$$,'P0001','blind_invalid_state','creator cannot remotely interrupt live recipient workout');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.set_activity_paused((select (value->'activity'->>'id')::uuid from qa_blind_state where key='cancel_live'),true)$$,'normal pause works inside live Blind Workout');
select is(public.cancel_activity((select (value->'activity'->>'id')::uuid from qa_blind_state where key='cancel_live')),true,'generic safety cancel delegates atomically to Blind cancellation');
insert into qa_blind_state values('cancelled',public.get_blind_workout('c7000000-0000-0000-0000-000000000002'));
select is((select value->'summary'->>'status' from qa_blind_state where key='cancelled'),'cancelled','generic cancellation updates Blind state');
select is((select value->'activity'->>'status' from qa_blind_state where key='cancelled'),'cancelled','generic cancellation updates matching activity');
select is((select value->'activity'->'paused_at' from qa_blind_state where key='cancelled'),'null'::jsonb,'cancellation safely clears paused timer');
select is((select jsonb_array_length(value->'visible_exercises') from qa_blind_state where key='cancelled'),1,'cancelled state retains only already revealed prefix');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','3','cancelled Blind grants no extra weekly credit');
select throws_ok($$select public.start_blind_workout('c7000000-0000-0000-0000-000000000002')$$,'P0001','blind_invalid_state','cancelled workout cannot restart to farm credits');
select throws_ok($$select public.copy_blind_workout('c7000000-0000-0000-0000-000000000002')$$,'P0001','forbidden','cancelled prefix cannot copy hidden remainder');

select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.send_blind_workout(pg_temp.qa_draft('c7000000-0000-0000-0000-000000000003'))$$,'third invitation sent for decline');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select is(public.respond_blind_workout('c7000000-0000-0000-0000-000000000003',false,false)->'summary'->>'status','declined','recipient can decline without equipment');
select is(public.respond_blind_workout('c7000000-0000-0000-0000-000000000003',false,false)->'visible_exercises','[]'::jsonb,'decline retry does not reveal exercises');
select throws_ok($$select public.start_blind_workout('c7000000-0000-0000-0000-000000000003')$$,'P0001','blind_invalid_state','declined invitation cannot start');

-- Revocation removes all normal read/write access but keeps safe cancellation.
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.send_blind_workout(pg_temp.qa_draft('c7000000-0000-0000-0000-000000000004'))$$,'fourth invitation sent for revocation');
select lives_ok($$select public.send_blind_workout(pg_temp.qa_draft('c7000000-0000-0000-0000-000000000005'))$$,'fifth invitation remains unstarted for creator cancellation');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.respond_blind_workout('c7000000-0000-0000-0000-000000000004',true,true)$$,'fourth accepted');
insert into qa_blind_state values('blocked_live',public.start_blind_workout('c7000000-0000-0000-0000-000000000004'));
select lives_ok($$select public.block_user('a7000000-0000-0000-0000-000000000001')$$,'recipient may block creator while workout live');
select is(jsonb_array_length(public.list_blind_workouts()),0,'block immediately removes all source Blind Workouts from collection');
select throws_ok($$select public.get_blind_workout('c7000000-0000-0000-0000-000000000004')$$,'P0001','forbidden','blocked Blind detail no longer readable');
select is((select count(*) from public.blind_workout_exercises),0::bigint,'block revokes direct revealed exercise access');
select is((select count(*) from public.blind_workout_sets),0::bigint,'block revokes direct actual access through source Blind');
select throws_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000004',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='blocked_live'),'[]',true)$$,'P0001','forbidden','block prevents future exercise reveals');
select throws_ok($$select public.finish_blind_workout('c7000000-0000-0000-0000-000000000004')$$,'P0001','forbidden','block prevents completion from stale client state');
select throws_ok($$select public.react_to_blind_workout('c7000000-0000-0000-0000-000000000001','💪')$$,'P0001','forbidden','block revokes completed feedback access');
select is(public.cancel_blind_workout('c7000000-0000-0000-0000-000000000004')->'visible_exercises','[]'::jsonb,'recipient can cancel after block without new exercise disclosure');
select is((select status::text from public.activities where id=(select (value->'activity'->>'id')::uuid from qa_blind_state where key='blocked_live')),'cancelled','blocked recipient is not trapped in live activity');
select is(public.get_workout_plan((select (value->>'id')::uuid from qa_blind_state where key='copy'))->>'owner_id',auth.uid()::text,'previously copied independent plan survives friendship revocation');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select is(public.cancel_blind_workout('c7000000-0000-0000-0000-000000000005')->'visible_exercises','[]'::jsonb,'creator can withdraw unstarted invitation after block without new disclosure');

-- Another accepted recipient can mute invitations. Very short completions save
-- normally but remain ineligible under the same versioned weekly-credit rule.
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000005',true);
select lives_ok($$select public.save_notification_preferences(false,true,false,true,true,true,true,true)$$,'recipient mutes invitations');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
insert into qa_blind_state values('short_draft',jsonb_set(pg_temp.qa_draft('c7000000-0000-0000-0000-000000000006','a7000000-0000-0000-0000-000000000005'),
 '{exercises}',jsonb_build_array((select value->'exercises'->0 from qa_blind_state where key='draft')))||jsonb_build_object('title','X'));
select lives_ok($$select public.send_blind_workout((select value from qa_blind_state where key='short_draft'))$$,'one-exercise workout with one-character optional title valid');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000005',true);
select is((select count(*) from public.notifications where type='blind_workout_received'),0::bigint,'invitation mute suppresses new Blind push');
select lives_ok($$select public.respond_blind_workout('c7000000-0000-0000-0000-000000000006',true,true)$$,'muted invitation still usable in app');
insert into qa_blind_state values('short_started',public.start_blind_workout('c7000000-0000-0000-0000-000000000006'));
select lives_ok($$select public.save_blind_workout_exercise('c7000000-0000-0000-0000-000000000006',(select (value->'visible_exercises'->0->>'id')::uuid from qa_blind_state where key='short_started'),'[]',true)$$,'simple one-exercise completion works');
select is(public.finish_blind_workout('c7000000-0000-0000-0000-000000000006')->'summary'->>'status','completed','short Blind Workout still saved completed');
select is((select reason from public.weekly_activity_credits where activity_id=(select (value->'activity'->>'id')::uuid from qa_blind_state where key='short_started')),'active_duration_under_60_seconds','short Blind cannot evade weekly antiabuse rule');
select ok((select public.copy_blind_workout('c7000000-0000-0000-0000-000000000006')->>'name') like 'Blind Workout%','single-letter optional title becomes valid copied plan name');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='blind_workout_completed' and data->>'blind_workout_id'='c7000000-0000-0000-0000-000000000006'),0::bigint,'muted creator receives no completion notification');

-- The sender may not reference another user's custom library entry, even with
-- a forged client-side created_by/is_custom snapshot.
reset role;
insert into public.exercises(id,name,primary_muscle_group,equipment,exercise_type,created_by)
values('b7000000-0000-0000-0000-000000000005','Foreign private row','chest','bodyweight','strength','a7000000-0000-0000-0000-000000000005');
set local role authenticated;
select throws_ok($$select public.send_blind_workout(jsonb_set(pg_temp.qa_draft(gen_random_uuid(),'a7000000-0000-0000-0000-000000000005'),'{exercises,0,exercise}',
 '{"id":"b7000000-0000-0000-0000-000000000005","is_custom":false,"created_by":"a7000000-0000-0000-0000-000000000001"}'))$$,'P0001','exercise_not_available','forged foreign custom ownership rejected');

-- Creator account deletion does not clear the durable marker or create an
-- alternate completion route. Recipient can always cancel the orphan safely.
reset role;
insert into public.friendships(requester_id,addressee_id,status) values('a7000000-0000-0000-0000-000000000007','a7000000-0000-0000-0000-000000000006','accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000007',true);
select lives_ok($$select public.send_blind_workout((select value from qa_blind_state where key='short_draft')||jsonb_build_object('id','c7000000-0000-0000-0000-000000000007','recipient_id','a7000000-0000-0000-0000-000000000006'))$$,'temporary creator sends standard-library workout');
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000006',true);
select lives_ok($$select public.respond_blind_workout('c7000000-0000-0000-0000-000000000007',true,true)$$,'recipient accepts temporary creator workout');
insert into qa_blind_state values('orphan',public.start_blind_workout('c7000000-0000-0000-0000-000000000007'));
reset role;
delete from auth.users where id='a7000000-0000-0000-0000-000000000007';
set local role authenticated;
select is((select blind_workout_id::text from public.activities where id=(select (value->'activity'->>'id')::uuid from qa_blind_state where key='orphan')),'c7000000-0000-0000-0000-000000000007','creator deletion retains immutable Blind activity marker');
select throws_ok($$select public.complete_activity((select (value->'activity'->>'id')::uuid from qa_blind_state where key='orphan'),null)$$,'P0001','blind_workout_finish_required','orphaned Blind cannot bypass completion guard');
select is(public.cancel_activity((select (value->'activity'->>'id')::uuid from qa_blind_state where key='orphan')),true,'orphaned recipient activity remains safely cancellable');
select is((select status::text from public.activities where id=(select (value->'activity'->>'id')::uuid from qa_blind_state where key='orphan')),'cancelled','orphan safety exit persists');
reset role;
select lives_ok($$set constraints all immediate$$,'all deferred identity/reference constraints hold before transaction rollback');

select * from finish();
rollback;
