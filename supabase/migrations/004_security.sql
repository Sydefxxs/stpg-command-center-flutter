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

