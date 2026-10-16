-- STPG push notifications: device tokens + triggers that call the `stpg-push` Edge Function.
-- Run in Supabase Dashboard → SQL Editor → paste → Run. Safe to run more than once.

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

-- 2) Where the Edge Function lives (service role only: RLS on, no policies).
create table if not exists public.stpg_push_config (
  id            int primary key default 1 check (id = 1),
  function_url  text,   -- e.g. https://zastfoacrnuhzztvgsck.supabase.co/functions/v1/stpg-push
  service_key   text    -- the project's service_role key (keep secret)
);
alter table public.stpg_push_config enable row level security;
insert into public.stpg_push_config (id) values (1) on conflict (id) do nothing;

-- 3) Trigger function: forwards the new row to the Edge Function.
create or replace function public.stpg_notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare cfg record;
begin
  select function_url, service_key into cfg from public.stpg_push_config where id = 1;
  if cfg.function_url is null or cfg.service_key is null then
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
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || cfg.service_key),
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
