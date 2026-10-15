-- User reports on feedback/comments (App Store guideline 1.2) + iOS update settings.

create table if not exists public.content_reports (
  id bigint generated always as identity primary key,
  target_type text not null check (target_type in ('feedback', 'comment')),
  target_id bigint not null,
  reporter_token text not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (target_type, target_id, reporter_token)
);
alter table public.content_reports enable row level security;
revoke all on public.content_reports from anon, authenticated;

create or replace function public.report_content(
  p_target_type text,
  p_target_id bigint,
  p_device_token text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if p_target_type not in ('feedback', 'comment') then
    raise exception 'invalid target type';
  end if;
  if coalesce(p_device_token, '') = '' then
    raise exception 'device token required';
  end if;
  insert into public.content_reports (target_type, target_id, reporter_token, reason)
  values (p_target_type, p_target_id, left(p_device_token, 100), left(p_reason, 200))
  on conflict (target_type, target_id, reporter_token) do nothing;
end;
$$;

-- Only reports whose target still exists, so deleted posts drop out on their own.
create or replace function public.admin_get_reports(p_key text)
returns table (target_type text, target_id bigint, report_count bigint, last_reported_at timestamptz)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.admin_verify(p_key) then
    raise exception 'not authorized';
  end if;
  return query
    select r.target_type, r.target_id, count(*)::bigint, max(r.created_at)
    from public.content_reports r
    where (r.target_type = 'feedback' and exists (select 1 from public.feedback f where f.id = r.target_id))
       or (r.target_type = 'comment' and exists (select 1 from public.feedback_comments c where c.id = r.target_id))
    group by r.target_type, r.target_id;
end;
$$;

alter table public.app_config
  add column if not exists ios_latest_build int not null default 0,
  add column if not exists ios_min_build int not null default 0,
  add column if not exists ios_store_url text;

create or replace function public.get_app_config()
returns json
language sql
stable
security definer
set search_path to 'public'
as $$
  select json_build_object(
    'latest_version_code', latest_version_code,
    'min_version_code', min_version_code,
    'update_message', update_message,
    'ios_latest_build', ios_latest_build,
    'ios_min_build', ios_min_build,
    'ios_store_url', ios_store_url
  )
  from public.app_config
  where id = 1;
$$;

grant execute on function public.report_content(text, bigint, text, text) to anon, authenticated;
grant execute on function public.admin_get_reports(text) to anon, authenticated;
grant execute on function public.get_app_config() to anon, authenticated;
