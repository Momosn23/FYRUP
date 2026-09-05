create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values
 ('a1000000-0000-0000-0000-000000000001'),('a1000000-0000-0000-0000-000000000002');
insert into public.profiles(id,username,display_name) values
 ('a1000000-0000-0000-0000-000000000001','qa_pause_owner','Owner'),
 ('a1000000-0000-0000-0000-000000000002','qa_pause_stranger','Stranger');
insert into public.activities(id,user_id,sport,status,started_at) values
 ('e1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','running','live',now()-interval '10 minutes');
select ok(not has_function_privilege('anon','public.set_activity_paused(uuid,boolean)','execute'),'anonymous pause denied');
select ok(not has_function_privilege('authenticated','public.finalize_activity_pause()','execute'),'pause trigger helper not public RPC');
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',false)).paused_seconds,0,'resume while running is no-op');
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',true)).paused_at,now(),'pause persists timestamp');
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',true)).paused_at,now(),'pause retry does not restart pause interval');
select throws_ok($$select public.set_activity_paused('e1000000-0000-0000-0000-000000000001',null)$$,'P0001','invalid_pause','null pause intent rejected');

-- Only the test administrator advances the fixture's pause start; no sleep required.
reset role;
update public.activities set paused_at=now()-interval '90 seconds' where id='e1000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',true)).paused_at,now()-interval '90 seconds','pause retry preserves earlier server timestamp');
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',false)).paused_seconds,90,'resume adds exact elapsed pause');
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',false)).paused_at,null::timestamptz,'resume clears pause timestamp');
select is((public.set_activity_paused('e1000000-0000-0000-0000-000000000001',false)).paused_seconds,90,'resume retry does not add twice');

select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.set_activity_paused('e1000000-0000-0000-0000-000000000001',true)$$,'P0001','activity_not_live','another account cannot pause activity');
select throws_ok($$select public.complete_activity('e1000000-0000-0000-0000-000000000001',null)$$,'P0001','activity_not_live','another account cannot complete activity');
select set_config('request.jwt.claim.sub','a1000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.set_activity_paused('e1000000-0000-0000-0000-000000000001',true)$$,'second pause allowed');
reset role;
update public.activities set paused_at=now()-interval '30 seconds' where id='e1000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((public.complete_activity('e1000000-0000-0000-0000-000000000001',2000)).paused_seconds,120,'completion includes final active pause exactly once');
select is((select paused_at from public.activities where id='e1000000-0000-0000-0000-000000000001'),null::timestamptz,'completed activity no longer paused');
select is((select distance_meters from public.activities where id='e1000000-0000-0000-0000-000000000001'),2000,'completion keeps distance input');
select is((select floor(extract(epoch from(ended_at-started_at)))::integer-paused_seconds from public.activities where id='e1000000-0000-0000-0000-000000000001'),480,'active duration excludes all pauses');
select throws_ok($$select public.complete_activity('e1000000-0000-0000-0000-000000000001',null)$$,'P0001','activity_not_live','completion retains established duplicate guard');
select throws_ok($$select public.set_activity_paused('e1000000-0000-0000-0000-000000000001',false)$$,'P0001','activity_not_live','completed activity cannot resume');

reset role;
insert into public.activities(id,user_id,sport,status,started_at,paused_at,paused_seconds) values
 ('e1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','gym','live',now()-interval '5 minutes',now()-interval '10 seconds',20);
set local role authenticated;
select lives_ok($$select public.cancel_activity('e1000000-0000-0000-0000-000000000002')$$,'existing cancellation works while paused');
select is((select paused_seconds from public.activities where id='e1000000-0000-0000-0000-000000000002'),30,'cancellation freezes accumulated pause');
select is((select paused_at from public.activities where id='e1000000-0000-0000-0000-000000000002'),null::timestamptz,'cancellation clears pause timestamp');
select throws_ok($$select public.set_activity_paused('e1000000-0000-0000-0000-000000000002',true)$$,'P0001','activity_not_live','cancelled activity cannot pause');
reset role;
select * from finish();
rollback;
