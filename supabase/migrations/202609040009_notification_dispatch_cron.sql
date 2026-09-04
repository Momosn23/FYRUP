begin;

create extension if not exists pg_net;
create extension if not exists supabase_vault with schema vault;

do $$
declare existing_job bigint;
begin
  for existing_job in select jobid from cron.job where jobname='fyrup-dispatch-notifications' loop
    perform cron.unschedule(existing_job);
  end loop;
  perform cron.schedule(
    'fyrup-dispatch-notifications',
    '* * * * *',
    $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='fyrup_project_url' limit 1)
          || '/functions/v1/dispatch-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name='fyrup_cron_secret' limit 1)
        ),
        body := jsonb_build_object('source', 'cron'),
        timeout_milliseconds := 10000
      ) as request_id;
    $job$
  );
end;
$$;

commit;
