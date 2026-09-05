// Disposable PostgreSQL WASM verification. No real users, credentials or backend.
// Uses the same pinned local packages as run_workout_tests.mjs.
// node supabase/tests/run_step_tests.mjs
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
try {
  await db.exec(`create role anon; create role authenticated;
    create schema auth; create schema extensions;
    create table auth.users(id uuid primary key);
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
    '202609050004_activity_pause.sql',
  ]) {
    await db.exec(await readFile(resolve('supabase/migrations', filename), 'utf8'));
    console.log(`Applied ${filename}`);
  }
  const results = await db.exec(await readFile(resolve('supabase/tests/daily_steps.sql'), 'utf8'));
  const tap = results.flatMap(result => result.rows ?? []).flatMap(row => Object.values(row))
    .filter(value => typeof value === 'string' && /^(ok |not ok |1\.\.|#)/.test(value));
  for (const line of tap) console.log(line);
  assert.ok(tap.some(line => /^1\.\./.test(line)), 'Missing TAP plan');
  assert.ok(!tap.some(line => /(^|\n)not ok |(^|\n)#.*(?:failed|planned .* but ran)/i.test(line)), 'Step database tests failed');
  console.log('PASS: local PostgreSQL step RPC/RLS/revocation/day-boundary tests. HealthKit hardware, hosted deployment, PostgREST and concurrent physical DB sessions NOT tested.');
} catch (error) {
  console.error(error.message);
  if (error.query) console.error(error.query);
  process.exitCode = 1;
} finally {
  await db.close();
}
