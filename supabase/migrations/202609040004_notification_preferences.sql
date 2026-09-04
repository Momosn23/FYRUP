-- Per-user push preferences and an opt-in notification for ordinary friend starts.
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  friend_starts boolean not null default false,
  fyrup boolean not null default true,
  invitations boolean not null default true,
  reactions boolean not null default true,
  friend_requests boolean not null default true,
  reminders boolean not null default true,
  weekly_goal boolean not null default true,
  crew_goal boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

do $$
begin
  create policy notification_preferences_owner
    on public.notification_preferences for all to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());
exception when duplicate_object then null;
end $$;

create or replace function public.get_notification_preferences()
returns public.notification_preferences
language plpgsql security definer set search_path = '' as $$
declare value public.notification_preferences;
begin
  insert into public.notification_preferences(user_id) values(auth.uid())
    on conflict(user_id) do nothing;
  select * into value from public.notification_preferences where user_id=auth.uid();
  return value;
end; $$;

create or replace function public.save_notification_preferences(
  p_friend_starts boolean,
  p_fyrup boolean,
  p_invitations boolean,
  p_reactions boolean,
  p_friend_requests boolean,
  p_reminders boolean,
  p_weekly_goal boolean,
  p_crew_goal boolean
) returns public.notification_preferences
language plpgsql security definer set search_path = '' as $$
declare value public.notification_preferences;
begin
  insert into public.notification_preferences(
    user_id, friend_starts, fyrup, invitations, reactions,
    friend_requests, reminders, weekly_goal, crew_goal
  ) values (
    auth.uid(), p_friend_starts, p_fyrup, p_invitations, p_reactions,
    p_friend_requests, p_reminders, p_weekly_goal, p_crew_goal
  )
  on conflict(user_id) do update set
    friend_starts=excluded.friend_starts,
    fyrup=excluded.fyrup,
    invitations=excluded.invitations,
    reactions=excluded.reactions,
    friend_requests=excluded.friend_requests,
    reminders=excluded.reminders,
    weekly_goal=excluded.weekly_goal,
    crew_goal=excluded.crew_goal,
    updated_at=now()
  returning * into value;
  return value;
end; $$;

create or replace function public.notify_friends_on_activity_live()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare actor_name text;
begin
  if new.status <> 'live' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'live' then return new; end if;

  select display_name into actor_name from public.profiles where id=new.user_id;
  insert into public.notifications(recipient_id,actor_id,type,title,body,data)
  select p.id,new.user_id,'activity_started',actor_name || ' trainiert gerade 🔥',
         new.sport::text || coalesce(' · ' || new.subtype,''),
         jsonb_build_object('activity_id',new.id)
  from public.profiles p
  join public.notification_preferences pref on pref.user_id=p.id and pref.friend_starts
  where public.are_friends(new.user_id,p.id)
    and not exists (
      select 1 from public.session_invites i
      where i.session_id=new.planned_session_id and i.invitee_id=p.id and i.status='accepted'
    );
  return new;
end; $$;

drop trigger if exists activities_notify_friends_live on public.activities;
create trigger activities_notify_friends_live
after insert or update of status on public.activities
for each row execute function public.notify_friends_on_activity_live();

grant select,insert,update on public.notification_preferences to authenticated;
grant execute on function public.get_notification_preferences(),
  public.save_notification_preferences(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)
  to authenticated;
