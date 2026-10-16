# Setup checklist — what's still needed

Everything the code needs from outside: accounts, keys and one-time steps. The app runs without any of them; each one switches a feature on.

**Never put a secret in the code, a commit, an issue or a chat.** Secrets go in GitHub → *Settings → Secrets and variables → Actions*, or in Supabase → *Edge Functions → Secrets*.

## Status

| # | Item | Needed for | Status |
|---|---|---|---|
| 1 | Supabase database scripts `000`–`004` | Everything | `000`, `001` run on the dev project; `002`–`004` pending |
| 2 | Supabase sign-up settings + driver approval | Keeping strangers out of the convoy | Pending |
| 3 | Google Maps key | Google maps + traffic-aware routes in the phone apps | Demo key in `GOOGLE_MAPS_API_KEY` secret; production key pending |
| 4 | Firebase project + push function | Push notifications | Pending |
| 5 | Release signing key (Android) | Google Play | Pending |
| 6 | Apple Developer account | iPhone app (TestFlight / App Store), iPhone push | Pending |
| 7 | Google Play Console | Android store release | Pending |
| 8 | Legal pages reviewed by STPG | Store listings | Drafts live: `privacy.html`, `terms.html` |
| 9 | Store listing assets | Store release | Pending |

---

## 1. Supabase database

Dev project: `https://wofuesquilkkniswpikn.supabase.co`. Dashboard → **SQL Editor** → **New query** → paste the whole file → **Run**. Run in order; every script is safe to run again.

| Script | What it does |
|---|---|
| `000_stpg_core_schema.sql` | All core tables (fresh project only) |
| `001_driver_locations.sql` | Live convoy table |
| `002_push_tokens.sql` | Push tokens + triggers that call the push function |
| `003_hazards.sql` | Hazard pins |
| `004_security.sql` | Driver approval, protected profile fields, server-filled names |

Make yourself an admin (use your sign-in email):
```sql
insert into public.stpg_admins (user_id)
select id from auth.users where email = 'you@example.com' on conflict do nothing;
```

To use a different Supabase project, put its URL and **publishable** key in `lib/config.dart`. Never use the `service_role` key in the app.

## 2. Who can get in

After `004`, a new login sees nothing until an admin approves it.

- **Approve a driver:** Table Editor → `founding_drivers` → set `approved` to `true`, or in the SQL Editor:
  ```sql
  update public.founding_drivers set approved = true
  where user_id = (select id from auth.users where email = 'driver@example.com');
  ```
- **Turn off open sign-ups** (drivers are added by STPG): Authentication → Sign In / Providers → turn off **Allow new users to sign up**. Add drivers with Authentication → Users → **Invite user**.
- Keep **Confirm email** on.

## 3. Google Maps

1. Google Cloud Console → a project with billing on.
2. Enable **Maps SDK for Android**, **Maps SDK for iOS** and **Routes API**. The old Directions API can't be enabled on new projects.
3. Create an API key, then under **API restrictions** allow only those three APIs, and set a daily quota.
4. Add it as GitHub **secret** `GOOGLE_MAPS_API_KEY`.

The public web app is built **without** this key on purpose; it uses OpenStreetMap/Esri maps and free OSRM routing. For local runs:
`flutter run --dart-define=GOOGLE_MAPS_API_KEY=...`, plus `GOOGLE_MAPS_API_KEY=...` in `android/local.properties` (that file is git-ignored).

## 4. Push notifications (Firebase + Supabase)

**a. Firebase project**
1. Firebase console → **Add project**. It can reuse the Google Cloud project.
2. **Add app → Android**, package `com.drivestpg.commandcenter.flutter`.
3. **Add app → iOS**, bundle ID from Xcode (Runner → General → Bundle Identifier). This needs the Apple account from step 6 for the APNs key: Firebase → Project settings → **Cloud Messaging** → upload the **APNs Authentication Key**.
4. Add these as GitHub **variables** (not secrets; they identify the app and aren't passwords). All values are in Firebase → **Project settings**:

| Variable | Where in Project settings |
|---|---|
| `FIREBASE_PROJECT_ID` | General → Project ID |
| `FIREBASE_SENDER_ID` | Cloud Messaging → Sender ID |
| `FIREBASE_API_KEY` | General → Web API key, or the Android app's API key |
| `FIREBASE_ANDROID_APP_ID` | General → Your apps → Android → App ID (`1:…:android:…`) |
| `FIREBASE_IOS_APP_ID` | General → Your apps → iOS → App ID (`1:…:ios:…`) |
| `FIREBASE_IOS_BUNDLE_ID` | The iOS bundle ID |

**b. Push function**
1. Firebase → Project settings → **Service accounts** → **Generate new private key**. This downloads a JSON file. Keep it private, and delete it from your computer once step 3 is done.
2. Supabase → **Edge Functions** → **Deploy a new function** → **Via editor**, name `stpg-push`. Paste `supabase/functions/stpg-push/index.ts` and turn **off** "Verify JWT"; the function checks its own secret instead.
3. Supabase → Edge Functions → **Secrets**, add:
   - `FCM_SERVICE_ACCOUNT` = the whole JSON file contents
   - `STPG_WEBHOOK_SECRET` = a long random string, e.g. from `openssl rand -hex 32`
4. SQL Editor (run `002` first), using the same random string:
   ```sql
   update public.stpg_push_config
   set function_url = 'https://wofuesquilkkniswpikn.supabase.co/functions/v1/stpg-push',
       webhook_secret = '<the same random string>'
   where id = 1;
   ```

New dispatches and active missions then go to every signed-in phone, and new assistance requests go to admins. The web app doesn't get push.

## 5. Android release signing

1. Create a keystore once and keep it backed up. Losing it means you can't update the Play listing.
   `keytool -genkey -v -keystore stpg-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stpg`
2. Add these GitHub **secrets**:
   - `ANDROID_KEYSTORE_BASE64` (output of `base64 -w0 stpg-release.jks`)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS` (`stpg`)
   - `ANDROID_KEY_PASSWORD`
3. Local builds: `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword` (git-ignored).

Without these, release APKs are signed with the debug key. That's fine for testing; Google Play won't accept it.

## 6. Apple / iPhone app

- An Apple Developer Program membership ($99/yr) is needed for TestFlight, the App Store and iPhone push notifications.
- After joining, add signing to the iOS build (App Store Connect API key as GitHub secrets) and turn on **Push Notifications** and **Background Modes → Location** in Xcode.
- Until then, iPhone users use the web app: https://sydefxxs.github.io/stpg-command-center-flutter/

## 7. Google Play

- Play Console account ($25 once).
- **Data safety** form: declare location (precise, shared with other users, app functionality), personal info (name, email) and device IDs (push token). Data is encrypted in transit and users can request deletion. The privacy page lists all of it.
- **Background location declaration:** the app uses it only to record an active Coastal Convoy mission. Play needs a short video showing the in-app prompt and that feature.
- **Account deletion URL:** `https://sydefxxs.github.io/stpg-command-center-flutter/privacy.html#delete-account`

## 8. Legal pages

- Drafts are published with the web app: `/privacy.html` and `/terms.html`. The app links to them on the login screen and in the driver profile.
- STPG must review and approve them, and should add a direct contact email; they currently point to drivestpg.com. Have someone qualified review them before store submission.
- When hosting moves to STPG's own site, update `privacyUrl` / `termsUrl` in `lib/config.dart`.

## 9. Store listing assets

- Final app icon (1024×1024, no transparency for iOS)
- Launch screen artwork
- Screenshots: phone, plus 7" and 10" tablets for Play, and 6.7" and 6.5" iPhone for the App Store
- Short and full descriptions, support URL and contact email
