-- The private notification worker must recheck accepted friendship and both
-- block directions immediately before delivering queued social notifications.
-- Do not depend on environment-specific default function privileges.
begin;
grant execute on function public.are_friends(uuid, uuid) to service_role;
commit;
