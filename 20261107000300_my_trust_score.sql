begin;

-- Trust is separate from reward points. Start each account at 5/5; one
-- confirmed parking report adds 0.5 once per report, and each nearby leaving
-- report that misses its photo deadline subtracts 0.5. The score stays in 0..5.
create function public.get_my_trust_score()
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_parked_reports bigint;
  v_missed_photo_reports bigint;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  select count(*) into v_parked_reports
  from public.parking_reports as report
  where report.author_id = v_user_id
    and report.cancelled_at is null
    and exists (
      select 1
      from public.parking_report_feedback as feedback
      where feedback.report_id = report.id
        and feedback.user_id <> v_user_id
        and feedback.outcome = 'parked'
        and (report.kind <> 'leaving'
          or feedback.created_at >= report.created_at
            + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
    );

  select count(*) into v_missed_photo_reports
  from public.parking_reports as report
  where report.author_id = v_user_id
    and report.kind = 'leaving'
    and report.leaving_presence = 'nearby'
    and report.photo_object_path is null
    and report.cancelled_at is null
    and report.resolved_at is null
    and now() >= report.created_at
      + make_interval(mins => coalesce(report.estimated_departure_minutes, 0));

  return least(
    5::numeric,
    greatest(
      0::numeric,
      5::numeric + 0.5::numeric * (v_parked_reports - v_missed_photo_reports)
    )
  );
end;
$$;

revoke all on function public.get_my_trust_score()
  from public, anon, authenticated;
grant execute on function public.get_my_trust_score()
  to authenticated;

commit;
