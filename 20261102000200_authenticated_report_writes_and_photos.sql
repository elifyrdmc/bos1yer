begin;

alter table public.parking_reports
  add column if not exists estimated_departure_minutes smallint;

alter table public.parking_reports
  drop constraint if exists parking_reports_estimated_departure_minutes_check;
alter table public.parking_reports
  add constraint parking_reports_estimated_departure_minutes_check
  check (estimated_departure_minutes is null or estimated_departure_minutes in (5, 10));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'parking-report-photos',
  'parking-report-photos',
  false,
  8388608,
  array['image/jpeg']::text[]
)
on conflict (id) do nothing;

create policy parking_report_photos_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'parking-report-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy parking_report_photos_select_active
  on storage.objects for select to authenticated
  using (
    bucket_id = 'parking-report-photos'
    and exists (
      select 1
      from public.parking_reports as report
      where report.photo_object_path = storage.objects.name
        and report.created_at > (now() - interval '10 minutes')
    )
  );

create policy parking_report_photos_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'parking-report-photos'
    and owner_id = (select auth.uid()::text)
  );

grant insert (
  author_id,
  kind,
  location,
  note,
  photo_object_path,
  estimated_departure_minutes
) on table public.parking_reports to authenticated;

grant select (
  id,
  kind,
  location,
  created_at,
  note,
  photo_object_path,
  estimated_departure_minutes
) on table public.parking_reports to authenticated;

create policy parking_reports_insert_own
  on public.parking_reports for insert to authenticated
  with check (
    (select auth.uid()) = author_id
    and photo_object_path is not null
    and photo_object_path like ((select auth.uid()::text) || '/%')
  );

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
  estimated_departure_minutes smallint
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
      as age_seconds,
    report.note,
    report.photo_object_path,
    report.estimated_departure_minutes
  from public.parking_reports as report
  where report.created_at > (now() - interval '10 minutes')
  order by report.created_at desc;
$$;

revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports() to authenticated;

create function public.create_parking_report(
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
security invoker
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

revoke all on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint
) from public, anon, authenticated;
grant execute on function public.create_parking_report(
  text, double precision, double precision, text, text, smallint
) to authenticated;

commit;
