-- Private, server-derived history for an authenticated user's completed Gym sets.
-- Targets, unfinished sets, live activities and other users are deliberately excluded.
begin;

create index if not exists workout_logs_exercise_history_idx
  on public.workout_exercise_logs(exercise_id, activity_id)
  where exercise_id is not null;

create or replace function public.get_exercise_performance(p_exercises uuid[])
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if p_exercises is null or cardinality(p_exercises) = 0 or cardinality(p_exercises) > 40
     or array_position(p_exercises, null) is not null then
    raise exception 'invalid_exercises';
  end if;

  return coalesce((
    with requested as (
      select distinct unnest(p_exercises) as exercise_id
    ), actual_sets as (
      select l.exercise_id, a.ended_at, s.weight, s.reps, s.set_number,
             dense_rank() over (partition by l.exercise_id order by a.ended_at desc, a.id) as activity_rank
        from requested q
        join public.workout_exercise_logs l on l.exercise_id=q.exercise_id
        join public.workout_records r on r.activity_id=l.activity_id and r.owner_id=v_user
        join public.activities a on a.id=r.activity_id and a.user_id=v_user
          and a.status='completed' and a.ended_at is not null
        join public.workout_set_logs s on s.workout_exercise_log_id=l.id
          and s.completed and (s.weight is not null or s.reps is not null)
    ), latest as (
      select distinct on (exercise_id) exercise_id, ended_at, weight, reps
        from actual_sets where activity_rank=1
       order by exercise_id, weight desc nulls last, reps desc nulls last, set_number
    ), best as (
      select distinct on (exercise_id) exercise_id, ended_at, weight, reps
        from actual_sets
       order by exercise_id, weight desc nulls last, reps desc nulls last, ended_at desc, set_number
    )
    select jsonb_agg(jsonb_build_object(
      'exercise_id', q.exercise_id,
      'last_completed_at', l.ended_at,
      'last_weight', l.weight,
      'last_reps', l.reps,
      'best_completed_at', b.ended_at,
      'best_weight', b.weight,
      'best_reps', b.reps
    ) order by q.exercise_id)
      from requested q
      join latest l using (exercise_id)
      join best b using (exercise_id)
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_exercise_performance(uuid[]) from public, anon;
grant execute on function public.get_exercise_performance(uuid[]) to authenticated;

commit;
