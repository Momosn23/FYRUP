// Isolated migration and authorization checks. Never contacts Supabase.
import { createRequire } from 'node:module';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
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
  const initial = ['202609040001_initial_schema.sql','202609040002_scheduled_sessions.sql',
    '202609040004_notification_preferences.sql','202609040005_planned_session_details.sql',
    '202609040006_session_friendship_cleanup.sql','202609040007_today_feed_ordering.sql','202609040010_training_groups.sql'];
  const rest = (await readdir('supabase/migrations')).filter(x => x >= '20260905' && x < '202609080017').sort();
  for (const filename of [...initial, ...rest]) await db.exec(await readFile(resolve('supabase/migrations', filename), 'utf8'));
  const owner = 'dd800000-0000-0000-0000-000000000001';
  const other = 'dd800000-0000-0000-0000-000000000002';
  await db.exec(`insert into auth.users values ('${owner}'),('${other}');
    insert into public.profiles(id,username,display_name) values ('${owner}','reference_owner','Reference'),('${other}','reference_other','Other');`);
  const baseline = (await db.query('select id,current_weekly_goal from public.profiles order by id')).rows;
  await db.exec(await readFile('supabase/migrations/202609080017_weekly_goal_two.sql', 'utf8'));
  assert.deepEqual((await db.query('select id,current_weekly_goal from public.profiles order by id')).rows, baseline);
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`);
  const value = async sql => (await db.query(sql)).rows[0].value;
  const state = await value("select public.confirm_weekly_goal(2,'Europe/Berlin') as value");
  assert.equal(state.current_week.weekly_goal, 2);
  assert.equal(state.current_week.completed_workouts, 0);
  const repeated = await value("select public.confirm_weekly_goal(2,'Europe/Berlin') as value");
  assert.equal(repeated.current_week.id, state.current_week.id);
  assert.equal(repeated.current_week.flame_earned, false);
  const scheduled = await value('select public.set_next_weekly_goal(7) as value');
  assert.equal(scheduled.current_week.weekly_goal, 2);
  assert.equal(scheduled.next_weekly_goal, 7);
  for (const invalid of ['1','8','null']) {
    await assert.rejects(value(`select public.set_next_weekly_goal(${invalid}) as value`), /invalid_weekly_goal/);
  }
  await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`);
  assert.equal(await value(`select count(*)::int as value from public.weekly_progress where user_id='${owner}'`), 0);
  await db.exec("reset role; set role anon; select set_config('request.jwt.claim.sub','',false);");
  await assert.rejects(value("select public.confirm_weekly_goal(2,'UTC') as value"));
  console.log('PASS: 2-unit goal, unchanged existing data, repeat confirmation, next-week-only change, bounds, stranger RLS and anonymous rejection. Production/iPhone not tested.');
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally { await db.close(); }
