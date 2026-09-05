// Local, disposable PostgreSQL WASM test. No network/database credentials used.
// Install pinned test dependencies into .qa/workout-db, then run from repo root:
// pnpm add --dir .qa/workout-db --ignore-scripts @electric-sql/pglite@0.5.8 @electric-sql/pglite-pgtap@0.0.9
// node supabase/tests/run_workout_tests.mjs
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
  // Supabase platform-owned schemas are minimal fixtures, not a simulated auth service.
  await db.exec(`create role anon; create role authenticated;
    create schema auth; create schema extensions;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public,extensions to authenticated,anon;
    grant execute on function auth.uid() to authenticated,anon;
    alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;
    create extension pgtap with schema extensions;`);
  const migrations = [
    '202609040001_initial_schema.sql',
    '202609040002_scheduled_sessions.sql',
    '202609040004_notification_preferences.sql',
    '202609040005_planned_session_details.sql',
    '202609040006_session_friendship_cleanup.sql',
    '202609040007_today_feed_ordering.sql',
    '202609040010_training_groups.sql',
    '202609050001_workout_plans.sql',
    '202609050002_exercise_library.sql',
    '202609050004_activity_pause.sql',
  ];
  for (const filename of migrations) {
    await db.exec(await readFile(resolve('supabase/migrations', filename), 'utf8'));
    console.log(`Applied ${filename}`);
  }
  const catalog = (await readFile(resolve('FYRUP/Resources/exercise-library.tsv'), 'utf8'))
    .split(/\r?\n/).filter(line => line && !line.startsWith('#')).map(line => line.split('\t'));
  assert.equal(catalog.length, 122);
  const seeded = (await db.query(`select e.id,e.name,e.primary_muscle_group,e.equipment,e.exercise_type,e.is_custom,
    array(select s.muscle_group from public.exercise_secondary_muscles s where s.exercise_id=e.id order by s.muscle_group) secondary
    from public.exercises e order by e.id`)).rows;
  assert.equal(seeded.length, catalog.length);
  for (const row of catalog) {
    const match = seeded.find(e => e.id === row[0]);
    assert.ok(match, `Missing ID ${row[0]}`);
    assert.deepEqual([match.name, match.primary_muscle_group, match.secondary.join(','), match.equipment, match.exercise_type],
      [row[1], row[2], row[3].split(',').filter(Boolean).sort().join(','), row[4], row[5]], row[0]);
    assert.equal(match.is_custom, false);
  }
  console.log('PASS: all 122 explicit IDs and complete catalog metadata match app TSV.');
  for (const filename of ['workout_plans.sql', 'activity_pause.sql']) {
    console.log(`Suite: ${filename}`);
    const results = await db.exec(await readFile(resolve('supabase/tests', filename), 'utf8'));
    const tap = results.flatMap(result => result.rows ?? []).flatMap(row => Object.values(row))
      .filter(value => typeof value === 'string' && /^(ok |not ok |1\.\.|#)/.test(value));
    for (const line of tap) console.log(line);
    assert.ok(tap.some(line => /^1\.\./.test(line)), 'Missing TAP test plan');
    assert.ok(!tap.some(line => /(^|\n)not ok |(^|\n)#.*(?:failed|planned .* but ran)/i.test(line)), 'Database tests failed');
  }
  console.log('PASS: local PostgreSQL migration/RPC/RLS tests. Hosted deployment, concurrent sessions, PostgREST, push delivery and iPhone NOT tested.');
} catch (error) {
  console.error(error.message);
  if (error.query) console.error(error.query);
  process.exitCode = 1;
} finally {
  await db.close();
}
