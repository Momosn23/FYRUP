-- Disposable fixtures only. Verify the exact narrow PATCH semantics used by iOS.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users(id) values
 ('ab140000-0000-0000-0000-000000000001'),('ab140000-0000-0000-0000-000000000002');
insert into public.profiles(id,username,display_name,city,bio) values
 ('ab140000-0000-0000-0000-000000000001','qa_privacy_one','Privacy One','Berlin','Keep this'),
 ('ab140000-0000-0000-0000-000000000002','qa_privacy_two','Privacy Two','Hamburg','Also keep');
insert into public.friendships(requester_id,addressee_id,status) values
 ('ab140000-0000-0000-0000-000000000001','ab140000-0000-0000-0000-000000000002','accepted');
insert into public.activities(user_id,sport,status,started_at,ended_at) values
 ('ab140000-0000-0000-0000-000000000001','gym','completed',now()-interval '30 minutes',now());
select ok(has_column_privilege('authenticated','public.profiles','activity_visibility','update'),'existing column permission allows own visibility PATCH');
select ok(not has_column_privilege('anon','public.profiles','activity_visibility','update'),'anonymous visibility changes unavailable');
select set_config('request.jwt.claim.sub','ab140000-0000-0000-0000-000000000002',true);
set local role authenticated;
select is((select count(*) from public.activities where user_id='ab140000-0000-0000-0000-000000000001'),1::bigint,'friend can read activity before opt-out');
with changed as (update public.profiles set activity_visibility='nobody'
 where id='ab140000-0000-0000-0000-000000000001' and activity_visibility='friends' returning *)
select is((select count(*) from changed),0::bigint,'owner filter plus RLS rejects writes by a friend');
select set_config('request.jwt.claim.sub','ab140000-0000-0000-0000-000000000001',true);
with changed as (update public.profiles set activity_visibility='nobody'
 where id='ab140000-0000-0000-0000-000000000001' and activity_visibility='friends' returning *)
select is((select count(*) from changed where id=auth.uid() and activity_visibility='nobody'),1::bigint,'own atomic change returns one confirmed matching row');
select is((select city from public.profiles where id=auth.uid()),'Berlin','narrow PATCH preserves city');
select is((select bio from public.profiles where id=auth.uid()),'Keep this','narrow PATCH preserves bio');
select is((select display_name from public.profiles where id=auth.uid()),'Privacy One','narrow PATCH preserves name');
with changed as (update public.profiles set activity_visibility='friends'
 where id='ab140000-0000-0000-0000-000000000001' and activity_visibility='friends' returning *)
select is((select count(*) from changed),0::bigint,'stale expected value cannot overwrite the committed opt-out');
select is((select activity_visibility from public.profiles where id=auth.uid()),'nobody','conflict leaves opt-out intact');
select set_config('request.jwt.claim.sub','ab140000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.activities where user_id='ab140000-0000-0000-0000-000000000001'),0::bigint,'friend activity access disappears after opt-out');
select is((select activity_visibility from public.profiles where id=auth.uid()),'friends','other account choice remains unchanged');
select set_config('request.jwt.claim.sub','ab140000-0000-0000-0000-000000000001',true);
with changed as (update public.profiles set activity_visibility='friends'
 where id='ab140000-0000-0000-0000-000000000001' and activity_visibility='nobody' returning *)
select is((select count(*) from changed),1::bigint,'reviewed latest value permits an explicit change back');
select set_config('request.jwt.claim.sub','',true);
with changed as (update public.profiles set activity_visibility='nobody'
 where id='ab140000-0000-0000-0000-000000000001' and activity_visibility='friends' returning *)
select is((select count(*) from changed),0::bigint,'missing authenticated subject cannot change visibility');
reset role;
select is((select count(*) from public.notifications where recipient_id::text like 'ab140000%'),0::bigint,'privacy edits send no social notification');
select * from finish();
rollback;
