-- STPG hazard pins: drivers drop a pin (washout, deep sand, police...) and the whole convoy sees it.
-- Run in Supabase Dashboard → SQL Editor → paste → Run. Safe to run more than once.
create table if not exists public.stpg_hazards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  kind text not null,
  note text,
  latitude double precision not null,
  longitude double precision not null,
  driver_name text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '12 hours'
);
create index if not exists stpg_hazards_expires_idx on public.stpg_hazards (expires_at);
alter table public.stpg_hazards enable row level security;
drop policy if exists "hazards read" on public.stpg_hazards;
drop policy if exists "hazards insert own" on public.stpg_hazards;
drop policy if exists "hazards delete own or admin" on public.stpg_hazards;
create policy "hazards read" on public.stpg_hazards for select to authenticated using (true);
create policy "hazards insert own" on public.stpg_hazards for insert to authenticated with check (user_id = auth.uid());
create policy "hazards delete own or admin" on public.stpg_hazards for delete to authenticated
  using (user_id = auth.uid() or public.is_stpg_admin());
