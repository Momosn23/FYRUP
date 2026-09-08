// Disposable local PostgreSQL validates the precise all-or-nothing deployment wrapper.
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { assembleReferenceDeployment, assembleExistingPerformanceReceipt, referenceDeploymentFiles } from '../../scripts/reference-deployment-bundle.mjs';
import { assembleDeployment, loadDeploymentSources, assembleFollowup, followupFiles, assemblePersonalTraining, personalTrainingFile, assembleSupplements, supplementsFile, assembleProfilePrivacy, profilePrivacyFile, assembleActivityPlace, activityPlaceFile, assembleExercisePerformance, exercisePerformanceFile } from '../../scripts/deployment-bundle.mjs';
const require = createRequire(resolve('.qa/workout-db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const { citext } = require('@electric-sql/pglite/contrib/citext');
const { pgcrypto } = require('@electric-sql/pglite/contrib/pgcrypto');
const db = new PGlite({ extensions: { citext, pgcrypto } });
try {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema extensions; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public,extensions to authenticated,anon;
    grant execute on function auth.uid() to authenticated,anon;
    alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;`);
  for (const file of ['202609040001_initial_schema.sql','202609040002_scheduled_sessions.sql',
    '202609040004_notification_preferences.sql','202609040005_planned_session_details.sql',
    '202609040006_session_friendship_cleanup.sql','202609040007_today_feed_ordering.sql','202609040010_training_groups.sql']) {
    await db.exec(await readFile(resolve('supabase/migrations', file), 'utf8'));
  }
  const sources = await loadDeploymentSources();
  const broken = { ...sources, '202609050009_push_friendship_authorization.sql': 'begin;\nselect missing_deliberate_validation_failure();\ncommit;' };
  await assert.rejects(db.exec(assembleDeployment(broken)));
  await db.exec('rollback;');
  assert.equal((await db.query("select to_regclass('public.workout_plans') as value")).rows[0].value, null);
  assert.equal((await db.query("select to_regclass('supabase_migrations.schema_migrations') as value")).rows[0].value, null);
  await db.exec(assembleDeployment(sources));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 9);
  assert.equal((await db.query('select count(*)::integer as count from public.exercises where not is_custom')).rows[0].count, 122);
  assert.equal((await db.query('select count(*)::integer as count from fyrup_deployment.schema_snapshots')).rows[0].count, 1);
  assert.equal((await db.query("select has_schema_privilege('authenticated','fyrup_deployment','USAGE') as value")).rows[0].value, false);
  assert.equal((await db.query("select count(*)::integer as count from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','fyrup_deployment','supabase_migrations') and c.relkind='r' and not c.relrowsecurity and (c.relname in ('schema_snapshots','schema_migrations') or c.relname in ('exercises','exercise_secondary_muscles','exercise_favorites','workout_plans','workout_plan_exercises','workout_plan_shares','workout_records','workout_exercise_logs','workout_set_logs','step_sharing_preferences','daily_activity_metrics','weekly_progress','weekly_activity_credits','weekly_flame_reactions','weekly_flame_celebrations','weekly_goal_changes','blind_workouts','blind_workout_exercises','blind_workout_sets','blind_workout_copies','blind_workout_reactions','weekly_commitments','weekly_shot_reactions'))")).rows[0].count, 0);
  await assert.rejects(db.exec(assembleDeployment(sources)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 9);
  const followups = Object.fromEntries(await Promise.all(followupFiles.map(async name => [name, await readFile(resolve('supabase/migrations', name), 'utf8')])));
  const brokenFollowup = { ...followups, [followupFiles[1]]: 'begin;\nselect missing_deliberate_validation_failure();\ncommit;' };
  await assert.rejects(db.exec(assembleFollowup(brokenFollowup)));
  await db.exec('rollback;');
  assert.equal((await db.query("select to_regclass('public.workout_plan_copy_requests') as value")).rows[0].value, null);
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 9);
  await db.exec(assembleFollowup(followups));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 11);
  assert.equal((await db.query("select relrowsecurity as value from pg_class where oid='public.workout_plan_copy_requests'::regclass")).rows[0].value, true);
  assert.equal((await db.query("select has_table_privilege('authenticated','public.notification_preferences','UPDATE') as value")).rows[0].value, false);
  await assert.rejects(db.exec(assembleFollowup(followups)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 11);
  const personal = await readFile(resolve('supabase/migrations', personalTrainingFile), 'utf8');
  await assert.rejects(db.exec(assemblePersonalTraining(personal.replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;'))));
  await db.exec('rollback;');
  assert.equal((await db.query("select to_regclass('public.personal_training_routines') as value")).rows[0].value, null);
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 11);
  await db.exec(assemblePersonalTraining(personal));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 12);
  assert.equal((await db.query("select count(*)::integer as count from pg_class where oid in ('public.personal_training_routines'::regclass,'public.personal_workout_feedback'::regclass) and relrowsecurity")).rows[0].count, 2);
  assert.equal((await db.query("select has_table_privilege('authenticated','public.personal_workout_feedback','UPDATE') as value")).rows[0].value, false);
  await assert.rejects(db.exec(assemblePersonalTraining(personal)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 12);
  const supplements = await readFile(resolve('supabase/migrations', supplementsFile), 'utf8');
  const oldRegister = (await db.query("select pg_get_functiondef('public.register_device_token(text,text)'::regprocedure) as value")).rows[0].value;
  await assert.rejects(db.exec(assembleSupplements(supplements.replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;'))));
  await db.exec('rollback;');
  assert.equal((await db.query("select to_regclass('public.supplement_plans') as value")).rows[0].value, null);
  assert.equal((await db.query("select pg_get_functiondef('public.register_device_token(text,text)'::regprocedure) as value")).rows[0].value, oldRegister);
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 12);
  await db.exec(assembleSupplements(supplements));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 13);
  assert.equal((await db.query("select count(*)::integer as count from pg_class where oid in ('public.supplement_settings'::regclass,'public.supplement_plans'::regclass,'public.supplement_doses'::regclass,'public.supplement_receipts'::regclass,'public.supplement_reminder_jobs'::regclass) and relrowsecurity")).rows[0].count, 5);
  assert.equal((await db.query("select has_table_privilege('authenticated','public.supplement_receipts','SELECT') as value")).rows[0].value, false);
  assert.equal((await db.query("select has_function_privilege('authenticated','public.process_supplement_reminders(timestamptz)','EXECUTE') as value")).rows[0].value, false);
  await assert.rejects(db.exec(assembleSupplements(supplements)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 13);
  const profilePrivacy = await readFile(resolve('supabase/migrations', profilePrivacyFile), 'utf8');
  const oldProfileSave = (await db.query("select pg_get_functiondef('public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text)'::regprocedure) as value")).rows[0].value;
  await assert.rejects(db.exec(assembleProfilePrivacy(profilePrivacy.replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;'))));
  await db.exec('rollback;');
  assert.equal((await db.query("select pg_get_functiondef('public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text)'::regprocedure) as value")).rows[0].value, oldProfileSave);
  assert.equal((await db.query("select count(*)::integer as count from fyrup_deployment.schema_snapshots where version='before-202609050014'")).rows[0].count, 0);
  await db.exec(assembleProfilePrivacy(profilePrivacy));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 14);
  const savedProfileRoutine = (await db.query("select routines->0->>'definition' as value from fyrup_deployment.schema_snapshots where version='before-202609050014'")).rows[0].value;
  assert.equal(savedProfileRoutine, oldProfileSave);
  await assert.rejects(db.exec(assembleProfilePrivacy(profilePrivacy)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 14);
  const activityPlace = await readFile(resolve('supabase/migrations', activityPlaceFile), 'utf8');
  await assert.rejects(db.exec(assembleActivityPlace(activityPlace.replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;'))));
  await db.exec('rollback;');
  assert.equal((await db.query("select count(*)::integer as count from information_schema.columns where table_schema='public' and table_name='activities' and column_name='place_name'")).rows[0].count, 0);
  assert.equal((await db.query("select count(*)::integer as count from fyrup_deployment.schema_snapshots where version='before-202609050015'")).rows[0].count, 0);
  await db.exec(assembleActivityPlace(activityPlace));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 15);
  assert.equal((await db.query("select count(*)::integer as count from information_schema.columns where table_schema='public' and table_name='activities' and column_name='place_name'")).rows[0].count, 1);
  assert.equal((await db.query("select has_function_privilege('authenticated','public.start_activity(public.sport_kind,text,uuid,uuid,text)','EXECUTE') as value")).rows[0].value, true);
  assert.equal((await db.query("select has_function_privilege('anon','public.start_activity(public.sport_kind,text,uuid,uuid,text)','EXECUTE') as value")).rows[0].value, false);
  const placeUser = '11111111-1111-4111-8111-111111111111';
  await db.exec(`insert into auth.users(id) values ('${placeUser}');
    insert into public.profiles(id,username,display_name) values ('${placeUser}','place_test','Place Test');
    select set_config('request.jwt.claim.sub','${placeUser}',false);`);
  const startedAtPlace = (await db.query("select (public.start_activity('running',null,null,null,'  Rheinpark  ')).place_name as value")).rows[0].value;
  assert.equal(startedAtPlace, 'Rheinpark');
  const currentActivity = (await db.query(`select id from public.activities where user_id='${placeUser}' and status='live'`)).rows[0].id;
  await db.query(`select public.cancel_activity('${currentActivity}')`);
  await assert.rejects(db.query("select public.start_activity('running',null,null,null,repeat('x',121))"));
  await db.exec('rollback;');
  await assert.rejects(db.exec(assembleActivityPlace(activityPlace)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 15);
  const performance = await readFile(resolve('supabase/migrations', exercisePerformanceFile), 'utf8');
  await assert.rejects(db.exec(assembleExercisePerformance(performance.replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;'))));
  await db.exec('rollback;');
  assert.equal((await db.query("select to_regprocedure('public.get_exercise_performance(uuid[])') is not null as value")).rows[0].value, false);
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 15);
  await db.exec(assembleExercisePerformance(performance));
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 16);
  assert.equal((await db.query("select has_function_privilege('authenticated','public.get_exercise_performance(uuid[])','EXECUTE') as value")).rows[0].value, true);
  assert.equal((await db.query("select has_function_privilege('anon','public.get_exercise_performance(uuid[])','EXECUTE') as value")).rows[0].value, false);
  const performanceUser = '22222222-2222-4222-8222-222222222222';
  const otherPerformanceUser = '33333333-3333-4333-8333-333333333333';
  const performanceExercise = '44444444-4444-4444-8444-444444444444';
  await db.exec(`
    insert into auth.users(id) values ('${performanceUser}'),('${otherPerformanceUser}');
    insert into public.profiles(id,username,display_name) values
      ('${performanceUser}','performance_owner','Performance Owner'),
      ('${otherPerformanceUser}','performance_other','Performance Other');
    insert into public.exercises(id,name,primary_muscle_group,equipment,exercise_type,is_custom,created_by)
      values ('${performanceExercise}','Private Press','chest','barbell','strength',true,'${performanceUser}');
    insert into public.activities(id,user_id,sport,status,started_at,ended_at) values
      ('50000000-0000-4000-8000-000000000001','${performanceUser}','gym','completed','2026-09-01T09:00:00Z','2026-09-01T10:00:00Z'),
      ('50000000-0000-4000-8000-000000000002','${performanceUser}','gym','completed','2026-09-02T09:00:00Z','2026-09-02T10:00:00Z'),
      ('50000000-0000-4000-8000-000000000003','${performanceUser}','gym','live','2026-09-03T09:00:00Z',null),
      ('50000000-0000-4000-8000-000000000004','${otherPerformanceUser}','gym','completed','2026-09-04T09:00:00Z','2026-09-04T10:00:00Z');
    insert into public.workout_records(activity_id,owner_id,plan_name) values
      ('50000000-0000-4000-8000-000000000001','${performanceUser}','First'),
      ('50000000-0000-4000-8000-000000000002','${performanceUser}','Latest'),
      ('50000000-0000-4000-8000-000000000003','${performanceUser}','Live'),
      ('50000000-0000-4000-8000-000000000004','${otherPerformanceUser}','Foreign');
    insert into public.workout_exercise_logs(id,activity_id,exercise_id,exercise_snapshot,sort_order,target_sets,target_reps_min,target_reps_max) values
      ('60000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','${performanceExercise}','{}',0,2,1,20),
      ('60000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002','${performanceExercise}','{}',0,2,1,20),
      ('60000000-0000-4000-8000-000000000003','50000000-0000-4000-8000-000000000003','${performanceExercise}','{}',0,1,1,20),
      ('60000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000004','${performanceExercise}','{}',0,1,1,20);
    insert into public.workout_set_logs(workout_exercise_log_id,set_number,weight,reps,completed) values
      ('60000000-0000-4000-8000-000000000001',1,100,5,true),
      ('60000000-0000-4000-8000-000000000001',2,150,12,false),
      ('60000000-0000-4000-8000-000000000002',1,80,10,true),
      ('60000000-0000-4000-8000-000000000002',2,85,8,true),
      ('60000000-0000-4000-8000-000000000003',1,200,20,true),
      ('60000000-0000-4000-8000-000000000004',1,300,30,true);
    select set_config('request.jwt.claim.sub','${performanceUser}',false);
  `);
  const performanceResult = (await db.query(`select public.get_exercise_performance(array['${performanceExercise}'::uuid]) as value`)).rows[0].value[0];
  assert.equal(Number(performanceResult.last_weight), 85, 'Latest completed workout wins, using its strongest completed set');
  assert.equal(performanceResult.last_reps, 8);
  assert.equal(Number(performanceResult.best_weight), 100, 'Personal best ignores unfinished, live and foreign sets');
  assert.equal(performanceResult.best_reps, 5);
  await assert.rejects(db.query(`select public.get_exercise_performance(array[]::uuid[])`));
  await assert.rejects(db.query(`select public.get_exercise_performance(array_fill('${performanceExercise}'::uuid,array[41]))`));
  await assert.rejects(db.exec(assembleExercisePerformance(performance)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::integer as count from supabase_migrations.schema_migrations')).rows[0].count, 16);
  const referenceSources = Object.fromEntries(await Promise.all(referenceDeploymentFiles.map(async name => [name, await readFile(resolve('supabase/migrations', name), 'utf8')])));
  // Reproduce the observed production mismatch in this disposable database only.
  await db.exec("delete from supabase_migrations.schema_migrations where version='202609060016';");
  await assert.rejects(db.exec(assembleExistingPerformanceReceipt(performance.replace('v_user uuid', 'v_another_user uuid'))),/does not exactly match/);
  await db.exec('rollback;');
  await db.exec("alter function public.get_exercise_performance(uuid[]) volatile;");
  await assert.rejects(db.exec(assembleExistingPerformanceReceipt(performance)),/does not exactly match/);
  await db.exec('rollback;');
  await db.exec("alter function public.get_exercise_performance(uuid[]) stable;");
  await db.exec(assembleExistingPerformanceReceipt(performance));
  await assert.rejects(db.exec(assembleExistingPerformanceReceipt(performance)),/does not exactly match/);
  await db.exec('rollback;');
  const beforeProfiles = (await db.query('select * from public.profiles order by id')).rows;
  const beforeDefaults = (await db.query("select column_default from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='activity_visibility'")).rows;
  const brokenReference = {...referenceSources, [referenceDeploymentFiles[2]]: referenceSources[referenceDeploymentFiles[2]].replace(/commit;\s*$/, 'select missing_deliberate_validation_failure();\ncommit;')};
  await assert.rejects(db.exec(assembleReferenceDeployment(brokenReference)));
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::int as count from supabase_migrations.schema_migrations')).rows[0].count,16);
  assert.deepEqual((await db.query("select column_default from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='activity_visibility'")).rows,beforeDefaults);
  assert.equal((await db.query("select count(*)::int as count from information_schema.columns where table_schema='public' and table_name='supplement_plans' and column_name='amount'")).rows[0].count,0);
  await db.exec(assembleReferenceDeployment(referenceSources));
  assert.deepEqual((await db.query('select * from public.profiles order by id')).rows,beforeProfiles,'Deployment does not rewrite existing customers');
  assert.equal((await db.query('select count(*)::int as count from supabase_migrations.schema_migrations')).rows[0].count,19);
  assert.equal((await db.query("select count(*)::int as count from fyrup_deployment.schema_snapshots where version='before-202609080017-019'")).rows[0].count,1);
  assert.equal((await db.query("select has_function_privilege('anon','public.save_supplement_plan(jsonb)','EXECUTE') as value")).rows[0].value,false);
  await assert.rejects(db.exec(assembleReferenceDeployment(referenceSources)),/unexpected reference deployment baseline/);
  await db.exec('rollback;');
  assert.equal((await db.query('select count(*)::int as count from supabase_migrations.schema_migrations')).rows[0].count,19);
  console.log('PASS: atomic deployments through reference 017–019; failure rollback including defaults, routines and columns; 19 exact history entries; existing customer records unchanged; private snapshots; duplicate refusal. No hosted database contacted.');
} finally { await db.close(); }
