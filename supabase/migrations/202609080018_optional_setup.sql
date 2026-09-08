-- New optional setup flow. No existing preferences, goals or histories change.
begin;

alter table public.profiles alter column activity_visibility set default 'nobody';

create or replace function public.upsert_profile(
 p_username citext,p_display_name text,p_avatar_path text default null,
 p_birth_year smallint default null,p_city text default null,p_bio text default null,
 p_sports public.sport_kind[] default '{}',p_weekly_goal smallint default 4,
 p_activity_visibility text default 'nobody'
) returns public.profiles language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles;
begin
 if auth.uid() is null then raise exception 'forbidden'; end if;
 if lower(p_username::text) in ('admin','administrator','fyrup','support','help','system','moderator','root') then raise exception 'reserved_username'; end if;
 insert into public.profiles(id,username,display_name,avatar_path,birth_year,city,bio,sports,activity_visibility)
 values(auth.uid(),lower(p_username::text),p_display_name,p_avatar_path,p_birth_year,p_city,p_bio,p_sports,p_activity_visibility)
 on conflict(id) do update set username=excluded.username,display_name=excluded.display_name,
 avatar_path=excluded.avatar_path,birth_year=excluded.birth_year,city=excluded.city,bio=excluded.bio,
 sports=excluded.sports,updated_at=now()
 returning * into v_profile;
 return v_profile;
end; $$;
revoke all on function public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text) from public,anon;
grant execute on function public.upsert_profile(citext,text,text,smallint,text,text,public.sport_kind[],smallint,text) to authenticated;

create or replace function public.save_onboarding_state(p_step text,p_gym_focus text[] default null)
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
 -- Finishing setup is not confirming a goal, picking a sport, creating an
 -- activity or consenting to Health/sharing. The corresponding RPCs stay separate.
 update public.profiles set onboarding_step=p_step,gym_focus=coalesce(p_gym_focus,gym_focus),updated_at=now()
 where id=auth.uid() returning * into v_profile;
 return v_profile;
end; $$;
revoke all on function public.save_onboarding_state(text,text[]) from public,anon;
grant execute on function public.save_onboarding_state(text,text[]) to authenticated;
commit;
