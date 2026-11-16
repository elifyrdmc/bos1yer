begin;

-- Active reports are exposed through get_active_parking_reports(), which
-- returns only the short-lived fields the map needs. Do not allow clients to
-- query public.parking_reports directly: that table contains private author,
-- note and photo-object data, and table grants are separate from RLS rules.
drop policy if exists parking_reports_read_active_map
  on public.parking_reports;

revoke select on table public.parking_reports
  from public, anon, authenticated;

comment on table public.parking_reports is
  'Short-lived map contributions. Client reads must use get_active_parking_reports(); direct table reads are disabled.';

-- Keep the safe map projection as the only client read path.
revoke all on function public.get_active_parking_reports()
  from public, anon, authenticated;
grant execute on function public.get_active_parking_reports()
  to authenticated;

commit;
