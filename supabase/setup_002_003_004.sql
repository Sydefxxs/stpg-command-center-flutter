-- One-time setup for an existing STPG project that already ran 000 and 001.
-- Contains 002 + 003 + 004. Paste everything into Supabase → SQL Editor → Run. Safe to run again.

-- ===== 002_push_tokens.sql =====
-- STPG push notifications: device tokens + triggers that call the `stpg-push` Edge Function.
-- Safe to run more than once. Setup steps: docs/SETUP.md.

create extension if not exists pg_net;

-- 1) Device tokens (one row per phone/tablet)
create table if not exists public.stpg_push_tokens (
  token       text primary key,
  user_id     uuid not null references auth.users on delete cascade,
  platform    text,
  updated_at  timestamptz not null default now()
);
alter table public.stpg_push_tokens enable row level security;

drop policy if exists "own tokens select" on public.stpg_push_tokens;
drop policy if exists "own tokens insert" on public.stpg_push_tokens;
drop policy if exists "own tokens update" on public.stpg_push_tokens;
drop policy if exists "own tokens delete" on public.stpg_push_tokens;
create policy "own tokens select" on public.stpg_push_tokens for select to authenticated using (user_id = auth.uid());
create policy "own tokens insert" on public.stpg_push_tokens for insert to authenticated with check (user_id = auth.uid());
create policy "own tokens update" on public.stpg_push_tokens for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own tokens delete" on public.stpg_push_tokens for delete to authenticated using (user_id = auth.uid());

-- 2) Where the Edge Function lives + the shared secret it checks.
--    Locked down: RLS on, no policies, no grants to app roles (only the trigger reads it).
create table if not exists public.stpg_push_config (
  id              int primary key default 1 check (id = 1),
  function_url    text,
  webhook_secret  text
);
alter table public.stpg_push_config add column if not exists webhook_secret text;
alter table public.stpg_push_config drop column if exists service_key;
alter table public.stpg_push_config enable row level security;
revoke all on public.stpg_push_config from anon, authenticated;
insert into public.stpg_push_config (id) values (1) on conflict (id) do nothing;

-- 3) Trigger function: forwards the new row to the Edge Function.
create or replace function public.stpg_notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare cfg record;
begin
  select function_url, webhook_secret into cfg from public.stpg_push_config where id = 1;
  if cfg.function_url is null or cfg.webhook_secret is null then
    return new; -- push not configured yet
  end if;
  -- Missions: only when they become ACTIVE. Assistance: only new ACTIVE requests.
  if tg_table_name = 'stpg_missions' and (new.status is distinct from 'ACTIVE'
       or (tg_op = 'UPDATE' and old.status = 'ACTIVE')) then
    return new;
  end if;
  if tg_table_name = 'stpg_assistance_requests' and new.status is distinct from 'ACTIVE' then
    return new;
  end if;
  perform net.http_post(
    url := cfg.function_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-stpg-webhook-secret', cfg.webhook_secret),
    body := jsonb_build_object('type', tg_table_name, 'record', to_jsonb(new))
  );
  return new;
end $$;

drop trigger if exists stpg_push_dispatch on public.stpg_dispatches;
create trigger stpg_push_dispatch after insert on public.stpg_dispatches
  for each row execute function public.stpg_notify_push();

drop trigger if exists stpg_push_mission on public.stpg_missions;
create trigger stpg_push_mission after insert or update of status on public.stpg_missions
  for each row execute function public.stpg_notify_push();

drop trigger if exists stpg_push_assistance on public.stpg_assistance_requests;
create trigger stpg_push_assistance after insert on public.stpg_assistance_requests
  for each row execute function public.stpg_notify_push();

revoke execute on function public.stpg_notify_push() from public, anon, authenticated;

-- ===== 003_hazards.sql =====
-- STPG hazard pins: drivers mark a spot (washout, deep sand, police…) for the whole convoy.
-- Pins expire after 12 hours. Safe to run more than once.
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

-- Only known kinds, short notes, real coordinates.
alter table public.stpg_hazards drop constraint if exists stpg_hazards_kind_chk;
alter table public.stpg_hazards add constraint stpg_hazards_kind_chk check (kind in
  ('WASHOUT','DEEP SAND','MUD','ROCKS','WATER CROSSING','LIVESTOCK','DEBRIS','POLICE','OTHER'));
alter table public.stpg_hazards drop constraint if exists stpg_hazards_note_chk;
alter table public.stpg_hazards add constraint stpg_hazards_note_chk check (note is null or char_length(note) <= 280);
alter table public.stpg_hazards drop constraint if exists stpg_hazards_coords_chk;
alter table public.stpg_hazards add constraint stpg_hazards_coords_chk check
  (latitude between -90 and 90 and longitude between -180 and 180);

alter table public.stpg_hazards enable row level security;
drop policy if exists "hazards read" on public.stpg_hazards;
drop policy if exists "hazards insert own" on public.stpg_hazards;
drop policy if exists "hazards delete own or admin" on public.stpg_hazards;
create policy "hazards read" on public.stpg_hazards for select to authenticated using (true);
create policy "hazards insert own" on public.stpg_hazards for insert to authenticated with check (user_id = auth.uid());
create policy "hazards delete own or admin" on public.stpg_hazards for delete to authenticated
  using (user_id = auth.uid() or public.is_stpg_admin());
grant select, insert, delete on public.stpg_hazards to authenticated;

-- The server fills in who reported it and when it expires (clients can't fake either).
create or replace function public.stpg_hazard_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.user_id := auth.uid();
  new.created_at := now();
  new.expires_at := now() + interval '12 hours';
  select full_name into new.driver_name from public.founding_drivers where user_id = auth.uid();
  return new;
end $$;
drop trigger if exists stpg_hazard_defaults on public.stpg_hazards;
create trigger stpg_hazard_defaults before insert on public.stpg_hazards
  for each row execute function public.stpg_hazard_defaults();

-- ===== 004_security.sql =====
-- STPG security hardening. Run after 000–003. Safe to run more than once.
--
-- 1) Approved drivers only: anyone can create a login, but only drivers an admin has
--    approved (or admins) can see the convoy, hazards, dispatches and missions.
-- 2) Drivers can't change their own driver number or approval.
-- 3) Names on convoy positions come from the driver profile, not from the phone.

-- ---------- 1) Approval ----------
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'founding_drivers' and column_name = 'approved') then
    alter table public.founding_drivers add column approved boolean not null default false;
    update public.founding_drivers set approved = true;  -- drivers that already exist stay approved
  end if;
end $$;

create or replace function public.is_stpg_member() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_stpg_admin()
      or exists (select 1 from public.founding_drivers where user_id = auth.uid() and approved);
$$;
grant execute on function public.is_stpg_member() to authenticated;

-- Profiles: see your own, members see everyone (needed for the convoy list).
drop policy if exists "drivers read" on public.founding_drivers;
create policy "drivers read" on public.founding_drivers for select to authenticated
  using (user_id = auth.uid() or public.is_stpg_member());

drop policy if exists "dispatch read" on public.stpg_dispatches;
create policy "dispatch read" on public.stpg_dispatches for select to authenticated using (public.is_stpg_member());
drop policy if exists "missions read" on public.stpg_missions;
create policy "missions read" on public.stpg_missions for select to authenticated using (public.is_stpg_member());
drop policy if exists "radio read" on public.stpg_radio_settings;
create policy "radio read" on public.stpg_radio_settings for select to authenticated using (public.is_stpg_member());

-- Live convoy
drop policy if exists "stpg_loc_select" on public.stpg_driver_locations;
create policy "stpg_loc_select" on public.stpg_driver_locations for select to authenticated
  using (user_id = auth.uid() or (sharing and public.is_stpg_member()));
drop policy if exists "stpg_loc_insert" on public.stpg_driver_locations;
create policy "stpg_loc_insert" on public.stpg_driver_locations for insert to authenticated
  with check (user_id = auth.uid() and public.is_stpg_member());
drop policy if exists "stpg_loc_update" on public.stpg_driver_locations;
create policy "stpg_loc_update" on public.stpg_driver_locations for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_stpg_member());

-- Hazards
drop policy if exists "hazards read" on public.stpg_hazards;
create policy "hazards read" on public.stpg_hazards for select to authenticated using (public.is_stpg_member());
drop policy if exists "hazards insert own" on public.stpg_hazards;
create policy "hazards insert own" on public.stpg_hazards for insert to authenticated
  with check (user_id = auth.uid() and public.is_stpg_member());

-- ---------- 2) Protected profile fields ----------
create or replace function public.stpg_protect_driver() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_stpg_admin() then
    new.user_id := old.user_id;
    new.driver_number := old.driver_number;
    new.approved := old.approved;
  end if;
  return new;
end $$;
drop trigger if exists stpg_protect_driver on public.founding_drivers;
create trigger stpg_protect_driver before update on public.founding_drivers
  for each row execute function public.stpg_protect_driver();

-- ---------- 3) Server-filled convoy identity + sane values ----------
create or replace function public.stpg_location_identity() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select full_name, driver_number into new.driver_name, new.driver_number
    from public.founding_drivers where user_id = new.user_id;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists stpg_location_identity on public.stpg_driver_locations;
create trigger stpg_location_identity before insert or update on public.stpg_driver_locations
  for each row execute function public.stpg_location_identity();

alter table public.stpg_driver_locations drop constraint if exists stpg_loc_coords_chk;
alter table public.stpg_driver_locations add constraint stpg_loc_coords_chk check
  (latitude between -90 and 90 and longitude between -180 and 180);

-- Assistance messages: keep them short.
alter table public.stpg_assistance_requests drop constraint if exists stpg_assist_msg_chk;
alter table public.stpg_assistance_requests add constraint stpg_assist_msg_chk check
  (message is null or char_length(message) <= 1000);

