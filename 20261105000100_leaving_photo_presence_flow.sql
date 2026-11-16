begin;

-- This schema may not exist yet if the earlier RPC-hardening migration was
-- not applied to the development project. Keep it outside PostgREST exposure.
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;

alter table public.parking_reports
  add column leaving_presence text,
  add column photo_uploaded_at timestamptz;

-- Existing leaving reports were created with a required photo, so preserve
-- their meaning when introducing the explicit presence choice.
update public.parking_reports
set leaving_presence = 'at_location'
where kind = 'leaving' and leaving_presence is null;

update public.parking_reports
set photo_uploaded_at = created_at
where photo_object_path is not null and photo_uploaded_at is null;

alter table public.parking_reports
  add constraint parking_reports_leaving_presence_check
  check (
    (kind = 'vacancy' and leaving_presence is null)
    or (kind = 'leaving' and leaving_presence is not null
      and leaving_presence in ('at_location', 'nearby'))
  ),
  add constraint parking_reports_presence_photo_check
  check (
    (kind <> 'leaving' or leaving_presence <> 'at_location'
      or photo_object_path is not null)
    and ((photo_object_path is null) = (photo_uploaded_at is null))
  );

comment on column public.parking_reports.leaving_presence is
  'For leaving reports, at_location requires a photo at creation; nearby permits a follow-up photo within ten minutes.';
comment on column public.parking_reports.photo_uploaded_at is
  'Server timestamp for the attached photo, used for the follow-up deadline and UI freshness.';

-- The old create RPC required a photo for every report. Replace its private
-- implementation and public wrapper so only nearby leaving reports can omit it.
drop function if exists public.create_parking_report(
  text, double precision, double precision, text, text, smallint
);
drop function if exists app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint
);

create function app_private.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null,
  p_leaving_presence text default null
)
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer,
  note text,
  photo_object_path text,
  estimated_departure_minutes smallint,
  leaving_presence text,
  photo_age_seconds integer,
  can_upload_photo boolean
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required to create a parking report.';
  end if;
  if p_kind not in ('vacancy', 'leaving') then
    raise exception 'Unsupported parking report kind.';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid parking report coordinates.';
  end if;
  if p_note is not null and char_length(p_note) > 300 then
    raise exception 'The parking report note is too long.';
  end if;
  if p_photo_object_path is not null then
    if p_photo_object_path not like ((select auth.uid()::text) || '/%') then
      raise exception 'The report photo must belong to the signed-in user.';
    end if;
    if not exists (
      select 1 from storage.objects as photo
      where photo.bucket_id = 'parking-report-photos'
        and photo.name = p_photo_object_path
        and photo.owner_id = (select auth.uid()::text)
    ) then
      raise exception 'The report photo must exist in the user''s private bucket.';
    end if;
  end if;
  if p_kind = 'leaving' then
    if p_estimated_departure_minutes is null
       or p_estimated_departure_minutes not in (5, 10) then
      raise exception 'Leaving reports require a 5 or 10 minute estimate.';
    end if;
    if p_leaving_presence is null
       or p_leaving_presence not in ('at_location', 'nearby') then
      raise exception 'Leaving reports require a presence choice.';
    end if;
    if p_leaving_presence = 'at_location' and p_photo_object_path is null then
      raise exception 'A photo is required when at the parking location.';
    end if;
  elsif p_estimated_departure_minutes is not null
        or p_leaving_presence is not null
        or p_photo_object_path is null then
    raise exception 'Vacancy reports require a photo and cannot have a leaving estimate or presence choice.';
  end if;

  return query
    insert into public.parking_reports (
      author_id,
      kind,
      location,
      note,
      photo_object_path,
      estimated_departure_minutes,
      leaving_presence,
      photo_uploaded_at
    )
    values (
      (select auth.uid()),
      p_kind,
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude), 4326
      )::extensions.geography,
      nullif(btrim(p_note), ''),
      p_photo_object_path,
      p_estimated_departure_minutes,
      p_leaving_presence,
      case when p_photo_object_path is null then null else now() end
    )
    returning
      parking_reports.id,
      parking_reports.kind,
      extensions.st_y(parking_reports.location::extensions.geometry),
      extensions.st_x(parking_reports.location::extensions.geometry),
      parking_reports.created_at,
      0,
      parking_reports.note,
      parking_reports.photo_object_path,
      parking_reports.estimated_departure_minutes,
      parking_reports.leaving_presence,
      case when parking_reports.photo_uploaded_at is null then null else 0 end,
      parking_reports.author_id = (select auth.uid());
end;
$function$;

revoke all on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
) from public, anon, authenticated;
grant execute on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
) to authenticated;

create function public.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null,
  p_leaving_presence text default null
)
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer,
  note text,
  photo_object_path text,
  estimated_departure_minutes smallint,
  leaving_presence text,
  photo_age_seconds integer,
  can_upload_photo boolean
)
language sql
security invoker
set search_path = ''
as $function$
  select * from app_private.create_parking_report(
    p_kind, p_latitude, p_longitude, p_note, p_photo_object_path,
    p_estimated_departure_minutes, p_leaving_presence
  );
$function$;

revoke all on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
) from public, anon, authenticated;
grant execute on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
) to authenticated;

create function app_private.attach_leaving_report_photo(
  p_report_id uuid,
  p_photo_object_path text,
  p_latitude double precision,
  p_longitude double precision
)
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer,
  note text,
  photo_object_path text,
  estimated_departure_minutes smallint,
  leaving_presence text,
  photo_age_seconds integer,
  can_upload_photo boolean
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_report public.parking_reports%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid photo coordinates.' using errcode = '22023';
  end if;
  if p_photo_object_path is null
     or p_photo_object_path not like (v_user_id::text || '/%')
     or not exists (
       select 1 from storage.objects as photo
       where photo.bucket_id = 'parking-report-photos'
         and photo.name = p_photo_object_path
         and photo.owner_id = v_user_id::text
     ) then
    raise exception 'The photo must be uploaded by the signed-in user.'
      using errcode = '42501';
  end if;

  select report.* into v_report
  from public.parking_reports as report
  where report.id = p_report_id and report.author_id = v_user_id
  for update;

  if not found
     or v_report.kind <> 'leaving'
     or v_report.leaving_presence <> 'nearby'
     or v_report.photo_object_path is not null
     or now() >= v_report.created_at + interval '10 minutes'
     or now() >= v_report.created_at + interval '10 minutes'
       + make_interval(mins => v_report.estimated_departure_minutes) then
    raise exception 'Photo upload is no longer allowed for this report.'
      using errcode = 'P0002';
  end if;

  if not extensions.st_dwithin(
    v_report.location,
    extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography,
    30
  ) then
    raise exception 'The photo must be taken within 30 meters of the report.'
      using errcode = '22023';
  end if;

  update public.parking_reports as report
  set photo_object_path = p_photo_object_path,
      photo_uploaded_at = now()
  where report.id = p_report_id
  returning report.* into v_report;

  return query select
    v_report.id,
    v_report.kind,
    extensions.st_y(v_report.location::extensions.geometry),
    extensions.st_x(v_report.location::extensions.geometry),
    v_report.created_at,
    floor(extract(epoch from (now() - v_report.created_at)))::integer,
    v_report.note,
    v_report.photo_object_path,
    v_report.estimated_departure_minutes,
    v_report.leaving_presence,
    floor(extract(epoch from (now() - v_report.photo_uploaded_at)))::integer,
    v_report.author_id = v_user_id;
end;
$function$;

revoke all on function app_private.attach_leaving_report_photo(
  uuid, text, double precision, double precision
) from public, anon, authenticated;
grant execute on function app_private.attach_leaving_report_photo(
  uuid, text, double precision, double precision
) to authenticated;

create function public.attach_leaving_report_photo(
  p_report_id uuid,
  p_photo_object_path text,
  p_latitude double precision,
  p_longitude double precision
)
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer,
  note text,
  photo_object_path text,
  estimated_departure_minutes smallint,
  leaving_presence text,
  photo_age_seconds integer,
  can_upload_photo boolean
)
language sql
security invoker
set search_path = ''
as $function$
  select * from app_private.attach_leaving_report_photo(
    p_report_id, p_photo_object_path, p_latitude, p_longitude
  );
$function$;

revoke all on function public.attach_leaving_report_photo(
  uuid, text, double precision, double precision
) from public, anon, authenticated;
grant execute on function public.attach_leaving_report_photo(
  uuid, text, double precision, double precision
) to authenticated;

drop function public.get_active_parking_reports();
create function public.get_active_parking_reports()
returns table (
  id uuid,
  kind text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  age_seconds integer,
  note text,
  photo_object_path text,
  estimated_departure_minutes smallint,
  leaving_presence text,
  photo_age_seconds integer,
  can_upload_photo boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.id,
    report.kind,
    extensions.st_y(report.location::extensions.geometry),
    extensions.st_x(report.location::extensions.geometry),
    report.created_at,
    floor(extract(epoch from (now() - report.created_at)))::integer,
    report.note,
    report.photo_object_path,
    report.estimated_departure_minutes,
    report.leaving_presence,
    case when report.photo_uploaded_at is null then null
      else floor(extract(epoch from (now() - report.photo_uploaded_at)))::integer
    end,
    report.author_id = (select auth.uid())
  from public.parking_reports as report
  where auth.uid() is not null
    and now() < report.created_at + interval '10 minutes'
      + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
    and (report.kind <> 'vacancy' or report.resolved_at is null)
    and (report.kind <> 'leaving'
      or report.leaving_presence <> 'nearby'
      or report.photo_object_path is not null
      or now() < report.created_at + interval '10 minutes')
  order by report.created_at desc;
$$;
revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports()
  to authenticated;

create or replace function public.get_parking_report_feedback(p_report_id uuid)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.parking_reports as report
    where report.id = p_report_id
      and now() < report.created_at + interval '10 minutes'
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
      and (report.kind <> 'leaving'
        or report.leaving_presence <> 'nearby'
        or report.photo_object_path is not null)
  ) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;
  return query
  select
    count(*) filter (where feedback.outcome = 'parked'),
    count(*) filter (where feedback.outcome = 'occupied'),
    count(*) filter (where feedback.outcome = 'not_found'),
    max(feedback.outcome) filter (where feedback.user_id = v_user_id),
    (select report.author_id <> v_user_id
      from public.parking_reports as report where report.id = p_report_id)
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id;
end;
$$;

create or replace function public.submit_parking_report_feedback(
  p_report_id uuid,
  p_outcome text
)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_kind text;
  v_created_at timestamptz;
  v_resolved_at timestamptz;
  v_estimate smallint;
  v_presence text;
  v_photo_path text;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;
  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes, report.leaving_presence,
         report.photo_object_path
    into v_kind, v_created_at, v_resolved_at, v_estimate, v_presence,
         v_photo_path
  from public.parking_reports as report
  where report.id = p_report_id
  for update;
  if not found
     or (v_kind = 'vacancy' and v_resolved_at is not null)
     or now() >= v_created_at + interval '10 minutes'
       + make_interval(mins => coalesce(v_estimate, 0))
     or (v_kind = 'leaving' and v_presence = 'nearby'
         and v_photo_path is null) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.parking_reports as report
    where report.id = p_report_id and report.author_id = v_user_id
  ) then
    raise exception 'Report creators cannot submit feedback.'
      using errcode = '42501';
  end if;
  insert into public.parking_report_feedback (report_id, user_id, outcome)
  values (p_report_id, v_user_id, p_outcome);
  if v_kind = 'vacancy' and p_outcome in ('parked', 'occupied') then
    update public.parking_reports set resolved_at = now()
    where id = p_report_id;
  end if;
  return query select * from public.get_parking_report_feedback(p_report_id);
end;
$$;

revoke all on function public.get_parking_report_feedback(uuid)
  from public, anon, authenticated;
grant execute on function public.get_parking_report_feedback(uuid)
  to authenticated;
revoke all on function public.submit_parking_report_feedback(uuid, text)
  from public, anon, authenticated;
grant execute on function public.submit_parking_report_feedback(uuid, text)
  to authenticated;

-- A pending follow-up photo is private until the owner attaches it and the
-- report stays within its applicable active lifetime.
drop policy if exists parking_report_photos_select_active on storage.objects;
create policy parking_report_photos_select_active
  on storage.objects for select to authenticated
  using (
    bucket_id = 'parking-report-photos'
    and exists (
      select 1
      from public.parking_reports as report
      where report.photo_object_path = storage.objects.name
        and now() < report.created_at + interval '10 minutes'
          + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
    )
  );

commit;
