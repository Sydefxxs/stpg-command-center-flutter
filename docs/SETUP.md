# STPG Command Center — owner setup checklist

The app works without these steps; each one switches on an upgrade.

## 1. Google Maps (maps, traffic, convoy directions)
1. https://console.cloud.google.com → create a project → turn on billing.
2. APIs & Services → Library → enable **Maps SDK for Android**, **Maps SDK for iOS**, **Directions API**.
3. APIs & Services → Credentials → **Create credentials → API key**. Restrict it to those APIs
   (and to Android package `com.drivestpg.commandcenter.flutter` if you build release keys only).
4. GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**:
   name `GOOGLE_MAPS_API_KEY`, value = the key. The next build uses it automatically.
   Never put the key in the code or in chat.
   Local runs: `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...` and add `GOOGLE_MAPS_API_KEY=...` to `android/local.properties`.
Without a key the app uses OpenStreetMap/Esri maps and free OSRM routing.

## 2. Live convoy map (Supabase)
Supabase Dashboard → **SQL Editor** → paste `supabase/migrations/001_driver_locations.sql` → **Run**.

## 3. Push notifications (Firebase + Supabase)
1. https://console.firebase.google.com → **Add project** (can reuse the Google Cloud project).
2. Add an **Android app**, package `com.drivestpg.commandcenter.flutter` → download `google-services.json`
   → put it in `android/app/`.
3. Add an **iOS app** (bundle id from Xcode) → download `GoogleService-Info.plist` → put it in `ios/Runner/`
   → in Firebase Project settings → Cloud Messaging, upload your **APNs auth key** (Apple Developer account).
4. Supabase SQL Editor → run `supabase/migrations/002_push_tokens.sql`.

**Hazard pins:** Supabase SQL Editor → run `supabase/migrations/003_hazards.sql` (creates `stpg_hazards`). Until then the app shows "HAZARD TABLE MISSING".
5. Firebase → Project settings → **Service accounts → Generate new private key** (JSON).
6. Deploy the function (Supabase CLI): `supabase functions deploy stpg-push --no-verify-jwt`, then
   `supabase secrets set FCM_PROJECT_ID=<firebase project id> FCM_SERVICE_ACCOUNT="$(cat key.json)"`.
7. SQL Editor:
   `update stpg_push_config set function_url = 'https://zastfoacrnuhzztvgsck.supabase.co/functions/v1/stpg-push', service_key = '<service_role key>' where id = 1;`
New dispatches, active missions and assistance requests then push to every signed-in phone/tablet.
Assistance alerts go to admins only if a `stpg_admins(user_id)` table exists (edit the function to match your admin rule).

## 4. SOS + trip history
Nothing to set up. SOS uses the existing assistance-request table; trips are stored on the device.
