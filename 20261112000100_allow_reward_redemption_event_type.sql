-- Allow server-owned demo coupon redemptions in the points ledger.
-- The detailed row-shape and negative-points checks remain enforced by
-- point_transactions_known_awards_only.

begin;

alter table public.point_transactions
  drop constraint if exists point_transactions_event_type_check;

alter table public.point_transactions
  add constraint point_transactions_event_type_check
    check (event_type in (
      'report_parked_author_reward',
      'parked_confirmation_reward',
      'photo_report_reward',
      'reward_redemption'
    ));

commit;
