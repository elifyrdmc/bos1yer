begin;

-- Re-assert the RPC-only write boundary in case the earlier column grants were
-- applied to the development project and survived a schema refresh.
drop policy if exists parking_reports_insert_own
  on public.parking_reports;

revoke insert on table public.parking_reports
  from public, anon, authenticated;

-- Normal report creation remains available through the validated RPC. The
-- development project may have a slightly different argument type or an
-- additional optional argument, so handle every public overload by identity
-- instead of hard-coding one signature here.
do $$
declare
  function_identity text;
begin
  for function_identity in
    select p.oid::regprocedure::text
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_parking_report'
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated',
      function_identity
    );
    execute format(
      'grant execute on function %s to authenticated',
      function_identity
    );
  end loop;
end;
$$;

commit;
