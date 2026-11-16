begin;

-- Points are a server-owned ledger. Clients read a restricted projection
-- through the own-account RPC below; they never access the ledger directly.
create table public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  report_id uuid not null,
  feedback_id uuid not null,
  idempotency_key text not null unique,
  event_type text not null
    check (event_type in (
      'report_parked_author_reward',
      'parked_confirmation_reward'
    )),
  points_delta integer not null,
  description text not null,
  created_at timestamptz not null default now(),
  constraint point_transactions_feedback_event_once
    unique (feedback_id, event_type),
  constraint point_transactions_known_awards_only check (
    (event_type = 'report_parked_author_reward' and points_delta = 10)
    or
    (event_type = 'parked_confirmation_reward' and points_delta = 2)
  )
);

comment on table public.point_transactions is
  'Server-owned points ledger. The balance is the sum of points_delta.';
comment on column public.point_transactions.idempotency_key is
  'Generated only by the database: one author award per report and one confirmer award per feedback.';
comment on column public.point_transactions.report_id is
  'Source report UUID retained as an audit reference without cascading ledger history.';
comment on column public.point_transactions.feedback_id is
  'Source feedback UUID retained as an audit reference without cascading ledger history.';

create index point_transactions_user_created_idx
  on public.point_transactions (user_id, created_at desc, id desc);

alter table public.point_transactions enable row level security;
revoke all on table public.point_transactions from public, anon, authenticated;

-- Defense in depth if direct SELECT is intentionally granted in a future
-- migration: an account can only see its own ledger rows.
create policy point_transactions_read_own
  on public.point_transactions for select to authenticated
  using ((select auth.uid()) = user_id);

-- Positive points are granted only when another authenticated driver submits
-- a valid "parked" outcome through the existing feedback RPC. This trigger
-- adds both awards in the same transaction as the feedback row.
create function app_private.award_points_for_parked_feedback()
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

  -- A report author receives this award once per report, even if multiple
  -- drivers submit a parked outcome on a leaving report.
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
    10,
    'Başka bir sürücü bildiriminle park etti'
  )
  on conflict do nothing;

  -- A driver can receive this confirmation award only once for this feedback.
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
    2,
    'Park ettim bildirimi'
  )
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function app_private.award_points_for_parked_feedback()
  from public, anon, authenticated;

create trigger parking_feedback_award_points
after insert on public.parking_report_feedback
for each row execute function app_private.award_points_for_parked_feedback();

-- The client gets a single read-only response: full balance plus a bounded
-- recent history. No balance-changing RPC is exposed to authenticated users.
create function public.get_my_points_wallet(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'balance', coalesce(
      (
        select sum(entry.points_delta)::bigint
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      0::bigint
    ),
    'transactions', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', recent.id,
            'points_delta', recent.points_delta,
            'event_type', recent.event_type,
            'description', recent.description,
            'created_at', recent.created_at
          ) order by recent.created_at desc, recent.id desc
        )
        from (
          select
            entry.id,
            entry.points_delta,
            entry.event_type,
            entry.description,
            entry.created_at
          from public.point_transactions as entry
          where entry.user_id = v_user_id
          order by entry.created_at desc, entry.id desc
          limit v_limit
        ) as recent
      ),
      '[]'::jsonb
    )
  );
end;
$$;

revoke all on function public.get_my_points_wallet(integer)
  from public, anon, authenticated;
grant execute on function public.get_my_points_wallet(integer)
  to authenticated;

commit;
