-- Private account identity and cross-device profile preferences.

begin;

alter table public.profiles
  add column if not exists full_name text;

alter table public.profiles
  drop constraint if exists profiles_full_name_length_check;
alter table public.profiles
  add constraint profiles_full_name_length_check
  check (full_name is null or char_length(btrim(full_name)) between 2 and 80);

-- Preserve each existing private nickname as a combined display name. Keep the
-- original nickname untouched and do not guess where first and last names split.
-- The historical "Sürücü" fallback is not a user-provided name, so leave those
-- accounts blank for the owner to complete in profile settings.
update public.profiles
set full_name = btrim(nickname)
where full_name is null
  and nullif(btrim(nickname), '') is not null
  and btrim(nickname) <> 'Sürücü';

alter table public.profiles
  drop constraint if exists profiles_avatar_owned_path_check;
alter table public.profiles
  add constraint profiles_avatar_owned_path_check
  check (
    avatar_object_path is null
    or split_part(avatar_object_path, '/', 1) = id::text
  );

comment on column public.profiles.full_name is
  'Private account profile data. Readable only by the owning authenticated user; not exposed on public reports.';
comment on column public.profiles.avatar_object_path is
  'Private Storage object path under the owning user ID folder. Never store or return a public URL.';

grant select (full_name) on table public.profiles to authenticated;
grant insert (full_name) on table public.profiles to authenticated;
grant update (full_name) on table public.profiles to authenticated;

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

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists profile_photos_read_own on storage.objects;
create policy profile_photos_read_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists profile_photos_insert_own on storage.objects;
create policy profile_photos_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists profile_photos_update_own on storage.objects;
create policy profile_photos_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists profile_photos_delete_own on storage.objects;
create policy profile_photos_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create or replace function public.get_my_account_export()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'A signed-in user is required' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'profile', coalesce(
      (
        select jsonb_build_object(
          'full_name', profile.full_name,
          'created_at', profile.created_at,
          'updated_at', profile.updated_at
        )
        from public.profiles as profile
        where profile.id = v_user_id
      ),
      '{}'::jsonb
    ),
    'favorite_districts', coalesce(
      (
        select jsonb_agg(favorite.district_name order by favorite.district_name)
        from public.favorite_districts as favorite
        where favorite.user_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'reports', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', report.id,
            'kind', report.kind,
            'latitude', extensions.st_y(report.location::extensions.geometry),
            'longitude', extensions.st_x(report.location::extensions.geometry),
            'created_at', report.created_at,
            'note', report.note,
            'estimated_departure_minutes', report.estimated_departure_minutes,
            'leaving_presence', report.leaving_presence,
            'photo_uploaded_at', report.photo_uploaded_at,
            'resolved_at', report.resolved_at,
            'cancelled_at', report.cancelled_at,
            'parked_count', coalesce(feedback.parked_count, 0),
            'occupied_count', coalesce(feedback.occupied_count, 0),
            'not_found_count', coalesce(feedback.not_found_count, 0)
          ) order by report.created_at desc, report.id desc
        )
        from public.parking_reports as report
        left join lateral (
          select
            count(*) filter (where response.outcome = 'parked') as parked_count,
            count(*) filter (where response.outcome = 'occupied') as occupied_count,
            count(*) filter (where response.outcome = 'not_found') as not_found_count
          from public.parking_report_feedback as response
          where response.report_id = report.id
            and (
              report.kind <> 'leaving'
              or response.created_at >= report.created_at
                + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
            )
        ) as feedback on true
        where report.author_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'points', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', entry.id,
            'points_delta', entry.points_delta,
            'event_type', entry.event_type,
            'description', entry.description,
            'created_at', entry.created_at
          ) order by entry.created_at desc, entry.id desc
        )
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'points_balance', coalesce(
      (
        select sum(entry.points_delta)::bigint
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      0::bigint
    )
  );
end;
$$;

revoke all on function public.get_my_account_export()
  from public, anon, authenticated;
grant execute on function public.get_my_account_export()
  to authenticated;

comment on function public.get_my_account_export() is
  'Exports only the signed-in user profile, favorites, report history and points ledger. Private storage paths and other users are excluded.';

commit;
