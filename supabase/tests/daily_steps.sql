-- Actual authenticated role and RLS; synthetic HealthKit aggregates only.
-- Fixtures roll back. Run against a disposable/reset test database.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
set local time zone 'UTC';
select no_plan();
insert into auth.users(id) values
 ('a3000000-0000-0000-0000-000000000001'),('a3000000-0000-0000-0000-000000000002'),
 ('a3000000-0000-0000-0000-000000000003'),('a3000000-0000-0000-0000-000000000004');
insert into public.profiles(id,username,display_name) values
 ('a3000000-0000-0000-0000-000000000001','qa_steps_owner','Momo'),
 ('a3000000-0000-0000-0000-000000000002','qa_steps_friend','Max'),
 ('a3000000-0000-0000-0000-000000000003','qa_steps_stranger','Stranger'),
 ('a3000000-0000-0000-0000-000000000004','qa_steps_pending','Pending');
insert into public.friendships(requester_id,addressee_id,status) values
 ('a3000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000002','accepted'),
 ('a3000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000004','pending');
create temporary table qa_step_state(key text primary key,value jsonb);
grant all on qa_step_state to authenticated;

select ok(not has_function_privilege('anon','public.friend_daily_steps()','execute'),'anonymous cannot query shared steps');
select ok(not has_function_privilege('anon','public.get_step_sharing(uuid)','execute'),'anonymous cannot query preferences');
select ok(not has_function_privilege('authenticated','public.steps_are_shared(uuid)','execute'),'raw sharing preference helper is private');
select ok(not has_table_privilege('authenticated','public.daily_activity_metrics','insert'),'direct metric insert denied');
select ok(not has_table_privilege('authenticated','public.daily_activity_metrics','update'),'direct metric update denied');
select ok(not has_table_privilege('authenticated','public.step_sharing_preferences','update'),'direct preference update denied');
select ok(not has_column_privilege('authenticated','public.daily_activity_metrics','timezone','select'),'stored timezone is not exposed to friends');
select columns_are('public','daily_activity_metrics',array['id','user_id','local_date','timezone','steps','steps_shared','updated_at'],'metric table stores aggregate only, no samples or device fields');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is(public.get_step_sharing(auth.uid())->>'sharing_enabled','false','sharing defaults off with no preference row');
select is(public.get_step_sharing(auth.uid())->>'sharing_revision','0','new account starts at revision zero');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,0,clock_timestamp()),false,'OFF rejects aggregate upload');
select is((select count(*) from public.daily_activity_metrics),0::bigint,'no Health aggregate stored before explicit opt-in');
select is(public.set_step_sharing(auth.uid(),false)->>'sharing_revision','0','explicit initial OFF is idempotent');
select is(public.set_step_sharing(auth.uid(),true)->>'sharing_revision','1','opt-in increments sharing revision');
select is(public.set_step_sharing(auth.uid(),true)->>'sharing_revision','1','duplicate opt-in preserves token');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421),false,'unversioned client upload fails closed');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1),false,'missing observation timestamp fails closed');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,0,clock_timestamp()),false,'previous-revision upload fails closed');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,clock_timestamp()),true,'confirmed opt-in accepts today aggregate');
select is((select steps from public.daily_activity_metrics),8421,'owner reads exact 8421 aggregate');
insert into qa_step_state select 'first_metric',jsonb_build_object('id',id,'updated_at',updated_at) from public.daily_activity_metrics;
insert into qa_step_state select 'first_observation',to_jsonb(last_observed_at) from public.step_sharing_preferences where user_id=auth.uid();
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,(select (value#>>'{}')::timestamptz from qa_step_state where key='first_observation')),true,'identical observation retry is idempotent');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',1,1,(select (value#>>'{}')::timestamptz from qa_step_state where key='first_observation')),false,'same-time conflicting observation rejected');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8900,1,clock_timestamp()),true,'later daily value updates existing day');
select is((select count(*) from public.daily_activity_metrics),1::bigint,'same owner/date remains unique');
select is((select id::text from public.daily_activity_metrics),(select value->>'id' from qa_step_state where key='first_metric'),'daily row ID is stable on retry');
select is((select steps from public.daily_activity_metrics),8900,'refresh updates rather than sums aggregate');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,(select (value#>>'{}')::timestamptz from qa_step_state where key='first_observation')),false,'reverse arrival cannot replace newer Health observation');
select is((select steps from public.daily_activity_metrics),8900,'reversed old upload leaves latest total intact');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,clock_timestamp()),true,'corrected lower Health total is accepted without double-counting');
select is(public.goal_summary('UTC')->>'weekly_count','0','steps create no workout credits');
select is((select count(*) from public.activities),0::bigint,'steps do not create activities');
select is((select count(*) from public.notifications),0::bigint,'step changes create no push spam');
select throws_ok($$select public.set_step_sharing(auth.uid(),null)$$,'P0001','invalid_sharing_preference','null opt-in intent rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,'Not/A_Timezone',8421,1,clock_timestamp())$$,'P0001','invalid_timezone','unknown time zone rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,null,8421,1,clock_timestamp())$$,'P0001','invalid_timezone','missing time zone rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),null,'UTC',8421,1,clock_timestamp())$$,'P0001','stale_step_day','missing local day rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date-1,'UTC',8421,1,clock_timestamp())$$,'P0001','stale_step_day','yesterday cannot be uploaded as today');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date+1,'UTC',8421,1,clock_timestamp())$$,'P0001','stale_step_day','future day cannot be uploaded');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,'UTC',-1,1,clock_timestamp())$$,'P0001','invalid_step_count','negative step count rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,'UTC',300001,1,clock_timestamp())$$,'P0001','invalid_step_count','out-of-range step count rejected');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,clock_timestamp()+interval '1 day')$$,'P0001','invalid_observation_time','far-future observation cannot poison ordering cursor');
select throws_ok($$select public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,1,clock_timestamp()-interval '25 hours')$$,'P0001','invalid_observation_time','observation older than 24 hours rejected');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(jsonb_array_length(public.friend_daily_steps()),1,'accepted friend sees one shared owner');
select is(public.friend_daily_steps()->0->>'steps','8421','accepted friend sees exact shared value');
select is((select steps from public.daily_activity_metrics),8421,'direct RLS read matches authorized friend RPC');
select is((select array_agg(key order by key) from jsonb_object_keys(public.friend_daily_steps()->0) key),array['local_date','steps','updated_at','user_id','valid_until'],'friend JSON only contains necessary aggregate fields');
select ok((public.friend_daily_steps()->0->>'valid_until')::timestamptz>now(),'friend cache expiry is in the future');
select ok((public.friend_daily_steps()->0->>'valid_until')::timestamptz<=now()+interval '120 seconds','friend cache expiry is capped at 120 seconds');
select ok((public.friend_daily_steps()->0->>'valid_until')::timestamptz<=((current_date+1)::timestamp at time zone 'UTC'),'friend cache cannot outlive owner midnight');
select is((select count(*) from public.step_sharing_preferences),0::bigint,'friend cannot inspect owner sharing settings');
select throws_ok($$select public.get_step_sharing('a3000000-0000-0000-0000-000000000001')$$,'P0001','forbidden','friend cannot infer owner connection/preferences');
select throws_ok($$select public.set_step_sharing('a3000000-0000-0000-0000-000000000001',false)$$,'P0001','forbidden','friend cannot change owner sharing');
select throws_ok($$select public.sync_daily_steps('a3000000-0000-0000-0000-000000000001',current_date,'UTC',1,1,clock_timestamp())$$,'P0001','forbidden','friend cannot forge owner aggregate');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000003',true);
select is(jsonb_array_length(public.friend_daily_steps()),0,'stranger gets no shared values');
select is((select count(*) from public.daily_activity_metrics),0::bigint,'stranger direct RLS read returns no metrics');
select is(public.can_read_daily_steps((select (value->>'id')::uuid from qa_step_state where key='first_metric')),false,'known metric ID does not bypass friendship');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000004',true);
select is(jsonb_array_length(public.friend_daily_steps()),0,'pending friendship is insufficient');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.set_step_sharing(auth.uid(),false)->>'sharing_revision','2','revocation rotates upload token');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',9999,1,clock_timestamp()),false,'queued old upload after OFF cannot republish');
select is((select steps from public.daily_activity_metrics),8421,'rejected upload leaves private aggregate unchanged');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(jsonb_array_length(public.friend_daily_steps()),0,'OFF immediately revokes friend RPC');
select is((select count(*) from public.daily_activity_metrics),0::bigint,'OFF immediately revokes direct RLS');
select is(public.can_read_daily_steps((select (value->>'id')::uuid from qa_step_state where key='first_metric')),false,'OFF revokes even a previously known metric ID');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.set_step_sharing(auth.uid(),true)->>'sharing_revision','3','new opt-in gets new revision');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',9999,1,clock_timestamp()),false,'old pre-OFF upload still rejected after OFF-ON');
select is((select count(*) from public.daily_activity_metrics where steps_shared),0::bigint,'ON alone never republishes stored history');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,3,clock_timestamp()),true,'freshly confirmed upload republishes only current total');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',null,3,clock_timestamp()),true,'unavailable data withdraws safely without fabricated zero');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',8421,3,(select (value#>>'{}')::timestamptz from qa_step_state where key='first_observation')),false,'late count cannot undo a newer no-data withdrawal');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(jsonb_array_length(public.friend_daily_steps()),0,'no-data state is indistinguishable from private/disabled');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',0,3,clock_timestamp()),true,'actual zero is a legitimate aggregate');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(public.friend_daily_steps()->0->>'steps','0','actual shared zero remains distinct from unavailable');

-- Date-line travel: both time zones' saved dates would independently be current.
-- The latest device-day becomes the only publishable row, never two rows per user.
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.sync_daily_steps(auth.uid(),(now() at time zone 'Etc/GMT+12')::date,'Etc/GMT+12',5000,3,clock_timestamp()),true,'UTC-12 owner day accepted');
select is(public.sync_daily_steps(auth.uid(),(now() at time zone 'Pacific/Kiritimati')::date,'Pacific/Kiritimati',100,3,clock_timestamp()),true,'UTC+14 travel day accepted');
select is((select count(*) from public.daily_activity_metrics where steps_shared),1::bigint,'only one row published across time zones');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(jsonb_array_length(public.friend_daily_steps()),1,'travel cannot produce duplicate friend rows');
select is(public.friend_daily_steps()->0->>'local_date',((now() at time zone 'Pacific/Kiritimati')::date)::text,'friend sees latest owner-local date, not viewer-local date');
select is(public.friend_daily_steps()->0->>'steps','100','old timezone value not displayed as new today');
select is((public.friend_daily_steps()->0->>'valid_until')::timestamptz,
 least((((now() at time zone 'Pacific/Kiritimati')::date+1)::timestamp at time zone 'Pacific/Kiritimati'),now()+interval '120 seconds'),
 'travel cache expiry follows owner timezone, not viewer timezone');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.sync_daily_steps(auth.uid(),(now() at time zone 'Etc/GMT+12')::date,'Etc/GMT+12',5000,3,
 (select (value#>>'{}')::timestamptz from qa_step_state where key='first_observation')),false,'delayed old-timezone upload cannot undo newer travel day');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select is(public.friend_daily_steps()->0->>'steps','100','latest travel observation survives reversed network arrival');

-- Simulate midnight by administratively ageing the stored local date. RLS expiry
-- itself uses real database time: no background job/client refresh is needed.
reset role;
update public.daily_activity_metrics set local_date=local_date-10 where user_id='a3000000-0000-0000-0000-000000000001' and steps_shared;
set local role authenticated;
select is(jsonb_array_length(public.friend_daily_steps()),0,'midnight expiry removes yesterday without client refresh');
select is((select count(*) from public.daily_activity_metrics),0::bigint,'direct RLS also expires past days');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select ok((select count(*) from public.daily_activity_metrics)>0,'owner may read own private day history');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',25,3,clock_timestamp()),true,'new day accepts fresh aggregate');
select is((select count(*) from public.daily_activity_metrics where steps_shared),1::bigint,'new day does not republish history');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',50,3,
 least(clock_timestamp()+interval '1 minute',((current_date+1)::timestamp at time zone 'UTC')-interval '1 microsecond')),true,
 'small clock skew is tolerated within current day');
select ok((select last_observed_at<=clock_timestamp() from public.step_sharing_preferences where user_id=auth.uid()),'tolerated future observation is clamped to server receipt time');
select is(public.sync_daily_steps(auth.uid(),current_date,'UTC',55,3,clock_timestamp()),true,'legitimate next upload is not blocked by tolerated future timestamp');

select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.block_user('a3000000-0000-0000-0000-000000000001')$$,'accepted friend can block owner');
select is(jsonb_array_length(public.friend_daily_steps()),0,'blocked friend cannot read steps');
select is((select count(*) from public.daily_activity_metrics),0::bigint,'blocked direct table read denied');
select set_config('request.jwt.claim.sub','a3000000-0000-0000-0000-000000000001',true);
select is(public.get_step_sharing(auth.uid())->>'sharing_enabled','true','blocking does not change owner preference');
select is(public.goal_summary('UTC')->>'weekly_count','0','all step operations still earn no workout/flame credits');
select is((select count(*) from public.notifications),0::bigint,'no notifications generated by step updates');
reset role;
select ok(not exists(select 1 from pg_trigger where tgrelid='public.daily_activity_metrics'::regclass and not tgisinternal),'step aggregates have no activity/flame side-effect triggers');
select * from finish();
rollback;
