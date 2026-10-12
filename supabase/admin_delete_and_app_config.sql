-- Admin moderation + app update config.
-- The admin key is never stored in plain text: only its SHA-256 hex digest lives in
-- public.app_admin (row inserted separately, not committed to this repo).

create table if not exists public.app_admin (
  id int primary key default 1 check (id = 1),
  key_hash text not null
);
alter table public.app_admin enable row level security;
revoke all on public.app_admin from anon, authenticated;

create table if not exists public.app_config (
  id int primary key default 1 check (id = 1),
  latest_version_code int not null default 0,
  min_version_code int not null default 0,
  update_message text
);
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
insert into public.app_config (id, latest_version_code, min_version_code)
values (1, 0, 0)
on conflict (id) do nothing;

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
    'update_message', update_message
  )
  from public.app_config
  where id = 1;
$$;

create or replace function public.admin_verify(p_key text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.app_admin
    where id = 1
      and key_hash = encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex')
  );
$$;

create or replace function public.admin_delete_feedback(p_id bigint, p_key text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.admin_verify(p_key) then
    raise exception 'not authorized';
  end if;
  delete from public.feedback_comments where feedback_id = p_id;
  delete from public.feedback where id = p_id;
end;
$$;

-- Unlike delete_comment, this also removes the comment's replies so none are left orphaned.
create or replace function public.admin_delete_comment(p_id bigint, p_key text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.admin_verify(p_key) then
    raise exception 'not authorized';
  end if;
  delete from public.feedback_comments where parent_comment_id = p_id;
  delete from public.feedback_comments where id = p_id;
end;
$$;

grant execute on function public.get_app_config() to anon, authenticated;
grant execute on function public.admin_verify(text) to anon, authenticated;
grant execute on function public.admin_delete_feedback(bigint, text) to anon, authenticated;
grant execute on function public.admin_delete_comment(bigint, text) to anon, authenticated;
