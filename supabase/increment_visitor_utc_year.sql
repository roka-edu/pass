-- Visitor counter reset policy
-- today: UTC 00:00:00 through UTC 23:59:59
-- total: UTC calendar year, January 1 through December 31

create table if not exists public.visitor_daily_counts_utc (
  visit_date date primary key,
  visit_count bigint not null default 0 check (visit_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.visitor_daily_counts_utc enable row level security;

create or replace function public.increment_visitor()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  utc_now timestamp := timezone('UTC', now());
  utc_today date := utc_now::date;
  utc_year_start date := make_date(extract(year from utc_now)::int, 1, 1);
  utc_next_year_start date := make_date(extract(year from utc_now)::int + 1, 1, 1);
  today_count bigint;
  year_total bigint;
begin
  insert into public.visitor_daily_counts_utc (visit_date, visit_count, updated_at)
  values (utc_today, 1, now())
  on conflict (visit_date)
  do update set
    visit_count = public.visitor_daily_counts_utc.visit_count + 1,
    updated_at = now()
  returning visit_count into today_count;

  select coalesce(sum(visit_count), 0)
  into year_total
  from public.visitor_daily_counts_utc
  where visit_date >= utc_year_start
    and visit_date < utc_next_year_start;

  return jsonb_build_object(
    'today', today_count,
    'total', year_total,
    'basis', 'UTC',
    'total_period_start', utc_year_start,
    'total_period_end', utc_next_year_start - 1
  );
end;
$$;

grant execute on function public.increment_visitor() to anon, authenticated;
