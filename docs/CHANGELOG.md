# Changelog

## Part 7 — Security & legal (`part-7-security-legal`)
- `004_security.sql`:
  - New logins must be approved before they can see the convoy, hazards, dispatches or missions.
  - Drivers can't change their own driver number.
  - Names on convoy positions and hazard pins are filled in by the server.
- Hazard pins: only known kinds, notes up to 280 characters, valid coordinates.
- Push:
  - The function now requires a shared webhook secret.
  - The database no longer stores the `service_role` key.
  - Assistance alerts are never sent to everyone by mistake.
- App:
  - Sign-in tokens are kept in the Keychain or Android encrypted storage.
  - Android backups and plain-HTTP traffic are off.
  - Token refresh is shared between callers, which fixes random sign-outs when several screens refreshed at once.
  - A clear "account not approved" message on the convoy and hazards.
- Builds:
  - Firebase is configured through build variables.
  - Android release signing comes from secrets.
  - The web build no longer includes the Maps key.
  - The CI-log branches were removed.
- Legal: privacy policy (with account-deletion instructions) and terms of use, linked from the login screen and the driver profile.
- Docs: `SETUP.md` rewritten as the single checklist of missing keys and steps; leftover scaffolding removed.

## Part 6 — Drive Mode & hazards (`part-6-drive-mode-hazards`)
- **Drive Mode** screen (`lib/screens/drive_screen.dart`): huge speed, compass, next-turn card with maneuver arrow, remaining distance / arrival time / minutes left, HAZARD / MAP / SOS buttons, landscape layout.
- **Route guidance engine** (`lib/services/route_guidance.dart`): progress along the polyline, next maneuver, live remaining distance & ETA, spoken turns (speed-scaled lead distance), off-route detection (≈75 m for 3 accurate fixes) and automatic reroute to the stops not yet reached, arrival detection.
- **Voice** (`voice_service.dart`, `flutter_tts`): on/off toggle saved per device; iOS ducks music and speaks on silent.
- **Hazard pins** (`hazard_service.dart`, `dialogs/hazard_dialog.dart`, migration `003_hazards.sql`): 9 hazard kinds, 12-hour expiry, map markers, details/remove dialog, spoken warning when a pin is ahead within 500 m.
- **Convoy gap**: miles behind the leader computed from fresh drivers; spoken alert at ≥ 2 mi (max every 5 min).
- **Keep screen awake** (`wake_service.dart`, `wakelock_plus`) during a route, Drive Mode and the convoy map.
- GPS accuracy colors (green ≤ 33 ft, orange ≤ 100 ft, red), haptic feedback on buttons.

## Part 5 — Compass (`part-5-compass`)
- `HeadingService`: magnetometer via `flutter_compass`; web uses `deviceorientation(absolute)` / `webkitCompassHeading`; iPhone Safari asks permission on tap.
- Falls back to GPS course above 3 mph; smoothing with 359°→0° wraparound.
- Compass tape shows `042° NE` and the source (MAG / GPS / NO SIGNAL); width fits the screen.

## Part 4 — Web app & phone layout (`part-4-web-app-phone-layout`)
- Web build deployed to GitHub Pages; Add-to-Home-Screen icons/meta.
- iPhone Safari GPS fix (no Permissions API), location retry bar, weather fallback to San Antonio before the first fix.
- New phone layouts for Home and Navigation.

## Part 3 — Dev backend & Routes API (`part-3-dev-backend-routes-api`)
- `000_stpg_core_schema.sql` recreates every table the app uses on a fresh Supabase project.
- `STPG_BACKEND` switch (default `dev`).
- Google Routes API `computeRoutes` with OSRM fallback; Maps key injected from the `GOOGLE_MAPS_API_KEY` secret.

## Part 2 — Upgrades (`part-2-maps-convoy-push-sos`)
- Google Maps widget with OSM/Esri fallback, convoy route + directions.
- Live convoy (`stpg_driver_locations`, migration `001`).
- Push notifications (FCM v1 Edge Function `stpg-push`, migration `002`).
- SOS beacon (location update every 30 s) and trip history with GPX export.

## Part 1 — Core app (`part-1-core-app`)
- Flutter recreation of every screen and dialog of the original Android app, Supabase REST client, weather, GMRS sync, admin alerts, guided tours, mission recorder; Android + iOS CI.
