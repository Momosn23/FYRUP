// Disposable local PostgreSQL validates the precise all-or-nothing deployment wrapper.
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { assembleDeployment, loadDeploymentSources, assembleFollowup, followupFiles } from '../../scripts/deployment-bundle.mjs';
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
  console.log('PASS: atomic base and followup deployments, deliberate-error rollbacks, eleven truthful history entries, private schema-only recovery snapshot, protected receipts/CAS, 122 catalog entries, duplicate-deployment refusal. No hosted database contacted.');
} finally { await db.close(); }
