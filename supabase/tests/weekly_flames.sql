-- Run only on a disposable test database. Administrator clocks/fixtures below
-- never become client RPCs. Production callers cannot provide completion time.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
set local time zone 'UTC';
select no_plan();
insert into auth.users(id) select ('a5000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,14)n;
insert into public.profiles(id,username,display_name)
select id,'qa_week_'||right(id::text,2),'Week '||right(id::text,2) from auth.users where id::text like 'a5000000%';
insert into public.friendships(requester_id,addressee_id,status) values
 ('a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000002','accepted'),
 ('a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000004','pending');
create temporary table qa_week_state(key text primary key,value jsonb);
grant all on qa_week_state to authenticated;
-- Test-owned fixture helper backdates only the start of a live activity. The
-- real public completion RPC sets its own end clock and performs all credits.
create function pg_temp.qa_complete(p_sport public.sport_kind,p_seconds int,p_pause int default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 insert into public.activities(user_id,sport,status,started_at,paused_seconds)
 values(auth.uid(),p_sport,'live',clock_timestamp()-make_interval(secs=>p_seconds),p_pause) returning id into v_id;
 perform public.complete_activity(v_id,null);
 return v_id;
end; $$;
grant execute on function pg_temp.qa_complete(public.sport_kind,int,int) to authenticated;

select ok(not has_function_privilege('anon','public.get_weekly_state(uuid,text)','execute'),'anonymous weekly state denied');
select ok(not has_function_privilege('anon','public.set_next_weekly_goal(integer)','execute'),'anonymous goal mutation denied');
select ok(not has_function_privilege('authenticated','public.ensure_weekly_period(uuid,timestamptz)','execute'),'client cannot choose server weekly clock');
select ok(not has_function_privilege('authenticated','public.credit_weekly_activity(uuid,boolean)','execute'),'client cannot manufacture credit RPC');
select ok(not has_function_privilege('authenticated','public.award_weekly_flame(uuid,timestamptz,boolean)','execute'),'client cannot award a flame');
select ok(not has_function_privilege('authenticated','public.weekly_state_document(uuid,timestamptz,boolean)','execute'),'raw state helper cannot bypass friendship');
select ok(not has_function_privilege('authenticated','public.lock_weekly_people()','execute'),'lock helper is not a public RPC');
select ok(not has_function_privilege('authenticated','public.today_feed_before_weekly_flames(text)','execute'),'old weekly counting route is inaccessible');
select ok(not has_column_privilege('authenticated','public.profiles','weekly_goal','update'),'direct legacy target update denied');
select ok(not has_column_privilege('authenticated','public.profiles','current_weekly_goal','update'),'direct current target update denied');
select ok(not has_column_privilege('authenticated','public.profiles','weekly_goal_confirmed_at','insert'),'direct confirmed profile insert denied');
select ok(not has_table_privilege('authenticated','public.weekly_progress','update'),'direct weekly counter update denied');
select ok(not has_table_privilege('authenticated','public.weekly_activity_credits','insert'),'direct credit insert denied');
select ok(not has_table_privilege('authenticated','public.weekly_goal_changes','update'),'direct pending target update denied');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name in('next_weekly_goal','next_weekly_timezone')),'pending intent cannot leak through legacy profile composites');

select is((select current_weekly_goal from public.profiles where username='qa_legacy_four'),4,'migration preserves valid legacy target');
select ok((select weekly_goal_confirmed_at is not null from public.profiles where username='qa_legacy_four'),'valid legacy target migrated confirmed');
select is((select current_weekly_goal from public.profiles where username='qa_legacy_two'),3,'legacy target two safely upgraded to three');
select ok((select weekly_goal_confirmed_at is null from public.profiles where username='qa_legacy_two'),'legacy below minimum requires conscious confirmation');
select is((select count(*) from public.weekly_progress where user_id='af500000-0000-0000-0000-000000000001'),1::bigint,'migration does not fabricate historical weeks');
select is((select completed_workouts from public.weekly_progress where user_id='af500000-0000-0000-0000-000000000001'),4,'backfill credits actual eligible current week only');
select ok((select flame_earned from public.weekly_progress where user_id='af500000-0000-0000-0000-000000000001'),'backfill earns current legacy flame');
select is((select count(*) from public.notifications where type='weekly_goal'),0::bigint,'backfill never sends old achievement pushes');

select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000001',true);
set local role authenticated;
insert into qa_week_state values('initial',public.get_weekly_state(auth.uid(),'UTC'));
select is((select value->>'goal_confirmed' from qa_week_state where key='initial'),'false','new profile starts unconfirmed');
select is((select value->>'suggested_weekly_goal' from qa_week_state where key='initial'),'4','new profile proposes four');
select is((select value->'current_week' from qa_week_state where key='initial'),'null'::jsonb,'unconfirmed progress hidden from normal week model');
select throws_ok($$select public.confirm_weekly_goal(2,'UTC')$$,'P0001','invalid_weekly_goal','target below three rejected');
select throws_ok($$select public.confirm_weekly_goal(8,'UTC')$$,'P0001','invalid_weekly_goal','target above seven rejected');
select throws_ok($$select public.confirm_weekly_goal(null,'UTC')$$,'P0001','invalid_weekly_goal','missing conscious choice rejected');
select throws_ok($$select public.confirm_weekly_goal(4,'Not/AZone')$$,'P0001','invalid_timezone','unknown timezone rejected');
select throws_ok($$select public.set_next_weekly_goal(5)$$,'P0001','weekly_goal_not_confirmed','pending cannot bypass initial confirmation');
select is(public.confirm_weekly_goal(4,'UTC')->>'goal_confirmed','true','conscious valid target confirmed');
insert into qa_week_state values('confirmed',public.get_weekly_state(auth.uid(),null));
select is(public.get_weekly_state(auth.uid(),null)->'current_week'->>'weekly_goal','4','target survives subsequent state request');
select is(public.confirm_weekly_goal(4,'UTC')->'current_week'->>'id',(select value->'current_week'->>'id' from qa_week_state where key='confirmed'),'same confirmation is idempotent');
select throws_ok($$select public.confirm_weekly_goal(3,'UTC')$$,'P0001','weekly_goal_already_confirmed','repeat confirm cannot lower current target');
select lives_ok($$select public.upsert_profile('qa_week_01','Renamed',null,null,null,null,'{}',1::smallint,'nobody')$$,'legacy profile editing remains compatible');
-- Visibility is a separate, consciously reviewed write, never a profile field replay.
update public.profiles set activity_visibility='nobody' where id=auth.uid();
select is((select weekly_goal::int from public.profiles where id=auth.uid()),4,'legacy upsert target parameter cannot bypass current goal');
select is(public.get_weekly_state(auth.uid(),null)->>'goal_confirmed','true','profile editing retains confirmation');
select throws_ok($$update public.profiles set weekly_goal=3 where id=auth.uid()$$,'42501','permission denied for table profiles','real authenticated direct legacy target write is forbidden');
select throws_ok($$update public.weekly_progress set completed_workouts=99 where user_id=auth.uid()$$,'42501','permission denied for table weekly_progress','real authenticated counter write is forbidden');
select ok((public.get_weekly_state(auth.uid(),null)->>'server_now')::timestamptz>=now(),'state contains authoritative server clock');
select is(public.goal_summary('UTC')->>'weekly_count','0','legacy goals surface begins at same zero');

insert into qa_week_state values('activity1',to_jsonb(pg_temp.qa_complete('gym',600)));
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','1','first completed training earns one credit');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','false','one of four has no flame');
select lives_ok($$select pg_temp.qa_complete('running',600)$$,'second different sport completes');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','2','second completed training earns second credit');
select lives_ok($$select pg_temp.qa_complete('martial_arts',600)$$,'third sport completes same day');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','3','multiple real same-day trainings count');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','false','three of four still no flame');
select lives_ok($$select pg_temp.qa_complete('football',600)$$,'fourth training completes');
insert into qa_week_state values('earned',public.get_weekly_state());
select is((select value->'current_week'->>'completed_workouts' from qa_week_state where key='earned'),'4','fourth training reaches target');
select is((select value->'current_week'->>'flame_earned' from qa_week_state where key='earned'),'true','flame immediately earned before Sunday');
select is(public.get_weekly_state()->>'current_streak','0','open successful week does not prematurely raise finalized streak');
select is((select count(*) from public.notifications where type='weekly_goal'),1::bigint,'one achievement notification queued');
select is(public.claim_flame_celebration((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned')),true,'first device claims celebration');
select is(public.claim_flame_celebration((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned')),false,'second/retry device cannot repeat celebration');
select lives_ok($$select pg_temp.qa_complete('yoga',600)$$,'fifth workout still permitted after target');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','5','overachievement is represented as five of four');
select is(public.get_weekly_state()->'current_week'->>'flame_earned_at',(select value->'current_week'->>'flame_earned_at' from qa_week_state where key='earned'),'overachievement preserves first earned instant');
select is((select count(*) from public.notifications where type='weekly_goal'),1::bigint,'overachievement generates no second flame notification');
select throws_ok($$select public.complete_activity((select (value #>> '{}')::uuid from qa_week_state where key='activity1'),null)$$,'P0001','activity_not_live','duplicate completion keeps owner/live guard');
reset role;
select is(public.credit_weekly_activity((select (value #>> '{}')::uuid from qa_week_state where key='activity1')),false,'internal duplicate delivery is idempotent');
set local role authenticated;
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','5','duplicate completion did not increment');
insert into qa_week_state values('short',to_jsonb(pg_temp.qa_complete('other',59)));
select is((select status::text from public.activities where id=(select (value #>> '{}')::uuid from qa_week_state where key='short')),'completed','short training is still saved normally');
select is((select reason from public.weekly_activity_credits where activity_id=(select (value #>> '{}')::uuid from qa_week_state where key='short')),'active_duration_under_60_seconds','short training records explicit antiabuse reason');
select is((select rule_version from public.weekly_activity_credits where activity_id=(select (value #>> '{}')::uuid from qa_week_state where key='short')),1,'credit decisions carry versioned rule');
select lives_ok($$select pg_temp.qa_complete('cycling',600,550)$$,'mostly paused workout saves normally');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','5','short and mostly paused workouts earn no credit');
select lives_ok($$select pg_temp.qa_complete('swimming',60)$$,'exactly sixty active seconds eligible');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','6','sixty-second boundary counts exactly once');
select lives_ok($$select pg_temp.qa_complete(s,600) from unnest(array['basketball','racket','other']::public.sport_kind[])s$$,'remaining regular sport kinds complete');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','9','all regular sports are eligible');
select is((select count(distinct a.sport) from public.weekly_activity_credits c join public.activities a on a.id=c.activity_id where c.eligible),9::bigint,'eligible credit records preserve varied sport relation');

select is(public.set_next_weekly_goal(6)->>'next_weekly_goal','6','increase scheduled for following week');
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','4','increase cannot rewrite active target');
select is(public.set_next_weekly_goal(3)->>'next_weekly_goal','3','decrease also only schedules following week');
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','4','decrease cannot rewrite active target');
select is(public.set_next_weekly_goal(4)->'next_weekly_goal','null'::jsonb,'selecting current target clears pending change');
select is(public.set_next_weekly_goal(5)->>'next_weekly_goal','5','pending next target restored for rollover test');
select is(public.get_weekly_state(auth.uid(),'America/New_York')->>'next_timezone','America/New_York','travel zone queued for following week');
select is(public.get_weekly_state()->'current_week'->>'timezone','UTC','active zone frozen during travel');
select is(public.goal_summary('America/New_York')->>'weekly_count','9','legacy summary uses credits not raw completed count');

-- Planned/live/cancelled and large step aggregates never create weekly credit.
insert into qa_week_state values('live',to_jsonb((public.start_activity('gym',null,null,null)).id));
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','9','live training counts zero until completion');
select lives_ok($$select public.cancel_activity((select (value #>> '{}')::uuid from qa_week_state where key='live'))$$,'live training can be cancelled');
select lives_ok($$select public.plan_session('running',null,now()+interval '2 hours',60::smallint,null,'{}')$$,'planned training remains available');
select lives_ok($$select public.set_step_sharing(auth.uid(),true)$$,'separate step consent can be enabled');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',20000,1,clock_timestamp()),true,'twenty thousand steps shared');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','9','cancelled/planned/steps leave workout credits unchanged');
select throws_ok($$select public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'🔥')$$,'P0001','forbidden','owner cannot self-react');

-- Authorized friend can see flame, not private credit details or pending intent.
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000002',true);
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'current_week'->>'completed_workouts','9','accepted friend sees progress even when activities private');
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'next_weekly_goal','null'::jsonb,'friend cannot inspect next target');
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'next_timezone','null'::jsonb,'friend cannot inspect pending travel');
select is((select count(*) from public.weekly_goal_changes),0::bigint,'direct RLS hides other users pending intent');
select is((select count(*) from public.weekly_activity_credits),0::bigint,'friend cannot inspect private credit decisions');
select is(jsonb_array_length(public.get_friends_weekly_state()),1,'batch contains accepted friend only');
select is(public.get_friends_weekly_state()->0->'history','[]'::jsonb,'batch omits heavy historical list');
select throws_ok($$select public.get_weekly_state('a5000000-0000-0000-0000-000000000001','Asia/Tokyo')$$,'P0001','forbidden','friend cannot change owners zone');
select throws_ok($$select public.claim_flame_celebration((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'))$$,'P0001','forbidden','friend cannot consume owners celebration');
select is(public.today_feed('UTC')->'crew'->0->>'weekly_count','9','existing friend feed adopts authoritative credited count');
select is(public.today_feed('UTC')->'crew'->0->'activity','null'::jsonb,'private activity details remain hidden while aggregate visible');
select is(public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'🔥'),true,'friend can react to earned flame');
select is(public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'🔥'),true,'reaction retry idempotent');
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'current_week'->>'my_reaction','🔥','reaction reflected in authorized state');
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'current_week'->'reaction_counts'->0->>'count','1','reaction aggregation deduplicates repeated taps');
select throws_ok($$select public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'👎')$$,'P0001','invalid_reaction','unsupported reaction rejected');
select is(public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'💪'),true,'friend can change reaction');
select is(public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),null),true,'explicit null removes reaction');
select is(public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)->'current_week'->'reaction_counts','[]'::jsonb,'removed reaction disappears from counts');
select is(public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'👏'),true,'reaction may be re-added');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.notifications where type='flame_reaction'),1::bigint,'change/remove/re-add does not spam reaction notifications');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)$$,'P0001','forbidden','stranger cannot query owner stats');
select is((select count(*) from public.weekly_progress),0::bigint,'stranger direct RLS cannot read weeks');
select throws_ok($$select public.set_flame_reaction((select (value->'current_week'->>'id')::uuid from qa_week_state where key='earned'),'🔥')$$,'P0001','forbidden','stranger cannot react by guessing UUID');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000004',true);
select throws_ok($$select public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)$$,'P0001','forbidden','pending friendship insufficient');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.block_user('a5000000-0000-0000-0000-000000000001')$$,'blocking remains available');
select throws_ok($$select public.get_weekly_state('a5000000-0000-0000-0000-000000000001',null)$$,'P0001','forbidden','blocked friend stats immediately unavailable');
select is(jsonb_array_length(public.get_friends_weekly_state()),0,'blocked owner removed from batch');
select is((select count(*) from public.weekly_progress where user_id='a5000000-0000-0000-0000-000000000001'),0::bigint,'blocked direct week read unavailable');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000001',true);
select is(public.get_weekly_state()->'current_week'->'reaction_counts','[]'::jsonb,'blocked reactions vanish from aggregates');
select is((select count(*) from public.weekly_flame_reactions),0::bigint,'blocked reactions also hidden by direct RLS');

-- No flame until explicit confirmation, but valid training never disappears.
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000005',true);
select lives_ok($$select pg_temp.qa_complete('gym',600) from generate_series(1,3)$$,'existing unconfirmed account may still train');
select is(public.get_weekly_state()->'current_week','null'::jsonb,'pre-confirm workouts do not expose unconfirmed progress model');
select is((select count(*) from public.notifications where type='weekly_goal'),0::bigint,'no flame or push without conscious goal');
select is(public.confirm_weekly_goal(3,'Europe/Berlin')->'current_week'->>'completed_workouts','3','confirmation retains valid current-week training');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','true','confirmed reached target can earn flame immediately');

-- Muting optional notifications never disables the achievement itself.
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000006',true);
select lives_ok($$select public.confirm_weekly_goal(3,'UTC')$$,'muted user confirms goal');
select lives_ok($$select public.save_notification_preferences(false,true,true,false,true,true,false,true)$$,'weekly and reaction pushes can be disabled');
select lives_ok($$select pg_temp.qa_complete('gym',600) from generate_series(1,3)$$,'muted user completes three trainings');
select is(public.get_weekly_state()->'current_week'->>'flame_earned','true','muted user still earns flame');
select is((select count(*) from public.notifications where type in('weekly_goal','flame_reaction')),0::bigint,'muted achievement produces no optional notification');
select lives_ok($$select pg_temp.qa_complete('cycling',600)$$,'normal cycling also earns credit');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','4','cycling credit counts independently of paused cycling rejection');
reset role;
insert into public.friendships(requester_id,addressee_id,status) values
 ('a5000000-0000-0000-0000-000000000005','a5000000-0000-0000-0000-000000000006','accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000005',true);
select is(public.set_flame_reaction((public.get_weekly_state('a5000000-0000-0000-0000-000000000006',null)->'current_week'->>'id')::uuid,'🔥'),true,'friend can react despite recipient push mute');
select set_config('request.jwt.claim.sub','a5000000-0000-0000-0000-000000000006',true);
select is(public.get_weekly_state()->'current_week'->'reaction_counts'->0->>'count','1','muted reaction still visible in app');
select is((select count(*) from public.notifications where type='flame_reaction'),0::bigint,'reaction preference suppresses optional notification');
select is(public.set_next_weekly_goal(7)->>'next_weekly_goal','7','maximum valid goal seven accepted for next week');
select throws_ok($$select public.set_next_weekly_goal(8)$$,'P0001','invalid_weekly_goal','pending target above maximum rejected');
select throws_ok($$select public.set_next_weekly_goal(2)$$,'P0001','invalid_weekly_goal','pending target below minimum rejected');
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','3','invalid pending changes preserve current target');

-- Administrator-only deterministic calendar fixtures (never arbitrary client clocks).
reset role;
update public.profiles set current_weekly_goal=3,weekly_goal=3,weekly_goal_confirmed_at='2026-01-01Z',weekly_timezone='Europe/Berlin'
where id::text between 'a5000000-0000-0000-0000-000000000007' and 'a5000000-0000-0000-0000-000000000014';
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-03T12:00:00Z')$$,'historical period created for time-boundary fixture');
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a5000000-0000-0000-0000-000000000007','gym','completed','2026-08-04T10:00:00Z'::timestamptz,'2026-08-04T11:00:00Z'::timestamptz from generate_series(1,3);
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-09T21:59:59Z')->>'current_streak','0','first still-open success does not count finalized streak');
select is((public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-09T21:59:59Z')).week_start_date,'2026-08-03'::date,'Sunday last second stays old week');
insert into public.weekly_goal_changes(user_id,next_weekly_goal) values('a5000000-0000-0000-0000-000000000007',5);
select is((public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-09T22:00:00Z')).weekly_goal,5,'exact Monday applies pending five');
select is((select count(*) from public.weekly_goal_changes where user_id='a5000000-0000-0000-0000-000000000007'),0::bigint,'rollover clears pending change atomically');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-10T12:00:00Z')->'current_week'->>'completed_workouts','0','new Monday resets only new week');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-10T12:00:00Z')->>'current_streak','1','finished successful first week starts streak');
select is((select weekly_goal from public.weekly_progress where user_id='a5000000-0000-0000-0000-000000000007' and week_start_date='2026-08-03'),3,'closed historical target unchanged');
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a5000000-0000-0000-0000-000000000007','gym','completed','2026-08-11T10:00:00Z'::timestamptz,'2026-08-11T11:00:00Z'::timestamptz from generate_series(1,5);
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-17T12:00:00Z')$$,'second week finalizes');
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a5000000-0000-0000-0000-000000000007','running','completed','2026-08-18T10:00:00Z'::timestamptz,'2026-08-18T11:00:00Z'::timestamptz from generate_series(1,5);
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-24T12:00:00Z')$$,'third week finalizes');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-24T12:00:00Z')->>'current_streak','3','three finalized successful weeks yield streak three');
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-08-31T12:00:00Z')$$,'empty fourth week finalizes');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-31T12:00:00Z')->>'current_streak','0','failed week resets current streak');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-08-31T12:00:00Z')->>'best_streak','3','failed week preserves best streak');
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a5000000-0000-0000-0000-000000000007','yoga','completed','2026-09-01T10:00:00Z'::timestamptz,'2026-09-01T11:00:00Z'::timestamptz from generate_series(1,5);
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-09-07T12:00:00Z')$$,'next successful week finalizes');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-09-07T12:00:00Z')->>'current_streak','1','success after miss starts streak one');
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000007','2026-09-28T12:00:00Z')$$,'long absence materializes all intermediate weeks');
select is((select count(*) from public.weekly_progress where user_id='a5000000-0000-0000-0000-000000000007'),9::bigint,'missing weeks are not skipped');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-09-28T12:00:00Z')->>'current_streak','0','long absence breaks streak');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000007','2026-09-28T12:00:00Z')->>'best_streak','3','long absence preserves record');

-- Berlin -> New York: nominal label+7 end, not a six-hour miniweek.
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000008','2026-08-03T12:00:00Z')$$,'Berlin travel fixture initialized');
insert into public.weekly_goal_changes(user_id,next_weekly_timezone) values('a5000000-0000-0000-0000-000000000008','America/New_York');
insert into qa_week_state values('travel',to_jsonb(public.ensure_weekly_period('a5000000-0000-0000-0000-000000000008','2026-08-09T22:00:00Z')));
select is((select value->>'week_start_date' from qa_week_state where key='travel'),'2026-08-10','travel labels advance exactly seven dates');
select is((select (value->>'starts_at')::timestamptz from qa_week_state where key='travel'),'2026-08-09T22:00:00Z'::timestamptz,'new travel period starts exactly at old end');
select is((select (value->>'ends_at')::timestamptz from qa_week_state where key='travel'),'2026-08-17T04:00:00Z'::timestamptz,'new travel period ends following nominal Monday in new zone');
select is((select extract(epoch from((value->>'ends_at')::timestamptz-(value->>'starts_at')::timestamptz))::int from qa_week_state where key='travel'),174*3600,'Berlin to New York transition is 174 hours not six');
insert into public.activities(user_id,sport,status,started_at,ended_at) values
 ('a5000000-0000-0000-0000-000000000008','running','completed','2026-08-09T21:00:00Z','2026-08-09T22:00:00Z');
select is((select completed_workouts from public.weekly_progress where user_id='a5000000-0000-0000-0000-000000000008' and week_start_date='2026-08-10'),1,'cross-boundary training belongs to server completion week');
select is((select completed_workouts from public.weekly_progress where user_id='a5000000-0000-0000-0000-000000000008' and week_start_date='2026-08-03'),0,'cross-boundary training never double credits old week');

update public.profiles set weekly_timezone='Etc/GMT+12' where id='a5000000-0000-0000-0000-000000000009';
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000009','2026-08-04T12:00:00Z')$$,'UTC minus twelve fixture initialized');
insert into public.weekly_goal_changes(user_id,next_weekly_timezone) values('a5000000-0000-0000-0000-000000000009','Pacific/Kiritimati');
insert into qa_week_state values('dateline',to_jsonb(public.ensure_weekly_period('a5000000-0000-0000-0000-000000000009','2026-08-10T12:00:00Z')));
select is((select extract(epoch from((value->>'ends_at')::timestamptz-(value->>'starts_at')::timestamptz))::int from qa_week_state where key='dateline'),142*3600,'UTC minus12 to plus14 remains 142 hours without miniweek');
select is((select value->>'week_start_date' from qa_week_state where key='dateline'),'2026-08-10','date-line travel preserves contiguous Monday labels');

insert into qa_week_state values('spring',to_jsonb(public.ensure_weekly_period('a5000000-0000-0000-0000-000000000010','2026-03-25T12:00:00Z')));
select is((select extract(epoch from((value->>'ends_at')::timestamptz-(value->>'starts_at')::timestamptz))::int from qa_week_state where key='spring'),167*3600,'Berlin spring DST week has 167 hours');
insert into qa_week_state values('autumn',to_jsonb(public.ensure_weekly_period('a5000000-0000-0000-0000-000000000011','2026-10-21T12:00:00Z')));
select is((select extract(epoch from((value->>'ends_at')::timestamptz-(value->>'starts_at')::timestamptz))::int from qa_week_state where key='autumn'),169*3600,'Berlin autumn DST week has 169 hours');

-- Historical gaps and unconfirmed successes must never be interpreted as streaks.
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000012','2026-01-05T12:00:00Z')$$,'long history fixture initialized');
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000012','2027-02-01T12:00:00Z')$$,'long history finalized without missing weeks');
select is(jsonb_array_length(public.weekly_state_document('a5000000-0000-0000-0000-000000000012','2027-02-01T12:00:00Z')->'history'),52,'history bounded to most recent 52 closed weeks');
update public.profiles set weekly_goal_confirmed_at=null where id='a5000000-0000-0000-0000-000000000013';
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000013','2026-08-03T12:00:00Z')$$,'unconfirmed prior-week fixture initialized');
insert into public.activities(user_id,sport,status,started_at,ended_at)
select 'a5000000-0000-0000-0000-000000000013','gym','completed','2026-08-04T10:00:00Z'::timestamptz,'2026-08-04T11:00:00Z'::timestamptz from generate_series(1,4);
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000013','2026-08-10T12:00:00Z')$$,'unconfirmed previous success finalizes without flame');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000013','2026-08-10T12:00:00Z')->'history','[]'::jsonb,'unconfirmed past successes excluded from flame history');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000013','2026-08-10T12:00:00Z')->>'current_streak','0','unconfirmed prior week never grants streak');

-- A sparse/restored history cannot join successes across an absent week.
insert into public.weekly_progress(user_id,week_start_date,timezone,starts_at,ends_at,weekly_goal,goal_confirmed,
 completed_workouts,flame_earned,flame_earned_at,finalized,finalized_at)
select 'a5000000-0000-0000-0000-000000000014',d,'UTC',d::timestamp at time zone 'UTC',(d+7)::timestamp at time zone 'UTC',3,true,
 3,true,(d+1)::timestamp at time zone 'UTC',true,(d+7)::timestamp at time zone 'UTC'
from unnest(array['2026-08-03','2026-08-17']::date[])d;
select lives_ok($$select public.ensure_weekly_period('a5000000-0000-0000-0000-000000000014','2026-08-24T12:00:00Z')$$,'sparse history advances to current week');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000014','2026-08-24T12:00:00Z')->>'current_streak','1','missing historical week breaks streak instead of joining two successes');
select is(public.weekly_state_document('a5000000-0000-0000-0000-000000000014','2026-08-24T12:00:00Z')->>'best_streak','1','sparse history does not inflate best streak');
select ok(not exists(select 1 from public.weekly_progress a join public.weekly_progress b on a.user_id=b.user_id and a.week_start_date<b.week_start_date
 where tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(b.starts_at,b.ends_at,'[)')),'all produced weekly periods have nonoverlapping UTC boundaries');
select is((select count(*) from public.weekly_activity_credits),
 (select count(distinct activity_id) from public.weekly_activity_credits),'every activity maps to at most one credited week');

select * from finish();
rollback;
