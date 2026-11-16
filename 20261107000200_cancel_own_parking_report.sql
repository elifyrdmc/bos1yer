begin;

-- Only the report owner may cancel their still-active report. Setting both
-- timestamps closes feedback and removes it from the active map immediately.
create function public.cancel_my_parking_report(p_report_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_report public.parking_reports%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  select report.* into v_report
  from public.parking_reports as report
  where report.id = p_report_id
    and report.author_id = v_user_id
  for update;

  if not found then
    raise exception 'Report not found or not owned by this account.'
      using errcode = 'P0002';
  end if;

  if v_report.cancelled_at is not null then
    return;
  end if;

  if v_report.resolved_at is not null
     or now() >= v_report.created_at + interval '10 minutes'
       + make_interval(mins => coalesce(v_report.estimated_departure_minutes, 0))
     or (v_report.kind = 'leaving'
       and v_report.leaving_presence = 'nearby'
       and v_report.photo_object_path is null
       and now() >= v_report.created_at
         + make_interval(mins => coalesce(v_report.estimated_departure_minutes, 0))) then
    raise exception 'This report is no longer active.' using errcode = 'P0002';
  end if;

  update public.parking_reports
  set cancelled_at = now(),
      resolved_at = now()
  where id = p_report_id;
end;
$$;

revoke all on function public.cancel_my_parking_report(uuid)
  from public, anon, authenticated;
grant execute on function public.cancel_my_parking_report(uuid)
  to authenticated;

commit;
