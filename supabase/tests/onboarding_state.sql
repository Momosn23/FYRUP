-- Disposable-database regression tests only. Never run fixture creation against production.
create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
set local time zone 'UTC';
select no_plan();

insert into auth.users(id) select ('a6000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,4)n;
insert into public.profiles(id,username,display_name,sports) values
 ('a6000000-0000-0000-0000-000000000001','qa_onboard_owner','Onboarding Owner','{}'),
 ('a6000000-0000-0000-0000-000000000002','qa_onboard_friend','Onboarding Friend','{gym}'),
 ('a6000000-0000-0000-0000-000000000004','qa_onboard_runner','Onboarding Runner','{running}');
insert into public.friendships(requester_id,addressee_id,status) values
 ('a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000002','accepted');

select ok((select onboarding_step is null from public.profiles where username='qa_onboard_legacy'),'migration does not restart an existing profile');
select is((select onboarding_step from public.profiles where username='qa_onboard_owner'),'sports','new profiles start at sports');
select ok((select gym_focus is null from public.profiles where username='qa_onboard_owner'),'new gym focus is optional, not invented');
select ok(has_function_privilege('authenticated','public.save_onboarding_state(text,text[])','execute'),'authenticated user can call onboarding RPC');
select ok(not has_function_privilege('anon','public.save_onboarding_state(text,text[])','execute'),'anonymous onboarding RPC denied');
select ok(not has_column_privilege('authenticated','public.profiles','onboarding_step','update'),'direct onboarding step update cannot bypass RPC guards');
select ok(not has_column_privilege('authenticated','public.profiles','gym_focus','update'),'direct gym focus update denied');
select ok(not has_column_privilege('authenticated','public.profiles','onboarding_step','insert'),'client cannot insert an already-completed profile');

select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
select throws_ok($$select public.save_onboarding_state('sports')$$,'P0001','forbidden','missing auth identity denied even under authenticated role');
reset role;
select set_config('request.jwt.claim.sub','a6000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select throws_ok($$select public.save_onboarding_state('sports')$$,'P0001','profile required','onboarding cannot create a profile implicitly');
reset role;

select set_config('request.jwt.claim.sub','a6000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select throws_ok($$select public.save_onboarding_state(null)$$,'P0001','invalid onboarding step','missing step denied');
select throws_ok($$select public.save_onboarding_state('main')$$,'P0001','invalid onboarding step','unsupported step denied');
select throws_ok($$select public.save_onboarding_state('done')$$,'P0001','confirm weekly goal first','cannot bypass conscious weekly confirmation');
select throws_ok($$select public.save_onboarding_state('weekly_goal')$$,'P0001','choose sports first','cannot advance past sports without any sport');
select is((public.save_onboarding_state('sports')).onboarding_step,'sports','valid initial step is saved');
select throws_ok($$select public.save_onboarding_state('sports',array[null]::text[])$$,'P0001','invalid gym focus','null gym focus member denied');
select throws_ok($$select public.save_onboarding_state('sports',array['   '])$$,'P0001','invalid gym focus','blank gym focus member denied');
select throws_ok($$select public.save_onboarding_state('sports',array[repeat('x',81)])$$,'P0001','invalid gym focus','overlong gym focus member denied');
select throws_ok($$select public.save_onboarding_state('sports',array_fill('Push'::text,array[25]))$$,'P0001','invalid gym focus','more than24 focus entries denied');
select throws_ok($$select public.save_onboarding_state('sports',array_fill('Push'::text,array[2,20]))$$,'P0001','invalid gym focus','multidimensional array cannot bypass total24 item limit');
select throws_ok($$select public.save_onboarding_state('sports',array[['Push','Pull'],['Legs','Core']])$$,'P0001','invalid gym focus','even a small nested array is rejected because the native model requires a flat list');
select throws_ok($$update public.profiles set onboarding_step='done' where id=auth.uid()$$,'42501','permission denied for table profiles','direct completed state write denied');
select is((select onboarding_step from public.profiles where id=auth.uid()),'sports','invalid requests leave current step unchanged');

-- A real profile edit selects sports; the legacy target argument must not confirm a weekly goal.
select lives_ok($$select public.upsert_profile('qa_onboard_owner','Onboarding Owner',null,null,null,null,array['gym']::public.sport_kind[],4::smallint,'friends')$$,'profile sport selection saved through existing RPC');
select is((public.save_onboarding_state('gym',array['Push','Pull'])).onboarding_step,'gym','gym focus step advances after sport selection');
select is((select gym_focus from public.profiles where id=auth.uid()),array['Push','Pull'],'selected gym focus persists exactly');
select is((public.save_onboarding_state('weekly_goal')).onboarding_step,'weekly_goal','next step waits for explicit weekly goal');
select is((select gym_focus from public.profiles where id=auth.uid()),array['Push','Pull'],'omitted focus preserves prior selection');
select throws_ok($$select public.save_onboarding_state('friends')$$,'P0001','confirm weekly goal first','friend step cannot imply confirmation');
select throws_ok($$select public.save_onboarding_state('complete')$$,'P0001','confirm weekly goal first','completion preview cannot imply confirmation');
select is(public.confirm_weekly_goal(4,'UTC')->>'goal_confirmed','true','explicit goal button authorizes weekly goal');
select is((public.save_onboarding_state('friends')).onboarding_step,'friends','friends step allowed after conscious confirmation');
select is((public.save_onboarding_state('complete')).onboarding_step,'complete','optional friends may be skipped to completion preview');
select is((public.save_onboarding_state('done')).onboarding_step,'done','explicit finish persists done');
select is((public.save_onboarding_state('done')).onboarding_step,'done','finish retry is idempotent');
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','4','onboarding transitions do not rewrite weekly goal');
select is(public.get_weekly_state()->'current_week'->>'completed_workouts','0','onboarding never awards workout credit');
select lives_ok($$select public.upsert_profile('qa_onboard_owner','Renamed Owner',null,null,null,null,array['gym','running']::public.sport_kind[],7::smallint,'friends')$$,'later profile edit remains available');
select is((select onboarding_step from public.profiles where id=auth.uid()),'done','later profile editing cannot restart onboarding');
select is((select gym_focus from public.profiles where id=auth.uid()),array['Push','Pull'],'later profile edit preserves gym focus');
select is(public.get_weekly_state()->'current_week'->>'weekly_goal','4','legacy profile parameter cannot mutate confirmed goal');
select is((public.save_onboarding_state('done','{}'::text[])).gym_focus,'{}'::text[],'explicit empty focus clears optional choices');
select is((public.save_onboarding_state('done',array[repeat('x',80)])).gym_focus,array[repeat('x',80)],'80 character focus boundary accepted');
reset role;
select is((select onboarding_step from public.profiles where username='qa_onboard_friend'),'sports','caller transitions never change accepted friend state');
select ok((select gym_focus is null from public.profiles where username='qa_onboard_friend'),'caller focus never changes friend preference');

-- Simulate a fresh authenticated request after app/session restart.
select set_config('request.jwt.claim.sub','a6000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is((select onboarding_step from public.profiles where id=auth.uid()),'done','restored account reads server-persisted done state');
select is(public.get_weekly_state()->>'goal_confirmed','true','restored account retains conscious goal confirmation');
reset role;

-- Non-gym users can legitimately proceed directly from sport selection to weekly goal.
select set_config('request.jwt.claim.sub','a6000000-0000-0000-0000-000000000004',true);
set local role authenticated;
select is((public.save_onboarding_state('weekly_goal')).onboarding_step,'weekly_goal','non-gym sport does not require gym focus');
select lives_ok($$select public.confirm_weekly_goal(3,'UTC')$$,'non-gym user consciously confirms minimum valid goal');
select is((public.save_onboarding_state('done')).onboarding_step,'done','non-gym user can complete optional remaining onboarding');
reset role;

select * from finish();
rollback;
