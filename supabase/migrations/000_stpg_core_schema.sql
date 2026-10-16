-- STPG Command Center — core schema for a fresh Supabase project (dev/test backend).
-- Recreates everything the app reads/writes on the original STPG backend.
-- Safe to run more than once. Setup steps: docs/SETUP.md.

-- ============ Admins ============
create table if not exists public.stpg_admins (
  user_id uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.stpg_admins enable row level security;
drop policy if exists "admins read own" on public.stpg_admins;
create policy "admins read own" on public.stpg_admins for select to authenticated using (user_id = auth.uid());

create or replace function public.is_stpg_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.stpg_admins where user_id = auth.uid());
$$;
grant execute on function public.is_stpg_admin() to authenticated;

-- ============ Founding drivers (profile) ============
create sequence if not exists public.stpg_driver_number_seq start 1;
create table if not exists public.founding_drivers (
  user_id uuid primary key references auth.users on delete cascade,
  full_name text,
  driver_number int unique default nextval('public.stpg_driver_number_seq'),
  vehicle text,
  created_at timestamptz not null default now()
);
alter table public.founding_drivers enable row level security;
drop policy if exists "drivers read" on public.founding_drivers;
drop policy if exists "drivers update own" on public.founding_drivers;
drop policy if exists "admins manage drivers" on public.founding_drivers;
create policy "drivers read" on public.founding_drivers for select to authenticated using (true);
create policy "drivers update own" on public.founding_drivers for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "admins manage drivers" on public.founding_drivers for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

-- Every new sign-up gets a driver profile + number automatically.
create or replace function public.stpg_new_driver() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.founding_drivers (user_id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)))
  on conflict (user_id) do nothing;
  return new;
end $$;
drop trigger if exists stpg_on_auth_user_created on auth.users;
create trigger stpg_on_auth_user_created after insert on auth.users
  for each row execute function public.stpg_new_driver();
insert into public.founding_drivers (user_id, full_name)
  select id, split_part(email, '@', 1) from auth.users on conflict (user_id) do nothing;

-- ============ Badge photos ============
create table if not exists public.driver_badge_media (
  user_id uuid primary key references auth.users on delete cascade,
  badge_photo_path text,
  updated_at timestamptz not null default now()
);
alter table public.driver_badge_media enable row level security;
drop policy if exists "badge own" on public.driver_badge_media;
drop policy if exists "badge admin" on public.driver_badge_media;
create policy "badge own" on public.driver_badge_media for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "badge admin" on public.driver_badge_media for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

insert into storage.buckets (id, name, public) values ('driver-badge-photos', 'driver-badge-photos', false)
  on conflict (id) do nothing;
drop policy if exists "badge photos read own" on storage.objects;
drop policy if exists "badge photos admin" on storage.objects;
create policy "badge photos read own" on storage.objects for select to authenticated
  using (bucket_id = 'driver-badge-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "badge photos admin" on storage.objects for all to authenticated
  using (bucket_id = 'driver-badge-photos' and public.is_stpg_admin())
  with check (bucket_id = 'driver-badge-photos' and public.is_stpg_admin());

-- ============ Dispatches ============
create table if not exists public.stpg_dispatches (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  message text not null,
  recipient_type text not null default 'all',
  created_by uuid default auth.uid() references auth.users on delete set null,
  created_at timestamptz not null default now()
);
alter table public.stpg_dispatches enable row level security;
drop policy if exists "dispatch read" on public.stpg_dispatches;
drop policy if exists "dispatch admin write" on public.stpg_dispatches;
create policy "dispatch read" on public.stpg_dispatches for select to authenticated using (true);
create policy "dispatch admin write" on public.stpg_dispatches for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

-- ============ Missions ============
create table if not exists public.stpg_missions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructions text,
  deadline timestamptz,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.stpg_missions enable row level security;
drop policy if exists "missions read" on public.stpg_missions;
drop policy if exists "missions admin write" on public.stpg_missions;
create policy "missions read" on public.stpg_missions for select to authenticated using (true);
create policy "missions admin write" on public.stpg_missions for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

create table if not exists public.stpg_mission_interactions (
  mission_id uuid not null references public.stpg_missions on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  first_viewed_at timestamptz,
  completed_at timestamptz,
  primary key (mission_id, user_id)
);
alter table public.stpg_mission_interactions enable row level security;
drop policy if exists "interactions own" on public.stpg_mission_interactions;
drop policy if exists "interactions admin read" on public.stpg_mission_interactions;
create policy "interactions own" on public.stpg_mission_interactions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "interactions admin read" on public.stpg_mission_interactions for select to authenticated using (public.is_stpg_admin());

-- ============ Assistance / SOS ============
create table if not exists public.stpg_assistance_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  request_type text not null,
  message text,
  latitude double precision,
  longitude double precision,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.stpg_assistance_requests enable row level security;
drop policy if exists "assist own" on public.stpg_assistance_requests;
drop policy if exists "assist admin" on public.stpg_assistance_requests;
create policy "assist own" on public.stpg_assistance_requests for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "assist admin" on public.stpg_assistance_requests for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

-- ============ Shared GMRS channel ============
create table if not exists public.stpg_radio_settings (
  id text primary key,
  channel int check (channel between 1 and 22),
  updated_at timestamptz not null default now()
);
alter table public.stpg_radio_settings enable row level security;
drop policy if exists "radio read" on public.stpg_radio_settings;
drop policy if exists "radio admin" on public.stpg_radio_settings;
create policy "radio read" on public.stpg_radio_settings for select to authenticated using (true);
create policy "radio admin" on public.stpg_radio_settings for update to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());
insert into public.stpg_radio_settings (id, channel) values ('global', 5) on conflict (id) do nothing;

-- ============ Parts counter orders (admin) ============
create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  customer_name text, customer_address text, city text, state text, postal_code text, country text,
  email text, phone text, product_name text, quantity int default 1, vendor text,
  order_status text default 'NEW', payment_status text default 'PENDING'
);
alter table public.store_orders enable row level security;
drop policy if exists "orders admin" on public.store_orders;
create policy "orders admin" on public.store_orders for all to authenticated using (public.is_stpg_admin()) with check (public.is_stpg_admin());

-- ============ Sample data so the screens aren't empty ============
insert into public.stpg_dispatches (subject, message)
  select 'WELCOME TO STPG DEV', 'Test backend is online. Dispatches sent from the app appear here.'
  where not exists (select 1 from public.stpg_dispatches);
insert into public.stpg_missions (title, instructions, deadline, status)
  select 'COASTAL CONVOY SHAKEDOWN', 'Meet at Hacienda Ford, run the convoy to Beach Access #6 and record the route.', now() + interval '7 days', 'ACTIVE'
  where not exists (select 1 from public.stpg_missions);

