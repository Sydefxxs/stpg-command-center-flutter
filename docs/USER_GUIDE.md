# User guide

## Getting the app

- **iPhone / any phone (web app):** open https://sydefxxs.github.io/stpg-command-center-flutter/ in **Safari** (iPhone) or **Chrome** (Android) — not inside another app's browser — then *Share → Add to Home Screen*.
- **Android app:** GitHub → Actions → latest run → artifact `stpg-command-center-apk` → install the APK.
- **iOS app:** needs an Apple Developer account for TestFlight; until then use the web app.

Sign in with your STPG driver email and password. First launch runs a 10-step guided tour (replay it from Comms).

**Allow location** when asked. On iPhone, if GPS stays on *SEARCHING*: Settings → Privacy & Security → Location Services → Safari Websites → *While Using*, then tap the location bar on Home.

## Home — Raptor Command Center

| Area | What it does |
|---|---|
| Location bar | Shows your coordinates; tap to retry GPS |
| Compass | Heading from the phone's compass (`MAG`) or GPS while driving (`GPS`). On iPhone tap **TAP TO ENABLE COMPASS** once |
| Mission bar | Start / end the Coastal Convoy mission (records your GPX track) |
| **▶ DRIVE MODE** | Big driving dashboard (see below) |
| Cards | Driver profile, weather, GPS, GMRS channel, vehicle, system — tap for details |
| Tiles | Navigation, Comms, Vehicle, Update |
| Theme | DAY / NIGHT / AUTO (auto follows sunrise/sunset) |

## Navigation

- **onX / GOOGLE** chips switch satellite and road view (double-tap opens the onX or Google Maps app).
- **CONVOY ROUTE** plans a route from you through the four Coastal Convoy stops. The orange banner shows the next turn and live distance; it turns **red** when you're off route (the app recalculates automatically) and **green** on arrival.
- **DIRECTIONS / VEHICLE** toggle the side panel: turn list (current step highlighted) with remaining miles and minutes, or vehicle stats.
- Left rail: **speedometer** = Drive Mode, **⚠** = mark a hazard, **speaker** = voice on/off.
- **ACC ± FT** dot: green = accurate (≤ 33 ft), orange = fair, red = poor.
- **◎** recenters on you. **OPEN IN GOOGLE MAPS** hands the route to Google Maps.

## Drive Mode

A dashboard for a phone mount. The screen stays on.

- **Top**: EXIT, GPS accuracy, VOICE / MUTED.
- **Turn card**: maneuver arrow, distance, instruction. Tap *START CONVOY ROUTE* if no route is active; ✕ ends the route.
- **Banners**: hazard ahead (yellow), behind the convoy leader (orange), route errors (red).
- **Center**: speed and compass. **Bottom**: remaining miles, arrival time, minutes left.
- **Buttons**: HAZARD, MAP, SOS.
- Turn the phone sideways for a two-column layout.

**Voice tips (iPhone):** tap a button (e.g. *Start Convoy Route*) before driving — Safari only speaks after a tap. The app lowers music instead of stopping it.

## Hazard pins

Tap ⚠ (Navigation or Drive Mode) and pick: washout, deep sand, mud, rocks, water crossing, livestock, debris, police, other. The pin marks your current spot for everyone for 12 hours. Drivers heading toward it hear "Caution, deep sand reported ahead, 500 feet." Tap a pin on the map for details; you (or an admin) can remove your own pins.

## Comms

| Tile | Use |
|---|---|
| Dispatch | STPG command updates (admins can send) |
| Missions | Current assignment, instructions, mark complete |
| Field Assistance | Request recovery/emergency help with your GPS; **hold SOS for 2 seconds** to start an SOS beacon that updates your location every 30 s |
| Live Convoy | Every driver sharing location, leader badge, distance/speed, LIVE/STALE; **SHARING ON/OFF** controls your own sharing |
| Trip History | Saved convoy trips — view track, export GPX, delete |
| GMRS | Shared radio channel (admins set it) |

When you're 2+ miles behind the convoy leader you get a spoken alert (at most every 5 minutes).

## Admin tools

Visible only to accounts in `stpg_admins`: send dispatches, Assistance Command (active requests, resolve), Parts Counter orders, pop-up alerts for new assistance requests and orders, set the GMRS channel, remove any hazard pin.
