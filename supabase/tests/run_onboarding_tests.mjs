// Disposable PostgreSQL WASM validation. No network, credentials or production DB.
// Uses existing local .qa/workout-db dependencies; run with node supabase/tests/run_onboarding_tests.mjs.
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
    '202609050004_activity_pause.sql', '202609050005_weekly_flames.sql',
  ]) {
    await db.exec(await readFile(resolve('supabase/migrations', filename), 'utf8'));
    console.log(`Applied ${filename}`);
  }
  // This profile exists before006; its null onboarding step must remain legacy-complete.
  await db.exec(`insert into auth.users values ('a6000000-0000-0000-0000-000000000000');
    insert into public.profiles(id,username,display_name,sports) values
    ('a6000000-0000-0000-0000-000000000000','qa_onboard_legacy','Legacy Onboarding','{gym}');`);
  await db.exec(await readFile(resolve('supabase/migrations/202609050006_onboarding_state.sql'), 'utf8'));
  console.log('Applied 202609050006_onboarding_state.sql over existing profile');
  const results = await db.exec(await readFile(resolve('supabase/tests/onboarding_state.sql'), 'utf8'));
  const tap = results.flatMap(result => result.rows ?? []).flatMap(row => Object.values(row))
    .filter(value => typeof value === 'string' && /^(ok |not ok |1\.\.|#)/.test(value));
  for (const line of tap) console.log(line);
  assert.ok(tap.some(line => /^1\.\./.test(line)), 'Missing TAP plan');
  assert.ok(!tap.some(line => /(^|\n)not ok |(^|\n)#.*(?:failed|planned .* but ran)/i.test(line)), 'Onboarding database tests failed');
  console.log('PASS: local onboarding migration/RPC/ownership/validation/confirmation/persistence guards. Native UI, hosted Supabase/PostgREST and physical concurrent sessions NOT tested.');
} catch (error) {
  console.error(error.message);
  if (error.query) console.error(error.query);
  process.exitCode = 1;
} finally {
  await db.close();
}
