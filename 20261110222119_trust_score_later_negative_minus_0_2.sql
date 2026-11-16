begin;

-- Keep the first four trust outcomes on the existing calibration. Later
-- confirmed parking adds 0.5, while an expired nearby report without a photo
-- subtracts 0.2. All other outcomes remain neutral.
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
          else -0.2::numeric
        end
      ) filter (where event_number <= 4), 0::numeric) as initial_score,
      coalesce(sum(
        case when outcome = 'positive' then 0.5::numeric else -0.2::numeric end
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

commit;
