-- Only run in the disposable local test database.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values
 ('ab150000-0000-0000-0000-000000000001'),('ab150000-0000-0000-0000-000000000002'),
 ('ab150000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,display_name,activity_visibility,sports) values
 ('ab150000-0000-0000-0000-000000000001','qa_keep_private','Private Owner','nobody','{gym}'),
 ('ab150000-0000-0000-0000-000000000002','qa_keep_friend','Friend','friends','{running}');
insert into public.friendships(requester_id,addressee_id,status) values
 ('ab150000-0000-0000-0000-000000000001','ab150000-0000-0000-0000-000000000002','accepted');
insert into public.activities(user_id,sport,status,started_at,ended_at) values
 ('ab150000-0000-0000-0000-000000000001','gym','completed',now()-interval '30 minutes',now());
select ok(not has_function_privilege('anon','public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text)','execute'),'anonymous profile RPC denied');
select set_config('request.jwt.claim.sub','ab150000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is((public.upsert_profile('qa_keep_private','New Name','ab150000-0000-0000-0000-000000000001/avatar.jpg',1998::smallint,'Köln','New bio','{gym,running}',7::smallint,'friends')).activity_visibility,'nobody','stale metadata save returns real private visibility');
select is((select display_name from public.profiles where id=auth.uid()),'New Name','name still saves');
select is((select city from public.profiles where id=auth.uid()),'Köln','city still saves');
select is((select avatar_path from public.profiles where id=auth.uid()),'ab150000-0000-0000-0000-000000000001/avatar.jpg','avatar still saves');
select is((select sports from public.profiles where id=auth.uid()),'{gym,running}'::public.sport_kind[],'sports still save');
select is((select onboarding_step from public.profiles where id=auth.uid()),'sports','metadata cannot mark onboarding done');
select is((select weekly_goal::integer from public.profiles where id=auth.uid()),4,'metadata cannot change weekly target');
select is((public.upsert_profile('qa_keep_private','Retry')).activity_visibility,'nobody','legacy omitted default cannot undo private choice either');
select set_config('request.jwt.claim.sub','ab150000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.activities where user_id='ab150000-0000-0000-0000-000000000001'),0::bigint,'friend remains unable to read activity after stale metadata save');
select is((public.upsert_profile('qa_keep_friend','Own Edit',null,null,null,null,'{running}',4::smallint,'nobody')).activity_visibility,'friends','metadata also cannot silently apply stale opt-out');
select set_config('request.jwt.claim.sub','ab150000-0000-0000-0000-000000000001',true);
with changed as (update public.profiles set activity_visibility='friends' where id=auth.uid() and activity_visibility='nobody' returning *)
select is((select count(*) from changed),1::bigint,'explicit current privacy PATCH remains available');
select is((public.upsert_profile('qa_keep_private','Edit after opt-in',null,null,null,null,'{gym}',4::smallint,'nobody')).activity_visibility,'friends','old metadata cannot overwrite newly reviewed opt-in');
select set_config('request.jwt.claim.sub','ab150000-0000-0000-0000-000000000003',true);
select is((public.upsert_profile('qa_new_private','New private',null,null,null,null,'{gym}',4::smallint,'nobody')).activity_visibility,'nobody','new profile can explicitly begin private');
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.upsert_profile('qa_no_identity','No identity')$$,'P0001','forbidden','missing identity rejected');
reset role;
select is((select count(*) from public.notifications where recipient_id::text like 'ab150000%'),0::bigint,'profile privacy preservation generates no social pushes');
select * from finish();
rollback;
