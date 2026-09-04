-- LOCAL DEVELOPMENT ONLY. Run after creating five Auth users in local Studio with
-- the stable UUIDs below. The FK guard means this never fabricates production users.
insert into public.profiles(id,username,display_name,sports,weekly_goal)
select id,username,display_name,sports,weekly_goal from (values
('00000000-0000-0000-0000-000000000001'::uuid,'momo','Momo',array['gym','running']::public.sport_kind[],4),
('00000000-0000-0000-0000-000000000002'::uuid,'max','Max',array['gym']::public.sport_kind[],4),
('00000000-0000-0000-0000-000000000003'::uuid,'sarah','Sarah',array['running']::public.sport_kind[],3),
('00000000-0000-0000-0000-000000000004'::uuid,'leon','Leon',array['football']::public.sport_kind[],3),
('00000000-0000-0000-0000-000000000005'::uuid,'tim','Tim',array['basketball']::public.sport_kind[],4)
) v(id,username,display_name,sports,weekly_goal) where exists(select 1 from auth.users u where u.id=v.id)
on conflict(id) do nothing;

insert into public.friendships(requester_id,addressee_id,status)
select '00000000-0000-0000-0000-000000000001',id,'accepted' from public.profiles where id in ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004') on conflict do nothing;

insert into public.activities(user_id,sport,subtype,status,started_at,ended_at,distance_meters)
select id,'gym','Pull','live',now()-interval '28 minutes',null,null from public.profiles where id='00000000-0000-0000-0000-000000000002'
union all select id,'running','Easy Run','completed',now()-interval '50 minutes',now()-interval '13 minutes',6400 from public.profiles where id='00000000-0000-0000-0000-000000000003';

insert into public.planned_sessions(host_id,sport,subtype,starts_at,duration_minutes,note)
select id,'martial_arts','Boxen · Sparring',date_trunc('day',now())+interval '19 hours',75,'Technik & Sparring' from public.profiles where id='00000000-0000-0000-0000-000000000001';
insert into public.activities(user_id,sport,subtype,status,planned_at,planned_duration_minutes,note,planned_session_id)
select s.host_id,s.sport,s.subtype,'planned',s.starts_at,s.duration_minutes,s.note,s.id from public.planned_sessions s where s.host_id='00000000-0000-0000-0000-000000000001' and not exists(select 1 from public.activities a where a.planned_session_id=s.id);

