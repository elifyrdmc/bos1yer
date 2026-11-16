begin;

-- Feedback is only actionable after the leaving driver's ETA (green phase).
-- Any responses collected earlier by the previous client are invalid and are
-- removed for still-active leaving reports so they cannot block a later answer.
delete from public.parking_report_feedback as feedback
using public.parking_reports as report
where feedback.report_id = report.id
  and report.kind = 'leaving'
  and feedback.created_at < report.created_at
    + make_interval(mins => coalesce(report.estimated_departure_minutes, 0));

-- Resolved reports of either kind must disappear from every active map.
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
    and report.resolved_at is null
    and (report.kind <> 'leaving'
      or report.leaving_presence <> 'nearby'
      or report.photo_object_path is not null
      or now() < report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
  order by report.created_at desc;
$$;

revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports()
  to authenticated;

drop function if exists public.submit_parking_report_feedback(uuid, text);
drop function if exists public.get_parking_report_feedback(uuid);

create function public.get_parking_report_feedback(
  p_report_id uuid,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null
)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean,
  feedback_open boolean,
  is_author boolean,
  is_nearby boolean,
  is_resolved boolean
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
  v_author_id uuid;
  v_feedback_open boolean;
  v_feedback_start timestamptz;
  v_nearby boolean := false;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes, report.leaving_presence,
         report.photo_object_path, report.author_id
    into v_kind, v_created_at, v_resolved_at, v_estimate, v_presence,
         v_photo_path, v_author_id
  from public.parking_reports as report
  where report.id = p_report_id;
  if not found or now() >= v_created_at + interval '10 minutes'
      + make_interval(mins => coalesce(v_estimate, 0)) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  v_feedback_start := v_created_at + make_interval(
    mins => case when v_kind = 'leaving' then coalesce(v_estimate, 0) else 0 end
  );
  v_feedback_open := v_resolved_at is null
    and now() >= v_feedback_start
    and now() < v_created_at + interval '10 minutes'
      + make_interval(mins => coalesce(v_estimate, 0))
    and (v_kind <> 'leaving' or v_presence <> 'nearby'
      or v_photo_path is not null);
  v_nearby := p_latitude is not null and p_longitude is not null
    and p_accuracy_meters is not null
    and p_accuracy_meters > 0 and p_accuracy_meters <= 30
    and p_latitude between -90 and 90
    and p_longitude between -180 and 180
    and extensions.st_dwithin(
      (select report.location from public.parking_reports as report
       where report.id = p_report_id),
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude), 4326
      )::extensions.geography,
      30
    );

  return query
  select
    count(*) filter (where feedback.outcome = 'parked'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    count(*) filter (where feedback.outcome = 'occupied'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    count(*) filter (where feedback.outcome = 'not_found'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    max(feedback.outcome) filter (where feedback.user_id = v_user_id
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    v_feedback_open and v_author_id <> v_user_id and v_nearby
      and not exists (
        select 1 from public.parking_report_feedback as mine
        where mine.report_id = p_report_id and mine.user_id = v_user_id
          and (v_kind <> 'leaving' or mine.created_at >= v_feedback_start)
      ),
    v_feedback_open,
    v_author_id = v_user_id,
    v_nearby,
    v_resolved_at is not null
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id;
end;
$$;

create function public.submit_parking_report_feedback(
  p_report_id uuid,
  p_outcome text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision
)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean,
  feedback_open boolean,
  is_author boolean,
  is_nearby boolean,
  is_resolved boolean
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
  v_author_id uuid;
  v_feedback_start timestamptz;
  v_not_found_count bigint;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;
  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes, report.leaving_presence,
         report.photo_object_path, report.author_id
    into v_kind, v_created_at, v_resolved_at, v_estimate, v_presence,
         v_photo_path, v_author_id
  from public.parking_reports as report
  where report.id = p_report_id
  for update;
  if not found then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  v_feedback_start := v_created_at + make_interval(
    mins => case when v_kind = 'leaving' then coalesce(v_estimate, 0) else 0 end
  );
  if v_resolved_at is not null
     or now() >= v_created_at + interval '10 minutes'
       + make_interval(mins => coalesce(v_estimate, 0))
     or now() < v_feedback_start
     or (v_kind = 'leaving' and v_presence = 'nearby'
       and v_photo_path is null) then
    raise exception 'Feedback is not open for this report.'
      using errcode = 'P0002';
  end if;
  if v_author_id = v_user_id then
    raise exception 'Report creators cannot submit feedback.'
      using errcode = '42501';
  end if;
  if p_latitude is null or p_longitude is null
     or p_accuracy_meters is null or p_accuracy_meters <= 0
     or p_accuracy_meters > 30
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180
     or not extensions.st_dwithin(
       (select report.location from public.parking_reports as report
        where report.id = p_report_id),
       extensions.st_setsrid(
         extensions.st_makepoint(p_longitude, p_latitude), 4326
       )::extensions.geography,
       30
     ) then
    raise exception 'Feedback requires a fresh GPS location within 30 meters.'
      using errcode = '42501';
  end if;
  if exists (
    select 1 from public.parking_report_feedback as feedback
    where feedback.report_id = p_report_id and feedback.user_id = v_user_id
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)
  ) then
    raise exception 'A response was already submitted for this report.'
      using errcode = '23505';
  end if;

  insert into public.parking_report_feedback (report_id, user_id, outcome)
  values (p_report_id, v_user_id, p_outcome);

  if p_outcome in ('parked', 'occupied') then
    update public.parking_reports set resolved_at = now()
    where id = p_report_id;
  elsif p_outcome = 'not_found' then
    select count(*) into v_not_found_count
    from public.parking_report_feedback as feedback
    where feedback.report_id = p_report_id
      and feedback.outcome = 'not_found'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start);
    if v_not_found_count >= 2 then
      update public.parking_reports set resolved_at = now()
      where id = p_report_id;
    end if;
  end if;

  return query select * from public.get_parking_report_feedback(
    p_report_id, p_latitude, p_longitude, p_accuracy_meters
  );
end;
$$;

revoke all on function public.get_parking_report_feedback(
  uuid, double precision, double precision, double precision
) from public, anon, authenticated;
grant execute on function public.get_parking_report_feedback(
  uuid, double precision, double precision, double precision
) to authenticated;
revoke all on function public.submit_parking_report_feedback(
  uuid, text, double precision, double precision, double precision
) from public, anon, authenticated;
grant execute on function public.submit_parking_report_feedback(
  uuid, text, double precision, double precision, double precision
) to authenticated;

commit;
