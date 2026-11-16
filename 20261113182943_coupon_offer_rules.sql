-- Add explicit business-configurable coupon terms and immutable issuance snapshots.
-- This migration prepares the schema only; it does not create merchant validation.

begin;

alter table public.reward_offers
  add column if not exists validity_months integer,
  add column if not exists validity_is_unlimited boolean not null default true,
  add column if not exists usage_kind text not null default 'single_use',
  add column if not exists usage_limit integer not null default 1,
  add column if not exists usage_limit_is_unlimited boolean not null default false,
  add column if not exists allow_repeat_purchase boolean not null default false,
  add column if not exists agreement_is_open_ended boolean not null default true,
  add column if not exists agreement_ends_at timestamptz,
  add column if not exists branch_scope text not null default 'not_applicable',
  add column if not exists valid_branches jsonb not null default '[]'::jsonb,
  add column if not exists instructions text not null default 'Kullanım talimatı henüz eklenmedi.';

-- The unlimited-use demo offer stores a NULL limit, so relax the old
-- NOT NULL constraint before seeding the offer examples below.
alter table public.reward_offers
  alter column usage_limit drop not null;

update public.reward_offers
set validity_months = 5,
    validity_is_unlimited = false,
    usage_kind = 'single_use',
    usage_limit = 1,
    usage_limit_is_unlimited = false,
    allow_repeat_purchase = true,
    branch_scope = 'all_branches',
    valid_branches = '[]'::jsonb,
    instructions = 'Demo örneği: QR biçimini gösterir; gerçek işletmede kullanılamaz.'
where id = 'demo-store-qr' and is_demo;

update public.reward_offers
set validity_months = 7,
    validity_is_unlimited = false,
    usage_kind = 'multi_use',
    usage_limit = 3,
    usage_limit_is_unlimited = false,
    allow_repeat_purchase = true,
    branch_scope = 'not_applicable',
    valid_branches = '[]'::jsonb,
    instructions = 'Demo örneği: çevrimiçi kod biçimini gösterir; gerçek işletmede kullanılamaz.'
where id = 'demo-online-code' and is_demo;

update public.reward_offers
set validity_months = null,
    validity_is_unlimited = true,
    usage_kind = 'multi_use',
    usage_limit = null,
    usage_limit_is_unlimited = true,
    allow_repeat_purchase = true,
    branch_scope = 'not_applicable',
    valid_branches = '[]'::jsonb,
    instructions = 'Demo örneği: kampanya bağlantısı biçimini gösterir; gerçek işletmede kullanılamaz.'
where id = 'demo-campaign-link' and is_demo;

alter table public.reward_offers
  alter column validity_is_unlimited drop default,
  alter column usage_kind drop default,
  alter column usage_limit drop default,
  alter column usage_limit_is_unlimited drop default,
  alter column allow_repeat_purchase drop default,
  alter column agreement_is_open_ended drop default,
  alter column branch_scope drop default,
  alter column valid_branches drop default,
  alter column instructions drop default;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reward_offers'::regclass
      and conname = 'reward_offers_agreement_term_rule'
  ) then
    alter table public.reward_offers
      add constraint reward_offers_agreement_term_rule check (
        (agreement_is_open_ended and agreement_ends_at is null)
        or
        (not agreement_is_open_ended and agreement_ends_at is not null)
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reward_offers'::regclass
      and conname = 'reward_offers_validity_rule'
  ) then
    alter table public.reward_offers
      add constraint reward_offers_validity_rule check (
        (validity_is_unlimited and validity_months is null)
        or
        (not validity_is_unlimited and validity_months > 0)
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reward_offers'::regclass
      and conname = 'reward_offers_usage_rule'
  ) then
    alter table public.reward_offers
      add constraint reward_offers_usage_rule check (
        (usage_kind = 'single_use'
          and usage_limit = 1
          and not usage_limit_is_unlimited)
        or
        (usage_kind = 'multi_use'
          and (
            (usage_limit_is_unlimited and usage_limit is null)
            or
            (not usage_limit_is_unlimited and usage_limit > 0)
          ))
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reward_offers'::regclass
      and conname = 'reward_offers_branch_rule'
  ) then
    alter table public.reward_offers
      add constraint reward_offers_branch_rule check (
        (branch_scope = 'selected_branches'
          and redemption_type = 'store_qr'
          and jsonb_typeof(valid_branches) = 'array'
          and jsonb_array_length(valid_branches) > 0)
        or
        (branch_scope in ('all_branches', 'not_applicable')
          and valid_branches = '[]'::jsonb)
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.reward_offers'::regclass
      and conname = 'reward_offers_rule_values'
  ) then
    alter table public.reward_offers
      add constraint reward_offers_rule_values check (
        usage_kind in ('single_use', 'multi_use')
        and branch_scope in ('all_branches', 'selected_branches', 'not_applicable')
        and length(btrim(instructions)) > 0
      );
  end if;
end;
$$;

comment on column public.reward_offers.validity_months is
  'Positive calendar-month count when validity_is_unlimited is false.';
comment on column public.reward_offers.validity_is_unlimited is
  'Explicitly distinguishes unlimited validity from a missing month count.';
comment on column public.reward_offers.usage_limit_is_unlimited is
  'For multi-use offers, explicitly distinguishes unlimited uses from a numeric limit.';
comment on column public.reward_offers.valid_branches is
  'JSON array of business-provided branch labels/addresses when branch_scope is selected_branches.';
comment on column public.reward_offers.agreement_ends_at is
  'Fixed merchant agreement end; new purchases stop at this instant, while issued coupons keep their snapshotted validity.';

alter table public.reward_redemptions
  add column if not exists offer_title_snapshot text,
  add column if not exists partner_name_snapshot text,
  add column if not exists summary_snapshot text,
  add column if not exists terms_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists expires_at timestamptz;

update public.reward_redemptions as redemption
set offer_title_snapshot = offer.title,
    partner_name_snapshot = offer.partner_name,
    summary_snapshot = offer.summary,
    terms_snapshot = jsonb_build_object(
      'legacy_terms', true,
      'validity_is_unlimited', true,
      'validity_months', null,
      'usage_kind', 'single_use',
      'usage_limit', 1,
      'usage_limit_is_unlimited', false,
      'allow_repeat_purchase', false,
      'agreement_is_open_ended', true,
      'agreement_ends_at', null,
      'branch_scope', 'not_applicable',
      'valid_branches', '[]'::jsonb,
      'instructions', 'Bu eski demo kuponu için ayrıntılı kullanım koşulları kaydedilmemiş.'
    )
from public.reward_offers as offer
where offer.id = redemption.reward_offer_id
  and redemption.offer_title_snapshot is null;

alter table public.reward_redemptions
  alter column offer_title_snapshot set not null,
  alter column partner_name_snapshot set not null,
  alter column summary_snapshot set not null;

alter table public.reward_redemptions
  drop constraint if exists reward_redemptions_one_offer_per_user;

create index if not exists reward_redemptions_user_offer_created_idx
  on public.reward_redemptions (user_id, reward_offer_id, created_at desc);

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

  -- Serialize purchases by account so concurrent requests cannot overspend
  -- or bypass the offer's repeat-purchase rule.
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
    -- Calendar months in Europe/Istanbul; PostgreSQL clamps month-end overflow
    -- (for example, January 31 plus one month becomes February 28/29).
    v_expires_at := (
      (v_issued_at at time zone 'Europe/Istanbul')
      + pg_catalog.make_interval(months => v_offer.validity_months)
    ) at time zone 'Europe/Istanbul';
  end if;

  v_code := 'BY-' || upper(substr(replace(v_redemption_id::text, '-', ''), 1, 12));
  v_terms_snapshot := jsonb_build_object(
    'legacy_terms', false,
    'redemption_type', v_offer.redemption_type,
    'validity_is_unlimited', v_offer.validity_is_unlimited,
    'validity_months', v_offer.validity_months,
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

revoke all on function public.redeem_reward_offer(text)
  from public, anon, authenticated;
grant execute on function public.redeem_reward_offer(text)
  to authenticated;

-- Keep the old RPC name working for previously installed clients.
create or replace function public.redeem_demo_reward(p_reward_offer_id text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select public.redeem_reward_offer(p_reward_offer_id);
$$;

revoke all on function public.redeem_demo_reward(text)
  from public, anon, authenticated;
grant execute on function public.redeem_demo_reward(text)
  to authenticated;

drop function if exists public.get_my_reward_redemptions();

create function public.get_my_reward_redemptions()
returns table (
  id uuid,
  offer_id text,
  title text,
  partner_name text,
  summary text,
  points integer,
  code text,
  redemption_type text,
  created_at timestamptz,
  expires_at timestamptz,
  terms_snapshot jsonb,
  coupon_status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    redemption.id,
    redemption.reward_offer_id,
    redemption.offer_title_snapshot,
    redemption.partner_name_snapshot,
    redemption.summary_snapshot,
    redemption.points_cost,
    redemption.code,
    redemption.redemption_type,
    redemption.created_at,
    redemption.expires_at,
    redemption.terms_snapshot,
    case
      when redemption.expires_at is not null
        and redemption.expires_at <= pg_catalog.clock_timestamp()
        then 'expired'
      else 'active'
    end
  from public.reward_redemptions as redemption
  where redemption.user_id = auth.uid()
  order by redemption.created_at desc, redemption.id desc;
$$;

revoke all on function public.get_my_reward_redemptions()
  from public, anon, authenticated;
grant execute on function public.get_my_reward_redemptions()
  to authenticated;

commit;
