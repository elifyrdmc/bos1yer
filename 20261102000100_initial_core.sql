-- Boş Bir Yer: initial backend foundation.
-- This migration is intentionally read-first. Report writes, moderation,
-- points, coupons, and public profile visibility need reviewed server rules.

begin;

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null
    check (char_length(btrim(nickname)) between 2 and 24),
  avatar_object_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Private profile settings. Public nickname/avatar visibility is not enabled.';
comment on column public.profiles.avatar_object_path is
  'Private Storage object path only; do not store a public URL here.';

create function public.touch_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.touch_profile_updated_at() from public, anon, authenticated;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_profile_updated_at();

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant usage on schema public to authenticated;
grant select (id, nickname, avatar_object_path, created_at, updated_at)
  on table public.profiles to authenticated;
grant insert (id, nickname, avatar_object_path)
  on table public.profiles to authenticated;
grant update (nickname, avatar_object_path)
  on table public.profiles to authenticated;

create policy profiles_read_own
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy profiles_insert_own
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy profiles_update_own
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create table public.parking_reports (
  id uuid primary key default gen_random_uuid(),
  -- Written by a future server-validated endpoint. Its FK/deletion behavior
  -- is deliberately deferred until account and report-retention rules are set.
  author_id uuid not null,
  kind text not null check (kind in ('vacancy', 'leaving')),
  location extensions.geography(point, 4326) not null,
  created_at timestamptz not null default now(),
  note text,
  photo_object_path text
);

comment on table public.parking_reports is
  'Short-lived map contributions. Only safe map columns are readable by clients.';
comment on column public.parking_reports.author_id is
  'Private internal UUID; set from a verified session on the server, never from a client request.';
comment on column public.parking_reports.photo_object_path is
  'Private Storage object path only. A private bucket and upload policy are not created yet.';

create index parking_reports_location_gix
  on public.parking_reports using gist (location);
create index parking_reports_created_at_idx
  on public.parking_reports (created_at desc);

alter table public.parking_reports enable row level security;

revoke all on table public.parking_reports from anon, authenticated;
grant usage on schema public, extensions to anon, authenticated;
grant select (id, kind, location, created_at)
  on table public.parking_reports to anon, authenticated;

create policy parking_reports_read_active_map
  on public.parking_reports for select to anon, authenticated
  using (created_at > (now() - interval '10 minutes'));

-- Return plain coordinates instead of exposing the PostGIS value format to
-- Flutter. SECURITY INVOKER keeps the caller's table grants and RLS in force.
create function public.get_active_parking_reports()
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    report.id,
    report.kind,
    extensions.st_y(report.location::extensions.geometry) as latitude,
    extensions.st_x(report.location::extensions.geometry) as longitude,
    report.created_at,
    floor(extract(epoch from (now() - report.created_at)))::integer
      as age_seconds
  from public.parking_reports as report
  where report.created_at > (now() - interval '10 minutes')
  order by report.created_at desc;
$$;

revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports()
  to anon, authenticated;

commit;
