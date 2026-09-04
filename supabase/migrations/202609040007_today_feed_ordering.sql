begin;

create or replace function public.today_feed(p_timezone text) returns jsonb
language sql stable security definer set search_path='' as $$
with bounds as (
  select
    (date_trunc('day',now() at time zone p_timezone) at time zone p_timezone) as start_at,
    ((date_trunc('day',now() at time zone p_timezone)+interval '1 day') at time zone p_timezone) as end_at
),
friends as (
  select case when requester_id=auth.uid() then addressee_id else requester_id end id
  from public.friendships
  where status='accepted' and auth.uid() in (requester_id,addressee_id)
),
people as (
  select p.* from public.profiles p join friends f on f.id=p.id
  where not public.is_blocked(p.id,auth.uid())
),
ranked as (
  select a.*,
    row_number() over (
      partition by user_id
      order by
        case status when 'live' then 1 when 'ready' then 2 when 'planned' then 2 when 'completed' then 3 else 4 end,
        case when status in ('ready','planned') then planned_at end asc nulls last,
        case when status='live' then started_at end desc nulls last,
        case when status='completed' then ended_at end desc nulls last
    ) rn
  from public.activities a,bounds b
  where status='live'
     or (status in ('ready','planned') and planned_at>=b.start_at and planned_at<b.end_at)
     or (status='completed' and ended_at>=b.start_at and ended_at<b.end_at)
),
week_counts as (
  select user_id,count(*)::int n from public.activities
  where status='completed' and ended_at>=date_trunc('week',now() at time zone p_timezone) at time zone p_timezone
  group by user_id
)
select jsonb_build_object(
  'me',(select to_jsonb(r)-'rn' from ranked r where r.user_id=auth.uid() and rn=1),
  'crew',coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'profile',to_jsonb(p),
        'activity',(select to_jsonb(r)-'rn' from ranked r where r.user_id=p.id and rn=1 and p.activity_visibility='friends'),
        'weekly_count',case when p.activity_visibility='friends' then coalesce(w.n,0) else 0 end
      )
      order by coalesce((select case status when 'live' then 1 when 'ready' then 2 when 'planned' then 2 when 'completed' then 3 else 4 end from ranked r where r.user_id=p.id and rn=1 and p.activity_visibility='friends'),4),p.display_name
    )
    from people p left join week_counts w on w.user_id=p.id
  ),'[]'::jsonb)
);
$$;

commit;
