begin;

-- Keep historical ledger entries from the previous amounts valid. New awards
-- are written with the updated values by the replaced trigger function below.
alter table public.point_transactions
  drop constraint point_transactions_known_awards_only;

alter table public.point_transactions
  add constraint point_transactions_known_awards_only check (
    (event_type = 'report_parked_author_reward' and points_delta in (10, 20))
    or
    (event_type = 'parked_confirmation_reward' and points_delta in (2, 10))
  );

create or replace function app_private.award_points_for_parked_feedback()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report_author_id uuid;
  v_report_kind text;
begin
  if new.outcome <> 'parked' then
    return new;
  end if;

  select report.author_id, report.kind
    into v_report_author_id, v_report_kind
  from public.parking_reports as report
  where report.id = new.report_id;

  if not found
     or v_report_author_id = new.user_id
     or v_report_kind not in ('vacancy', 'leaving') then
    return new;
  end if;

  -- The report author receives one award per report, even if multiple drivers
  -- confirm a leaving report. Keep the existing deterministic key unchanged.
  insert into public.point_transactions (
    user_id,
    report_id,
    feedback_id,
    idempotency_key,
    event_type,
    points_delta,
    description
  ) values (
    v_report_author_id,
    new.report_id,
    new.id,
    'report:' || new.report_id::text || ':parked-author',
    'report_parked_author_reward',
    20,
    'Başka bir sürücü bildiriminle park etti'
  )
  on conflict do nothing;

  insert into public.point_transactions (
    user_id,
    report_id,
    feedback_id,
    idempotency_key,
    event_type,
    points_delta,
    description
  ) values (
    new.user_id,
    new.report_id,
    new.id,
    'feedback:' || new.id::text || ':parked-confirmation',
    'parked_confirmation_reward',
    10,
    'Park ettim bildirimi'
  )
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function app_private.award_points_for_parked_feedback()
  from public, anon, authenticated;

commit;
