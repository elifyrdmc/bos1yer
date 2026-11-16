


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "app_private";


ALTER SCHEMA "app_private" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "app_private"."anonymize_account_data"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "app_private"."anonymize_account_data"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app_private"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) RETURNS TABLE("id" "uuid", "kind" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone, "age_seconds" integer, "note" "text", "photo_object_path" "text", "estimated_departure_minutes" smallint, "leaving_presence" "text", "photo_age_seconds" integer, "can_upload_photo" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_report public.parking_reports%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid photo coordinates.' using errcode = '22023';
  end if;
  if p_photo_object_path is null
     or p_photo_object_path not like (v_user_id::text || '/%')
     or not exists (
       select 1 from storage.objects as photo
       where photo.bucket_id = 'parking-report-photos'
         and photo.name = p_photo_object_path
         and photo.owner_id = v_user_id::text
     ) then
    raise exception 'The photo must be uploaded by the signed-in user.'
      using errcode = '42501';
  end if;

  select report.* into v_report
  from public.parking_reports as report
  where report.id = p_report_id and report.author_id = v_user_id
  for update;

  if not found
     or v_report.kind <> 'leaving'
     or v_report.leaving_presence <> 'nearby'
     or v_report.photo_object_path is not null
     or now() >= v_report.created_at
       + make_interval(mins => v_report.estimated_departure_minutes)
     or now() >= v_report.created_at + interval '10 minutes'
       + make_interval(mins => v_report.estimated_departure_minutes) then
    raise exception 'Photo upload is no longer allowed for this report.'
      using errcode = 'P0002';
  end if;

  if not extensions.st_dwithin(
    v_report.location,
    extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography,
    30
  ) then
    raise exception 'The photo must be taken within 30 meters of the report.'
      using errcode = '22023';
  end if;

  update public.parking_reports as report
  set photo_object_path = p_photo_object_path,
      photo_uploaded_at = now()
  where report.id = p_report_id
  returning report.* into v_report;

  return query select
    v_report.id,
    v_report.kind,
    extensions.st_y(v_report.location::extensions.geometry),
    extensions.st_x(v_report.location::extensions.geometry),
    v_report.created_at,
    floor(extract(epoch from (now() - v_report.created_at)))::integer,
    v_report.note,
    v_report.photo_object_path,
    v_report.estimated_departure_minutes,
    v_report.leaving_presence,
    floor(extract(epoch from (now() - v_report.photo_uploaded_at)))::integer,
    v_report.author_id = v_user_id;
end;
$$;


ALTER FUNCTION "app_private"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app_private"."award_points_for_parked_feedback"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_report_author_id uuid;
  v_report_kind text;
begin
  if new.outcome <> 'parked' then
    return new;
  end if;

  select report.author_id, report.kind
    into v_report_author_id, v_report_kind
  from public.parking_reports as report
  where report.id = new.report_id;

  if not found
     or v_report_author_id = new.user_id
     or v_report_kind not in ('vacancy', 'leaving') then
    return new;
  end if;

  -- The report author receives one award per report, even if multiple drivers
  -- confirm a leaving report. Keep the existing deterministic key unchanged.
  insert into public.point_transactions (
    user_id,
    report_id,
    feedback_id,
    idempotency_key,
    event_type,
    points_delta,
    description
  ) values (
    v_report_author_id,
    new.report_id,
    new.id,
    'report:' || new.report_id::text || ':parked-author',
    'report_parked_author_reward',
    20,
    'Başka bir sürücü bildiriminle park etti'
  )
  on conflict do nothing;

  insert into public.point_transactions (
    user_id,
    report_id,
    feedback_id,
    idempotency_key,
    event_type,
    points_delta,
    description
  ) values (
    new.user_id,
    new.report_id,
    new.id,
    'feedback:' || new.id::text || ':parked-confirmation',
    'parked_confirmation_reward',
    10,
    'Park ettim bildirimi'
  )
  on conflict do nothing;

  return new;
end;
$$;


ALTER FUNCTION "app_private"."award_points_for_parked_feedback"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app_private"."award_points_for_report_photo"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "app_private"."award_points_for_report_photo"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app_private"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint DEFAULT NULL::smallint, "p_leaving_presence" "text" DEFAULT NULL::"text", "p_device_latitude" double precision DEFAULT NULL::double precision, "p_device_longitude" double precision DEFAULT NULL::double precision) RETURNS TABLE("id" "uuid", "kind" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone, "age_seconds" integer, "note" "text", "photo_object_path" "text", "estimated_departure_minutes" smallint, "leaving_presence" "text", "photo_age_seconds" integer, "can_upload_photo" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_radius_meters double precision;
  v_report_location extensions.geography;
  v_device_location extensions.geography;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required to create a parking report.';
  end if;
  if p_kind not in ('vacancy', 'leaving') then
    raise exception 'Unsupported parking report kind.';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid parking report coordinates.';
  end if;
  if p_device_latitude is null or p_device_latitude < -90
     or p_device_latitude > 90 or p_device_longitude is null
     or p_device_longitude < -180 or p_device_longitude > 180 then
    raise exception 'Valid device GPS coordinates are required.';
  end if;
  v_report_location := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude), 4326
  )::extensions.geography;
  v_device_location := extensions.st_setsrid(
    extensions.st_makepoint(p_device_longitude, p_device_latitude), 4326
  )::extensions.geography;

  if p_note is not null and char_length(p_note) > 300 then
    raise exception 'The parking report note is too long.';
  end if;
  if p_photo_object_path is not null then
    if p_photo_object_path not like ((select auth.uid()::text) || '/%') then
      raise exception 'The report photo must belong to the signed-in user.';
    end if;
    if not exists (
      select 1 from storage.objects as photo
      where photo.bucket_id = 'parking-report-photos'
        and photo.name = p_photo_object_path
        and photo.owner_id = (select auth.uid()::text)
    ) then
      raise exception 'The report photo must exist in the user''s private bucket.';
    end if;
    if not extensions.st_dwithin(v_report_location, v_device_location, 30) then
      raise exception 'The photo must be taken within 30 meters of the report.';
    end if;
  end if;

  if p_kind = 'leaving' then
    if p_estimated_departure_minutes is null
       or p_estimated_departure_minutes not in (5, 10) then
      raise exception 'Leaving reports require a 5 or 10 minute estimate.';
    end if;
    if p_leaving_presence is null
       or p_leaving_presence not in ('at_location', 'nearby') then
      raise exception 'Leaving reports require a presence choice.';
    end if;
    if p_leaving_presence = 'at_location' and p_photo_object_path is null then
      raise exception 'A photo is required when at the parking location.';
    end if;
    if p_leaving_presence = 'nearby' and p_photo_object_path is null then
      v_radius_meters := case p_estimated_departure_minutes
        when 5 then 300
        when 10 then 500
      end;
      if not extensions.st_dwithin(
        v_report_location, v_device_location, v_radius_meters
      ) then
        raise exception 'The selected vehicle location is too far from the current GPS position.';
      end if;
    end if;
  elsif p_estimated_departure_minutes is not null
        or p_leaving_presence is not null
        or p_photo_object_path is null then
    raise exception 'Vacancy reports require a photo and cannot have a leaving estimate or presence choice.';
  end if;

  return query
    insert into public.parking_reports (
      author_id,
      kind,
      location,
      note,
      photo_object_path,
      estimated_departure_minutes,
      leaving_presence,
      photo_uploaded_at
    )
    values (
      (select auth.uid()),
      p_kind,
      v_report_location,
      nullif(btrim(p_note), ''),
      p_photo_object_path,
      p_estimated_departure_minutes,
      p_leaving_presence,
      case when p_photo_object_path is null then null else now() end
    )
    returning
      parking_reports.id,
      parking_reports.kind,
      extensions.st_y(parking_reports.location::extensions.geometry),
      extensions.st_x(parking_reports.location::extensions.geometry),
      parking_reports.created_at,
      0,
      parking_reports.note,
      parking_reports.photo_object_path,
      parking_reports.estimated_departure_minutes,
      parking_reports.leaving_presence,
      case when parking_reports.photo_uploaded_at is null then null else 0 end,
      parking_reports.author_id = (select auth.uid());
end;
$$;


ALTER FUNCTION "app_private"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "app_private"."get_report_author_trust_summary"("p_user_id" "uuid") RETURNS TABLE("score" numeric, "qualifying_outcome_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with positive_events as (
    select
      report.id as report_id,
      min(feedback.created_at) as occurred_at,
      'positive'::text as outcome
    from public.parking_reports as report
    join public.parking_report_feedback as feedback
      on feedback.report_id = report.id
     and feedback.user_id <> report.author_id
     and feedback.outcome = 'parked'
     and (report.kind <> 'leaving'
       or feedback.created_at >= report.created_at
         + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
    where report.author_id = p_user_id
      and report.cancelled_at is null
    group by report.id
  ),
  negative_events as (
    select
      report.id as report_id,
      report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
        as occurred_at,
      'negative'::text as outcome
    from public.parking_reports as report
    where report.author_id = p_user_id
      and report.kind = 'leaving'
      and report.leaving_presence = 'nearby'
      and report.photo_object_path is null
      and report.cancelled_at is null
      and report.resolved_at is null
      and now() >= report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
  ),
  ordered_events as (
    select
      events.report_id,
      events.occurred_at,
      events.outcome,
      row_number() over (
        order by events.occurred_at, events.report_id, events.outcome
      ) as event_number
    from (
      select * from positive_events
      union all
      select * from negative_events
    ) as events
  ),
  totals as (
    select
      count(*)::integer as outcome_count,
      coalesce(sum(
        case
          when event_number <= 4 and outcome = 'positive' then 1::numeric
          when event_number <= 4 then -0.5::numeric
          when outcome = 'positive' then 0.5::numeric
          else -0.2::numeric
        end
      ) filter (where event_number <= 4), 0::numeric) as initial_score,
      coalesce(sum(
        case when outcome = 'positive' then 0.5::numeric else -0.2::numeric end
      ) filter (where event_number > 4), 0::numeric) as later_delta
    from ordered_events
  )
  select
    case when totals.outcome_count < 4 then null::numeric
      else least(
        5::numeric,
        greatest(
          0::numeric,
          least(5::numeric, greatest(0::numeric, totals.initial_score))
            + totals.later_delta
        )
      )
    end,
    totals.outcome_count
  from totals;
$$;


ALTER FUNCTION "app_private"."get_report_author_trust_summary"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) RETURNS TABLE("id" "uuid", "kind" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone, "age_seconds" integer, "note" "text", "photo_object_path" "text", "estimated_departure_minutes" smallint, "leaving_presence" "text", "photo_age_seconds" integer, "can_upload_photo" boolean)
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  select * from app_private.attach_leaving_report_photo(
    p_report_id, p_photo_object_path, p_latitude, p_longitude
  );
$$;


ALTER FUNCTION "public"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_my_parking_report"("p_report_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_report public.parking_reports%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  select report.* into v_report
  from public.parking_reports as report
  where report.id = p_report_id
    and report.author_id = v_user_id
  for update;

  if not found then
    raise exception 'Report not found or not owned by this account.'
      using errcode = 'P0002';
  end if;

  if v_report.cancelled_at is not null then
    return;
  end if;

  if v_report.resolved_at is not null
     or now() >= v_report.created_at + interval '10 minutes'
       + make_interval(mins => coalesce(v_report.estimated_departure_minutes, 0))
     or (v_report.kind = 'leaving'
       and v_report.leaving_presence = 'nearby'
       and v_report.photo_object_path is null
       and now() >= v_report.created_at
         + make_interval(mins => coalesce(v_report.estimated_departure_minutes, 0))) then
    raise exception 'This report is no longer active.' using errcode = 'P0002';
  end if;

  update public.parking_reports
  set cancelled_at = now(),
      resolved_at = now()
  where id = p_report_id;
end;
$$;


ALTER FUNCTION "public"."cancel_my_parking_report"("p_report_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint DEFAULT NULL::smallint, "p_leaving_presence" "text" DEFAULT NULL::"text", "p_device_latitude" double precision DEFAULT NULL::double precision, "p_device_longitude" double precision DEFAULT NULL::double precision) RETURNS TABLE("id" "uuid", "kind" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone, "age_seconds" integer, "note" "text", "photo_object_path" "text", "estimated_departure_minutes" smallint, "leaving_presence" "text", "photo_age_seconds" integer, "can_upload_photo" boolean)
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  select * from app_private.create_parking_report(
    p_kind,
    p_latitude,
    p_longitude,
    p_note,
    p_photo_object_path,
    p_estimated_departure_minutes,
    p_leaving_presence,
    p_device_latitude,
    p_device_longitude
  );
$$;


ALTER FUNCTION "public"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_parking_reports"() RETURNS TABLE("id" "uuid", "kind" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone, "age_seconds" integer, "note" "text", "photo_object_path" "text", "estimated_departure_minutes" smallint, "leaving_presence" "text", "photo_age_seconds" integer, "can_upload_photo" boolean, "author_trust_score" numeric, "author_trust_outcome_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    report.id,
    report.kind,
    extensions.st_y(report.location::extensions.geometry),
    extensions.st_x(report.location::extensions.geometry),
    report.created_at,
    floor(extract(epoch from (now() - report.created_at)))::integer,
    report.note,
    report.photo_object_path,
    report.estimated_departure_minutes,
    report.leaving_presence,
    case when report.photo_uploaded_at is null then null
      else floor(extract(epoch from (now() - report.photo_uploaded_at)))::integer
    end,
    report.author_id = (select auth.uid()),
    trust.score,
    trust.qualifying_outcome_count
  from public.parking_reports as report
  left join lateral app_private.get_report_author_trust_summary(report.author_id)
    as trust on true
  where auth.uid() is not null
    and now() < report.created_at + interval '10 minutes'
      + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
    and report.resolved_at is null
    and (report.kind <> 'leaving'
      or report.leaving_presence <> 'nearby'
      or report.photo_object_path is not null
      or now() < report.created_at
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
  order by report.created_at desc;
$$;


ALTER FUNCTION "public"."get_active_parking_reports"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_account_export"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."get_my_account_export"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_my_account_export"() IS 'Exports only the signed-in user profile, favorites, report history and points ledger. Private storage paths and other users are excluded.';



CREATE OR REPLACE FUNCTION "public"."get_my_parking_report_counts"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'vacancy_count', (
      select count(*)
      from public.parking_reports as report
      where report.author_id = v_user_id
        and report.kind = 'vacancy'
    ),
    'leaving_count', (
      select count(*)
      from public.parking_reports as report
      where report.author_id = v_user_id
        and report.kind = 'leaving'
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_my_parking_report_counts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_parking_report_history"("p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "kind" "text", "created_at" timestamp with time zone, "photo_object_path" "text", "note" "text", "estimated_departure_minutes" smallint, "status" "text", "parked_count" bigint, "occupied_count" bigint, "not_found_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  if coalesce(p_offset, 0) < 0 then
    raise exception 'Offset must not be negative.' using errcode = '22023';
  end if;

  return query
  select
    report.id,
    report.kind,
    report.created_at,
    report.photo_object_path,
    report.note,
    report.estimated_departure_minutes,
    case
      when report.cancelled_at is not null then 'cancelled'
      when report.resolved_at is not null
        and coalesce(feedback.parked_count, 0) > 0 then 'parked'
      when report.resolved_at is not null
        and coalesce(feedback.occupied_count, 0) > 0 then 'occupied'
      when now() < report.created_at + interval '10 minutes'
        + make_interval(mins => coalesce(report.estimated_departure_minutes, 0))
        then 'active'
      when coalesce(feedback.parked_count, 0)
        + coalesce(feedback.occupied_count, 0)
        + coalesce(feedback.not_found_count, 0) > 0 then 'feedback'
      else 'expired'
    end,
    coalesce(feedback.parked_count, 0),
    coalesce(feedback.occupied_count, 0),
    coalesce(feedback.not_found_count, 0)
  from public.parking_reports as report
  left join lateral (
    select
      count(*) filter (where response.outcome = 'parked') as parked_count,
      count(*) filter (where response.outcome = 'occupied') as occupied_count,
      count(*) filter (where response.outcome = 'not_found') as not_found_count
    from public.parking_report_feedback as response
    where response.report_id = report.id
      and (report.kind <> 'leaving'
        or response.created_at >= report.created_at
          + make_interval(mins => coalesce(report.estimated_departure_minutes, 0)))
  ) as feedback on true
  where report.author_id = v_user_id
  order by report.created_at desc, report.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset coalesce(p_offset, 0);
end;
$$;


ALTER FUNCTION "public"."get_my_parking_report_history"("p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_points_wallet"("p_limit" integer DEFAULT 50) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'balance', coalesce(
      (
        select sum(entry.points_delta)::bigint
        from public.point_transactions as entry
        where entry.user_id = v_user_id
      ),
      0::bigint
    ),
    'transactions', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', recent.id,
            'points_delta', recent.points_delta,
            'event_type', recent.event_type,
            'description', recent.description,
            'created_at', recent.created_at
          ) order by recent.created_at desc, recent.id desc
        )
        from (
          select
            entry.id,
            entry.points_delta,
            entry.event_type,
            entry.description,
            entry.created_at
          from public.point_transactions as entry
          where entry.user_id = v_user_id
          order by entry.created_at desc, entry.id desc
          limit v_limit
        ) as recent
      ),
      '[]'::jsonb
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_my_points_wallet"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_reward_redemptions"() RETURNS TABLE("id" "uuid", "offer_id" "text", "title" "text", "partner_name" "text", "summary" "text", "points" integer, "code" "text", "redemption_type" "text", "created_at" timestamp with time zone, "expires_at" timestamp with time zone, "terms_snapshot" "jsonb", "coupon_status" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."get_my_reward_redemptions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_trust_score"() RETURNS TABLE("score" numeric, "qualifying_outcome_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select summary.score, summary.qualifying_outcome_count
  from app_private.get_report_author_trust_summary((select auth.uid()))
    as summary
  where (select auth.uid()) is not null;
$$;


ALTER FUNCTION "public"."get_my_trust_score"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_parking_report_feedback"("p_report_id" "uuid", "p_latitude" double precision DEFAULT NULL::double precision, "p_longitude" double precision DEFAULT NULL::double precision, "p_accuracy_meters" double precision DEFAULT NULL::double precision) RETURNS TABLE("parked_count" bigint, "occupied_count" bigint, "not_found_count" bigint, "my_outcome" "text", "can_submit" boolean, "feedback_open" boolean, "is_author" boolean, "is_nearby" boolean, "is_resolved" boolean, "can_update" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_kind text;
  v_created_at timestamptz;
  v_resolved_at timestamptz;
  v_estimate smallint;
  v_presence text;
  v_photo_path text;
  v_author_id uuid;
  v_feedback_open boolean;
  v_feedback_start timestamptz;
  v_nearby boolean := false;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes, report.leaving_presence,
         report.photo_object_path, report.author_id
    into v_kind, v_created_at, v_resolved_at, v_estimate, v_presence,
         v_photo_path, v_author_id
  from public.parking_reports as report
  where report.id = p_report_id;
  if not found or now() >= v_created_at + interval '10 minutes'
      + make_interval(mins => coalesce(v_estimate, 0)) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  v_feedback_start := v_created_at + make_interval(
    mins => case when v_kind = 'leaving' then coalesce(v_estimate, 0) else 0 end
  );
  v_feedback_open := v_resolved_at is null
    and now() >= v_feedback_start
    and now() < v_created_at + interval '10 minutes'
      + make_interval(mins => coalesce(v_estimate, 0))
    and (v_kind <> 'leaving' or v_presence <> 'nearby'
      or v_photo_path is not null);
  v_nearby := p_latitude is not null and p_longitude is not null
    and p_accuracy_meters is not null
    and p_accuracy_meters > 0 and p_accuracy_meters <= 30
    and p_latitude between -90 and 90
    and p_longitude between -180 and 180
    and extensions.st_dwithin(
      (select report.location from public.parking_reports as report
       where report.id = p_report_id),
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude), 4326
      )::extensions.geography,
      30
    );

  return query
  select
    count(*) filter (where feedback.outcome = 'parked'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    count(*) filter (where feedback.outcome = 'occupied'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    count(*) filter (where feedback.outcome = 'not_found'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    max(feedback.outcome) filter (where feedback.user_id = v_user_id
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)),
    v_feedback_open and v_author_id <> v_user_id
      and v_nearby
      and not exists (
        select 1 from public.parking_report_feedback as mine
        where mine.report_id = p_report_id and mine.user_id = v_user_id
          and (v_kind <> 'leaving' or mine.created_at >= v_feedback_start)
      ),
    v_feedback_open,
    v_author_id = v_user_id,
    v_nearby,
    v_resolved_at is not null,
    v_feedback_open and v_author_id <> v_user_id
      and exists (
        select 1 from public.parking_report_feedback as mine
        where mine.report_id = p_report_id
          and mine.user_id = v_user_id
          and mine.outcome = 'not_found'
          and mine.revision_count = 0
          and (v_kind <> 'leaving' or mine.created_at >= v_feedback_start)
      )
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id;
end;
$$;


ALTER FUNCTION "public"."get_parking_report_feedback"("p_report_id" "uuid", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prepare_my_account_deletion"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'A signed-in user is required';
  end if;

  perform app_private.anonymize_account_data(v_user_id);
end;
$$;


ALTER FUNCTION "public"."prepare_my_account_deletion"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."prepare_my_account_deletion"() IS 'Removes private account data and anonymizes authored parking reports before server-side auth deletion.';



CREATE OR REPLACE FUNCTION "public"."redeem_demo_reward"("p_reward_offer_id" "text") RETURNS "jsonb"
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  select public.redeem_reward_offer(p_reward_offer_id);
$$;


ALTER FUNCTION "public"."redeem_demo_reward"("p_reward_offer_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."redeem_reward_offer"("p_reward_offer_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."redeem_reward_offer"("p_reward_offer_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_parking_report_feedback"("p_report_id" "uuid", "p_outcome" "text", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) RETURNS TABLE("parked_count" bigint, "occupied_count" bigint, "not_found_count" bigint, "my_outcome" "text", "can_submit" boolean, "feedback_open" boolean, "is_author" boolean, "is_nearby" boolean, "is_resolved" boolean, "can_update" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_kind text;
  v_created_at timestamptz;
  v_resolved_at timestamptz;
  v_estimate smallint;
  v_presence text;
  v_photo_path text;
  v_author_id uuid;
  v_feedback_start timestamptz;
  v_not_found_count bigint;
  v_existing_outcome text;
  v_revision_count smallint;
  v_is_update boolean := false;
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;
  select report.kind, report.created_at, report.resolved_at,
         report.estimated_departure_minutes, report.leaving_presence,
         report.photo_object_path, report.author_id
    into v_kind, v_created_at, v_resolved_at, v_estimate, v_presence,
         v_photo_path, v_author_id
  from public.parking_reports as report
  where report.id = p_report_id
  for update;
  if not found then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  v_feedback_start := v_created_at + make_interval(
    mins => case when v_kind = 'leaving' then coalesce(v_estimate, 0) else 0 end
  );
  if v_resolved_at is not null
     or now() >= v_created_at + interval '10 minutes'
       + make_interval(mins => coalesce(v_estimate, 0))
     or now() < v_feedback_start
     or (v_kind = 'leaving' and v_presence = 'nearby'
       and v_photo_path is null) then
    raise exception 'Feedback is not open for this report.'
      using errcode = 'P0002';
  end if;
  if v_author_id = v_user_id then
    raise exception 'Report creators cannot submit feedback.'
      using errcode = '42501';
  end if;
  if p_latitude is null or p_longitude is null
     or p_accuracy_meters is null or p_accuracy_meters <= 0
     or p_accuracy_meters > 30
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180
     or not extensions.st_dwithin(
       (select report.location from public.parking_reports as report
        where report.id = p_report_id),
       extensions.st_setsrid(
         extensions.st_makepoint(p_longitude, p_latitude), 4326
       )::extensions.geography,
       30
     ) then
    raise exception 'Feedback requires a fresh GPS location within 30 meters.'
      using errcode = '42501';
  end if;

  select feedback.outcome, feedback.revision_count
    into v_existing_outcome, v_revision_count
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id and feedback.user_id = v_user_id
    and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start)
  for update;

  if found then
    if v_existing_outcome <> 'not_found'
       or v_revision_count <> 0
       or p_outcome = 'not_found' then
      raise exception 'Only a saved "not found" answer can be corrected once.'
        using errcode = '23505';
    end if;
    update public.parking_report_feedback as feedback
    set outcome = p_outcome, revision_count = 1
    where feedback.report_id = p_report_id and feedback.user_id = v_user_id;
    v_is_update := true;
  else
    insert into public.parking_report_feedback (report_id, user_id, outcome)
    values (p_report_id, v_user_id, p_outcome);
  end if;

  if p_outcome in ('parked', 'occupied') then
    update public.parking_reports set resolved_at = now()
    where id = p_report_id;
  elsif p_outcome = 'not_found' and not v_is_update then
    select count(*) into v_not_found_count
    from public.parking_report_feedback as feedback
    where feedback.report_id = p_report_id
      and feedback.outcome = 'not_found'
      and (v_kind <> 'leaving' or feedback.created_at >= v_feedback_start);
    if v_not_found_count >= 2 then
      update public.parking_reports set resolved_at = now()
      where id = p_report_id;
    end if;
  end if;

  return query select * from public.get_parking_report_feedback(
    p_report_id, p_latitude, p_longitude, p_accuracy_meters
  );
end;
$$;


ALTER FUNCTION "public"."submit_parking_report_feedback"("p_report_id" "uuid", "p_outcome" "text", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_profile_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;


ALTER FUNCTION "public"."touch_profile_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."favorite_districts" (
    "user_id" "uuid" NOT NULL,
    "district_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "favorite_districts_district_name_check" CHECK ((("char_length"("btrim"("district_name")) >= 2) AND ("char_length"("btrim"("district_name")) <= 48)))
);


ALTER TABLE "public"."favorite_districts" OWNER TO "postgres";


COMMENT ON TABLE "public"."favorite_districts" IS 'Private list of Istanbul districts saved by each account; never shown to other users.';



CREATE TABLE IF NOT EXISTS "public"."parking_report_feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "report_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "outcome" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revision_count" smallint DEFAULT 0 NOT NULL,
    CONSTRAINT "parking_report_feedback_outcome_check" CHECK (("outcome" = ANY (ARRAY['parked'::"text", 'occupied'::"text", 'not_found'::"text"]))),
    CONSTRAINT "parking_report_feedback_revision_count_check" CHECK ((("revision_count" >= 0) AND ("revision_count" <= 1)))
);


ALTER TABLE "public"."parking_report_feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."parking_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "author_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "location" "extensions"."geography"(Point,4326) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "note" "text",
    "photo_object_path" "text",
    "estimated_departure_minutes" smallint,
    "resolved_at" timestamp with time zone,
    "leaving_presence" "text",
    "photo_uploaded_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    CONSTRAINT "parking_reports_estimated_departure_minutes_check" CHECK ((("estimated_departure_minutes" IS NULL) OR ("estimated_departure_minutes" = ANY (ARRAY[5, 10])))),
    CONSTRAINT "parking_reports_kind_check" CHECK (("kind" = ANY (ARRAY['vacancy'::"text", 'leaving'::"text"]))),
    CONSTRAINT "parking_reports_leaving_presence_check" CHECK (((("kind" = 'vacancy'::"text") AND ("leaving_presence" IS NULL)) OR (("kind" = 'leaving'::"text") AND ("leaving_presence" IS NOT NULL) AND ("leaving_presence" = ANY (ARRAY['at_location'::"text", 'nearby'::"text"]))))),
    CONSTRAINT "parking_reports_presence_photo_check" CHECK (((("kind" <> 'leaving'::"text") OR ("leaving_presence" <> 'at_location'::"text") OR ("photo_object_path" IS NOT NULL)) AND (("photo_object_path" IS NULL) = ("photo_uploaded_at" IS NULL))))
);


ALTER TABLE "public"."parking_reports" OWNER TO "postgres";


COMMENT ON TABLE "public"."parking_reports" IS 'Short-lived map contributions. Client reads must use get_active_parking_reports(); direct table reads are disabled.';



COMMENT ON COLUMN "public"."parking_reports"."author_id" IS 'Private internal UUID; set from a verified session on the server, never from a client request.';



COMMENT ON COLUMN "public"."parking_reports"."photo_object_path" IS 'Private Storage object path only. A private bucket and upload policy are not created yet.';



COMMENT ON COLUMN "public"."parking_reports"."resolved_at" IS 'Set when a driver confirms a vacancy report is no longer available.';



COMMENT ON COLUMN "public"."parking_reports"."leaving_presence" IS 'For leaving reports, at_location requires a photo at creation; nearby permits a follow-up photo before the selected departure estimate.';



COMMENT ON COLUMN "public"."parking_reports"."photo_uploaded_at" IS 'Server timestamp when the presence photo was attached; the selected estimate, not this timestamp, controls the leaving pin color transition.';



CREATE TABLE IF NOT EXISTS "public"."point_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "report_id" "uuid",
    "feedback_id" "uuid",
    "idempotency_key" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "points_delta" integer NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reward_redemption_id" "uuid",
    CONSTRAINT "point_transactions_event_type_check" CHECK (("event_type" = ANY (ARRAY['report_parked_author_reward'::"text", 'parked_confirmation_reward'::"text", 'photo_report_reward'::"text", 'reward_redemption'::"text"]))),
    CONSTRAINT "point_transactions_known_awards_only" CHECK (((("event_type" = 'report_parked_author_reward'::"text") AND ("points_delta" = ANY (ARRAY[10, 20])) AND ("report_id" IS NOT NULL) AND ("feedback_id" IS NOT NULL) AND ("reward_redemption_id" IS NULL)) OR (("event_type" = 'parked_confirmation_reward'::"text") AND ("points_delta" = ANY (ARRAY[2, 10])) AND ("report_id" IS NOT NULL) AND ("feedback_id" IS NOT NULL) AND ("reward_redemption_id" IS NULL)) OR (("event_type" = 'photo_report_reward'::"text") AND ("points_delta" = 10) AND ("report_id" IS NOT NULL) AND ("feedback_id" IS NULL) AND ("reward_redemption_id" IS NULL)) OR (("event_type" = 'reward_redemption'::"text") AND ("points_delta" < 0) AND ("report_id" IS NULL) AND ("feedback_id" IS NULL) AND ("reward_redemption_id" IS NOT NULL))))
);


ALTER TABLE "public"."point_transactions" OWNER TO "postgres";


COMMENT ON TABLE "public"."point_transactions" IS 'Server-owned points ledger. The balance is the sum of points_delta.';



COMMENT ON COLUMN "public"."point_transactions"."report_id" IS 'Source report UUID retained as an audit reference without cascading ledger history.';



COMMENT ON COLUMN "public"."point_transactions"."feedback_id" IS 'Source feedback UUID retained as an audit reference without cascading ledger history.';



COMMENT ON COLUMN "public"."point_transactions"."idempotency_key" IS 'Generated only by the database: one author award per report and one confirmer award per feedback.';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "nickname" "text" NOT NULL,
    "avatar_object_path" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "full_name" "text",
    CONSTRAINT "profiles_avatar_owned_path_check" CHECK ((("avatar_object_path" IS NULL) OR ("split_part"("avatar_object_path", '/'::"text", 1) = ("id")::"text"))),
    CONSTRAINT "profiles_full_name_length_check" CHECK ((("full_name" IS NULL) OR (("char_length"("btrim"("full_name")) >= 3) AND ("char_length"("btrim"("full_name")) <= 80)))),
    CONSTRAINT "profiles_nickname_check" CHECK ((("char_length"("btrim"("nickname")) >= 2) AND ("char_length"("btrim"("nickname")) <= 24)))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Private profile settings. Public nickname/avatar visibility is not enabled.';



COMMENT ON COLUMN "public"."profiles"."avatar_object_path" IS 'Private Storage object path under the owning user ID folder. Never store or return a public URL.';



COMMENT ON COLUMN "public"."profiles"."full_name" IS 'Private account profile data. Readable only by the owning authenticated user; not exposed on public reports.';



CREATE TABLE IF NOT EXISTS "public"."reward_offers" (
    "id" "text" NOT NULL,
    "partner_name" "text" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "redemption_type" "text" NOT NULL,
    "points_cost" integer NOT NULL,
    "is_demo" boolean DEFAULT true NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "validity_months" integer,
    "validity_is_unlimited" boolean NOT NULL,
    "usage_kind" "text" NOT NULL,
    "usage_limit" integer,
    "usage_limit_is_unlimited" boolean NOT NULL,
    "allow_repeat_purchase" boolean NOT NULL,
    "agreement_is_open_ended" boolean NOT NULL,
    "agreement_ends_at" timestamp with time zone,
    "branch_scope" "text" NOT NULL,
    "valid_branches" "jsonb" NOT NULL,
    "instructions" "text" NOT NULL,
    "validity_days" integer,
    CONSTRAINT "reward_offers_agreement_term_rule" CHECK ((("agreement_is_open_ended" AND ("agreement_ends_at" IS NULL)) OR ((NOT "agreement_is_open_ended") AND ("agreement_ends_at" IS NOT NULL)))),
    CONSTRAINT "reward_offers_branch_rule" CHECK (((("branch_scope" = 'selected_branches'::"text") AND ("redemption_type" = 'store_qr'::"text") AND ("jsonb_typeof"("valid_branches") = 'array'::"text") AND ("jsonb_array_length"("valid_branches") > 0)) OR (("branch_scope" = ANY (ARRAY['all_branches'::"text", 'not_applicable'::"text"])) AND ("valid_branches" = '[]'::"jsonb")))),
    CONSTRAINT "reward_offers_points_cost_check" CHECK (("points_cost" > 0)),
    CONSTRAINT "reward_offers_redemption_type_check" CHECK (("redemption_type" = ANY (ARRAY['store_qr'::"text", 'online_code'::"text", 'campaign_link'::"text"]))),
    CONSTRAINT "reward_offers_rule_values" CHECK ((("usage_kind" = ANY (ARRAY['single_use'::"text", 'multi_use'::"text"])) AND ("branch_scope" = ANY (ARRAY['all_branches'::"text", 'selected_branches'::"text", 'not_applicable'::"text"])) AND ("length"("btrim"("instructions")) > 0))),
    CONSTRAINT "reward_offers_usage_rule" CHECK (((("usage_kind" = 'single_use'::"text") AND ("usage_limit" = 1) AND (NOT "usage_limit_is_unlimited")) OR (("usage_kind" = 'multi_use'::"text") AND (("usage_limit_is_unlimited" AND ("usage_limit" IS NULL)) OR ((NOT "usage_limit_is_unlimited") AND ("usage_limit" > 0)))))),
    CONSTRAINT "reward_offers_validity_rule" CHECK ((("validity_is_unlimited" AND ("validity_months" IS NULL) AND ("validity_days" IS NULL)) OR ((NOT "validity_is_unlimited") AND ((("validity_months" > 0) AND ("validity_days" IS NULL)) OR (("validity_days" > 0) AND ("validity_months" IS NULL))))))
);


ALTER TABLE "public"."reward_offers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."reward_offers"."validity_months" IS 'Positive calendar-month count when validity_is_unlimited is false.';



COMMENT ON COLUMN "public"."reward_offers"."validity_is_unlimited" IS 'Explicitly distinguishes unlimited validity from a missing month count.';



COMMENT ON COLUMN "public"."reward_offers"."usage_limit_is_unlimited" IS 'For multi-use offers, explicitly distinguishes unlimited uses from a numeric limit.';



COMMENT ON COLUMN "public"."reward_offers"."agreement_ends_at" IS 'Fixed merchant agreement end; new purchases stop at this instant, while issued coupons keep their snapshotted validity.';



COMMENT ON COLUMN "public"."reward_offers"."valid_branches" IS 'JSON array of business-provided branch labels/addresses when branch_scope is selected_branches.';



COMMENT ON COLUMN "public"."reward_offers"."validity_days" IS 'Positive day count when validity_is_unlimited is false and validity_months is null.';



CREATE TABLE IF NOT EXISTS "public"."reward_redemptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "reward_offer_id" "text" NOT NULL,
    "points_cost" integer NOT NULL,
    "redemption_type" "text" NOT NULL,
    "code" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "offer_title_snapshot" "text" NOT NULL,
    "partner_name_snapshot" "text" NOT NULL,
    "summary_snapshot" "text" NOT NULL,
    "terms_snapshot" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "expires_at" timestamp with time zone,
    CONSTRAINT "reward_redemptions_points_cost_check" CHECK (("points_cost" > 0)),
    CONSTRAINT "reward_redemptions_redemption_type_check" CHECK (("redemption_type" = ANY (ARRAY['store_qr'::"text", 'online_code'::"text", 'campaign_link'::"text"])))
);


ALTER TABLE "public"."reward_redemptions" OWNER TO "postgres";


ALTER TABLE ONLY "public"."favorite_districts"
    ADD CONSTRAINT "favorite_districts_pkey" PRIMARY KEY ("user_id", "district_name");



ALTER TABLE ONLY "public"."parking_report_feedback"
    ADD CONSTRAINT "parking_report_feedback_once_per_user" UNIQUE ("report_id", "user_id");



ALTER TABLE ONLY "public"."parking_report_feedback"
    ADD CONSTRAINT "parking_report_feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."parking_reports"
    ADD CONSTRAINT "parking_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_feedback_event_once" UNIQUE ("feedback_id", "event_type");



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reward_offers"
    ADD CONSTRAINT "reward_offers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reward_redemptions"
    ADD CONSTRAINT "reward_redemptions_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."reward_redemptions"
    ADD CONSTRAINT "reward_redemptions_pkey" PRIMARY KEY ("id");



CREATE INDEX "parking_report_feedback_report_id_idx" ON "public"."parking_report_feedback" USING "btree" ("report_id");



CREATE INDEX "parking_reports_created_at_idx" ON "public"."parking_reports" USING "btree" ("created_at" DESC);



CREATE INDEX "parking_reports_location_gix" ON "public"."parking_reports" USING "gist" ("location");



CREATE UNIQUE INDEX "point_transactions_photo_report_once" ON "public"."point_transactions" USING "btree" ("report_id") WHERE ("event_type" = 'photo_report_reward'::"text");



CREATE INDEX "point_transactions_user_created_idx" ON "public"."point_transactions" USING "btree" ("user_id", "created_at" DESC, "id" DESC);



CREATE INDEX "reward_redemptions_user_created_idx" ON "public"."reward_redemptions" USING "btree" ("user_id", "created_at" DESC, "id" DESC);



CREATE INDEX "reward_redemptions_user_offer_created_idx" ON "public"."reward_redemptions" USING "btree" ("user_id", "reward_offer_id", "created_at" DESC);



CREATE OR REPLACE TRIGGER "parking_feedback_award_points" AFTER INSERT ON "public"."parking_report_feedback" FOR EACH ROW EXECUTE FUNCTION "app_private"."award_points_for_parked_feedback"();



CREATE OR REPLACE TRIGGER "parking_report_photo_points_on_attach" AFTER UPDATE OF "photo_object_path" ON "public"."parking_reports" FOR EACH ROW WHEN ((("old"."photo_object_path" IS NULL) AND ("new"."photo_object_path" IS NOT NULL))) EXECUTE FUNCTION "app_private"."award_points_for_report_photo"();



CREATE OR REPLACE TRIGGER "parking_report_photo_points_on_create" AFTER INSERT ON "public"."parking_reports" FOR EACH ROW EXECUTE FUNCTION "app_private"."award_points_for_report_photo"();



CREATE OR REPLACE TRIGGER "profiles_touch_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_profile_updated_at"();



ALTER TABLE ONLY "public"."favorite_districts"
    ADD CONSTRAINT "favorite_districts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."parking_report_feedback"
    ADD CONSTRAINT "parking_report_feedback_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "public"."parking_reports"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."parking_report_feedback"
    ADD CONSTRAINT "parking_report_feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_reward_redemption_id_fkey" FOREIGN KEY ("reward_redemption_id") REFERENCES "public"."reward_redemptions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."point_transactions"
    ADD CONSTRAINT "point_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reward_redemptions"
    ADD CONSTRAINT "reward_redemptions_reward_offer_id_fkey" FOREIGN KEY ("reward_offer_id") REFERENCES "public"."reward_offers"("id");



ALTER TABLE ONLY "public"."reward_redemptions"
    ADD CONSTRAINT "reward_redemptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can read active reward offers" ON "public"."reward_offers" FOR SELECT TO "authenticated" USING ("is_active");



ALTER TABLE "public"."favorite_districts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "favorite_districts_delete_own" ON "public"."favorite_districts" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "favorite_districts_insert_own" ON "public"."favorite_districts" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "favorite_districts_read_own" ON "public"."favorite_districts" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."parking_report_feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."parking_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."point_transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "point_transactions_read_own" ON "public"."point_transactions" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_read_own" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."reward_offers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reward_redemptions" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "app_private" TO "authenticated";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































REVOKE ALL ON FUNCTION "app_private"."anonymize_account_data"("p_user_id" "uuid") FROM PUBLIC;



REVOKE ALL ON FUNCTION "app_private"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "app_private"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "app_private"."award_points_for_parked_feedback"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "app_private"."award_points_for_report_photo"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "app_private"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "app_private"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "app_private"."get_report_author_trust_summary"("p_user_id" "uuid") FROM PUBLIC;

























































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































REVOKE ALL ON FUNCTION "public"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."attach_leaving_report_photo"("p_report_id" "uuid", "p_photo_object_path" "text", "p_latitude" double precision, "p_longitude" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."cancel_my_parking_report"("p_report_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_my_parking_report"("p_report_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_parking_report"("p_kind" "text", "p_latitude" double precision, "p_longitude" double precision, "p_note" "text", "p_photo_object_path" "text", "p_estimated_departure_minutes" smallint, "p_leaving_presence" "text", "p_device_latitude" double precision, "p_device_longitude" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_active_parking_reports"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_active_parking_reports"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_account_export"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_account_export"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_parking_report_counts"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_parking_report_counts"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_parking_report_history"("p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_parking_report_history"("p_limit" integer, "p_offset" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_points_wallet"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_points_wallet"("p_limit" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_reward_redemptions"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_reward_redemptions"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_my_trust_score"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_my_trust_score"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_parking_report_feedback"("p_report_id" "uuid", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_parking_report_feedback"("p_report_id" "uuid", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."prepare_my_account_deletion"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."prepare_my_account_deletion"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."redeem_demo_reward"("p_reward_offer_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."redeem_demo_reward"("p_reward_offer_id" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."redeem_reward_offer"("p_reward_offer_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."redeem_reward_offer"("p_reward_offer_id" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."submit_parking_report_feedback"("p_report_id" "uuid", "p_outcome" "text", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_parking_report_feedback"("p_report_id" "uuid", "p_outcome" "text", "p_latitude" double precision, "p_longitude" double precision, "p_accuracy_meters" double precision) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."touch_profile_updated_at"() FROM PUBLIC;

















































































GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."favorite_districts" TO "service_role";
GRANT SELECT,INSERT,DELETE ON TABLE "public"."favorite_districts" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."parking_report_feedback" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."parking_reports" TO "service_role";



GRANT SELECT("author_id") ON TABLE "public"."parking_reports" TO "service_role";



GRANT SELECT("photo_object_path") ON TABLE "public"."parking_reports" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."point_transactions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("id"),INSERT("id") ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT("id") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("nickname"),INSERT("nickname"),UPDATE("nickname") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("avatar_object_path"),INSERT("avatar_object_path"),UPDATE("avatar_object_path") ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT("avatar_object_path") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("created_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("updated_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("full_name"),INSERT("full_name"),UPDATE("full_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."reward_offers" TO "service_role";
GRANT SELECT ON TABLE "public"."reward_offers" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."reward_redemptions" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";



































