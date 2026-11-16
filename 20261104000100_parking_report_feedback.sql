begin;

-- One authenticated driver can report one outcome for each short-lived report.
create table public.parking_report_feedback (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null
    references public.parking_reports(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  outcome text not null
    check (outcome in ('parked', 'occupied', 'not_found')),
  created_at timestamptz not null default now(),
  constraint parking_report_feedback_once_per_user
    unique (report_id, user_id)
);

create index parking_report_feedback_report_id_idx
  on public.parking_report_feedback (report_id);

alter table public.parking_report_feedback enable row level security;
revoke all on table public.parking_report_feedback from anon, authenticated;

-- Feedback is accepted only while the report is active, from a different
-- signed-in user, and once per user/report pair. User IDs are never exposed.
create function public.get_parking_report_feedback(p_report_id uuid)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.parking_reports as report
    where report.id = p_report_id
      and report.created_at > (now() - interval '10 minutes')
  ) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;

  return query
  select
    count(*) filter (where feedback.outcome = 'parked'),
    count(*) filter (where feedback.outcome = 'occupied'),
    count(*) filter (where feedback.outcome = 'not_found'),
    max(feedback.outcome) filter (where feedback.user_id = v_user_id),
    (select report.author_id <> v_user_id
     from public.parking_reports as report
     where report.id = p_report_id)
  from public.parking_report_feedback as feedback
  where feedback.report_id = p_report_id;
end;
$$;

create function public.submit_parking_report_feedback(
  p_report_id uuid,
  p_outcome text
)
returns table (
  parked_count bigint,
  occupied_count bigint,
  not_found_count bigint,
  my_outcome text,
  can_submit boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Sign-in required.' using errcode = '28000';
  end if;
  if p_outcome not in ('parked', 'occupied', 'not_found') then
    raise exception 'Invalid feedback outcome.' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.parking_reports as report
    where report.id = p_report_id
      and report.created_at > (now() - interval '10 minutes')
  ) then
    raise exception 'This report is unavailable for feedback.'
      using errcode = 'P0002';
  end if;
  if exists (
    select 1
    from public.parking_reports as report
    where report.id = p_report_id
      and report.author_id = v_user_id
  ) then
    raise exception 'Report creators cannot submit feedback.'
      using errcode = '42501';
  end if;

  insert into public.parking_report_feedback (report_id, user_id, outcome)
  values (p_report_id, v_user_id, p_outcome);

  return query
  select * from public.get_parking_report_feedback(p_report_id);
end;
$$;

revoke all on function public.get_parking_report_feedback(uuid)
  from public, anon, authenticated;
revoke all on function public.submit_parking_report_feedback(uuid, text)
  from public, anon, authenticated;
grant execute on function public.get_parking_report_feedback(uuid)
  to authenticated;
grant execute on function public.submit_parking_report_feedback(uuid, text)
  to authenticated;

commit;
