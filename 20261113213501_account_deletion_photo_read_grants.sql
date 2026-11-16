-- The account-deletion Edge Function uses the service role to remove only
-- photos owned by the account being deleted. Keep client access revoked and
-- grant the function the two columns it needs to locate those objects.
grant select (id, avatar_object_path)
on public.profiles
to service_role;

grant select (author_id, photo_object_path)
on public.parking_reports
to service_role;
