-- Store each signed-in account's saved Istanbul districts privately.

begin;

create table if not exists public.favorite_districts (
  user_id uuid not null references auth.users (id) on delete cascade,
  district_name text not null
    check (char_length(btrim(district_name)) between 2 and 48),
  created_at timestamptz not null default now(),
  primary key (user_id, district_name)
);

comment on table public.favorite_districts is
  'Private list of Istanbul districts saved by each account; never shown to other users.';

alter table public.favorite_districts enable row level security;
revoke all on table public.favorite_districts from anon, authenticated;
grant select, insert, delete on table public.favorite_districts to authenticated;

drop policy if exists favorite_districts_read_own on public.favorite_districts;
create policy favorite_districts_read_own
  on public.favorite_districts for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists favorite_districts_insert_own on public.favorite_districts;
create policy favorite_districts_insert_own
  on public.favorite_districts for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists favorite_districts_delete_own on public.favorite_districts;
create policy favorite_districts_delete_own
  on public.favorite_districts for delete to authenticated
  using ((select auth.uid()) = user_id);

commit;
