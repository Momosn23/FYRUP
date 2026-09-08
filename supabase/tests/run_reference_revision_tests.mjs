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
  await db.exec('reset role;');
  const beforeOptional = (await db.query('select id,activity_visibility,onboarding_step,current_weekly_goal,weekly_goal_confirmed_at from public.profiles order by id')).rows;
  const optionalMigration = await readFile('supabase/migrations/202609080018_optional_setup.sql', 'utf8');
  await db.exec(optionalMigration);
  await db.exec(optionalMigration); // Safe to rerun: no data rewrite, exact RPC signatures.
  assert.deepEqual((await db.query('select id,activity_visibility,onboarding_step,current_weekly_goal,weekly_goal_confirmed_at from public.profiles order by id')).rows, beforeOptional);
  const fresh = 'dd800000-0000-0000-0000-000000000003';
  const absent = 'dd800000-0000-0000-0000-000000000004';
  await db.exec(`insert into auth.users values ('${fresh}'),('${absent}'); set role authenticated; select set_config('request.jwt.claim.sub','${fresh}',false);`);
  await value("select public.upsert_profile('reference_fresh','Fresh') as value");
  assert.equal(await value('select activity_visibility as value from public.profiles where id=auth.uid()'), 'nobody');
  assert.equal(await value('select weekly_goal_confirmed_at is null as value from public.profiles where id=auth.uid()'), true);
  for (const step of ['friends', 'complete', 'done', 'done']) {
    assert.equal(await value(`select (public.save_onboarding_state('${step}')).onboarding_step as value`), step);
  }
  assert.equal(await value('select cardinality(sports) as value from public.profiles where id=auth.uid()'), 0);
  assert.equal(await value('select weekly_goal_confirmed_at is null as value from public.profiles where id=auth.uid()'), true);
  assert.equal(await value('select count(*)::int as value from public.activities where user_id=auth.uid()'), 0);
  await value("select public.upsert_profile('reference_fresh','Renamed',null,null,null,null,'{}',7::smallint,'friends') as value");
  assert.equal(await value('select activity_visibility as value from public.profiles where id=auth.uid()'), 'nobody', 'Metadata cannot replay privacy consent');
  assert.equal(await value('select onboarding_step as value from public.profiles where id=auth.uid()'), 'done');
  for (const invalid of ['null', "'main'"]) await assert.rejects(value(`select public.save_onboarding_state(${invalid}) as value`), /invalid onboarding step/);
  for (const invalid of ["array[null]::text[]", "array['   ']", "array[repeat('x',81)]", "array_fill('Push'::text,array[25])", "array[['Push','Pull'],['Legs','Core']]"]) {
    await assert.rejects(value(`select public.save_onboarding_state('done',${invalid}) as value`), /invalid gym focus/);
  }
  await assert.rejects(value("update public.profiles set onboarding_step='friends' where id=auth.uid() returning onboarding_step as value"));
  await db.exec(`select set_config('request.jwt.claim.sub','${absent}',false);`);
  await assert.rejects(value("select public.save_onboarding_state('done') as value"), /profile required/);
  await db.exec("select set_config('request.jwt.claim.sub','',false);");
  await assert.rejects(value("select public.save_onboarding_state('done') as value"), /forbidden/);
  await db.exec('reset role;');
  assert.deepEqual((await db.query(`select id,activity_visibility,onboarding_step,current_weekly_goal,weekly_goal_confirmed_at from public.profiles where id in ('${owner}','${other}') order by id`)).rows, beforeOptional);
  await db.exec('set role anon;');
  await assert.rejects(value("select public.save_onboarding_state('done') as value"));
  await db.exec('reset role;');
  const amountsMigration = await readFile('supabase/migrations/202609080019_supplement_amounts.sql', 'utf8');
  await db.exec(amountsMigration); await db.exec(amountsMigration);
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${fresh}',false);`);
  await value("select public.get_supplements('Europe/Berlin') as value");
  const plan = {id:'dd800000-1000-0000-0000-000000000001',owner_id:fresh,revision:0,name:'Eigene Auswahl',weekdays:[1,2,3,4,5,6,7],
    slots:[{id:'dd800000-2000-0000-0000-000000000001',minute:540}],is_paused:false,is_archived:false,reminders_enabled:false,repeat_minutes:60,repeat_count:0};
  const savePlan = async p => (await db.query('select public.save_supplement_plan($1::jsonb) as value',[JSON.stringify(p)])).rows[0].value;
  let saved = await savePlan(plan); assert.equal(saved.amount,null);
  saved = await savePlan({...plan,revision:saved.revision,amount:{value:1.5,unit:'g'}});
  assert.deepEqual(saved.amount,{value:1.5,unit:'g'});
  const own = await value("select public.get_supplements('Europe/Berlin') as value");
  assert.deepEqual(own.plans[0].amount,saved.amount);
  saved = await savePlan({...plan,revision:saved.revision,name:'Umbenannt'});
  assert.deepEqual(saved.amount,{value:1.5,unit:'g'},'Old clients must not erase amounts');
  for (const amount of [{value:0,unit:'g'},{value:-1,unit:'g'},{value:1000001,unit:'g'},{value:'NaN',unit:'g'}, {value:2,unit:'unknown'}, {unit:'g'}, [], '5g']) {
    await assert.rejects(savePlan({...plan,revision:saved.revision,amount}), /invalid_supplement_amount/);
  }
  saved = await savePlan({...plan,revision:saved.revision,amount:null}); assert.equal(saved.amount,null);
  await assert.rejects(savePlan({...plan,revision:0,amount:{value:1,unit:'capsule'}}),/supplement_conflict/);
  await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`);
  await value("select public.get_supplements('Europe/Berlin') as value");
  await assert.rejects(savePlan({...plan,owner_id:other,revision:saved.revision,amount:{value:1,unit:'capsule'}}),/unauthorized/);
  assert.equal(await value(`select count(*)::int as value from public.supplement_plans where owner_id='${fresh}'`),0);
  await db.exec("reset role; set role anon; select set_config('request.jwt.claim.sub','',false);");
  await assert.rejects(savePlan(plan));
  await db.exec('reset role;');
  for (const malformed of [{value:null,unit:'g'}, {value:1,unit:null}, {unit:'g'}, {value:1}]) {
    await assert.rejects(db.query('update public.supplement_plans set amount=$1::jsonb where id=$2::uuid', [JSON.stringify(malformed),plan.id]), /supplement_amount_valid/);
  }
  console.log('PASS: goals 2–7, optional private setup; supplement amounts create/read/update/clear, legacy preservation, bounds, conflict, RLS and idempotent migrations. Production/iPhone not tested.');
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally { await db.close(); }
