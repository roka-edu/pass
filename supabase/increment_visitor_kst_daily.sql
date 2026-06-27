-- Visitor counter timezone fix
-- today: Asia/Seoul 00:00:00 through 23:59:59
-- total: keeps the existing cumulative counter behavior
--
-- Run this once in Supabase SQL Editor.

do $$
begin
  if to_regprocedure('public.increment_visitor_utc_backup()') is null then
    execute 'alter function public.increment_visitor() rename to increment_visitor_utc_backup';
  end if;
end;
$$;

create table if not exists public.visitor_daily_counts_kst (
  visit_date date primary key,
  visit_count bigint not null default 0 check (visit_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.visitor_daily_counts_kst enable row level security;

create or replace function public.increment_visitor()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_result jsonb;
  kst_today date := timezone('Asia/Seoul', now())::date;
  today_count bigint;
  total_count bigint;
begin
  existing_result := public.increment_visitor_utc_backup()::jsonb;

  insert into public.visitor_daily_counts_kst (visit_date, visit_count, updated_at)
  values (kst_today, 1, now())
  on conflict (visit_date)
  do update set
    visit_count = public.visitor_daily_counts_kst.visit_count + 1,
    updated_at = now()
  returning visit_count into today_count;

  total_count := coalesce((existing_result->>'total')::bigint, today_count);

  return jsonb_build_object(
    'today', today_count,
    'total', total_count,
    'today_basis', 'Asia/Seoul',
    'today_date', kst_today
  );
end;
$$;

grant execute on function public.increment_visitor() to anon, authenticated;
