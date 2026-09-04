begin;

create table if not exists public.training_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists training_groups_owner_name_unique
  on public.training_groups(owner_id, lower(name));

create table if not exists public.training_group_members (
  group_id uuid not null references public.training_groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index if not exists training_group_members_user_idx
  on public.training_group_members(user_id);

alter table public.training_groups enable row level security;
alter table public.training_group_members enable row level security;

create policy training_groups_read on public.training_groups for select to authenticated
using (
  owner_id=auth.uid()
  or exists(select 1 from public.training_group_members m where m.group_id=id and m.user_id=auth.uid())
);

create policy training_group_members_read on public.training_group_members for select to authenticated
using (
  user_id=auth.uid()
  or exists(select 1 from public.training_groups g where g.id=group_id and g.owner_id=auth.uid())
);

create or replace function public.my_training_groups() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',g.id,
    'owner_id',g.owner_id,
    'name',g.name,
    'members',coalesce((
      select jsonb_agg(to_jsonb(p) order by (p.id=g.owner_id) desc,p.display_name)
      from public.profiles p
      where p.id=g.owner_id
         or exists(select 1 from public.training_group_members gm where gm.group_id=g.id and gm.user_id=p.id)
    ),'[]'::jsonb)
  ) order by g.updated_at desc),'[]'::jsonb)
  from public.training_groups g
  where g.owner_id=auth.uid()
     or exists(select 1 from public.training_group_members gm where gm.group_id=g.id and gm.user_id=auth.uid());
$$;

create or replace function public.create_training_group(p_name text,p_member_ids uuid[]) returns boolean
language plpgsql security definer set search_path='' as $$
declare
  v_group uuid;
  candidate uuid;
  cleaned_name text := trim(p_name);
begin
  if char_length(cleaned_name) not between 2 and 40 then raise exception 'invalid_group_name'; end if;
  insert into public.training_groups(owner_id,name) values(auth.uid(),cleaned_name) returning id into v_group;
  foreach candidate in array coalesce(p_member_ids,'{}'::uuid[]) loop
    if public.are_friends(auth.uid(),candidate) then
      insert into public.training_group_members(group_id,user_id) values(v_group,candidate) on conflict do nothing;
    end if;
  end loop;
  return true;
exception when unique_violation then raise exception 'group_name_exists' using errcode='23505';
end; $$;

create or replace function public.delete_training_group(p_group uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  delete from public.training_groups where id=p_group and owner_id=auth.uid();
  return found;
end; $$;

revoke execute on function public.my_training_groups() from public,anon;
revoke execute on function public.create_training_group(text,uuid[]) from public,anon;
revoke execute on function public.delete_training_group(uuid) from public,anon;
grant execute on function public.my_training_groups() to authenticated;
grant execute on function public.create_training_group(text,uuid[]) to authenticated;
grant execute on function public.delete_training_group(uuid) to authenticated;

commit;
