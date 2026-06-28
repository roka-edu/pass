-- Add daily visitor stats while keeping the existing page-view counter behavior.
--
-- Existing behavior:
-- - Every page load increments visitor_stats.total_count.
-- - visitor_stats.today_count resets when CURRENT_DATE changes.
--
-- New behavior:
-- - Every page load also increments visitor_daily_stats.visit_count for CURRENT_DATE.
-- - Today's current visitor_stats.today_count is seeded into visitor_daily_stats once.

create table if not exists public.visitor_daily_stats (
  visit_date date primary key,
  visit_count bigint not null default 0 check (visit_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.visitor_daily_stats enable row level security;

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

  v_result := json_build_object(
    'total', v_total_count,
    'today', v_today_count,
    'daily', v_daily_count
  );

  return v_result;
end;
$function$;

grant execute on function public.increment_visitor() to anon, authenticated;

-- Check daily stats after running this script:
-- select visit_date, visit_count
-- from public.visitor_daily_stats
-- order by visit_date desc;
