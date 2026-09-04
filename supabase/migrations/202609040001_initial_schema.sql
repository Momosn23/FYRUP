begin;

create extension if not exists pgcrypto;
create extension if not exists citext;
create type public.sport_kind as enum ('gym','running','football','basketball','cycling','swimming','martial_arts','racket','yoga','other');
create type public.activity_status as enum ('planned','ready','live','completed','cancelled');
create type public.friendship_status as enum ('pending','accepted','declined');
create type public.invitation_status as enum ('pending','accepted','maybe','declined');
create type public.reaction_kind as enum ('🔥','💪','👏');
create type public.session_status as enum ('planned','ready','live','completed','cancelled');

create table public.sports (
  key public.sport_kind primary key,
  label_de text not null,
  sort_order smallint not null unique
);
create table public.sport_subtypes (
  id uuid primary key default gen_random_uuid(),
  sport public.sport_kind not null references public.sports(key),
  label_de text not null,
  parent_label text,
  sort_order smallint not null,
  unique (sport, label_de)
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext not null unique check (username::text ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 50),
  avatar_path text,
  birth_year smallint check (birth_year between 1900 and extract(year from current_date)::int - 13),
  city text check (char_length(city) <= 80),
  bio text check (char_length(bio) <= 180),
  sports public.sport_kind[] not null default '{}',
  weekly_goal smallint not null default 4 check (weekly_goal between 1 and 7),
  activity_visibility text not null default 'friends' check (activity_visibility in ('friends','nobody')),
  timezone text not null default 'Europe/Berlin',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status public.friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);
create unique index friendships_pair_unique on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_requester_status_idx on public.friendships(requester_id, status);
create index friendships_addressee_status_idx on public.friendships(addressee_id, status);
create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create table public.planned_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_kind not null,
  subtype text,
  starts_at timestamptz not null,
  duration_minutes smallint check (duration_minutes between 5 and 1440),
  note text check (char_length(note) <= 280),
  friends_can_join boolean not null default true,
  status public.session_status not null default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.session_invites (
  session_id uuid not null references public.planned_sessions(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  status public.invitation_status not null default 'pending',
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (session_id, invitee_id)
);
create index session_invites_invitee_idx on public.session_invites(invitee_id, status);
create table public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_kind not null,
  subtype text,
  status public.activity_status not null,
  planned_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  distance_meters integer check (distance_meters > 0),
  planned_duration_minutes smallint check (planned_duration_minutes between 5 and 1440),
  note text check (char_length(note) <= 280),
  planned_session_id uuid references public.planned_sessions(id) on delete set null,
  linked_activity_id uuid references public.activities(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status <> 'live') or started_at is not null),
  check ((status <> 'completed') or (started_at is not null and ended_at is not null and ended_at >= started_at))
);
create unique index one_live_activity_per_user on public.activities(user_id) where status = 'live';
create index activities_user_started_idx on public.activities(user_id, started_at desc);
create index activities_planned_idx on public.activities(planned_at) where status in ('planned','ready');
create index activities_session_idx on public.activities(planned_session_id);
create unique index activities_session_user_unique on public.activities(planned_session_id,user_id) where planned_session_id is not null;
create table public.activity_reactions (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction public.reaction_kind not null,
  created_at timestamptz not null default now(),
  primary key (activity_id, user_id)
);
create table public.fyrups (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  sender_local_date date not null,
  created_at timestamptz not null default now(),
  unique (sender_id, recipient_id, sender_local_date),
  check (sender_id <> recipient_id)
);
create index fyrups_recipient_idx on public.fyrups(recipient_id, created_at desc);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications(recipient_id, created_at desc);
create index notifications_push_queue_idx on public.notifications(created_at) where push_sent_at is null;
create table public.device_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  environment text not null check (environment in ('ios','ios-sandbox')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
create table public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete set null,
  name text not null,
  properties jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create table public.account_deletion_requests (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now()
);

insert into public.sports values
('gym','Gym',1),('running','Laufen',2),('football','Fußball',3),('basketball','Basketball',4),('cycling','Fahrrad',5),('swimming','Schwimmen',6),('martial_arts','Kampfsport',7),('racket','Tennis / Padel',8),('yoga','Yoga',9),('other','Sonstiges',10);
insert into public.sport_subtypes(sport,label_de,parent_label,sort_order) values
('gym','Push',null,1),('gym','Pull',null,2),('gym','Legs',null,3),('gym','Upper Body',null,4),('gym','Lower Body',null,5),('gym','Full Body',null,6),('gym','Chest',null,7),('gym','Back',null,8),('gym','Arms',null,9),('gym','Shoulders',null,10),('gym','Cardio',null,11),('gym','Freies Training',null,12),
('running','Easy Run',null,1),('running','Recovery Run',null,2),('running','Tempo Run',null,3),('running','Intervalle',null,4),('running','Long Run',null,5),('running','Frei',null,6),
('football','Mannschaftstraining',null,1),('football','Spiel',null,2),('football','Freizeit / Bolzplatz',null,3),('football','Einzeltraining',null,4),
('basketball','Training',null,1),('basketball','Spiel',null,2),('basketball','Freizeit',null,3),('basketball','Shooting',null,4),('basketball','Einzeltraining',null,5),
('cycling','Road',null,1),('cycling','Gravel',null,2),('cycling','MTB',null,3),('cycling','Indoor',null,4),('cycling','Locker',null,5),('cycling','Intervalle',null,6),
('swimming','Locker',null,1),('swimming','Technik',null,2),('swimming','Ausdauer',null,3),('swimming','Intervalle',null,4),('swimming','Freies Schwimmen',null,5),
('martial_arts','Technik','Boxen',1),('martial_arts','Sparring','Boxen',2),('martial_arts','Open Mat','BJJ',3),('martial_arts','Drills','MMA',4),('martial_arts','Conditioning',null,5),
('racket','Training','Tennis',1),('racket','Match','Tennis',2),('racket','Training','Padel',3),('racket','Match','Padel',4),('racket','Freies Spielen',null,5),
('yoga','Mobility',null,1),('yoga','Stretching',null,2),('yoga','Yoga',null,3),('yoga','Recovery',null,4);

create or replace function public.is_blocked(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.blocks where (blocker_id=a and blocked_id=b) or (blocker_id=b and blocked_id=a));
$$;
create or replace function public.are_friends(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.friendships where status='accepted' and ((requester_id=a and addressee_id=b) or (requester_id=b and addressee_id=a))) and not public.is_blocked(a,b);
$$;

create or replace function public.upsert_profile(p_username citext,p_display_name text,p_avatar_path text default null,p_birth_year smallint default null,p_city text default null,p_bio text default null,p_sports public.sport_kind[] default '{}',p_weekly_goal smallint default 4,p_activity_visibility text default 'friends') returns public.profiles language plpgsql security definer set search_path='' as $$
declare v public.profiles;
begin
  if lower(p_username::text) in ('admin','administrator','fyrup','support','help','system','moderator','root') then raise exception 'reserved_username'; end if;
  insert into public.profiles(id,username,display_name,avatar_path,birth_year,city,bio,sports,weekly_goal,activity_visibility)
  values(auth.uid(),lower(p_username::text),p_display_name,p_avatar_path,p_birth_year,p_city,p_bio,p_sports,p_weekly_goal,p_activity_visibility)
  on conflict(id) do update set username=excluded.username,display_name=excluded.display_name,avatar_path=excluded.avatar_path,birth_year=excluded.birth_year,city=excluded.city,bio=excluded.bio,sports=excluded.sports,weekly_goal=excluded.weekly_goal,activity_visibility=excluded.activity_visibility,updated_at=now()
  returning * into v; return v;
end; $$;

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.planned_sessions enable row level security;
alter table public.session_invites enable row level security;
alter table public.activities enable row level security;
alter table public.activity_reactions enable row level security;
alter table public.fyrups enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;
alter table public.analytics_events enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.sports enable row level security;
alter table public.sport_subtypes enable row level security;

create policy sports_read on public.sports for select to authenticated using (true);
create policy subtypes_read on public.sport_subtypes for select to authenticated using (true);
create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or (public.are_friends(id,auth.uid()) and not public.is_blocked(id,auth.uid())));
create policy profiles_insert on public.profiles for insert to authenticated with check (id=auth.uid());
create policy profiles_update on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
create policy friendships_read on public.friendships for select to authenticated using (auth.uid() in (requester_id,addressee_id));
create policy blocks_read on public.blocks for select to authenticated using (blocker_id=auth.uid());
create policy sessions_read on public.planned_sessions for select to authenticated using (host_id=auth.uid() or exists(select 1 from public.session_invites i where i.session_id=id and i.invitee_id=auth.uid()) or (friends_can_join and public.are_friends(host_id,auth.uid()) and exists(select 1 from public.profiles p where p.id=host_id and p.activity_visibility='friends')));
create policy invites_read on public.session_invites for select to authenticated using (invitee_id=auth.uid() or exists(select 1 from public.planned_sessions s where s.id=session_id and s.host_id=auth.uid()));
create policy activities_read on public.activities for select to authenticated using (user_id=auth.uid() or (public.are_friends(user_id,auth.uid()) and exists(select 1 from public.profiles p where p.id=user_id and p.activity_visibility='friends')));
create policy reactions_read on public.activity_reactions for select to authenticated using (user_id=auth.uid() or exists(select 1 from public.activities a where a.id=activity_id and (a.user_id=auth.uid() or public.are_friends(a.user_id,auth.uid()))));
create policy fyrups_read on public.fyrups for select to authenticated using (sender_id=auth.uid() or recipient_id=auth.uid());
create policy notifications_read on public.notifications for select to authenticated using (recipient_id=auth.uid());
create policy tokens_owner on public.device_tokens for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy analytics_insert on public.analytics_events for insert to authenticated with check (user_id=auth.uid());
create policy deletion_owner on public.account_deletion_requests for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.send_friend_request(p_addressee uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
  if p_addressee=auth.uid() or public.is_blocked(auth.uid(),p_addressee) then raise exception 'not_allowed'; end if;
  insert into public.friendships(requester_id,addressee_id) values(auth.uid(),p_addressee);
  insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(p_addressee,auth.uid(),'friend_request','Neue Freundschaftsanfrage','Jemand möchte Teil deiner Crew sein.',jsonb_build_object('user_id',auth.uid()));
  return true;
exception when unique_violation then raise exception 'friendship_exists' using errcode='23505';
end; $$;
create or replace function public.answer_friend_request(p_requester uuid,p_accept boolean) returns boolean language plpgsql security definer set search_path='' as $$
begin
  update public.friendships set status=case when p_accept then 'accepted'::public.friendship_status else 'declined'::public.friendship_status end,updated_at=now()
  where requester_id=p_requester and addressee_id=auth.uid() and status='pending';
  if not found then raise exception 'request_not_found'; end if;
  if p_accept then insert into public.notifications(recipient_id,actor_id,type,title,body) values(p_requester,auth.uid(),'friend_accepted','Anfrage angenommen','Ihr seid jetzt Teil derselben Crew.'); end if;
  return true;
end; $$;
create or replace function public.remove_friend(p_friend uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin delete from public.friendships where status='accepted' and ((requester_id=auth.uid() and addressee_id=p_friend) or (requester_id=p_friend and addressee_id=auth.uid())); return found; end; $$;
create or replace function public.block_user(p_blocked uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
  if p_blocked=auth.uid() then raise exception 'not_allowed'; end if;
  insert into public.blocks values(auth.uid(),p_blocked,now()) on conflict do nothing;
  delete from public.friendships where (requester_id=auth.uid() and addressee_id=p_blocked) or (requester_id=p_blocked and addressee_id=auth.uid());
  return true;
end; $$;

create or replace function public.start_activity(p_sport public.sport_kind,p_subtype text default null,p_linked_activity_id uuid default null,p_planned_session_id uuid default null) returns public.activities language plpgsql security definer set search_path='' as $$
declare v public.activities;
begin
  if p_linked_activity_id is not null and not exists(select 1 from public.activities a join public.profiles p on p.id=a.user_id where a.id=p_linked_activity_id and a.status='live' and p.activity_visibility='friends' and public.are_friends(a.user_id,auth.uid())) then raise exception 'invalid_link'; end if;
  if p_planned_session_id is not null then
    update public.activities set status='live',started_at=now(),updated_at=now() where user_id=auth.uid() and planned_session_id=p_planned_session_id and status in ('planned','ready') returning * into v;
  end if;
  if v.id is null then insert into public.activities(user_id,sport,subtype,status,started_at,linked_activity_id,planned_session_id) values(auth.uid(),p_sport,p_subtype,'live',now(),p_linked_activity_id,p_planned_session_id) returning * into v; end if;
  if p_planned_session_id is not null and exists(select 1 from public.planned_sessions where id=p_planned_session_id and host_id=auth.uid()) then
    update public.planned_sessions set status='live',updated_at=now() where id=p_planned_session_id;
    insert into public.notifications(recipient_id,actor_id,type,title,body,data)
      select i.invitee_id,auth.uid(),'session_started','Training wurde gestartet 🔥','Du kannst jetzt ebenfalls starten.',jsonb_build_object('session_id',p_planned_session_id)
      from public.session_invites i where i.session_id=p_planned_session_id and i.status='accepted';
  end if;
  if p_linked_activity_id is not null then insert into public.notifications(recipient_id,actor_id,type,title,body,data) select a.user_id,auth.uid(),'joined_live','Jemand zieht mit dir durch 👊','Deine Crew ist jetzt ebenfalls LIVE.',jsonb_build_object('activity_id',v.id) from public.activities a where a.id=p_linked_activity_id; end if;
  return v;
exception when unique_violation then raise exception 'already_live' using errcode='23505';
end; $$;
create or replace function public.complete_activity(p_activity_id uuid,p_distance_meters integer default null) returns public.activities language plpgsql security definer set search_path='' as $$
declare v public.activities;
begin update public.activities set status='completed',ended_at=now(),distance_meters=p_distance_meters,updated_at=now() where id=p_activity_id and user_id=auth.uid() and status='live' returning * into v; if v.id is null then raise exception 'activity_not_live'; end if; return v; end; $$;
create or replace function public.cancel_activity(p_activity_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin update public.activities set status='cancelled',updated_at=now() where id=p_activity_id and user_id=auth.uid() and status in ('planned','ready','live'); return found; end; $$;

create or replace function public.plan_session(p_sport public.sport_kind,p_subtype text,p_starts_at timestamptz,p_duration_minutes smallint,p_note text,p_invitees uuid[]) returns public.planned_sessions language plpgsql security definer set search_path='' as $$
declare v public.planned_sessions; invitee uuid;
begin
  if p_starts_at < now() then raise exception 'start_in_past'; end if;
  insert into public.planned_sessions(host_id,sport,subtype,starts_at,duration_minutes,note) values(auth.uid(),p_sport,p_subtype,p_starts_at,p_duration_minutes,p_note) returning * into v;
  insert into public.activities(user_id,sport,subtype,status,planned_at,planned_duration_minutes,note,planned_session_id) values(auth.uid(),p_sport,p_subtype,'planned',p_starts_at,p_duration_minutes,p_note,v.id);
  foreach invitee in array coalesce(p_invitees,'{}') loop
    if public.are_friends(auth.uid(),invitee) then
      insert into public.session_invites(session_id,invitee_id) values(v.id,invitee) on conflict do nothing;
      insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(invitee,auth.uid(),'session_invite','Trainingseinladung 🔥',p_sport::text||' · '||to_char(p_starts_at at time zone 'UTC','DD.MM. HH24:MI'),jsonb_build_object('session_id',v.id));
    end if;
  end loop;
  return v;
end; $$;
create or replace function public.respond_to_invite(p_session uuid,p_status public.invitation_status) returns boolean language plpgsql security definer set search_path='' as $$
declare host uuid; s public.planned_sessions;
begin
  if p_status='pending' then raise exception 'invalid_status'; end if;
  update public.session_invites set status=p_status,responded_at=now() where session_id=p_session and invitee_id=auth.uid() returning session_id into p_session;
  if not found then raise exception 'invite_not_found'; end if;
  select * into s from public.planned_sessions where id=p_session; host:=s.host_id;
  if p_status='accepted' then insert into public.activities(user_id,sport,subtype,status,planned_at,planned_duration_minutes,note,planned_session_id) values(auth.uid(),s.sport,s.subtype,'planned',s.starts_at,s.duration_minutes,s.note,s.id) on conflict do nothing;
  else update public.activities set status='cancelled',updated_at=now() where user_id=auth.uid() and planned_session_id=s.id and status in ('planned','ready'); end if;
  insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(host,auth.uid(),'invite_response','Antwort auf deine Einladung',p_status::text,jsonb_build_object('session_id',p_session)); return true;
end; $$;
create or replace function public.join_session(p_session uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare s public.planned_sessions;
begin
  select * into s from public.planned_sessions where id=p_session and friends_can_join and status in ('planned','ready');
  if s.id is null or not public.are_friends(s.host_id,auth.uid()) then raise exception 'not_allowed'; end if;
  insert into public.session_invites(session_id,invitee_id,status,responded_at) values(s.id,auth.uid(),'accepted',now()) on conflict(session_id,invitee_id) do update set status='accepted',responded_at=now();
  insert into public.activities(user_id,sport,subtype,status,planned_at,planned_duration_minutes,note,planned_session_id) values(auth.uid(),s.sport,s.subtype,'planned',s.starts_at,s.duration_minutes,s.note,s.id) on conflict do nothing;
  insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(s.host_id,auth.uid(),'session_joined','Jemand macht mit 🔥','Ein Freund hat sich deinem Training angeschlossen.',jsonb_build_object('session_id',s.id)); return true;
end; $$;
create or replace function public.cancel_session(p_session uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
  update public.planned_sessions set status='cancelled',updated_at=now() where id=p_session and host_id=auth.uid() and status in ('planned','ready'); if not found then return false; end if;
  update public.activities set status='cancelled',updated_at=now() where planned_session_id=p_session and status in ('planned','ready');
  insert into public.notifications(recipient_id,actor_id,type,title,body,data) select invitee_id,auth.uid(),'session_cancelled','Training abgesagt','Der Host hat das Training abgesagt.',jsonb_build_object('session_id',p_session) from public.session_invites where session_id=p_session; return true;
end; $$;

create or replace function public.send_fyrup(p_recipient uuid,p_timezone text) returns boolean language plpgsql security definer set search_path='' as $$
begin
  if not public.are_friends(auth.uid(),p_recipient) then raise exception 'friends_only'; end if;
  insert into public.fyrups(sender_id,recipient_id,sender_local_date) values(auth.uid(),p_recipient,(now() at time zone p_timezone)::date);
  insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(p_recipient,auth.uid(),'fyrup','Deine Crew glaubt an dich 🔥','Jemand hat dich heute FYR UPed.',jsonb_build_object('sender_id',auth.uid())); return true;
exception when unique_violation then raise exception 'already_sent_today' using errcode='23505';
end; $$;
create or replace function public.set_reaction(p_activity uuid,p_reaction text) returns boolean language plpgsql security definer set search_path='' as $$
declare owner uuid;
begin
  select user_id into owner from public.activities where id=p_activity and status='completed';
  if owner is null or not public.are_friends(owner,auth.uid()) or not exists(select 1 from public.profiles where id=owner and activity_visibility='friends') then raise exception 'friends_only'; end if;
  if p_reaction='' then delete from public.activity_reactions where activity_id=p_activity and user_id=auth.uid();
  else insert into public.activity_reactions(activity_id,user_id,reaction) values(p_activity,auth.uid(),p_reaction::public.reaction_kind) on conflict(activity_id,user_id) do update set reaction=excluded.reaction,created_at=now();
    insert into public.notifications(recipient_id,actor_id,type,title,body,data) values(owner,auth.uid(),'reaction','Neue Reaktion',p_reaction,jsonb_build_object('activity_id',p_activity));
  end if; return true;
end; $$;

create or replace function public.search_profiles(p_query text) returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'username',username,'display_name',display_name,'avatar_path',avatar_path,'sports','[]'::jsonb,'weekly_goal',1,'activity_visibility','nobody') order by username),'[]'::jsonb)
  from (select p.id,p.username,p.display_name,p.avatar_path from public.profiles p where char_length(trim(p_query))>=2 and p.id<>auth.uid() and not public.is_blocked(p.id,auth.uid()) and (p.username::text ilike trim(p_query)||'%' or p.display_name ilike '%'||trim(p_query)||'%') order by p.username limit 20) found;
$$;
create or replace function public.pending_friend_requests() returns setof public.profiles language sql stable security definer set search_path='' as $$
  select p.* from public.friendships f join public.profiles p on p.id=f.requester_id where f.addressee_id=auth.uid() and f.status='pending' order by f.created_at;
$$;
create or replace function public.my_session_invites() returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('session_id',i.session_id,'status',i.status,'session',to_jsonb(s),'host',to_jsonb(p)) order by s.starts_at),'[]'::jsonb)
  from public.session_invites i join public.planned_sessions s on s.id=i.session_id join public.profiles p on p.id=s.host_id
  where i.invitee_id=auth.uid() and s.status not in ('completed','cancelled') and s.starts_at>now()-interval '6 hours';
$$;
create or replace function public.today_feed(p_timezone text) returns jsonb language sql stable security definer set search_path='' as $$
with bounds as (select (date_trunc('day',now() at time zone p_timezone) at time zone p_timezone) as start_at, ((date_trunc('day',now() at time zone p_timezone)+interval '1 day') at time zone p_timezone) as end_at),
friends as (select case when requester_id=auth.uid() then addressee_id else requester_id end id from public.friendships where status='accepted' and auth.uid() in (requester_id,addressee_id)),
people as (select p.* from public.profiles p join friends f on f.id=p.id where not public.is_blocked(p.id,auth.uid())),
ranked as (select a.*,row_number() over(partition by user_id order by case status when 'live' then 1 when 'ready' then 2 when 'planned' then 2 when 'completed' then 3 else 4 end,coalesce(started_at,planned_at,ended_at) desc) rn from public.activities a,bounds b where status='live' or coalesce(started_at,planned_at,ended_at)>=b.start_at and coalesce(started_at,planned_at,ended_at)<b.end_at),
week_counts as (select user_id,count(*)::int n from public.activities where status='completed' and ended_at>=date_trunc('week',now() at time zone p_timezone) at time zone p_timezone group by user_id)
select jsonb_build_object('me',(select to_jsonb(r) - 'rn' from ranked r where r.user_id=auth.uid() and rn=1),'crew',coalesce((select jsonb_agg(jsonb_build_object('profile',to_jsonb(p),'activity',(select to_jsonb(r)-'rn' from ranked r where r.user_id=p.id and rn=1 and p.activity_visibility='friends'),'weekly_count',case when p.activity_visibility='friends' then coalesce(w.n,0) else 0 end) order by coalesce((select case status when 'live' then 1 when 'ready' then 2 when 'planned' then 2 when 'completed' then 3 else 4 end from ranked r where r.user_id=p.id and rn=1 and p.activity_visibility='friends'),4),p.display_name) from people p left join week_counts w on w.user_id=p.id),'[]'::jsonb));
$$;
create or replace function public.goal_summary(p_timezone text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_goal int; v_week int; v_month int; v_crew int; v_people int; v_streak int := 0; v_cursor timestamp; v_count int;
begin
  select weekly_goal into v_goal from public.profiles where id=auth.uid();
  v_cursor := date_trunc('week',now() at time zone p_timezone);
  select count(*) into v_week from public.activities where user_id=auth.uid() and status='completed' and ended_at >= v_cursor at time zone p_timezone;
  select count(*) into v_month from public.activities where user_id=auth.uid() and status='completed' and ended_at >= date_trunc('month',now() at time zone p_timezone) at time zone p_timezone;
  if v_week < v_goal then v_cursor := v_cursor - interval '1 week'; end if;
  for i in 1..104 loop
    select count(*) into v_count from public.activities where user_id=auth.uid() and status='completed' and ended_at >= v_cursor at time zone p_timezone and ended_at < (v_cursor+interval '1 week') at time zone p_timezone;
    exit when v_count < v_goal; v_streak := v_streak+1; v_cursor := v_cursor-interval '1 week';
  end loop;
  with people as (select auth.uid() id union select p.id from public.friendships f join public.profiles p on p.id=case when f.requester_id=auth.uid() then f.addressee_id else f.requester_id end where f.status='accepted' and auth.uid() in (f.requester_id,f.addressee_id) and p.activity_visibility='friends' and not public.is_blocked(p.id,auth.uid()))
  select count(a.id),count(distinct p.id) into v_crew,v_people from people p left join public.activities a on a.user_id=p.id and a.status='completed' and a.ended_at>=date_trunc('week',now() at time zone p_timezone) at time zone p_timezone;
  return jsonb_build_object('weekly_count',v_week,'weekly_goal',v_goal,'streak',v_streak,'month_count',v_month,'crew_count',v_crew,'crew_target',greatest(4,v_people*4));
end; $$;
create or replace function public.mark_notifications_read() returns boolean language plpgsql security definer set search_path='' as $$ begin update public.notifications set read_at=now() where recipient_id=auth.uid() and read_at is null; return true; end; $$;
create or replace function public.register_device_token(p_token text,p_environment text) returns boolean language plpgsql security definer set search_path='' as $$ begin insert into public.device_tokens(user_id,token,environment) values(auth.uid(),p_token,p_environment) on conflict(user_id,token) do update set environment=excluded.environment,updated_at=now(); return true; end; $$;
create or replace function public.request_account_deletion() returns boolean language plpgsql security definer set search_path='' as $$ begin insert into public.account_deletion_requests(user_id) values(auth.uid()) on conflict(user_id) do update set requested_at=now(); return true; end; $$;

revoke execute on all functions in schema public from public,anon;
grant execute on function public.is_blocked(uuid,uuid),public.are_friends(uuid,uuid),public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text),public.send_friend_request(uuid),public.answer_friend_request(uuid,boolean),public.remove_friend(uuid),public.block_user(uuid),public.start_activity(public.sport_kind,text,uuid,uuid),public.complete_activity(uuid,integer),public.cancel_activity(uuid),public.plan_session(public.sport_kind,text,timestamptz,smallint,text,uuid[]),public.respond_to_invite(uuid,public.invitation_status),public.join_session(uuid),public.cancel_session(uuid),public.send_fyrup(uuid,text),public.set_reaction(uuid,text),public.search_profiles(text),public.pending_friend_requests(),public.my_session_invites(),public.today_feed(text),public.goal_summary(text),public.mark_notifications_read(),public.register_device_token(text,text),public.request_account_deletion() to authenticated;

commit;
