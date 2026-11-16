-- Keep retained report rows valid while removing account-owned private data.
-- Marking the report resolved removes it from active map queries. A retained
-- leaving report uses the photo-optional presence state after its photo path
-- is erased, so existing table checks continue to protect normal writes.

begin;

create or replace function app_private.anonymize_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    raise exception 'A user id is required';
  end if;

  update public.parking_reports
  set author_id = '00000000-0000-0000-0000-000000000000'::uuid,
      note = null,
      photo_object_path = null,
      photo_uploaded_at = null,
      leaving_presence = case
        when kind = 'leaving' then 'nearby'
        else null
      end,
      resolved_at = coalesce(resolved_at, now()),
      cancelled_at = coalesce(cancelled_at, now())
  where author_id = p_user_id;

  delete from public.profiles
  where id = p_user_id;
end;
$$;

revoke all on function app_private.anonymize_account_data(uuid)
  from public, anon, authenticated;

commit;
