# Architecture

One Flutter codebase builds Android, iOS and the web app. No code generation, no state-management package — a single `ChangeNotifier` plus a few singleton services.

```
lib/
  main.dart                 App root: MaterialApp, AppScope, screen switch, back-button handling
  config.dart               Backend switch (dev / stpg), keys from --dart-define, links, timings
  theme.dart                STPG colors (day/night), text styles
  models.dart               Plain data classes (LiveGps, weather, dispatch, mission, …)
  api/
    supabase_api.dart       Supabase REST/Auth/Storage client (+ generic `rest()`)
    weather_api.dart        Open-Meteo current weather + sunrise/sunset
  state/app_state.dart      AppState: session, screen history, theme, GPS, weather, radio, alerts, tours
  services/
    gps_service.dart        Location stream (geolocator), permission + retry, LiveGps notifier
    heading_service.dart    Compass heading: magnetometer / DeviceOrientation / GPS course, smoothed
      heading/heading_stub.dart   Android/iOS (flutter_compass)
      heading/heading_web.dart    Web (deviceorientation, iPhone permission)
    directions_service.dart Google Routes API → OSRM fallback; polyline decoding
    route_guidance.dart     Turn-by-turn engine: progress, ETA, voice prompts, reroute, hazard + convoy alerts
    voice_service.dart      Text-to-speech (flutter_tts), on/off preference
    wake_service.dart       Keep-screen-on with named holders (wakelock_plus)
    convoy_service.dart     Shares own position every 10 s, polls other drivers every 5 s
    hazard_service.dart     Hazard pins: list (20 s poll), drop, remove
    sos_service.dart        SOS beacon: creates assistance request, updates location every 30 s
    session_store.dart      Sign-in tokens: Keychain / Android encrypted storage (browser storage on web)
    mission_tracker.dart    Coastal Convoy GPX recorder, trip history on device
    push_service.dart       Firebase Messaging + local notifications, token registration
  widgets/                  StpgPanel/Button/…, CompassHud, StpgMap (Google or flutter_map), SosPanel
  screens/                  home, navigation, drive, comms, convoy, trips, dispatch, missions,
                            field_assistance, assistance_command, orders, vehicle, login, boot
  dialogs/                  driver profile, weather, GMRS, mission controls, hazard picker, alert overlays
  widgets/legal_links.dart  Privacy / Terms / Delete-account links
supabase/
  migrations/000–003        SQL to run in the Supabase SQL editor
  functions/stpg-push       Edge Function that sends FCM v1 pushes
web/                        index.html, manifest, icons (PWA), privacy.html, terms.html
.github/workflows/build.yml CI: analyze, APK, iOS (no codesign), GitHub Pages
```

## State and navigation

- `AppState` (`ChangeNotifier`) is exposed through `AppScope` (an `InheritedNotifier`). Screens call `AppScope.of(context)` and rebuild when it notifies.
- Navigation is a simple enum (`CommandScreen`) with a history stack: `app.go(screen)` / `app.back()`. `main.dart` switches on `app.screen`; Android back and iOS swipe call `back()`.
- Services are singletons (`XService.instance`) that expose `ValueNotifier`s; widgets listen with `ValueListenableBuilder` / `ListenableBuilder`.

## Sign-in lifecycle

`AppState._onSignedIn` starts, in order: GPS → weather → heading → route guidance → voice prefs → hazards → convoy → push → SOS restore. `signOut` stops convoy and hazards, clears the route and unregisters push. All Supabase calls go through `app.authed(...)`: on HTTP 401 it refreshes the session once — shared by every caller, because refresh tokens are single-use — and retries.

## Location, heading and guidance

```
geolocator ──► GpsService.live (LiveGps) ──┬─► AppState (UI rebuilds, weather)
                                            ├─► ConvoyService (upload every 10 s)
                                            ├─► HeadingService (GPS course fallback ≥ 3 mph)
                                            └─► RouteGuidance._onFix
magnetometer / deviceorientation ─► HeadingService.heading ─► CompassHud, map "YOU" arrow, hazard-ahead check
DirectionsService.route ─► RouteGuidance.state (GuidanceState) ─► Navigation banner, Drive Mode
```

`RouteGuidance` projects each fix onto the route polyline (equirectangular approximation) to get distance-along and distance-off. The next maneuver is the first step whose start lies ahead; prompts fire at speed-scaled distances (≈0.5 mi / 1 mi on highway, 250 m, "now"). Three accurate fixes more than 75 m off the line trigger a reroute (at most every 20 s) to the remaining stops.

## Maps

`StpgMap` hides the map engine: `google_maps_flutter` on Android/iOS when `GOOGLE_MAPS_API_KEY` is set, otherwise `flutter_map` with Esri satellite / OpenStreetMap tiles (always on the web). Markers have kinds `self`, `driver`, `stop`, `alert` and optional rotation.

## Configuration

| Define | Default | Purpose |
|---|---|---|
| `STPG_BACKEND` | `dev` | `dev` = your own Supabase project, `stpg` = original STPG backend |
| `GOOGLE_MAPS_API_KEY` | empty | Enables Google Maps + Routes API in the phone apps (CI secret; never in the web build) |
| `FIREBASE_*` | empty | Firebase options for push notifications (CI variables, see SETUP.md) |

Timings (convoy share/poll, SOS beacon, radio/alert polling, slideshow) are constants in `config.dart`.

## Platform notes

- **Android**: Maps key via `manifestPlaceholders`; core-library desugaring on; `google-services.json` applied only if present.
- **iOS**: `GMSApiKey` in Info.plist set by CI; location + background modes declared.
- **Web**: compass needs a tap on iPhone (motion permission); speech starts after the first tap; geolocation needs HTTPS (GitHub Pages).

## Security

- Only the Supabase **publishable** key ships in the app; every table is protected by row-level security (see BACKEND.md).
- Sign-in tokens are kept in the Keychain on iOS and encrypted storage on Android. Android backups are turned off, so tokens can't be copied out.
- Release signing keys, the Maps key and Firebase settings come from GitHub secrets and variables at build time. None of them are in the repo.
- The public web build doesn't include the Maps key.
- The push function only accepts calls that carry the database's shared secret.
