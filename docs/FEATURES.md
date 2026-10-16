# STPG Raptor Command Center — Feature Spec

Reference for every screen, text and backend call of the original STPG Command Center Android app (v1.1.0, `com.drivestpg.commandcenter`), which this Flutter app reproduces for Android, iOS and the web.

---

## 1. App flow

1. **Boot screen** (`CommandBootScreen`): "STPG / RAPTOR COMMAND CENTER / SYSTEM INITIALIZATION" with status lines that light up in sequence: DRIVER PROFILE → VERIFIED, GPS SYSTEM → ONLINE, NETWORK → ONLINE, VEHICLE LINK → CONNECTED, MISSION SYSTEM → STANDBY, NAVIGATION → READY, then "● ALL SYSTEMS OPERATIONAL" ("INITIALIZING COMMAND SYSTEM..." while running).
2. **Loading screen**: "STPG / CONNECTING TO COMMAND NETWORK..." while the stored session is checked/refreshed.
3. **Login** (`LoginScreen`): "DRIVER AUTHENTICATION // SOUTH TEXAS PROVING GROUNDS", fields DRIVER EMAIL + password, hint "USE THE SAME EMAIL + PASSWORD AS YOUR STPG DRIVER PORTAL", button "LOGIN // COMMAND CENTER" / "AUTHENTICATING...". Errors: "ENTER YOUR DRIVER EMAIL AND PASSWORD", "LOGIN FAILED // …".
4. **Home** → sub-screens via `CommandScreen` enum: HOME, NAVIGATION, COMMS, DISPATCH, MISSIONS, ASSISTANCE_COMMAND, FIELD_ASSISTANCE, ORDERS, VEHICLE.

Session is stored in prefs `stpg_session` (access + refresh token); refreshed on launch; cleared on "SWITCH DRIVER / SIGN OUT".

## 2. Screens

### Home — "RAPTOR COMMAND CENTER" (`HomeCommandCenter`)
- Full-screen **environment background** (13 truck images). Modes stored in prefs `stpg_theme_prefs`:
  - `image_mode` = `WEATHER` (default, picks image from live weather + solar phase) or `SLIDESHOW` (cycles every 8 s, `image_index` persisted).
  - Theme pills DAY / NIGHT / AUTO (`theme_mode`). AUTO follows solar phase. Hint text: "Tap AUTO for the 13-image slideshow. Hold AUTO to follow live weather." Toast "Live weather backgrounds enabled". Mode label "AUTO // BACKGROUNDS".
  - Environment keys: DAY, SUNRISE, SUNSET, NIGHT, CLOUDY, FOG, RAIN, HEAVY_RAIN, THUNDER, DUST, COLD_DRY, SNOW, EXTREME_HEAT → `assets/images/stpg_weather_*.webp` (COLD_DRY=cold, SNOW=freezing).
- Header: STPG logo + "SOUTH TEXAS PROVING GROUNDS", title, theme pills.
- **Mission bar**: "MISSION: STANDBY/ACTIVE", "COASTAL CONVOY", "%.1f MI • hh:mm:ss" when active, button START MISSION / END MISSION → opens Mission Controls dialog.
- Left cards: **Founding Driver** (driver number e.g. 044, "DRIVER PROFILE ›" → profile modal with badge photo, name, ASSIGNED VEHICLE, SWITCH DRIVER / SIGN OUT), **System Status** (GPS READY/SEARCHING, NETWORK ONLINE, COMMAND READY), **GPS Position** (lat/lng, TRACK: LIVE, speed MPH).
- Center: **Compass HUD** (W / N / E strip driven by GPS heading), "STPG RAPTOR • 2025" tag.
- Right cards: **Vehicle** (name from profile or "2025 RAPTOR", MODE NORMAL, RANGE —), **Weather** (temp °F, condition, wind, weather icon; tap → "STPG LIVE WEATHER // DETAILS" modal with humidity, SUNRISE LOCAL, SUNSET LOCAL, "OPEN SAMSUNG WEATHER"), **Comms** (GMRS CHANNEL n + sync label; tap → GMRS dialog).
- Bottom tiles: NAVIGATION, COMMS, VEHICLE, UPDATE APP (opens https://www.drivestpg.com/command-center).
- First-run **guided tour** (steps highlight panels; SKIP / ‹ BACK / NEXT › / "CONTINUE TO COMMS ›"); title "WELCOME TO STPG", "YOUR PROGRESS". Comms has its own tour (prefs keys `start_comms_tour_v1`, `completed_v3`; FINISH TOUR ✓).
- Admin-only overlays (polled): **Assistance alert** ("⚠ STPG ASSISTANCE ALERT / DRIVER NEEDS ASSISTANCE", GPS, VIEW REQUEST, "DISMISS DOES NOT RESOLVE THE REQUEST") and **New order alert** ("🛒 STPG NEW ORDER / PARTS COUNTER ORDER", customer, qty, vendor, "PAYMENT // VERIFY QUICKBOOKS", "DISMISS DOES NOT CHANGE ORDER OR PAYMENT STATUS").

### Navigation (`NavigationCenter`)
- Header STPG, DRIVER #, VEHICLE SYNCING.
- Status tiles: GPS LOCKED/ACQUIRING, NETWORK ONLINE, VEHICLE CONNECTED, MISSION STANDBY/ACTIVE.
- Live map (Mapbox in original — use flutter_map): satellite ↔ street toggle (chip "GOOGLE"), user location puck, "SPEED // 0 MPH".
- Vehicle side panel: VEHICLE SYNCING, DRIVE MODE NORMAL, FUEL -- %, RANGE --- MI, ALTITUDE n FT.
- Bottom tabs: NAV (LIVE MAP), COMMS (DRIVERS / DISPATCH), VEHICLE (DRIVER VEHICLE), PORTAL (DRIVER PORTAL → drivestpg.com/login).
- "ONX OFFROAD // GOOGLE MAPS" app panel: launch onX Offroad (`onxmaps.offroad`, else Play Store) or Google Maps.

### Comms — "DRIVER COMMUNICATIONS" (`CommsCenter`)
- "02 // COMMS", "STPG FIELD NETWORK", REPLAY TOUR, "← BACK // COMMAND CENTER".
- GMRS strip: "GMRS CHANNEL n" + SELECT CHANNEL (admin) / VIEW CHANNEL + sync label.
- 4 tiles: STPG DISPATCH (COMMAND CHANNEL, READY), STPG ASSISTANCE (ACTIVE RESPONSE COMMAND, MONITOR — admin), MISSIONS (CURRENT ASSIGNMENT, LIVE), TRAIL / EMERGENCY (FIELD ASSISTANCE, READY). Footer NETWORK // STPG, DRIVER // nnn.

### Dispatch — "02A // DISPATCH" (`DispatchCenter`)
- LIVE DISPATCH FEED (SUPABASE // STPG FIELD NETWORK), ↻ REFRESH DISPATCH, message cards (priority/title/message/time), empty "NO ACTIVE DISPATCHES", error card "DISPATCH CONNECTION ERROR".
- Status panels: CHANNEL STPG COMMAND (CONNECTED/ERROR), DRIVER/COMMAND ADMIN (AUTHENTICATED/VERIFYING), DISPATCHES count (SYNCING/LIVE).
- Admin composer: "+ SEND DISPATCH" / "✕ CLOSE COMPOSER", "COMMAND TRANSMISSION // ADMIN ONLY", DISPATCH SUBJECT, MESSAGE TO ALL DRIVERS, "▲ TRANSMIT DISPATCH TO ALL DRIVERS", "SUBJECT AND MESSAGE REQUIRED", "DISPATCH TRANSMITTED // ALL DRIVERS".

### Missions — "02B // MISSIONS" (`MissionsCenter`)
- "FIELD OBJECTIVES // DRIVER OPERATIONS", "DRIVER PORTAL MISSION FEED // CONNECTED", MISSION BRIEF card (status, title, instructions, "DEADLINE // …" / NO DEADLINE), ↻ REFRESH MISSION, "✓ MARK MISSION COMPLETE" (TAP TO CONFIRM → SYNCING COMPLETION...), MISSION COMPLETE state, empty text "Mission Control is online. No active mission is currently available from the STPG Driver Portal."

### Field Assistance — "02C // FIELD ASSISTANCE" (`FieldAssistanceCenter`)
- "STPG FIELD SUPPORT // LIVE GPS". If an active request exists: ASSISTANCE ACTIVE / STPG COMMAND HAS YOUR REQUEST / TYPE // … / GPS // …, "✕ CANCEL REQUEST".
- Otherwise "WHAT DO YOU NEED?": RECOVERY, STUCK, MECHANICAL, FLAT TIRE, OTHER; "MESSAGE // WHAT HAPPENED?"; "⚠ SEND ASSISTANCE REQUEST" (needs GPS lock: "WAITING FOR GPS LOCK...").
- SHARE MY LOCATION (share text "STPG DRIVER LOCATION\n…" with Google Maps link), "EMERGENCY // 911" → OPEN EMERGENCY DIALER (tel:911).

### Assistance Command — "02C // ASSISTANCE COMMAND" (admin, `AssistanceCommandCenter`)
- "ACTIVE ASSISTANCE REQUESTS", list cards "⚠ TYPE", "ACTIVE // time", DRIVER ID, message, GPS; NAVIGATE TO DRIVER (geo intent / Google Maps search URL), "✓ MARK RESOLVED". Non-admin: "ADMIN ACCESS REQUIRED".

### Orders — "STPG PARTS COUNTER / ORDER COMMAND" (admin, `StoreOrdersCenter`)
- "ADMIN ONLY // PAYMENT MUST BE VERIFIED IN QUICKBOOKS", list of recent `store_orders` with product, QTY, CUSTOMER, address, VENDOR, ORDER // status, PAYMENT // status (VERIFY QUICKBOOKS).

### Vehicle — "03 // VEHICLE" (`VehicleCenter`)
- "RAPTOR VEHICLE CENTER", "2025 FORD RAPTOR 37", system panels POWERTRAIN (ENGINE / TRANSMISSION, READY), OFF-ROAD SYSTEMS (TERRAIN / SUSPENSION, READY), AUXILIARY (LIGHTING / ACCESSORIES, STANDBY), "LIVE VEHICLE DATA // FUTURE LINK".

### Dialogs
- **GMRS** ("STPG COMMS // GMRS"): channel 1–22 grid, admin SAVE CHANNEL / SAVING…, notes: "STPG admins set the shared channel. Drivers receive updates automatically.", "Set your physical radio to the displayed channel. Channel sharing does not tune the radio.", "Saved. Connected tablets refresh within about 5 seconds.", COMMS CENTER, CLOSE.
- **Mission Controls** ("STPG MISSION // COASTAL CONVOY"): START MISSION / STARTING…, END MISSION / SAVING TRIP…, OPEN CONVOY ROUTE (Google Maps link), EXPORT DRIVEN ROUTE (GPX) (share `application/gpx+xml`), status line "%.1f MILES  •  hh:mm:ss", "Recording on this tablet, including while Maps is open. N GPS points recorded."

## 3. Mission recording (Coastal Convoy)
- Foreground location service, notification channel `stpg_mission_tracking` "Mission recording", text "%.1f miles • hh:mm:ss", END action.
- Trip id `Coastal_Convoy_<epochMs>`, files in `mission_trips/`: `<id>.csv` (lat,lng,timeMs,segment), `latest.json` state, `<id>.gpx`.
- Sample filter (MissionTrackAccumulator): accuracy ≤ 50 m, fix age ≤ 15 s; ≥ 2 s between points; gap > 30 s starts new segment; reject speed > 85 m/s; reject moves < max(5 m, 0.7 × accuracy); reject < 15 m when speed < 1 m/s. Haversine distance.
- GPX: metadata "STPG Coastal Convoy", 4 waypoints, track "Driven route" with trkseg per segment.
- Convoy stops: Hacienda Ford (26.3055915, -98.1961975); TEX BEST Travel Center (26.0154662, -97.4819084); South Padre Island Convention Center (26.1410463, -97.1751285); Cameron County Beach Access #6 (26.2073291, -97.1787862). Route URL https://maps.app.goo.gl/6b37own5WeShm4WS6?g_st=ac
- On app restart with an active/saving trip → status INTERRUPTED, GPX of saved portion.

## 4. Backend (Supabase REST, `https://zastfoacrnuhzztvgsck.supabase.co`, publishable key in `lib/config.dart`)
| Feature | Call |
|---|---|
| Login | POST `/auth/v1/token?grant_type=password` {email,password} |
| Refresh | POST `/auth/v1/token?grant_type=refresh_token` {refresh_token} |
| User id | GET `/auth/v1/user` |
| Dispatches | GET `/rest/v1/stpg_dispatches?select=id,subject,message,recipient_type,created_at&order=created_at.desc`; POST {subject,message,recipient_type:"all"} |
| Admin check | POST `/rest/v1/rpc/is_stpg_admin` |
| Mission | GET `/rest/v1/stpg_missions?select=id,title,instructions,deadline,status&status=eq.ACTIVE&order=updated_at.desc&limit=1` |
| Mission interaction | GET/POST/PATCH `/rest/v1/stpg_mission_interactions` (mission_id, user_id, first_viewed_at, completed_at) |
| Assistance | GET/POST/PATCH `/rest/v1/stpg_assistance_requests` (status ACTIVE / CANCELLED / RESOLVED) |
| Orders | GET `/rest/v1/store_orders?select=*&order=created_at.desc&limit=N` |
| Driver profile | GET `/rest/v1/founding_drivers?select=user_id,full_name,driver_number,vehicle&user_id=eq.X` |
| Badge photo | GET `/rest/v1/driver_badge_media?select=badge_photo_path&user_id=eq.X` → POST `/storage/v1/object/sign/driver-badge-photos/<path>` {expiresIn:3600} |
| GMRS channel | GET/PATCH `/rest/v1/stpg_radio_settings?id=eq.global&select=channel` (poll every 5 s) |
| Weather | Open-Meteo `api.open-meteo.com/v1/forecast` current temp/humidity/code/wind + daily sunrise/sunset, °F, mph, timezone=auto |

## 5. Design tokens
Orange `#FF6A00`, Green `#4CAF50`, Red `#FF3B30`. Day/Night pairs — black `#E2E6EC/#070A0F`, dark `#EDF1F6/#0D1117`, panel `#F8FAFC/#12161D`, border `#CBD5E1/#222B38`, gray `#475569/#9DA5B0`, text `#0F172A/#FFFFFF`, deepPanel `#FFFFFF/#090B0E`, alertPanel `#FFF1F0/#180B0B`, activePanel `#FFF4EA/#1E1610`. Uppercase labels, heavy weights, wide letter-spacing, rounded 16–20 px panels with 1 px borders (orange border when highlighted).

## 6. Issues in the original app (all fixed in this version)
- Shows literal "null"/"NULL" when no vehicle is assigned → show "NO VEHICLE ASSIGNED".
- System Status and GPS cards clip their last row (COMMAND / SPD) and don't scroll → size cards to content.
- Vehicle and Coastal Convoy elements look tappable but do nothing → open Vehicle Center / mission dialog.
- Compass HUD is faint over bright backgrounds → add contrast backing.
- Background mode (tap vs hold AUTO) is hidden → add a visible "WEATHER / SLIDESHOW" toggle.
- Dispatch showed "HTTP 401 // JWT expired" → refresh the session automatically and retry.
- "← BACK // COMMS" on sub-screens actually returns to Home → go back to Comms.
- Android back button exits the whole app → navigate back one screen instead.
- Navigation screen has no way back to Home → add a Home/back control.
- UPDATE APP only opens a web page that lists an older version (v1.0.0) → in-app version check against the server with an update banner.
- Tour card can be hidden behind other UI on small screens → keep it on-screen.
