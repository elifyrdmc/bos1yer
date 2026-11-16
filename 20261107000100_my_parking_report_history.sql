begin;

-- Preserve explicit owner cancellations separately from report outcomes.
alter table public.parking_reports
  add column if not exists cancelled_at timestamptz;

-- Return only the signed-in user's own report history. Raw report rows stay
-- private; this narrow RPC exposes the fields needed by the profile screen.
create function public.get_my_parking_report_history(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  kind text,
  created_at timestamptz,
  note text,
  estimated_departure_minutes smallint,
  status text,
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  if coalesce(p_offset, 0) < 0 then
    raise exception 'Offset must not be negative.' using errcode = '22023';
  end if;

  return query
  select
    report.id,
    report.kind,
    report.created_at,
    report.note,
    report.estimated_departure_minutes,
    case
      when report.cancelled_at is not null then 'cancelled'
      when report.resolved_at is not null
        and coalesce(feedback.parked_count, 0) > 0 then 'parked'
      when report.resolved_at is not null
        and coalesce(feedback.occupied_count, 0) > 0 then 'occupied'
      when now() < report.created_at + interval '10 minutes'
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
        then 'active'
      when coalesce(feedback.parked_count, 0)
        + coalesce(feedback.occupied_count, 0)
        + coalesce(feedback.not_found_count, 0) > 0 then 'feedback'
      else 'expired'
    end,
    coalesce(feedback.parked_count, 0),
    coalesce(feedback.occupied_count, 0),
    coalesce(feedback.not_found_count, 0)
  from public.parking_reports as report
  left join lateral (
    select
      count(*) filter (where response.outcome = 'parked') as parked_count,
      count(*) filter (where response.outcome = 'occupied') as occupied_count,
      count(*) filter (where response.outcome = 'not_found') as not_found_count
    from public.parking_report_feedback as response
    where response.report_id = report.id
      and (report.kind <> 'leaving'
        or response.created_at >= report.created_at
          + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
  ) as feedback on true
  where report.author_id = v_user_id
  order by report.created_at desc, report.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset coalesce(p_offset, 0);
end;
$$;

revoke all on function public.get_my_parking_report_history(integer, integer)
  from public, anon, authenticated;
grant execute on function public.get_my_parking_report_history(integer, integer)
  to authenticated;

commit;
