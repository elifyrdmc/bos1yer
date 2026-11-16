begin;

-- The map may show an aggregate trust score for the author of a live report.
-- Keep the calculation in the private schema so clients cannot choose a user
-- id or read the underlying feedback rows directly.
create or replace function app_private.get_report_author_trust_summary(
  p_user_id uuid
)
returns table (
  score numeric,
  qualifying_outcome_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with positive_events as (
    select
      report.id as report_id,
      min(feedback.created_at) as occurred_at,
      'positive'::text as outcome
    from public.parking_reports as report
    join public.parking_report_feedback as feedback
      on feedback.report_id = report.id
     and feedback.user_id <> report.author_id
     and feedback.outcome = 'parked'
     and (report.kind <> 'leaving'
       or feedback.created_at >= report.created_at
         + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
    where report.author_id = p_user_id
      and report.cancelled_at is null
    group by report.id
  ),
  negative_events as (
    select
      report.id as report_id,
      report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
        as occurred_at,
      'negative'::text as outcome
    from public.parking_reports as report
    where report.author_id = p_user_id
      and report.kind = 'leaving'
      and report.leaving_presence = 'nearby'
      and report.photo_object_path is null
      and report.cancelled_at is null
      and report.resolved_at is null
      and now() >= report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
  ),
  ordered_events as (
    select
      events.report_id,
      events.occurred_at,
      events.outcome,
      row_number() over (
        order by events.occurred_at, events.report_id, events.outcome
      ) as event_number
    from (
      select * from positive_events
      union all
      select * from negative_events
    ) as events
  ),
  totals as (
    select
      count(*)::integer as outcome_count,
      coalesce(sum(
        case
          when event_number <= 4 and outcome = 'positive' then 1::numeric
          when event_number <= 4 then -0.5::numeric
          when outcome = 'positive' then 0.5::numeric
          else -0.5::numeric
        end
      ) filter (where event_number <= 4), 0::numeric) as initial_score,
      coalesce(sum(
        case when outcome = 'positive' then 0.5::numeric else -0.5::numeric end
      ) filter (where event_number > 4), 0::numeric) as later_delta
    from ordered_events
  )
  select
    case when totals.outcome_count < 4 then null::numeric
      else least(
        5::numeric,
        greatest(
          0::numeric,
          least(5::numeric, greatest(0::numeric, totals.initial_score))
            + totals.later_delta
        )
      )
    end,
    totals.outcome_count
  from totals;
$$;

revoke all on function app_private.get_report_author_trust_summary(uuid)
  from public, anon, authenticated;

-- The return shape is changing, so replace the old zero-argument RPC instead
-- of using CREATE OR REPLACE (Postgres does not allow changing OUT columns).
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
  can_upload_photo boolean,
  author_trust_score numeric,
  author_trust_outcome_count integer
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
    report.author_id = (select auth.uid()),
    trust.score,
    trust.qualifying_outcome_count
  from public.parking_reports as report
  left join lateral app_private.get_report_author_trust_summary(report.author_id)
    as trust on true
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

commit;
