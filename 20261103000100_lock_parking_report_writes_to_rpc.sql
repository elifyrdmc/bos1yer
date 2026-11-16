begin;

-- Migration 002 grants column-level INSERT access so its SECURITY INVOKER RPC
-- can write reports. That also lets authenticated clients bypass the RPC's
-- validation with direct table inserts. Keep the privileged helper outside
-- PostgREST's exposed schemas and make the public RPC an invoker wrapper.
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;

create or replace function app_private.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null
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
  estimated_departure_minutes smallint
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
  if p_photo_object_path is null
     or p_photo_object_path not like ((select auth.uid()::text) || '/%') then
    raise exception 'A photo uploaded by the signed-in user is required.';
  end if;
  if not exists (
    select 1
    from storage.objects as photo
    where photo.bucket_id = 'parking-report-photos'
      and photo.name = p_photo_object_path
      and photo.owner_id = (select auth.uid()::text)
  ) then
    raise exception 'The report photo must exist in the user''s private bucket.';
  end if;
  if p_note is not null and char_length(p_note) > 300 then
    raise exception 'The parking report note is too long.';
  end if;
  if p_kind = 'leaving'
     and (p_estimated_departure_minutes is null
          or p_estimated_departure_minutes not in (5, 10)) then
    raise exception 'Leaving reports require a 5 or 10 minute estimate.';
  end if;
  if p_kind = 'vacancy' and p_estimated_departure_minutes is not null then
    raise exception 'Vacancy reports cannot have a departure estimate.';
  end if;

  return query
    insert into public.parking_reports (
      author_id,
      kind,
      location,
      note,
      photo_object_path,
      estimated_departure_minutes
    )
    values (
      (select auth.uid()),
      p_kind,
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude),
        4326
      )::extensions.geography,
      nullif(btrim(p_note), ''),
      p_photo_object_path,
      p_estimated_departure_minutes
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
      parking_reports.estimated_departure_minutes;
end;
$function$;

revoke all on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint
) from public, anon, authenticated;
grant execute on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint
) to authenticated;

comment on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint
) is
  'Private privileged implementation for the public invoker RPC. Keep app_private outside PostgREST exposed schemas; validates auth.uid(), coordinates, report fields, and owned photo object.';

create or replace function public.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null
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
  estimated_departure_minutes smallint
)
language sql
security invoker
set search_path = ''
as $function$
  select *
  from app_private.create_parking_report(
    p_kind,
    p_latitude,
    p_longitude,
    p_note,
    p_photo_object_path,
    p_estimated_departure_minutes
  );
$function$;

revoke insert (
  author_id,
  kind,
  location,
  note,
  photo_object_path,
  estimated_departure_minutes
) on table public.parking_reports from anon, authenticated;

-- Keep a future accidental INSERT grant from re-enabling direct writes.
drop policy if exists parking_reports_insert_own
  on public.parking_reports;

revoke all on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint
) from public, anon, authenticated;
grant execute on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint
) to authenticated;

comment on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint
) is
  'Authenticated invoker RPC that delegates validated insertion to app_private.create_parking_report.';

commit;
