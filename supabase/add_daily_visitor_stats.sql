-- Add daily and 6-hour visitor stats while keeping the existing page-view counter behavior.
--
-- Existing behavior:
-- - Every page load increments visitor_stats.total_count.
-- - visitor_stats.today_count resets when CURRENT_DATE changes.
--
-- New behavior:
-- - Every page load also increments visitor_daily_stats.visit_count for CURRENT_DATE.
-- - Every page load also increments visitor_6h_stats.visit_count for the current Asia/Seoul 6-hour bucket.
-- - Today's current visitor_stats.today_count is seeded into visitor_daily_stats once.

create table if not exists public.visitor_daily_stats (
  visit_date date primary key,
  visit_count bigint not null default 0 check (visit_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.visitor_daily_stats enable row level security;

create table if not exists public.visitor_6h_stats (
  bucket_date date not null,
  bucket_start_hour smallint not null check (bucket_start_hour in (0, 6, 12, 18)),
  bucket_end_hour smallint not null check (bucket_end_hour in (5, 11, 17, 23)),
  timezone_name text not null default 'Asia/Seoul',
  visit_count bigint not null default 0 check (visit_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (bucket_date, bucket_start_hour, timezone_name)
);

alter table public.visitor_6h_stats enable row level security;

insert into public.visitor_daily_stats (visit_date, visit_count, updated_at)
select today_date, today_count, now()
from public.visitor_stats
where id = 1
  and today_date is not null
on conflict (visit_date)
do update set
  visit_count = greatest(public.visitor_daily_stats.visit_count, excluded.visit_count),
  updated_at = now();

create or replace function public.increment_visitor()
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_today date := current_date;
  v_total_count bigint;
  v_today_count bigint;
  v_daily_count bigint;
  v_kst_now timestamp := timezone('Asia/Seoul', now());
  v_bucket_date date := v_kst_now::date;
  v_bucket_start_hour smallint := (floor(extract(hour from v_kst_now) / 6) * 6)::smallint;
  v_bucket_end_hour smallint := ((floor(extract(hour from v_kst_now) / 6) * 6) + 5)::smallint;
  v_bucket_count bigint;
  v_result json;
begin
  update public.visitor_stats
  set
    total_count = total_count + 1,
    today_count = case
      when today_date = v_today then today_count + 1
      else 1
    end,
    today_date = v_today
  where id = 1
  returning total_count, today_count
  into v_total_count, v_today_count;

  insert into public.visitor_daily_stats (visit_date, visit_count, updated_at)
  values (v_today, 1, now())
  on conflict (visit_date)
  do update set
    visit_count = public.visitor_daily_stats.visit_count + 1,
    updated_at = now()
  returning visit_count into v_daily_count;

  insert into public.visitor_6h_stats (
    bucket_date,
    bucket_start_hour,
    bucket_end_hour,
    timezone_name,
    visit_count,
    updated_at
  )
  values (
    v_bucket_date,
    v_bucket_start_hour,
    v_bucket_end_hour,
    'Asia/Seoul',
    1,
    now()
  )
  on conflict (bucket_date, bucket_start_hour, timezone_name)
  do update set
    visit_count = public.visitor_6h_stats.visit_count + 1,
    bucket_end_hour = excluded.bucket_end_hour,
    updated_at = now()
  returning visit_count into v_bucket_count;

  v_result := json_build_object(
    'total', v_total_count,
    'today', v_today_count,
    'daily', v_daily_count,
    'bucket_6h', v_bucket_count,
    'bucket_date', v_bucket_date,
    'bucket_start_hour', v_bucket_start_hour,
    'bucket_end_hour', v_bucket_end_hour,
    'bucket_timezone', 'Asia/Seoul'
  );

  return v_result;
end;
$function$;

grant execute on function public.increment_visitor() to anon, authenticated;

-- Check daily stats after running this script:
-- select visit_date, visit_count
-- from public.visitor_daily_stats
-- order by visit_date desc;

-- Check 6-hour stats after running this script:
-- select
--   bucket_date,
--   lpad(bucket_start_hour::text, 2, '0') || ':00 ~ ' ||
--     lpad(bucket_end_hour::text, 2, '0') || ':59' as bucket_time,
--   timezone_name,
--   visit_count
-- from public.visitor_6h_stats
-- order by bucket_date desc, bucket_start_hour desc;
