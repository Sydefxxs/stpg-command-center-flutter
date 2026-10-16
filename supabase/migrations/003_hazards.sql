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
