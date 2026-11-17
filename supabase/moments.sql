-- Password-protected "MyMoments" list for marriage/countdown.
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Then set the password with the separate one-line snippet (never commit the password).
--
-- The items live in the "private" schema, which the public page key cannot read.
-- The page can only reach them through the functions below, and each one checks the password first.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.moments (
  id          text primary key,
  text        text not null check (char_length(text) between 1 and 120),
  done        boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Holds a single bcrypt hash of the password.
create table if not exists private.moments_secret (
  id    int primary key default 1 check (id = 1),
  hash  text not null
);

create or replace function private.moments_ok(pw text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.moments_secret s
    where s.hash = extensions.crypt(coalesce(pw, ''), s.hash)
  );
$$;

create or replace function public.moments_list(pw text)
returns table (id text, text text, done boolean)
language plpgsql security definer set search_path = '' as $$
begin
  if not private.moments_ok(pw) then raise exception 'wrong password' using errcode = '28P01'; end if;
  return query select m.id, m.text, m.done from private.moments m order by m.created_at, m.id;
end $$;

create or replace function public.moments_add(pw text, item_id text, item_text text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.moments_ok(pw) then raise exception 'wrong password' using errcode = '28P01'; end if;
  insert into private.moments (id, text) values (item_id, item_text);
end $$;

create or replace function public.moments_set_done(pw text, item_id text, is_done boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.moments_ok(pw) then raise exception 'wrong password' using errcode = '28P01'; end if;
  update private.moments set done = is_done, updated_at = now() where id = item_id;
end $$;

create or replace function public.moments_delete(pw text, item_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.moments_ok(pw) then raise exception 'wrong password' using errcode = '28P01'; end if;
  delete from private.moments where id = item_id;
end $$;

revoke all on function private.moments_ok(text) from public, anon, authenticated;
revoke all on function public.moments_list(text) from public;
revoke all on function public.moments_add(text, text, text) from public;
revoke all on function public.moments_set_done(text, text, boolean) from public;
revoke all on function public.moments_delete(text, text) from public;
grant execute on function public.moments_list(text) to anon, authenticated;
grant execute on function public.moments_add(text, text, text) to anon, authenticated;
grant execute on function public.moments_set_done(text, text, boolean) to anon, authenticated;
grant execute on function public.moments_delete(text, text) to anon, authenticated;
