-- Preserve the existing profile export fields while adding private full name
-- and account-owned favorites introduced by the profile synchronization change.

begin;

create or replace function public.get_my_account_export()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'A signed-in user is required' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'profile', coalesce(
      (
        select jsonb_build_object(
          'id', profile.id,
          'nickname', profile.nickname,
          'full_name', profile.full_name,
          'created_at', profile.created_at,
          'updated_at', profile.updated_at
        )
        from public.profiles as profile
        where profile.id = v_user_id
      ),
      '{}'::jsonb
    ),
    'favorite_districts', coalesce(
      (
        select jsonb_agg(favorite.district_name order by favorite.district_name)
        from public.favorite_districts as favorite
        where favorite.user_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'reports', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', report.id,
            'kind', report.kind,
            'latitude', extensions.st_y(report.location::extensions.geometry),
            'longitude', extensions.st_x(report.location::extensions.geometry),
            'created_at', report.created_at,
            'note', report.note,
            'estimated_departure_minutes', report.estimated_departure_minutes,
            'leaving_presence', report.leaving_presence,
            'photo_uploaded_at', report.photo_uploaded_at,
            'resolved_at', report.resolved_at,
            'cancelled_at', report.cancelled_at,
            'parked_count', coalesce(feedback.parked_count, 0),
            'occupied_count', coalesce(feedback.occupied_count, 0),
            'not_found_count', coalesce(feedback.not_found_count, 0)
          ) order by report.created_at desc, report.id desc
        )
        from public.parking_reports as report
        left join lateral (
          select
            count(*) filter (where response.outcome = 'parked') as parked_count,
            count(*) filter (where response.outcome = 'occupied') as occupied_count,
            count(*) filter (where response.outcome = 'not_found') as not_found_count
          from public.parking_report_feedback as response
          where response.report_id = report.id
            and (
              report.kind <> 'leaving'
              or response.created_at >= report.created_at
                + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
            )
        ) as feedback on true
        where report.author_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'points', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', entry.id,
            'points_delta', entry.points_delta,
            'event_type', entry.event_type,
            'description', entry.description,
            'created_at', entry.created_at
          ) order by entry.created_at desc, entry.id desc
        )
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      '[]'::jsonb
    ),
    'points_balance', coalesce(
      (
        select sum(entry.points_delta)::bigint
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      0::bigint
    )
  );
end;
$$;

revoke all on function public.get_my_account_export()
  from public, anon, authenticated;
grant execute on function public.get_my_account_export()
  to authenticated;

comment on function public.get_my_account_export() is
  'Exports only the signed-in user profile, favorites, report history and points ledger. Private storage paths and other users are excluded.';

commit;
