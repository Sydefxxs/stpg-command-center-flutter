# Backend (Supabase)

The app talks to Supabase over plain REST (`lib/api/supabase_api.dart`) — no Supabase SDK. Row Level Security protects every table; only the **publishable** key is in the code.

| Backend | URL | Selected by |
|---|---|---|
| Dev (yours) | `https://wofuesquilkkniswpikn.supabase.co` | default (`STPG_BACKEND=dev`) |
| Original STPG | `https://zastfoacrnuhzztvgsck.supabase.co` | `--dart-define=STPG_BACKEND=stpg` |

## Migrations (run in Dashboard → SQL Editor, in order; all are safe to re-run)

| File | Creates | Needed for |
|---|---|---|
| `000_stpg_core_schema.sql` | `stpg_admins` + `is_stpg_admin()`, `founding_drivers` (auto-created on sign-up), `driver_badge_media` + `driver-badge-photos` bucket, `stpg_dispatches`, `stpg_missions`, `stpg_mission_interactions`, `stpg_assistance_requests`, `stpg_radio_settings`, `store_orders`, sample data | Everything (fresh project only) |
| `001_driver_locations.sql` | `stpg_driver_locations` (one row per driver: lat/lng, speed, heading, accuracy, sos, sharing) | Live convoy |
| `002_push_tokens.sql` | `stpg_push_tokens`, `stpg_push_config`, `pg_net` triggers on dispatches / missions / assistance | Push notifications |
| `003_hazards.sql` | `stpg_hazards` (kind, note, lat/lng, driver, 12 h expiry) | Hazard pins |

Make yourself an admin:
```sql
insert into public.stpg_admins (user_id) select id from auth.users where email = 'you@example.com' on conflict do nothing;
```

## Who can do what (RLS)

| Table | Drivers | Admins |
|---|---|---|
| dispatches, missions | read | read + write |
| mission interactions, assistance requests, badge media | own rows | all rows |
| driver locations | read all, write own | same |
| hazards | read all, add own, delete own | delete any |
| radio settings | read | update |
| store orders | — | all |

## Calls the app makes

| Feature | Request |
|---|---|
| Login / refresh | `POST /auth/v1/token?grant_type=password` / `refresh_token` |
| Admin check | `POST /rest/v1/rpc/is_stpg_admin` |
| Dispatches | `GET/POST /rest/v1/stpg_dispatches` |
| Active mission | `GET /rest/v1/stpg_missions?status=eq.ACTIVE&order=updated_at.desc&limit=1` |
| Assistance / SOS | `GET/POST/PATCH /rest/v1/stpg_assistance_requests` |
| Driver profile + badge | `founding_drivers`, `driver_badge_media` → signed URL from storage |
| GMRS channel | `GET/PATCH /rest/v1/stpg_radio_settings?id=eq.global` (every 5 s) |
| Convoy | upsert `stpg_driver_locations?on_conflict=user_id` (10 s), read last 30 min (5 s) |
| Hazards | `GET stpg_hazards?expires_at=gt.now` (20 s), `POST`, `DELETE` |
| Push tokens | upsert `stpg_push_tokens` |

## Push pipeline

Insert into dispatches / missions / assistance → `pg_net` trigger → Edge Function `stpg-push` (`supabase/functions/stpg-push/index.ts`) → FCM HTTP v1 → phones. Setup steps are in [SETUP.md](SETUP.md#3-push-notifications-firebase--supabase).

## Other services

- **Open-Meteo** — weather, no key.
- **Google Routes API** — `computeRoutes` (needs the Maps key; the legacy Directions API can't be enabled on new projects).
- **OSRM** (`router.project-osrm.org`) — free routing fallback.
