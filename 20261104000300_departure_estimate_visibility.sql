begin;

-- A leaving report stays visible for its ETA plus the normal ten-minute
-- observation window. Vacancy reports keep their existing ten-minute life.
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
    and now() < report.created_at + interval '10 minutes'
      + case
          when report.kind = 'leaving'
          then make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
          else interval '0 minutes'
        end
    and (report.kind <> 'vacancy' or report.resolved_at is null)
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
    select 1
    from public.parking_reports as report
    where report.id = p_report_id
      and now() < report.created_at + interval '10 minutes'
        + case
            when report.kind = 'leaving'
            then make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
            else interval '0 minutes'
          end
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
     from public.parking_reports as report
     where report.id = p_report_id)
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id;
end;
$$;

revoke all on function public.get_parking_report_feedback(uuid)
  from public, anon, authenticated;
grant execute on function public.get_parking_report_feedback(uuid)
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
  v_estimated_departure_minutes smallint;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;

  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes
    into v_kind, v_created_at, v_resolved_at,
         v_estimated_departure_minutes
  from public.parking_reports as report
  where report.id = p_report_id
  for update;

  if not found
     or (v_kind = 'vacancy' and v_resolved_at is not null)
     or (
       now() >= v_created_at + interval '10 minutes'
       and (
         v_kind <> 'leaving'
         or now() >= v_created_at + interval '10 minutes'
           + (coalesce(v_estimated_departure_minutes, 0) * interval '1 minute')
       )
     ) then
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
