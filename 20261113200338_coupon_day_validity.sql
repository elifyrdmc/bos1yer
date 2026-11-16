-- Support one-day coupon terms and add a small demo offer for expiry checks.
begin;

alter table public.reward_offers
  add column if not exists validity_days integer;

alter table public.reward_offers
  drop constraint if exists reward_offers_validity_rule;

alter table public.reward_offers
  add constraint reward_offers_validity_rule check (
    (validity_is_unlimited and validity_months is null and validity_days is null)
    or
    (not validity_is_unlimited and (
      (validity_months > 0 and validity_days is null)
      or (validity_days > 0 and validity_months is null)
    ))
  );

comment on column public.reward_offers.validity_days is
  'Positive day count when validity_is_unlimited is false and validity_months is null.';

insert into public.reward_offers (
  id, partner_name, title, summary, redemption_type, points_cost,
  is_demo, is_active, sort_order, validity_months, validity_days,
  validity_is_unlimited, usage_kind, usage_limit,
  usage_limit_is_unlimited, allow_repeat_purchase,
  agreement_is_open_ended, agreement_ends_at, branch_scope,
  valid_branches, instructions
) values (
  'demo-one-day-coupon', 'BOŞ1YER Demo', '1 Günlük Deneme Kuponu',
  'Kupon süresinin sona ermesini kontrol etmek için örnek teklif.',
  'store_qr', 1, true, true, 4, null, 1, false, 'single_use', 1,
  false, true, true, null, 'not_applicable', '[]'::jsonb,
  'Demo örneği: QR biçimini gösterir; gerçek işletmede kullanılamaz.'
)
on conflict (id) do update set
  partner_name = excluded.partner_name,
  title = excluded.title,
  summary = excluded.summary,
  redemption_type = excluded.redemption_type,
  points_cost = excluded.points_cost,
  is_demo = excluded.is_demo,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  validity_months = excluded.validity_months,
  validity_days = excluded.validity_days,
  validity_is_unlimited = excluded.validity_is_unlimited,
  usage_kind = excluded.usage_kind,
  usage_limit = excluded.usage_limit,
  usage_limit_is_unlimited = excluded.usage_limit_is_unlimited,
  allow_repeat_purchase = excluded.allow_repeat_purchase,
  agreement_is_open_ended = excluded.agreement_is_open_ended,
  agreement_ends_at = excluded.agreement_ends_at,
  branch_scope = excluded.branch_scope,
  valid_branches = excluded.valid_branches,
  instructions = excluded.instructions;

create or replace function public.redeem_reward_offer(p_reward_offer_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_offer public.reward_offers%rowtype;
  v_redemption_id uuid := pg_catalog.gen_random_uuid();
  v_balance bigint;
  v_code text;
  v_issued_at timestamptz := pg_catalog.clock_timestamp();
  v_expires_at timestamptz;
  v_terms_snapshot jsonb;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  select * into v_offer
  from public.reward_offers
  where id = p_reward_offer_id
    and is_active
    and is_demo
    and (agreement_is_open_ended or agreement_ends_at > v_issued_at)
  for share;

  if not found then
    raise exception 'Only active demo offers can be redeemed in this flow.'
      using errcode = '22023';
  end if;

  if not v_offer.allow_repeat_purchase and exists (
    select 1 from public.reward_redemptions
    where user_id = v_user_id and reward_offer_id = v_offer.id
  ) then
    raise exception 'This reward offer cannot be purchased again.' using errcode = '23505';
  end if;

  if v_offer.allow_repeat_purchase and exists (
    select 1 from public.reward_redemptions
    where user_id = v_user_id
      and reward_offer_id = v_offer.id
      and (expires_at is null or expires_at > v_issued_at)
  ) then
    raise exception 'An active coupon for this offer already exists.' using errcode = '23505';
  end if;

  select coalesce(sum(points_delta), 0)::bigint into v_balance
  from public.point_transactions
  where user_id = v_user_id;

  if v_balance < v_offer.points_cost then
    raise exception 'Not enough points.' using errcode = '22023';
  end if;

  if not v_offer.validity_is_unlimited then
    if v_offer.validity_days is not null then
      v_expires_at := v_issued_at + pg_catalog.make_interval(days => v_offer.validity_days);
    else
      v_expires_at := (
        (v_issued_at at time zone 'Europe/Istanbul')
        + pg_catalog.make_interval(months => v_offer.validity_months)
      ) at time zone 'Europe/Istanbul';
    end if;
  end if;

  v_code := 'BY-' || upper(substr(replace(v_redemption_id::text, '-', ''), 1, 12));
  v_terms_snapshot := jsonb_build_object(
    'legacy_terms', false,
    'redemption_type', v_offer.redemption_type,
    'validity_is_unlimited', v_offer.validity_is_unlimited,
    'validity_months', v_offer.validity_months,
    'validity_days', v_offer.validity_days,
    'usage_kind', v_offer.usage_kind,
    'usage_limit', v_offer.usage_limit,
    'usage_limit_is_unlimited', v_offer.usage_limit_is_unlimited,
    'allow_repeat_purchase', v_offer.allow_repeat_purchase,
    'agreement_is_open_ended', v_offer.agreement_is_open_ended,
    'agreement_ends_at', v_offer.agreement_ends_at,
    'branch_scope', v_offer.branch_scope,
    'valid_branches', v_offer.valid_branches,
    'instructions', v_offer.instructions,
    'is_demo', v_offer.is_demo
  );

  insert into public.reward_redemptions (
    id, user_id, reward_offer_id, points_cost, redemption_type, code,
    created_at, offer_title_snapshot, partner_name_snapshot,
    summary_snapshot, terms_snapshot, expires_at
  ) values (
    v_redemption_id, v_user_id, v_offer.id, v_offer.points_cost,
    v_offer.redemption_type, v_code, v_issued_at, v_offer.title,
    v_offer.partner_name, v_offer.summary, v_terms_snapshot, v_expires_at
  );

  insert into public.point_transactions (
    user_id, report_id, feedback_id, reward_redemption_id,
    idempotency_key, event_type, points_delta, description
  ) values (
    v_user_id, null, null, v_redemption_id,
    'reward:' || v_redemption_id::text,
    'reward_redemption', -v_offer.points_cost,
    case when v_offer.is_demo then 'Demo kupon puan kullanımı · '
         else 'Kupon puan kullanımı · ' end || v_offer.title
  );

  return jsonb_build_object(
    'id', v_redemption_id,
    'offer_id', v_offer.id,
    'title', v_offer.title,
    'partner_name', v_offer.partner_name,
    'summary', v_offer.summary,
    'points', v_offer.points_cost,
    'code', v_code,
    'redemption_type', v_offer.redemption_type,
    'created_at', v_issued_at,
    'expires_at', v_expires_at,
    'terms_snapshot', v_terms_snapshot,
    'coupon_status', 'active'
  );
end;
$$;

commit;
