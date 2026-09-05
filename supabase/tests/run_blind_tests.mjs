// Local disposable PostgreSQL only. No production connection, keys or network.
// node supabase/tests/run_blind_tests.mjs
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(resolve('.qa/workout-db/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const { citext } = require('@electric-sql/pglite/contrib/citext');
const { pgcrypto } = require('@electric-sql/pglite/contrib/pgcrypto');
const { pgtap } = require('@electric-sql/pglite-pgtap');
const db = new PGlite({ extensions: { citext, pgcrypto, pgtap } });
const includePreferenceCAS = process.argv.includes('--preference-cas');
const includeCopies = process.argv.includes('--copy-requests') || includePreferenceCAS;
const includeShots = process.argv.includes('--shots') || includeCopies;
try {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema extensions; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public,extensions to authenticated,anon;
    grant execute on function auth.uid() to authenticated,anon;
    alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;
    create extension pgtap with schema extensions;`);
  for (const filename of [
    '202609040001_initial_schema.sql', '202609040002_scheduled_sessions.sql',
    '202609040004_notification_preferences.sql', '202609040005_planned_session_details.sql',
    '202609040006_session_friendship_cleanup.sql', '202609040007_today_feed_ordering.sql',
    '202609040010_training_groups.sql', '202609050001_workout_plans.sql',
    '202609050002_exercise_library.sql', '202609050003_daily_steps.sql',
    '202609050004_activity_pause.sql', '202609050005_weekly_flames.sql',
    '202609050006_onboarding_state.sql', '202609050007_blind_workouts.sql',
    ...(includeShots ? ['202609050008_call_my_shot.sql', '202609050009_push_friendship_authorization.sql'] : []),
    ...(includeCopies ? ['202609050010_workout_copy_idempotency.sql'] : []),
    ...(includePreferenceCAS ? ['202609050011_notification_preference_cas.sql'] : []),
  ]) {
    if (filename === '202609050005_weekly_flames.sql') {
      await db.exec(`insert into auth.users values
        ('af500000-0000-0000-0000-000000000001'),('af500000-0000-0000-0000-000000000002');
        insert into public.profiles(id,username,display_name,weekly_goal,timezone) values
        ('af500000-0000-0000-0000-000000000001','qa_legacy_four','Legacy Four',4,'UTC'),
        ('af500000-0000-0000-0000-000000000002','qa_legacy_two','Legacy Two',2,'UTC');
        insert into public.activities(user_id,sport,status,started_at,ended_at)
        select 'af500000-0000-0000-0000-000000000001','gym','completed',now()-interval '10 minutes',now() from generate_series(1,4);
        insert into public.activities(user_id,sport,status,started_at,ended_at) values
        ('af500000-0000-0000-0000-000000000001','yoga','completed',now()-interval '21 days 10 minutes',now()-interval '21 days'),
        ('af500000-0000-0000-0000-000000000001','other','completed',now()-interval '10 seconds',now());`);
    }
    await db.exec(await readFile(resolve('supabase/migrations', filename), 'utf8'));
    console.log(`Applied ${filename}`);
  }
  for (const filename of [...(includePreferenceCAS ? ['notification_preference_cas.sql'] : []), ...(includeCopies ? ['workout_copy_idempotency.sql'] : []), ...(includeShots ? ['call_my_shot.sql'] : []), 'blind_workouts.sql', 'weekly_flames.sql', 'workout_plans.sql', 'activity_pause.sql', 'daily_steps.sql']) {
    console.log(`Suite: ${filename}`);
    let sql = await readFile(resolve('supabase/tests', filename), 'utf8');
    if (includeCopies && filename === 'workout_plans.sql') {
      // Earlier-migration suites remain runnable unchanged. Only this post-010
      // harness supplies stable IDs to their two legacy one-argument copy calls.
      sql = sql.replaceAll("public.copy_workout_plan('c0000000-0000-0000-0000-000000000001')",
        "public.copy_workout_plan('c0000000-0000-0000-0000-000000000001','ec100000-0000-0000-0000-000000000001')");
    }
    const results = await db.exec(sql);
    const tap = results.flatMap(result => result.rows ?? []).flatMap(row => Object.values(row))
      .filter(value => typeof value === 'string' && /^(ok |not ok |1\.\.|#)/.test(value));
    for (const line of tap) console.log(line);
    assert.ok(tap.some(line => /^1\.\./.test(line)), 'Missing TAP plan');
    assert.ok(!tap.some(line => /(^|\n)not ok |(^|\n)#.*(?:failed|planned .* but ran)/i.test(line)), 'Blind database tests failed');
  }
  console.log(`PASS: local ${includeShots ? 'Call My Shot + ' : ''}Blind RPC/RLS/hidden-data/one-credit suite with weekly/workout/pause/step regressions. Hosted Supabase, physical concurrency, push delivery and native iOS NOT tested.`);
} catch (error) {
  console.error(error.message);
  if (error.internalQuery) console.error(error.internalQuery);
  if (error.where) console.error(error.where);
  if (error.query && error.position) {
    const at = Number(error.position);
    console.error(`SQL position ${at}: ${error.query.slice(Math.max(0, at - 240), at + 160)}`);
  }
  process.exitCode = 1;
} finally {
  await db.close();
}
