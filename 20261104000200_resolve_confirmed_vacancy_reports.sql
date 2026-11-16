begin;

-- A vacancy is removed from every active map after a driver confirms that it
-- was parked in or already occupied. Leaving reports remain active until their
-- normal ten-minute expiry.
alter table public.parking_reports
  add column resolved_at timestamptz;

comment on column public.parking_reports.resolved_at is
  'Set when a driver confirms a vacancy report is no longer available.';

-- Keep the public RPC response unchanged while hiding resolved vacancies.
-- SECURITY DEFINER is needed because resolved_at is intentionally not exposed
-- through direct client table grants; this function returns only map-safe data.
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
  estimated_departure_minutes smallint
)
language sql
stable
security definer
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
  where auth.uid() is not null
    and report.created_at > (now() - interval '10 minutes')
    and (report.kind <> 'vacancy' or report.resolved_at is null)
  order by report.created_at desc;
$$;

revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports()
  to authenticated;

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
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;

  -- Serialize feedback against the report row so a second confirmation can't
  -- race with the first one and leave a resolved report on another map.
  select report.kind, report.created_at, report.resolved_at
    into v_kind, v_created_at, v_resolved_at
  from public.parking_reports as report
  where report.id = p_report_id
  for update;

  if not found
     or v_created_at <= (now() - interval '10 minutes')
     or (v_kind = 'vacancy' and v_resolved_at is not null) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.parking_reports as report
    where report.id = p_report_id
      and report.author_id = v_user_id
  ) then
    raise exception 'Report creators cannot submit feedback.'
      using errcode = '42501';
  end if;

  insert into public.parking_report_feedback (report_id, user_id, outcome)
  values (p_report_id, v_user_id, p_outcome);

  -- A driver outcome closes only an available-space report. "Bulamadım" is
  -- inconclusive, and feedback on a "Çıkıyorum" report never closes it.
  if v_kind = 'vacancy' and p_outcome in ('parked', 'occupied') then
    update public.parking_reports
    set resolved_at = now()
    where id = p_report_id;
  end if;

  return query
  select * from public.get_parking_report_feedback(p_report_id);
end;
$$;

revoke all on function public.submit_parking_report_feedback(uuid, text)
  from public, anon, authenticated;
grant execute on function public.submit_parking_report_feedback(uuid, text)
  to authenticated;

commit;
