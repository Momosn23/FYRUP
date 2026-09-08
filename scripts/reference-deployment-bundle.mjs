// Pure assembly only. No database connection, credentials, customer records or writes.
import { createHash } from 'node:crypto';
export const referenceDeploymentFiles = [
  '202609080017_weekly_goal_two.sql',
  '202609080018_optional_setup.sql',
  '202609080019_supplement_amounts.sql',
];

export function assembleReferenceDeployment(sources) {
  let sql = `begin;
set local lock_timeout = '4s';
set local statement_timeout = '60s';
do $preflight$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='202609060016')
  or exists(select 1 from supabase_migrations.schema_migrations where version>'202609060016')
  or to_regclass('public.supplement_plans') is null
  or exists(select 1 from information_schema.columns where table_schema='public' and table_name='supplement_plans' and column_name='amount')
  or to_regprocedure('public.save_onboarding_state(text,text[])') is null then
  raise exception 'unexpected reference deployment baseline; inspect before retrying';
 end if;
end $preflight$;
insert into fyrup_deployment.schema_snapshots(version,routines,policies)
select 'before-202609080017-019',
 (select coalesce(jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid)) order by p.proname),'[]')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f'),
 (select coalesce(jsonb_agg(to_jsonb(p)),'[]') from pg_policies p where p.schemaname='public');
`;
  for (const file of referenceDeploymentFiles) {
    const source = sources[file]?.replace(/\r\n/g, '\n').trimEnd();
    if (!source || !/^begin;$/m.test(source) || !/\ncommit;$/.test(source)) throw Error(`Invalid transaction wrapper: ${file}`);
    const body = source.replace(/^begin;\n/m, '').replace(/\ncommit;$/, '');
    if (body.includes('$migration_source$') || body.includes('$apply_migration$')) throw Error('SQL quote delimiter collision');
    const [version, ...parts] = file.replace(/\.sql$/, '').split('_');
    sql += `\n-- ${file}\ndo $apply_migration$ declare v_body text := $migration_source$${body}$migration_source$; begin\n`;
    sql += `execute v_body;\ninsert into supabase_migrations.schema_migrations(version,name,statements) values ('${version}','${parts.join('_')}',array[v_body]);\nend $apply_migration$;\n`;
  }
  return sql + "notify pgrst, 'reload schema';\ncommit;\n";
}

// Record an already-applied 016 only after exact body + signature + security + index verification.
// This does not execute its function/index DDL or rewrite application records.
export function assembleExistingPerformanceReceipt(source) {
  const body = source?.replace(/\r\n/g, '\n').match(/as \$\$([\s\S]*?)\$\$;/)?.[1];
  if (!body) throw Error('Missing verified performance source');
  const hash = createHash('md5').update(body).digest('hex');
  return `begin;
set local lock_timeout='4s';
set local statement_timeout='60s';
lock table supabase_migrations.schema_migrations in share row exclusive mode;
do $verify$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='202609050015')
  or exists(select 1 from supabase_migrations.schema_migrations where version>'202609050015')
  or not exists(select 1 from pg_proc p where p.oid=to_regprocedure('public.get_exercise_performance(uuid[])')
   and md5(replace(p.prosrc,chr(13)||chr(10),chr(10)))='${hash}'
   and p.prosecdef and p.provolatile='s' and p.proconfig=array['search_path=""']
   and p.prolang=(select oid from pg_language where lanname='plpgsql')
   and pg_get_function_arguments(p.oid)='p_exercises uuid[]' and pg_get_function_result(p.oid)='jsonb'
   and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE')
   and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'))
  or not exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.workout_logs_exercise_history_idx') and i.indisvalid
   and pg_get_indexdef(i.indexrelid)='CREATE INDEX workout_logs_exercise_history_idx ON public.workout_exercise_logs USING btree (exercise_id, activity_id) WHERE (exercise_id IS NOT NULL)') then
  raise exception 'existing performance migration does not exactly match; no receipt written';
 end if;
end $verify$;
insert into supabase_migrations.schema_migrations(version,name,statements)
values ('202609060016','exercise_performance',array[
 pg_get_indexdef('public.workout_logs_exercise_history_idx'::regclass)||';',
 pg_get_functiondef('public.get_exercise_performance(uuid[])'::regprocedure),
 'revoke all on function public.get_exercise_performance(uuid[]) from public, anon;',
 'grant execute on function public.get_exercise_performance(uuid[]) to authenticated;'
]);
commit;
`;
}
