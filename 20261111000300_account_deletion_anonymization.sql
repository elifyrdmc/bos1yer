-- Boş Bir Yer: retain useful report history when an account is deleted.
-- The Edge Function calls the public wrapper with the signed-in user's JWT,
-- then deletes the auth user with the service-role key on the server.

begin;

create schema if not exists app_private;

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

  -- Keep the location, kind and timestamps for aggregate/report history, but
  -- remove the author link and private contribution content.
  update public.parking_reports
  set author_id = '00000000-0000-0000-0000-000000000000'::uuid,
      note = null,
      photo_object_path = null,
      photo_uploaded_at = null
  where author_id = p_user_id;

  -- This row is private account data and is removed before auth.users is
  -- deleted. Feedback and point transactions follow their existing
  -- auth.users ON DELETE CASCADE rules.
  delete from public.profiles
  where id = p_user_id;
end;
$$;

revoke all on function app_private.anonymize_account_data(uuid)
  from public, anon, authenticated;

create or replace function public.prepare_my_account_deletion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'A signed-in user is required';
  end if;

  perform app_private.anonymize_account_data(v_user_id);
end;
$$;

revoke all on function public.prepare_my_account_deletion()
  from public, anon;
grant execute on function public.prepare_my_account_deletion()
  to authenticated;

comment on function public.prepare_my_account_deletion() is
  'Removes private account data and anonymizes authored parking reports before server-side auth deletion.';

commit;
