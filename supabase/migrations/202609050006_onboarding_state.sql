begin;

-- Existing users remain legacy-complete (NULL); only future profile inserts start onboarding.
alter table public.profiles add column gym_focus text[];
alter table public.profiles add column onboarding_step text
 check(onboarding_step in ('sports','gym','weekly_goal','friends','complete','done'));
alter table public.profiles alter column onboarding_step set default 'sports';

create function public.save_onboarding_state(p_step text,p_gym_focus text[] default null)
returns public.profiles language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if p_step is null or p_step not in ('sports','gym','weekly_goal','friends','complete','done') then raise exception 'invalid onboarding step'; end if;
 if p_gym_focus is not null and (cardinality(p_gym_focus)>24 or coalesce(array_ndims(p_gym_focus),1)<>1 or exists(
   select 1 from unnest(p_gym_focus) value where value is null or length(trim(value)) not between 1 and 80
 )) then raise exception 'invalid gym focus'; end if;
 select * into v_profile from public.profiles where id=auth.uid() for update;
 if not found then raise exception 'profile required'; end if;
 if p_step in ('friends','complete','done') and v_profile.weekly_goal_confirmed_at is null then raise exception 'confirm weekly goal first'; end if;
 if p_step <> 'sports' and cardinality(v_profile.sports)=0 then raise exception 'choose sports first'; end if;
 update public.profiles set onboarding_step=p_step,gym_focus=coalesce(p_gym_focus,gym_focus),updated_at=now()
 where id=auth.uid() returning * into v_profile;
 return v_profile;
end; $$;
revoke all on function public.save_onboarding_state(text,text[]) from public,anon;
grant execute on function public.save_onboarding_state(text,text[]) to authenticated;

commit;
