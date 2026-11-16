begin;

-- A nearby leaving report must receive its presence photo by the selected
-- departure estimate (5 or 10 minutes), not by a fixed ten-minute deadline.
comment on column public.parking_reports.leaving_presence is
  'For leaving reports, at_location requires a photo at creation; nearby permits a follow-up photo before the selected departure estimate.';
comment on column public.parking_reports.photo_uploaded_at is
  'Server timestamp when the presence photo was attached; the selected estimate, not this timestamp, controls the leaving pin color transition.';

create or replace function app_private.attach_leaving_report_photo(
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
     or now() >= v_report.created_at
       + make_interval(mins => v_report.estimated_departure_minutes)
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

create or replace function public.get_active_parking_reports()
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
      or now() < report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
  order by report.created_at desc;
$$;

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
