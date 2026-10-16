-- STPG live convoy: driver locations
-- Setup steps: docs/SETUP.md.
-- Safe to run more than once (idempotent).

create table if not exists public.stpg_driver_locations (
  user_id uuid primary key references auth.users on delete cascade,
  driver_name text,
  driver_number int,
  latitude double precision not null,
  longitude double precision not null,
  speed_mph int,
  heading int,
  accuracy_ft int,
  sos boolean not null default false,
  sharing boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists stpg_driver_locations_updated_at_idx
  on public.stpg_driver_locations (updated_at);

alter table public.stpg_driver_locations enable row level security;

drop policy if exists "stpg_loc_select" on public.stpg_driver_locations;
create policy "stpg_loc_select" on public.stpg_driver_locations
  for select to authenticated
  using (sharing = true or user_id = auth.uid());

drop policy if exists "stpg_loc_insert" on public.stpg_driver_locations;
create policy "stpg_loc_insert" on public.stpg_driver_locations
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "stpg_loc_update" on public.stpg_driver_locations;
create policy "stpg_loc_update" on public.stpg_driver_locations
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "stpg_loc_delete" on public.stpg_driver_locations;
create policy "stpg_loc_delete" on public.stpg_driver_locations
  for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.stpg_driver_locations to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.stpg_driver_locations;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
