-- Demo rewards stay explicitly non-redeemable with real businesses, but their
-- test allocation and point spend are server-owned and account-consistent.

begin;

create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_offer_id text not null references public.reward_offers(id),
  points_cost integer not null check (points_cost > 0),
  redemption_type text not null
    check (redemption_type in ('store_qr', 'online_code', 'campaign_link')),
  code text not null unique,
  created_at timestamptz not null default now(),
  constraint reward_redemptions_one_offer_per_user
    unique (user_id, reward_offer_id)
);

alter table public.reward_redemptions enable row level security;
revoke all on table public.reward_redemptions from public, anon, authenticated;

alter table public.point_transactions
  alter column report_id drop not null,
  alter column feedback_id drop not null;

alter table public.point_transactions
  add column if not exists reward_redemption_id uuid
    references public.reward_redemptions(id) on delete cascade;

alter table public.point_transactions
  drop constraint if exists point_transactions_known_awards_only;

alter table public.point_transactions
  add constraint point_transactions_known_awards_only check (
    (
      event_type = 'report_parked_author_reward'
      and points_delta in (10, 20)
      and report_id is not null
      and feedback_id is not null
      and reward_redemption_id is null
    )
    or
    (
      event_type = 'parked_confirmation_reward'
      and points_delta in (2, 10)
      and report_id is not null
      and feedback_id is not null
      and reward_redemption_id is null
    )
    or
    (
      event_type = 'photo_report_reward'
      and points_delta = 10
      and report_id is not null
      and feedback_id is null
      and reward_redemption_id is null
    )
    or
    (
      event_type = 'reward_redemption'
      and points_delta < 0
      and report_id is null
      and feedback_id is null
      and reward_redemption_id is not null
    )
  );

create index if not exists reward_redemptions_user_created_idx
  on public.reward_redemptions (user_id, created_at desc, id desc);

create function public.redeem_demo_reward(p_reward_offer_id text)
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
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  -- Serialize redemptions for one account so two devices cannot spend the
  -- same balance concurrently.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  select * into v_offer
  from public.reward_offers
  where id = p_reward_offer_id
    and is_active
    and is_demo;

  if not found then
    raise exception 'Only active demo rewards can be redeemed.' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.reward_redemptions
    where user_id = v_user_id and reward_offer_id = v_offer.id
  ) then
    raise exception 'This demo reward was already redeemed.' using errcode = '23505';
  end if;

  select coalesce(sum(points_delta), 0)::bigint into v_balance
  from public.point_transactions
  where user_id = v_user_id;

  if v_balance < v_offer.points_cost then
    raise exception 'Not enough points.' using errcode = '22023';
  end if;

  v_code := 'DEMO-' || upper(substr(replace(v_redemption_id::text, '-', ''), 1, 10));

  insert into public.reward_redemptions (
    id, user_id, reward_offer_id, points_cost, redemption_type, code
  ) values (
    v_redemption_id,
    v_user_id,
    v_offer.id,
    v_offer.points_cost,
    v_offer.redemption_type,
    v_code
  );

  insert into public.point_transactions (
    user_id, report_id, feedback_id, reward_redemption_id,
    idempotency_key, event_type, points_delta, description
  ) values (
    v_user_id,
    null,
    null,
    v_redemption_id,
    'reward:' || v_redemption_id::text,
    'reward_redemption',
    -v_offer.points_cost,
    'Örnek kupon puan kullanımı · ' || v_offer.title
  );

  return jsonb_build_object(
    'id', v_redemption_id,
    'title', v_offer.title,
    'partner_name', v_offer.partner_name,
    'points', v_offer.points_cost,
    'code', v_code,
    'redemption_type', v_offer.redemption_type,
    'created_at', now()
  );
end;
$$;

revoke all on function public.redeem_demo_reward(text)
  from public, anon, authenticated;
grant execute on function public.redeem_demo_reward(text)
  to authenticated;

create function public.get_my_reward_redemptions()
returns table (
  id uuid,
  title text,
  partner_name text,
  points integer,
  code text,
  redemption_type text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    redemption.id,
    offer.title,
    offer.partner_name,
    redemption.points_cost,
    redemption.code,
    redemption.redemption_type,
    redemption.created_at
  from public.reward_redemptions as redemption
  join public.reward_offers as offer on offer.id = redemption.reward_offer_id
  where redemption.user_id = auth.uid()
  order by redemption.created_at desc, redemption.id desc;
$$;

revoke all on function public.get_my_reward_redemptions()
  from public, anon, authenticated;
grant execute on function public.get_my_reward_redemptions()
  to authenticated;

commit;
