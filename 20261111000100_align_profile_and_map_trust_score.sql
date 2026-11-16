begin;

-- The map already reads this private calculation. Keep the existing public
-- RPC signature while making the signed-in profile use the same source.
create or replace function public.get_my_trust_score()
returns table (score numeric, qualifying_outcome_count integer)
language sql
stable
security definer
set search_path = ''
as $$
  select summary.score, summary.qualifying_outcome_count
  from app_private.get_report_author_trust_summary((select auth.uid()))
    as summary
  where (select auth.uid()) is not null;
$$;

revoke all on function public.get_my_trust_score()
  from public, anon, authenticated;
grant execute on function public.get_my_trust_score()
  to authenticated;

commit;
