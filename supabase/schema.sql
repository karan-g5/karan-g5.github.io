-- Shared wedding checklist for marriage/countdown.
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.

create table if not exists public.checklist_items (
  id          text primary key,
  text        text not null check (char_length(text) between 1 and 120),
  type        text not null check (char_length(type) between 1 and 60),
  done        boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.checklist_types (
  name        text primary key check (char_length(name) between 1 and 60),
  created_at  timestamptz not null default now()
);

alter table public.checklist_items enable row level security;
alter table public.checklist_types enable row level security;

-- Anyone with the page link can read and edit the list.
drop policy if exists "page can read and edit items" on public.checklist_items;
create policy "page can read and edit items" on public.checklist_items
  for all to anon, authenticated using (true) with check (true);

drop policy if exists "page can read and edit types" on public.checklist_types;
create policy "page can read and edit types" on public.checklist_types
  for all to anon, authenticated using (true) with check (true);

grant select, insert, update, delete on public.checklist_items to anon, authenticated;
grant select, insert, update, delete on public.checklist_types to anon, authenticated;

-- Live updates: other open phones refresh as soon as something changes.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'checklist_items') then
    alter publication supabase_realtime add table public.checklist_items;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'checklist_types') then
    alter publication supabase_realtime add table public.checklist_types;
  end if;
end $$;
