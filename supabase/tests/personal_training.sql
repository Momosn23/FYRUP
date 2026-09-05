create extension if not exists pgtap with schema extensions;
set search_path to public,extensions;
begin;
select no_plan();
insert into auth.users values ('ac120000-0000-0000-0000-000000000001'),('ac120000-0000-0000-0000-000000000002'),('ac120000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,display_name) values
 ('ac120000-0000-0000-0000-000000000001','qa_personal_one','Personal One'),
 ('ac120000-0000-0000-0000-000000000002','qa_personal_two','Personal Two'),
 ('ac120000-0000-0000-0000-000000000003','qa_personal_three','Personal Three');
insert into public.friendships(requester_id,addressee_id,status) values ('ac120000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000002','accepted');
insert into public.activities(id,user_id,sport,status,started_at,ended_at) values
 ('ac121000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','gym','live','2026-09-02 10:00Z',null),
 ('ac121000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000002','gym','completed','2026-09-01 10:00Z','2026-09-01 10:30Z'),
 ('ac121000-0000-0000-0000-000000000003','ac120000-0000-0000-0000-000000000001','running','completed','2026-08-31 23:50Z','2026-09-01 00:30Z'),
 ('ac121000-0000-0000-0000-000000000004','ac120000-0000-0000-0000-000000000001','yoga','cancelled','2026-09-01 10:00Z','2026-09-01 10:01Z'),
 ('ac121000-0000-0000-0000-000000000006','ac120000-0000-0000-0000-000000000002','gym','live','2026-09-02 10:00Z',null);
insert into public.activities(id,user_id,sport,status,planned_at) values
 ('ac121000-0000-0000-0000-000000000005','ac120000-0000-0000-0000-000000000001','gym','planned','2026-09-04 10:00Z');
insert into public.workout_records(activity_id,owner_id,plan_name) values
 ('ac121000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','Private plan');
insert into public.workout_exercise_logs(id,activity_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max) values
 ('ac122000-0000-0000-0000-000000000001','ac121000-0000-0000-0000-000000000001','{}',0,3,8,12);
insert into public.blind_workouts(id,creator_id,recipient_id,focus,estimated_duration_minutes,exercise_count,status,equipment_confirmed,activity_id,send_request) values
 ('ac123000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000002','push',30,2,'live',true,'ac121000-0000-0000-0000-000000000006','{}');
insert into public.blind_workout_exercises(id,blind_workout_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max,revealed_at) values
 ('ac124000-0000-0000-0000-000000000001','ac123000-0000-0000-0000-000000000001','{"exercise_type":"strength"}',0,3,8,12,now()),
 ('ac124000-0000-0000-0000-000000000002','ac123000-0000-0000-0000-000000000001','{"exercise_type":"strength"}',1,3,8,12,null);
insert into public.planned_sessions(id,host_id,sport,starts_at) values
 ('ac125000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000001','gym','2026-09-04 10:00Z'),
 ('ac125000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000002','running','2026-09-04 10:00Z'),
 ('ac125000-0000-0000-0000-000000000003','ac120000-0000-0000-0000-000000000002','yoga','2026-09-04 10:00Z'),
 ('ac125000-0000-0000-0000-000000000004','ac120000-0000-0000-0000-000000000003','gym','2026-09-04 10:00Z'),
 ('ac125000-0000-0000-0000-000000000005','ac120000-0000-0000-0000-000000000001','gym','2026-09-01 10:00Z');
insert into public.session_invites(session_id,invitee_id,status) values
 ('ac125000-0000-0000-0000-000000000002','ac120000-0000-0000-0000-000000000001','accepted'),
 ('ac125000-0000-0000-0000-000000000003','ac120000-0000-0000-0000-000000000001','pending'),
 ('ac125000-0000-0000-0000-000000000004','ac120000-0000-0000-0000-000000000001','accepted');
update public.activities set planned_session_id='ac125000-0000-0000-0000-000000000005' where id='ac121000-0000-0000-0000-000000000003';

select ok(relrowsecurity,'personal table RLS: '||relname) from pg_class where oid in ('public.personal_training_routines'::regclass,'public.personal_workout_feedback'::regclass);
select ok(not has_table_privilege('authenticated',t,p),'direct mutation denied: '||t||' '||p) from unnest(array['public.personal_training_routines','public.personal_workout_feedback']) t cross join unnest(array['insert','update','delete']) p;
select ok(not has_function_privilege('anon',f,'execute'),'anonymous RPC denied: '||f) from unnest(array['public.get_training_routine()','public.save_training_routine(jsonb)','public.get_personal_training_week(timestamptz,timestamptz)','public.get_personal_workout_feedback(uuid)','public.save_personal_workout_feedback(jsonb)']) f;
create temporary table qa_personal(k text primary key,v jsonb); grant all on qa_personal to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.get_training_routine()$$,'P0001','unauthorized','no-session read rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[]}')$$,'P0001','unauthorized','no-session save rejected');
select set_config('request.jwt.claim.sub','ac120000-0000-0000-0000-000000000001',true);
select is(public.get_training_routine(),'{"revision":0,"goals":[]}'::jsonb,'initial routine explicitly empty');
select is((select count(*) from public.personal_training_routines),0::bigint,'read creates no implicit goal');
select throws_ok($$select public.save_training_routine(null)$$,'P0001','invalid_routine','SQL null rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":null}')$$,'P0001','invalid_routine','JSON null goals rejected');
select throws_ok($$select public.save_training_routine('{"revision":"0","goals":[]}')$$,'P0001','invalid_routine','string revision rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":0,"weekdays":[]}]}')$$,'P0001','invalid_routine','zero frequency rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":8,"weekdays":[]}]}')$$,'P0001','invalid_routine','excessive frequency rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"minutes":4,"weekdays":[]}]}')$$,'P0001','invalid_duration','too short duration rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"minutes":361,"weekdays":[]}]}')$$,'P0001','invalid_duration','too long duration rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"weekdays":[1,1]}]}')$$,'P0001','invalid_weekdays','duplicate day rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":1,"weekdays":[1,2]}]}')$$,'P0001','invalid_weekdays','more days than frequency rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"weekdays":[0]}]}')$$,'P0001','invalid_weekdays','invalid day rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"weekdays":["1"]}]}')$$,'P0001','invalid_weekdays','string day rejected');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"weekdays":[],"credit":1}]}')$$,'P0001','unexpected_routine_data','cannot put credits in routine');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"weekdays":[]},{"sport":"gym","sessions":1,"weekdays":[]}]}')$$,'P0001','duplicate_sport','duplicate sport rejected');
insert into qa_personal values('routine',public.save_training_routine('{"revision":0,"goals":[{"sport":"gym","sessions":2,"minutes":60,"weekdays":[1,5]},{"sport":"running","sessions":1,"weekdays":[]}]}'));
select is((select v->>'revision' from qa_personal where k='routine'),'1','confirmed save increments revision');
select is(jsonb_array_length(public.get_training_routine()->'goals'),2,'fixed and flexible sports coexist');
select is(public.get_training_routine(),(select v from qa_personal where k='routine'),'read restores exact routine');
select throws_ok($$select public.save_training_routine('{"revision":0,"goals":[]}')$$,'P0001','routine_changed_reload','stale second device cannot overwrite routine');
select is(public.get_training_routine(),(select v from qa_personal where k='routine'),'conflict retains confirmed plan');
select lives_ok($$select public.save_training_routine('{"revision":1,"goals":[]}')$$,'clearing routine is an explicit revisioned save');
select is(jsonb_array_length(public.get_training_routine()->'goals'),0,'cleared plan remains empty');

insert into qa_personal values('week',public.get_personal_training_week('2026-08-31 00:00Z','2026-09-07 00:00Z'));
select is(jsonb_array_length((select v->'activities' from qa_personal where k='week')),3,'week contains own live, completed and planned, not cancelled or friends');
select is(jsonb_array_length((select v->'sessions' from qa_personal where k='week')),2,'week contains own pending and accepted current-friend session only');
select ok(not exists(select 1 from qa_personal,jsonb_array_elements(v->'sessions') s where k='week' and s->>'id'='ac125000-0000-0000-0000-000000000005'),'completed linked session is not also upcoming');
select is(jsonb_array_length(public.get_personal_training_week('2026-09-01 00:00Z','2026-09-02 00:00Z')->'activities'),1,'overnight completion belongs to ending day; end boundary excluded');
select throws_ok($$select public.get_personal_training_week('2026-09-02Z','2026-09-01Z')$$,'P0001','invalid_week','reversed interval rejected');
select throws_ok($$select public.get_personal_training_week('-infinity','infinity')$$,'P0001','invalid_week','infinite history rejected');
select throws_ok($$select public.get_personal_training_week('2026-09-01Z','2026-10-01Z')$$,'P0001','invalid_week','unbounded history rejected');

select is(public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000001')->>'revision','0','initial feedback explicit revision zero');
select throws_ok($$select public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000002')$$,'P0001','forbidden','accepted friend feedback still private');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":0,"exercises":[],"feeling":"great"}')$$,'P0001','finish_before_review','live workout cannot be reviewed as complete');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000004","revision":0,"exercises":[]}')$$,'P0001','forbidden','cancelled workout cannot receive completion feedback');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":0,"exercises":[{"exercise_id":"ac122000-0000-0000-0000-000000000001","effort":"unknown"}]}')$$,'P0001','invalid_effort','unsupported effort rejected');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":0,"exercises":[{"exercise_id":"ac122000-0000-0000-0000-000000000099","effort":"easy"}]}')$$,'P0001','exercise_not_available','unrelated exercise cannot be rated');
insert into qa_personal values('effort',public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":0,"exercises":[{"exercise_id":"ac122000-0000-0000-0000-000000000001","effort":"hardcore"}]}'));
select is((select v#>>'{exercises,0,effort}' from qa_personal where k='effort'),'hardcore','live exercise effort saved');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":0,"exercises":[]}')$$,'P0001','feedback_changed_reload','stale feedback cannot silently erase effort');
select is(public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000001","revision":1,"exercises":[]}')->'exercises','[]'::jsonb,'owner can remove an effort mark');
insert into qa_personal values('review',public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000003","revision":0,"exercises":[],"feeling":"okay","note":"  Private reflection  "}'));
select is((select v->>'note' from qa_personal where k='review'),'Private reflection','completed reflection saved normalized');
select is(public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000003')->>'feeling','okay','completed feeling restores');
select throws_ok($$select public.save_personal_workout_feedback(jsonb_build_object('activity_id','ac121000-0000-0000-0000-000000000003','revision',1,'exercises','[]'::jsonb,'note',repeat('x',501)))$$,'P0001','invalid_note','oversized note rejected without mutation');
select is(public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000003')->>'revision','1','invalid note does not advance version');

select set_config('request.jwt.claim.sub','ac120000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.personal_training_routines),0::bigint,'accepted friend cannot SELECT private routine');
select is((select count(*) from public.personal_workout_feedback),0::bigint,'accepted friend cannot SELECT private feedback');
select throws_ok($$select public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000003')$$,'P0001','forbidden','private review RPC rejects friend');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000003","revision":1,"exercises":[]}')$$,'P0001','forbidden','cannot overwrite other owner review');
select lives_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000006","revision":0,"exercises":[{"exercise_id":"ac124000-0000-0000-0000-000000000001","effort":"easy"}]}')$$,'recipient can rate revealed Blind exercise');
select throws_ok($$select public.save_personal_workout_feedback('{"activity_id":"ac121000-0000-0000-0000-000000000006","revision":1,"exercises":[{"exercise_id":"ac124000-0000-0000-0000-000000000002","effort":"easy"}]}')$$,'P0001','exercise_not_available','recipient cannot rate or probe hidden Blind exercise through new API');
select set_config('request.jwt.claim.sub','ac120000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000006')$$,'P0001','forbidden','Blind creator cannot access recipient effort');
reset role;
insert into public.blocks values ('ac120000-0000-0000-0000-000000000001','ac120000-0000-0000-0000-000000000002',now());
set local role authenticated;
select is(jsonb_array_length(public.get_personal_training_week('2026-08-31 00:00Z','2026-09-07 00:00Z')->'sessions'),1,'blocked host disappears from personal week immediately');
select is(public.get_personal_workout_feedback('ac121000-0000-0000-0000-000000000003')->>'note','Private reflection','blocking does not destroy own completed review');
select * from finish();
rollback;
