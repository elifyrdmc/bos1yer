-- Demo-only reward catalog. No real business offer or redeemable coupon is created.
begin;

create table if not exists public.reward_offers (
  id text primary key,
  partner_name text not null,
  title text not null,
  summary text not null,
  redemption_type text not null
    check (redemption_type in ('store_qr', 'online_code', 'campaign_link')),
  points_cost integer not null check (points_cost > 0),
  is_demo boolean not null default true,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.reward_offers enable row level security;

revoke all on table public.reward_offers from anon, authenticated;
grant select on table public.reward_offers to authenticated;

drop policy if exists "Authenticated users can read active reward offers"
  on public.reward_offers;
create policy "Authenticated users can read active reward offers"
  on public.reward_offers
  for select
  to authenticated
  using (is_active);

insert into public.reward_offers (
  id, partner_name, title, summary, redemption_type, points_cost, is_demo, is_active, sort_order
) values
  (
    'demo-store-qr',
    'Örnek Kafe',
    'Filtre kahve ikramı',
    'İşletmede gösterilecek tek kullanımlık QR kuponu örneği.',
    'store_qr',
    20,
    true,
    true,
    1
  ),
  (
    'demo-online-code',
    'Örnek E-ticaret',
    'Alışverişte %10 indirim',
    'İnternet sitesinde kullanılacak indirim kodu örneği.',
    'online_code',
    30,
    true,
    true,
    2
  ),
  (
    'demo-campaign-link',
    'Örnek Kampanya',
    'Kampanya sayfası fırsatı',
    'Bir kampanya sayfasına yönlendirme türü örneği.',
    'campaign_link',
    10,
    true,
    true,
    3
  )
on conflict (id) do update set
  partner_name = excluded.partner_name,
  title = excluded.title,
  summary = excluded.summary,
  redemption_type = excluded.redemption_type,
  points_cost = excluded.points_cost,
  is_demo = excluded.is_demo,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

commit;
