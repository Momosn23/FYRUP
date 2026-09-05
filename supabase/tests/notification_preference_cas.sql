create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values('ab110000-0000-0000-0000-000000000001'),('ab110000-0000-0000-0000-000000000002');
insert into public.profiles(id,username,display_name) values
 ('ab110000-0000-0000-0000-000000000001','qa_preference_one','Preference One'),
 ('ab110000-0000-0000-0000-000000000002','qa_preference_two','Preference Two');
create temporary table qa_preference_state(key text primary key,value jsonb);
grant all on qa_preference_state to authenticated;
insert into qa_preference_state values
 ('standard','{"friend_starts":false,"fyrup":true,"invitations":true,"reactions":true,"friend_requests":true,"reminders":true,"weekly_goal":true,"crew_goal":true}'),
 ('muted','{"friend_starts":false,"fyrup":false,"invitations":false,"reactions":false,"friend_requests":false,"reminders":false,"weekly_goal":false,"crew_goal":false}');
select ok(not has_table_privilege('authenticated','public.notification_preferences','update'),'authenticated direct table update cannot bypass CAS');
select ok(not has_table_privilege('authenticated','public.notification_preferences','insert'),'authenticated direct table insert cannot bypass CAS');
select ok(not has_table_privilege('authenticated','public.notification_preferences','delete'),'authenticated direct table delete cannot reset opt-outs');
select ok(has_table_privilege('authenticated','public.notification_preferences','select'),'owner read remains available with RLS');
select ok(not has_function_privilege('anon','public.save_notification_preferences_cas(jsonb,jsonb)','execute'),'anonymous CAS denied');
select ok(not has_function_privilege('anon','public.get_notification_preferences()','execute'),'anonymous read RPC denied');
select ok(not has_function_privilege('anon','public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)','execute'),'anonymous legacy write RPC denied');
select ok(has_function_privilege('authenticated','public.save_notification_preferences_cas(jsonb,jsonb)','execute'),'authenticated CAS available');
select ok(has_function_privilege('authenticated','public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)','execute'),'legacy installed client RPC retained explicitly');
select ok(position('for update' in pg_get_functiondef('public.save_notification_preferences_cas(jsonb,jsonb)'::regprocedure))
 <position('if v_current<>p_expected' in pg_get_functiondef('public.save_notification_preferences_cas(jsonb,jsonb)'::regprocedure)),
 'comparison happens after owner row lock, not in an unlocked preflight');

select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
select throws_ok($$select public.save_notification_preferences_cas('{}','{}')$$,'P0001','forbidden','missing authenticated subject rejected');
select set_config('request.jwt.claim.sub','ab110000-0000-0000-0000-000000000099',true);
select throws_ok($$select public.save_notification_preferences_cas('{}','{}')$$,'P0001','forbidden','missing profile rejected');
select set_config('request.jwt.claim.sub','ab110000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.save_notification_preferences_cas(null,(select value from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','missing expected snapshot never falls back to defaults');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),null)$$,'P0001','invalid_notification_preferences','missing desired snapshot rejected');
select throws_ok($$select public.save_notification_preferences_cas('[]',(select value from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','array expected snapshot rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),'false')$$,'P0001','invalid_notification_preferences','boolean desired snapshot rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value-'reactions' from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','partial expected snapshot rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value-'weekly_goal' from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','partial desired snapshot rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value||'{"unknown":false}'::jsonb from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','unknown expected field rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value||'{"user_id":"ab110000-0000-0000-0000-000000000002"}'::jsonb from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','caller cannot inject another account in desired document');
select throws_ok($$select public.save_notification_preferences_cas((select value||'{"reactions":"false"}'::jsonb from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','string boolean in expected rejected');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value||'{"weekly_goal":null}'::jsonb from qa_preference_state where key='muted'))$$,'P0001','invalid_notification_preferences','JSON null desired preference rejected');
select is((select count(*) from public.notification_preferences),0::bigint,'invalid requests do not create rows or implicit consent');
select lives_ok($$select public.get_notification_preferences()$$,'read-only client API still creates own initial default row');
select is((to_jsonb(public.get_notification_preferences())-array['user_id','created_at','updated_at']),(select value from qa_preference_state where key='standard'),'initial eight fields match documented defaults');

insert into qa_preference_state values('first_save',to_jsonb(public.save_notification_preferences_cas(
 (select value from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))));
select is((select value->>'user_id' from qa_preference_state where key='first_save'),auth.uid()::text,'CAS writes authenticated owner only');
select is((select value-array['user_id','created_at','updated_at'] from qa_preference_state where key='first_save'),(select value from qa_preference_state where key='muted'),'all explicit opt-outs saved');
select is(to_jsonb(public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))),
 (select value from qa_preference_state where key='first_save'),'lost-response retry with same desired state is idempotent including timestamps');
select throws_ok($$update public.notification_preferences set reactions=true where user_id=auth.uid()$$,'42501','permission denied for table notification_preferences','real direct write fails despite owner RLS');
select throws_ok($$delete from public.notification_preferences where user_id=auth.uid()$$,'42501','permission denied for table notification_preferences','real direct delete cannot re-enable defaults');
select throws_ok($$insert into public.notification_preferences(user_id) values(auth.uid())$$,'42501','permission denied for table notification_preferences','real direct insert cannot bypass required expected state');

-- Deterministically interleave two device snapshots. Device A's preflight saw
-- standard; B's opt-out commits before A attempts its whole-record write.
select lives_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='muted'),(select value from qa_preference_state where key='standard'))$$,'owner can explicitly restore preferences from reviewed muted state');
insert into qa_preference_state values('device_a_expected',to_jsonb(public.get_notification_preferences())-array['user_id','created_at','updated_at']);
select lives_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value||'{"reactions":false,"weekly_goal":false}'::jsonb from qa_preference_state where key='standard'))$$,'device B disables two categories after A preflight');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='device_a_expected'),(select value||'{"reminders":false}'::jsonb from qa_preference_state where key='device_a_expected'))$$,'P0001','notification_preferences_conflict','stale device A cannot re-enable B opt-outs even after successful preflight');
select is((public.get_notification_preferences()).reactions,false,'concurrent reaction opt-out survives');
select is((public.get_notification_preferences()).weekly_goal,false,'concurrent weekly opt-out survives');
select is((public.get_notification_preferences()).reminders,true,'conflict is atomic and does not partially apply A draft');
insert into qa_preference_state values('reviewed',to_jsonb(public.get_notification_preferences())-array['user_id','created_at','updated_at']);
select lives_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='reviewed'),(select value||'{"reminders":false}'::jsonb from qa_preference_state where key='reviewed'))$$,'reviewing latest state permits explicit new change');
select is((public.get_notification_preferences()).reminders,false,'reviewed reminders opt-out saved');
select is((public.get_notification_preferences()).reactions,false,'reviewed save preserves other device opt-out');
select is((public.get_notification_preferences()).friend_starts,false,'unrelated friend-start default remains off');

select set_config('request.jwt.claim.sub','ab110000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.notification_preferences),0::bigint,'another account cannot read first account preferences');
select lives_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='standard'),(select value from qa_preference_state where key='muted'))$$,'new second account can save from explicit initial snapshot');
select is((select count(*) from public.notification_preferences),1::bigint,'second account sees only its own row');
select is((public.get_notification_preferences()).user_id,auth.uid(),'CAS never accepts an externally supplied owner');
select lives_ok($$select public.save_notification_preferences(false,true,true,true,true,true,true,true)$$,'legacy server-controlled RPC remains callable for installed old clients');
select is((public.get_notification_preferences()).fyrup,true,'legacy RPC remains compatible');
select throws_ok($$select public.save_notification_preferences_cas((select value from qa_preference_state where key='muted'),(select value||'{"invitations":false}'::jsonb from qa_preference_state where key='standard'))$$,'P0001','notification_preferences_conflict','CAS also detects a competing legacy client change');
reset role;
select is((select count(*) from public.notifications where recipient_id::text like 'ab110000%'),0::bigint,'preference editing generates no social notification');
select is((select count(*) from public.weekly_activity_credits where user_id::text like 'ab110000%'),0::bigint,'preference editing awards no workout credit');
select * from finish();
rollback;
