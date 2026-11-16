begin;

-- Add a separate GPS origin to report creation. The report coordinates remain
-- the selected vehicle/parking point; the origin is used to limit accidental
-- or implausible remote placement. Follow-up photos keep the existing 30 m
-- server-side check in attach_leaving_report_photo.
drop function if exists public.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
);
drop function if exists app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint, text
);

create function app_private.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null,
  p_leaving_presence text default null,
  p_device_latitude double precision default null,
  p_device_longitude double precision default null
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
  v_radius_meters double precision;
  v_report_location extensions.geography;
  v_device_location extensions.geography;
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
  if p_device_latitude is null or p_device_latitude < -90
     or p_device_latitude > 90 or p_device_longitude is null
     or p_device_longitude < -180 or p_device_longitude > 180 then
    raise exception 'Valid device GPS coordinates are required.';
  end if;
  v_report_location := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude), 4326
  )::extensions.geography;
  v_device_location := extensions.st_setsrid(
    extensions.st_makepoint(p_device_longitude, p_device_latitude), 4326
  )::extensions.geography;

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
    if not extensions.st_dwithin(v_report_location, v_device_location, 30) then
      raise exception 'The photo must be taken within 30 meters of the report.';
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
    if p_leaving_presence = 'nearby' and p_photo_object_path is null then
      v_radius_meters := case p_estimated_departure_minutes
        when 5 then 300
        when 10 then 500
      end;
      if not extensions.st_dwithin(
        v_report_location, v_device_location, v_radius_meters
      ) then
        raise exception 'The selected vehicle location is too far from the current GPS position.';
      end if;
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
      v_report_location,
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
  text, double precision, double precision, text, text, smallint, text,
  double precision, double precision
) from public, anon, authenticated;
grant execute on function app_private.create_parking_report(
  text, double precision, double precision, text, text, smallint, text,
  double precision, double precision
) to authenticated;

create function public.create_parking_report(
  p_kind text,
  p_latitude double precision,
  p_longitude double precision,
  p_note text,
  p_photo_object_path text,
  p_estimated_departure_minutes smallint default null,
  p_leaving_presence text default null,
  p_device_latitude double precision default null,
  p_device_longitude double precision default null
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
    p_kind,
    p_latitude,
    p_longitude,
    p_note,
    p_photo_object_path,
    p_estimated_departure_minutes,
    p_leaving_presence,
    p_device_latitude,
    p_device_longitude
  );
$function$;

revoke all on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint, text,
  double precision, double precision
) from public, anon, authenticated;
grant execute on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint, text,
  double precision, double precision
) to authenticated;

commit;
