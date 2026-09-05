-- Metadata edits must never replay an old privacy choice. Keep the existing RPC
-- signature for already-installed clients; only initial creation consumes it.
begin;
create or replace function public.upsert_profile(
 p_username citext,p_display_name text,p_avatar_path text default null,
 p_birth_year smallint default null,p_city text default null,p_bio text default null,
 p_sports public.sport_kind[] default '{}',p_weekly_goal smallint default 4,
 p_activity_visibility text default 'friends'
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
commit;
