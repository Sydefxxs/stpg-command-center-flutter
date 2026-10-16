# Owner setup checklist

The app runs without these steps; each one switches on a feature.

## 1. Supabase backend
1. Create a project at https://supabase.com (or use the existing dev project `wofuesquilkkniswpikn`).
2. Dashboard → **SQL Editor** → run, in order: `000_stpg_core_schema.sql` (fresh project only), `001_driver_locations.sql`, `003_hazards.sql`, and `002_push_tokens.sql` when you set up push (step 3).
3. Make yourself an admin (see [BACKEND.md](BACKEND.md)).
4. Using a different project? Put its URL and **publishable** key in `lib/config.dart`.

Status: on the dev project `000` and `001` have been run; `002` and `003` have not.

## 2. Google Maps (maps, traffic-aware routes)
1. https://console.cloud.google.com → project with billing (or the free *Maps Demo Key*).
2. Enable **Maps SDK for Android**, **Maps SDK for iOS** and **Routes API** (the old Directions API can't be enabled on new projects).
3. Create an API key and restrict it to those APIs.
4. GitHub → **Settings → Secrets and variables → Actions** → secret `GOOGLE_MAPS_API_KEY`. The next build uses it. Never put the key in code or chat.
   Local runs: `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...` and `GOOGLE_MAPS_API_KEY=...` in `android/local.properties`.

Without a key: OpenStreetMap/Esri maps and free OSRM routing. The web app always uses OpenStreetMap/Esri tiles.

## 3. Push notifications (Firebase + Supabase)
1. https://console.firebase.google.com → **Add project**.
2. Add an **Android app** (`com.drivestpg.commandcenter.flutter`) → `google-services.json` → `android/app/`.
3. Add an **iOS app** → `GoogleService-Info.plist` → `ios/Runner/`; upload your **APNs auth key** under Cloud Messaging (Apple Developer account).
4. Supabase SQL Editor → run `002_push_tokens.sql`.
5. Firebase → Project settings → **Service accounts → Generate new private key**.
6. `supabase functions deploy stpg-push --no-verify-jwt`
   `supabase secrets set FCM_PROJECT_ID=<firebase project id> FCM_SERVICE_ACCOUNT="$(cat key.json)"`
7. SQL Editor:
   `update stpg_push_config set function_url = 'https://<project>.supabase.co/functions/v1/stpg-push', service_key = '<service_role key>' where id = 1;`

New dispatches, missions and assistance requests then push to signed-in phones.

## 4. Hazard pins
Run `003_hazards.sql`. Until then the app shows "HAZARD TABLE MISSING // RUN SUPABASE MIGRATION 003".

## 5. SOS, trip history, compass, Drive Mode, voice
Nothing to set up.

## 6. iOS App Store / TestFlight
Needs an Apple Developer account ($99/yr) and signing in CI. Until then iPhone users use the web app.
