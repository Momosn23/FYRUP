create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
set local time zone 'UTC';
select no_plan();
insert into auth.users(id) select ('a8000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,9)n;
insert into public.profiles(id,username,display_name)
select id,'qa_shot_'||right(id::text,2),'Shot '||right(id::text,2) from auth.users where id::text like 'a8000000%';
insert into public.friendships(requester_id,addressee_id,status) values
 ('a8000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000002','accepted'),
 ('a8000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000004','pending'),
 ('a8000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000005','accepted'),
 ('a8000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000006','accepted');
insert into public.blocks(blocker_id,blocked_id) values('a8000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000006');
insert into public.notification_preferences(user_id,weekly_goal) values('a8000000-0000-0000-0000-000000000005',false);
create temporary table qa_shot_state(key text primary key,value jsonb);
grant all on qa_shot_state to authenticated;
create function pg_temp.qa_shot_complete(p_seconds integer default 600) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 insert into public.activities(user_id,sport,status,started_at) values(auth.uid(),'running','live',clock_timestamp()-make_interval(secs=>p_seconds)) returning id into v_id;
 perform public.complete_activity(v_id,null);
 return v_id;
end; $$;
grant execute on function pg_temp.qa_shot_complete(integer) to authenticated;

select ok(not has_function_privilege('anon','public.call_my_shot(uuid)','execute'),'anonymous call denied');
select ok(to_regprocedure('public.call_my_shot()') is null,'no nullary overload may bypass expected-week consent');
select ok(not has_function_privilege('anon','public.set_shot_reaction(uuid,text)','execute'),'anonymous shot reaction denied');
select ok(not has_function_privilege('authenticated','public.weekly_commitment_document(uuid)','execute'),'raw commitment helper cannot bypass friendship');
select ok(not has_function_privilege('authenticated','public.sync_weekly_commitment()','execute'),'achievement synchronizer not a client RPC');
select ok(not has_function_privilege('authenticated','public.notify_weekly_commitment(uuid,text)','execute'),'client cannot spam notification helper');
select ok(not has_table_privilege('authenticated','public.weekly_commitments','insert'),'direct commitment insert denied');
select ok(not has_table_privilege('authenticated','public.weekly_commitments','update'),'direct achieved flag write denied');
select ok(not has_table_privilege('authenticated','public.weekly_commitments','delete'),'direct uncall/delete denied');
select ok(not has_table_privilege('authenticated','public.weekly_shot_reactions','insert'),'direct shot reaction writes denied');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select throws_ok($$select public.call_my_shot(gen_random_uuid())$$,'P0001','weekly_goal_not_confirmed','conscious weekly target is mandatory before calling');
select lives_ok($$select public.confirm_weekly_goal(4,'UTC')$$,'caller confirms four');
select is(public.get_weekly_state()->'current_week'->'commitment','null'::jsonb,'ordinary week has nullable absent commitment');
select is(public.set_next_weekly_goal(5)->>'next_weekly_goal','5','future goal may be pending before call');
select throws_ok($$select public.call_my_shot(null)$$,'P0001','weekly_week_changed','null consent week is rejected');
select throws_ok($$select public.call_my_shot(gen_random_uuid())$$,'P0001','weekly_week_changed','different consent week is rejected before any declaration');
select is((select count(*) from public.weekly_commitments),0::bigint,'invalid consent preconditions create no commitment');
insert into qa_shot_state values('called',public.call_my_shot((public.get_weekly_state()->'current_week'->>'id')::uuid));
select is((select value->>'weekly_goal' from qa_shot_state where key='called'),'4','call snapshots current four, never pending five');
select is((select value->>'user_id' from qa_shot_state where key='called'),auth.uid()::text,'call owner is authenticated account');
select is((select value->>'week_id' from qa_shot_state where key='called'),public.get_weekly_state()->'current_week'->>'id','commitment references exact authoritative week');
select is((select value->>'achieved' from qa_shot_state where key='called'),'false','new call is not an achievement');
select is((select value->>'finalized' from qa_shot_state where key='called'),'false','open call not finalized');
select ok((select (value->>'called_at')::timestamptz>=now() from qa_shot_state where key='called'),'called_at uses server clock');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'id',(select value->>'id' from qa_shot_state where key='called'),'weekly API includes same commitment for combined UI');
select throws_ok($$select public.call_my_shot((public.get_weekly_state()->'current_week'->>'id')::uuid)$$,'P0001','weekly_commitment_exists','calling again in same week is rejected');
select is((select count(*) from public.weekly_commitments),1::bigint,'repeated call cannot create second declaration');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','0','calling grants no training credit');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','false','calling alone grants no Flame');
select is((select count(*) from public.notifications where type in('shot_called','shot_achieved')),0::bigint,'caller receives no duplicate self call or success push');
select throws_ok($$update public.weekly_commitments set achieved=true where user_id=auth.uid()$$,'42501','permission denied for table weekly_commitments','real direct achievement manipulation blocked');
select throws_ok($$delete from public.weekly_commitments where user_id=auth.uid()$$,'42501','permission denied for table weekly_commitments','real direct uncall blocked');
select throws_ok($$select public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🔥')$$,'P0001','forbidden','owner cannot self-react');
select lives_ok($$select public.set_step_sharing(auth.uid(),true)$$,'steps remain independent optional feature');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',20000,1,clock_timestamp()),true,'twenty thousand steps accepted independently');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved','false','steps never achieve called shot');
select lives_ok($$select public.plan_session('gym',null,now()+interval '2 hours',60::smallint,null,'{}')$$,'planned training remains available with called shot');
insert into qa_shot_state values('live',to_jsonb((public.start_activity('gym',null,null,null)).id));
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','0','planned and live training do not count toward call');
select lives_ok($$select public.cancel_activity((select (value #>> '{}')::uuid from qa_shot_state where key='live'))$$,'cancel remains free of negative score');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved','false','cancel does not change call achievement');

select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.notifications where type='shot_called'),1::bigint,'accepted friend gets one optional call notification');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'current_week'->'commitment'->>'weekly_goal','4','accepted friend sees called target');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'next_weekly_goal','null'::jsonb,'new commitment field does not expose pending goal');
select is((select count(*) from public.weekly_commitments),1::bigint,'accepted friend direct RLS reads commitment');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🎯'),true,'friend can encourage shot with target reaction');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🎯'),true,'identical reaction retry idempotent');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'current_week'->'commitment'->>'my_reaction','🎯','friend sees own confirmed shot reaction');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'current_week'->'commitment'->'reaction_counts'->0->>'count','1','repeated taps do not inflate reaction count');
select throws_ok($$select public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'👏')$$,'P0001','invalid_reaction','shot reaction vocabulary remains distinct from flame reactions');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🔥'),true,'friend can change encouragement');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),null),true,'nil removes reaction without removing commitment');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'current_week'->'commitment'->'reaction_counts','[]'::jsonb,'removed reaction absent from counts');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'💪'),true,'friend can re-add reaction');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='shot_reaction'),1::bigint,'changes/re-adds cause no reaction notification spam');
select lives_ok($$select public.save_notification_preferences(false,true,true,false,true,true,true,true)$$,'caller can mute shot reaction alerts');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000005',true);
select is((select count(*) from public.notifications where type='shot_called'),0::bigint,'muted friend receives no call notification');
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🔥'),true,'muted friend still participates in app');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='shot_reaction'),1::bigint,'caller reaction mute suppresses second actor notification');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.weekly_commitments),0::bigint,'stranger cannot read commitment by direct table');
select throws_ok($$select public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)$$,'P0001','forbidden','stranger cannot inspect nested commitment');
select throws_ok($$select public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),'🎯')$$,'P0001','forbidden','stranger cannot react to guessed commitment ID');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000004',true);
select is((select count(*) from public.weekly_commitments),0::bigint,'pending friendship insufficient for commitment read');
select is((select count(*) from public.notifications where type='shot_called'),0::bigint,'pending friendship receives no call alert');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000006',true);
select is((select count(*) from public.weekly_commitments),0::bigint,'blocked friend has no commitment read');
select is((select count(*) from public.notifications where type='shot_called'),0::bigint,'blocked friend receives no call alert');

select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
insert into qa_shot_state values('first_credit',to_jsonb(pg_temp.qa_shot_complete()));
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','1','first completed training advances called goal');
select lives_ok($$select pg_temp.qa_shot_complete() from generate_series(1,2)$$,'two more genuine workouts finish');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','3','three of four while called');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved','false','call remains open at three of four');
select is(public.set_next_weekly_goal(3)->>'next_weekly_goal','3','lower goal can only be scheduled next week');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'weekly_goal','4','pending decrease cannot lower called target');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved','false','pending decrease cannot retroactively achieve call');

-- The complete social loop: a friend supplies the final Blind Workout.
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.send_blind_workout(jsonb_build_object('id','c8000000-0000-0000-0000-000000000001','recipient_id','a8000000-0000-0000-0000-000000000001',
 'focus','push','estimated_duration_minutes',30,'exercises',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),
 'exercise',jsonb_build_object('id','10000000-0000-0000-0000-000000000001'),'target_sets',3,'target_reps_min',8,'target_reps_max',12))))$$,'friend sends final Blind Workout for called goal');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.respond_blind_workout('c8000000-0000-0000-0000-000000000001',true,true)$$,'caller accepts final Blind Workout');
insert into qa_shot_state values('blind',public.start_blind_workout('c8000000-0000-0000-0000-000000000001'));
select lives_ok($$select public.save_blind_workout_exercise('c8000000-0000-0000-0000-000000000001',(select (value->'visible_exercises'->0->>'id')::uuid from qa_shot_state where key='blind'),'[]',true)$$,'caller completes revealed exercise');
reset role;
update public.activities set started_at=clock_timestamp()-interval '10 minutes' where blind_workout_id='c8000000-0000-0000-0000-000000000001';
set local role authenticated;
select lives_ok($$select public.finish_blind_workout('c8000000-0000-0000-0000-000000000001')$$,'Blind finish atomically completes fourth workout');
insert into qa_shot_state values('achieved',public.get_weekly_state());
select is((select value->'current_week'->>'completed_workouts' from qa_shot_state where key='achieved'),'4','Blind supplies fourth authoritative credit');
select is((select value->'current_week'->>'flame_earned' from qa_shot_state where key='achieved'),'true','same finish earns ordinary Flame');
select is((select value->'current_week'->'commitment'->>'achieved' from qa_shot_state where key='achieved'),'true','same finish marks CALLED IT achieved');
select is((select value->'current_week'->'commitment'->>'achieved_at' from qa_shot_state where key='achieved'),
 (select value->'current_week'->>'flame_earned_at' from qa_shot_state where key='achieved'),'shot and Flame share exact server achievement timestamp');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'called_at',(select value->>'called_at' from qa_shot_state where key='called'),'original declaration timestamp remains frozen');
select is((select count(*) from public.notifications where type='weekly_goal'),1::bigint,'combined success retains exactly one own Flame push');
select is((select count(*) from public.notifications where type='shot_achieved'),0::bigint,'combined success creates no duplicate self shot push');
select throws_ok($$select public.call_my_shot((public.get_weekly_state()->'current_week'->>'id')::uuid)$$,'P0001','weekly_commitment_exists','already-called achieved week cannot be called again');
select lives_ok($$select public.finish_blind_workout('c8000000-0000-0000-0000-000000000001')$$,'Blind finish retry remains harmless with commitment hook');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','4','combined success still one credit per activity');
select lives_ok($$select pg_temp.qa_shot_complete()$$,'overachievement remains possible after call achieved');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved_at',(select value->'current_week'->'commitment'->>'achieved_at' from qa_shot_state where key='achieved'),'overachievement cannot re-achieve or reset call timestamp');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.notifications where type='shot_achieved'),1::bigint,'accepted friend gets exactly one CALLED IT notification');
select is(public.get_weekly_state('a8000000-0000-0000-0000-000000000001',null)->'current_week'->'commitment'->>'achieved','true','friend sees combined success immediately');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000005',true);
select is((select count(*) from public.notifications where type='shot_achieved'),0::bigint,'weekly-goal mute also suppresses CALLED IT friend alert');

-- Fresh already-achieved week may not create a retroactive declaration.
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000008',true);
select lives_ok($$select public.confirm_weekly_goal(3,'UTC')$$,'independent account confirms goal');
select lives_ok($$select pg_temp.qa_shot_complete() from generate_series(1,3)$$,'independent account reaches goal without calling');
select throws_ok($$select public.call_my_shot((public.get_weekly_state()->'current_week'->>'id')::uuid)$$,'P0001','weekly_goal_already_reached','first call after Flame already earned is forbidden');
select is(public.get_weekly_state()->'current_week'->'commitment','null'::jsonb,'rejected late call leaves no fabricated history');

-- Block revokes nested, direct and reaction access for an existing commitment.
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.block_user('a8000000-0000-0000-0000-000000000001')$$,'friend can revoke access after achievement');
select is((select count(*) from public.weekly_commitments),0::bigint,'block removes previously visible commitment');
select is((select count(*) from public.weekly_shot_reactions),0::bigint,'block removes previously visible shot reactions');
select throws_ok($$select public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),null)$$,'P0001','forbidden','revoked friend cannot mutate old reaction');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000001',true);
select is(jsonb_array_length(public.get_weekly_state()->'current_week'->'commitment'->'reaction_counts'),1,'blocked actor disappears from owner counts while other accepted reaction remains');

-- Deterministic administrator-only rollover, no fake client clocks.
reset role;
insert into qa_shot_state values('rolled',to_jsonb(public.ensure_weekly_period('a8000000-0000-0000-0000-000000000001',
 (select (value->'current_week'->>'ends_at')::timestamptz from qa_shot_state where key='achieved'))));
select ok((select finalized from public.weekly_commitments where id=(select (value->>'id')::uuid from qa_shot_state where key='called')),'successful commitment finalizes with its week');
select ok((select achieved from public.weekly_commitments where id=(select (value->>'id')::uuid from qa_shot_state where key='called')),'finalizing preserves achieved commitment');
select is((select weekly_goal from public.weekly_commitments where id=(select (value->>'id')::uuid from qa_shot_state where key='called')),4,'old declaration keeps old target after next target applies');
select is((select value->>'weekly_goal' from qa_shot_state where key='rolled'),'3','pending goal applies only to new period');
select is(public.weekly_period_document((select (value->>'id')::uuid from qa_shot_state where key='rolled'))->'commitment','null'::jsonb,'new week begins without automatically calling again');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000005',true);
set local role authenticated;
select is(public.set_shot_reaction((select (value->>'id')::uuid from qa_shot_state where key='called'),null),true,'accepted friend may remove own reaction after finalization');
reset role;
update public.profiles set weekly_goal=3,current_weekly_goal=3,weekly_goal_confirmed_at=now()-interval '8 days',weekly_timezone='UTC'
where id='a8000000-0000-0000-0000-000000000009';
insert into qa_shot_state values('past_week',to_jsonb(public.ensure_weekly_period('a8000000-0000-0000-0000-000000000009',date_trunc('week',now())-interval '6 days')));
insert into public.weekly_commitments(user_id,week_id,week_start_date,weekly_goal,called_at)
select 'a8000000-0000-0000-0000-000000000009',(value->>'id')::uuid,(value->>'week_start_date')::date,3,(value->>'starts_at')::timestamptz+interval '1 hour' from qa_shot_state where key='past_week';
insert into public.weekly_goal_changes(user_id,next_weekly_goal) values('a8000000-0000-0000-0000-000000000009',5);
select lives_ok($$select public.ensure_weekly_period('a8000000-0000-0000-0000-000000000009',clock_timestamp())$$,'missed called week rolls forward normally');
select is((select finalized from public.weekly_commitments where user_id='a8000000-0000-0000-0000-000000000009'),true,'missed commitment finalized neutrally');
select is((select achieved from public.weekly_commitments where user_id='a8000000-0000-0000-0000-000000000009'),false,'missed commitment never becomes achieved');
select is((select count(*) from public.notifications where recipient_id='a8000000-0000-0000-0000-000000000009'),0::bigint,'missed week generates no negative/shaming notification');
select set_config('request.jwt.claim.sub','a8000000-0000-0000-0000-000000000009',true);
set local role authenticated;
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','5','new week has independently scheduled higher goal');
select throws_ok($$select public.call_my_shot((select (value->>'id')::uuid from qa_shot_state where key='past_week'))$$,'P0001','weekly_week_changed','old week consent cannot announce the new higher goal');
select is((select count(*) from public.weekly_commitments),1::bigint,'boundary rejection leaves only historical declaration');
select is(public.get_weekly_state()->'current_week'->'commitment','null'::jsonb,'boundary rejection leaves new week unannounced');
select is((select count(*) from public.notifications where type='shot_called'),0::bigint,'boundary rejection emits no call notification');
select lives_ok($$select public.call_my_shot((public.get_weekly_state()->'current_week'->>'id')::uuid)$$,'new week may be consciously called after last weeks miss');
select is((select count(*) from public.weekly_commitments),2::bigint,'one declaration per separate week preserves history');
select is(public.get_weekly_state()->'history'->0->'commitment'->>'achieved','false','profile history contains neutral missed declaration');
select is(public.get_weekly_state()->'current_week'->'commitment'->>'achieved','false','new call starts open not inherited achieved');
reset role;
select lives_ok($$set constraints all immediate$$,'combined feature constraints valid before rollback');
select * from finish();
rollback;
