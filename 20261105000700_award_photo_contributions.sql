begin;

-- A successfully stored photo is a small, one-time contribution reward.
-- The ledger remains server-owned; clients cannot award points themselves.
alter table public.point_transactions
  alter column feedback_id drop not null;

alter table public.point_transactions
  drop constraint point_transactions_event_type_check,
  add constraint point_transactions_event_type_check
    check (event_type in (
      'report_parked_author_reward',
      'parked_confirmation_reward',
      'photo_report_reward'
    )),
  drop constraint point_transactions_known_awards_only,
  add constraint point_transactions_known_awards_only check (
    (event_type = 'report_parked_author_reward' and points_delta in (10, 20))
    or
    (event_type = 'parked_confirmation_reward' and points_delta in (2, 10))
    or
    (event_type = 'photo_report_reward' and points_delta = 10)
  );

create unique index point_transactions_photo_report_once
  on public.point_transactions (report_id)
  where event_type = 'photo_report_reward';

create function app_private.award_points_for_report_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.photo_object_path is null
     or (tg_op = 'UPDATE' and old.photo_object_path is not null) then
    return new;
  end if;

  insert into public.point_transactions (
    user_id,
    report_id,
    feedback_id,
    idempotency_key,
    event_type,
    points_delta,
    description
  ) values (
    new.author_id,
    new.id,
    null,
    'report:' || new.id::text || ':photo-contribution',
    'photo_report_reward',
    10,
    case new.kind
      when 'vacancy' then 'Fotoğraflı boş yer bildirimi'
      else 'Çıkıyorum bildirimine fotoğraf eklendi'
    end
  )
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function app_private.award_points_for_report_photo()
  from public, anon, authenticated;

create trigger parking_report_photo_points_on_create
after insert on public.parking_reports
for each row execute function app_private.award_points_for_report_photo();

create trigger parking_report_photo_points_on_attach
after update of photo_object_path on public.parking_reports
for each row
when (old.photo_object_path is null and new.photo_object_path is not null)
execute function app_private.award_points_for_report_photo();

commit;
