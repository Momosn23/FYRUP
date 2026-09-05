// Assemble already-versioned migrations into one transaction for an audited Dashboard deployment.
// Never connects to a database and never reads credentials or user records.
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

export const deploymentFiles = [
  '202609050001_workout_plans.sql', '202609050002_exercise_library.sql',
  '202609050003_daily_steps.sql', '202609050004_activity_pause.sql',
  '202609050005_weekly_flames.sql', '202609050006_onboarding_state.sql',
  '202609050007_blind_workouts.sql', '202609050008_call_my_shot.sql',
  '202609050009_push_friendship_authorization.sql',
];

export const deploymentPrelude = `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if to_regclass('public.profiles') is null or to_regclass('public.workout_plans') is not null
    or to_regclass('public.daily_activity_metrics') is not null or to_regclass('public.weekly_progress') is not null
    or to_regclass('public.blind_workouts') is not null or to_regclass('public.weekly_commitments') is not null then
    raise exception 'unexpected deployment baseline; inspect before retrying';
  end if;
end $preflight$;
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations(version text primary key, statements text[], name text);
alter table supabase_migrations.schema_migrations enable row level security;
create schema if not exists fyrup_deployment;
revoke all on schema fyrup_deployment from public, anon, authenticated;
create table if not exists fyrup_deployment.schema_snapshots(
  version text primary key, captured_at timestamptz not null default now(), routines jsonb not null, policies jsonb not null
);
revoke all on fyrup_deployment.schema_snapshots from public, anon, authenticated;
alter table fyrup_deployment.schema_snapshots enable row level security;
insert into fyrup_deployment.schema_snapshots(version,routines,policies)
select 'before-202609050001-009',
  (select coalesce(jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid)) order by p.proname),'[]')
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f'),
  (select coalesce(jsonb_agg(to_jsonb(p)),'[]') from pg_policies p where p.schemaname='public');
`;

export function assembleDeployment(sources) {
  let sql = deploymentPrelude;
  for (const filename of deploymentFiles) {
    const source = sources[filename]?.replace(/\r\n/g, '\n').trimEnd();
    if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error(`Invalid transaction wrapper: ${filename}`);
    // Anchored lines only, never the BEGIN inside a function body.
    const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
    if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
    const [version, ...parts] = filename.replace(/\.sql$/, '').split('_');
    sql += `\n-- ${filename}\n${body}\n`;
    if (filename === '202609050002_exercise_library.sql') sql += 'alter table pg_temp.fyrup_catalog_seed enable row level security;\n';
    sql += `insert into supabase_migrations.schema_migrations(version,name,statements) values ('${version}','${parts.join('_')}',array[$migration_source$${body}$migration_source$]);\n`;
  }
  return sql + "notify pgrst, 'reload schema';\ncommit;\n";
}

export async function loadDeploymentSources() {
  return Object.fromEntries(await Promise.all(deploymentFiles.map(async name => [name, await readFile(resolve('supabase/migrations', name), 'utf8')])));
}

export const followupFiles = ['202609050010_workout_copy_idempotency.sql', '202609050011_notification_preference_cas.sql'];
export const followupPrelude = `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050009')
    or exists(select 1 from supabase_migrations.schema_migrations where version in ('202609050010','202609050011')) then
    raise exception 'unexpected followup baseline; inspect before retrying';
  end if;
end $preflight$;
`;

export function assembleFollowup(sources) {
  let sql = followupPrelude;
  for (const filename of followupFiles) {
    const source = sources[filename]?.replace(/\r\n/g, '\n').trimEnd();
    if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error(`Invalid transaction wrapper: ${filename}`);
    const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
    if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
    const [version, ...parts] = filename.replace(/\.sql$/, '').split('_');
    sql += `\n-- ${filename}\n${body}\n`;
    sql += `insert into supabase_migrations.schema_migrations(version,name,statements) values ('${version}','${parts.join('_')}',array[$migration_source$${body}$migration_source$]);\n`;
  }
  return sql + "notify pgrst, 'reload schema';\ncommit;\n";
}

export const personalTrainingFile = '202609050012_personal_training.sql';
export const supplementsFile = '202609050013_supplement_reminders.sql';
export const profilePrivacyFile = '202609050014_profile_privacy_preservation.sql';
export const activityPlaceFile = '202609050015_activity_place.sql';
export function assembleActivityPlace(source) {
  source = source?.replace(/\r\n/g, '\n').trimEnd();
  if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error('Invalid activity-place transaction wrapper');
  const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
  if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
  return `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050014')
    or exists(select 1 from supabase_migrations.schema_migrations where version='202609050015')
    or exists(select 1 from information_schema.columns where table_schema='public' and table_name='activities' and column_name='place_name') then
    raise exception 'unexpected activity place baseline; inspect before retrying';
  end if;
end $preflight$;
insert into fyrup_deployment.schema_snapshots(version,routines,policies)
select 'before-202609050015',
  (select coalesce(jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text)),'[]')
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in ('start_activity','start_workout')), '[]'::jsonb;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements)
values ('202609050015','activity_place',array[$migration_source$${body}$migration_source$]);
notify pgrst, 'reload schema';
commit;
`;
}
export function assembleProfilePrivacy(source) {
  source = source?.replace(/\r\n/g, '\n').trimEnd();
  if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error('Invalid profile privacy transaction wrapper');
  const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
  if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
  return `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050013')
    or exists(select 1 from supabase_migrations.schema_migrations where version='202609050014') then
    raise exception 'unexpected profile privacy baseline; inspect before retrying';
  end if;
end $preflight$;
insert into fyrup_deployment.schema_snapshots(version,routines,policies)
select 'before-202609050014',
  (select jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text))
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='upsert_profile'), '[]'::jsonb;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements)
values ('202609050014','profile_privacy_preservation',array[$migration_source$${body}$migration_source$]);
notify pgrst, 'reload schema';
commit;
`;
}
export function assembleSupplements(source) {
  source = source?.replace(/\r\n/g, '\n').trimEnd();
  if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error('Invalid supplement transaction wrapper');
  const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
  if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
  return `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050012')
    or exists(select 1 from supabase_migrations.schema_migrations where version='202609050013')
    or to_regclass('public.supplement_settings') is not null
    or to_regclass('public.supplement_plans') is not null
    or to_regclass('public.supplement_doses') is not null then
    raise exception 'unexpected supplement baseline; inspect before retrying';
  end if;
end $preflight$;
insert into fyrup_deployment.schema_snapshots(version,routines,policies)
select 'before-202609050013',
  (select coalesce(jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid),'acl',p.proacl::text)),'[]')
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='register_device_token'), '[]'::jsonb;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements)
values ('202609050013','supplement_reminders',array[$migration_source$${body}$migration_source$]);
notify pgrst, 'reload schema';
commit;
`;
}
export function assemblePersonalTraining(source) {
  source = source?.replace(/\r\n/g, '\n').trimEnd();
  if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error('Invalid personal-training transaction wrapper');
  const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
  if (body.includes('$migration_source$')) throw Error('SQL quote delimiter collision');
  return `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050011')
    or exists(select 1 from supabase_migrations.schema_migrations where version='202609050012')
    or to_regclass('public.personal_training_routines') is not null
    or to_regclass('public.personal_workout_feedback') is not null then
    raise exception 'unexpected personal-training baseline; inspect before retrying';
  end if;
end $preflight$;
${body}
insert into supabase_migrations.schema_migrations(version,name,statements)
values ('202609050012','personal_training',array[$migration_source$${body}$migration_source$]);
notify pgrst, 'reload schema';
commit;
`;
}
