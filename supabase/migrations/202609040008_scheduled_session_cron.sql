begin;

create extension if not exists pg_cron;

do $$
declare existing_job bigint;
begin
  for existing_job in select jobid from cron.job where jobname='fyrup-process-scheduled-sessions' loop
    perform cron.unschedule(existing_job);
  end loop;
  perform cron.schedule(
    'fyrup-process-scheduled-sessions',
    '*/5 * * * *',
    'select public.process_scheduled_sessions();'
  );
end;
$$;

commit;
