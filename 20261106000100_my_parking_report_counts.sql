begin;

-- Expose only aggregate counts for the signed-in user's own reports.
-- Report ownership and report rows remain private from client queries.
create function public.get_my_parking_report_counts()
returns jsonb
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

  return jsonb_build_object(
    'vacancy_count',
    (
      select count(*)
      from public.parking_reports as report
      where report.author_id = v_user_id
        and report.kind = 'vacancy'
    ),
    'leaving_count',
    (
      select count(*)
      from public.parking_reports as report
      where report.author_id = v_user_id
        and report.kind = 'leaving'
    )
  );
end;
$$;

revoke all on function public.get_my_parking_report_counts()
  from public, anon, authenticated;
grant execute on function public.get_my_parking_report_counts()
  to authenticated;

commit;
