# STPG Raptor Command Center (Flutter)

Flutter rebuild of the **STPG Raptor Command Center** Android app (`com.drivestpg.commandcenter`) for **Android, iOS and the web** — plus upgrades the original never had: Google Maps with turn-by-turn voice guidance, a live convoy map, hazard pins, SOS beacon, trip history, Drive Mode and a real compass.

**Try it on a phone:** https://sydefxxs.github.io/stpg-command-center-flutter/ (open in Safari / Chrome → *Add to Home Screen*).

## Documentation

| Doc | What's in it |
|---|---|
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | How drivers and admins use every screen |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Code layout, state, services, data flow |
| [docs/SETUP.md](docs/SETUP.md) | **What's still needed**: accounts, keys and one-time setup steps |
| [docs/BACKEND.md](docs/BACKEND.md) | Supabase tables, migrations, REST calls, security rules |
| [docs/BRANCHES.md](docs/BRANCHES.md) | The project split into parts — one branch per milestone |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | What changed in each part |
| [docs/FEATURES.md](docs/FEATURES.md) | Screen-by-screen spec of the original app |
| [Privacy](https://sydefxxs.github.io/stpg-command-center-flutter/privacy.html) · [Terms](https://sydefxxs.github.io/stpg-command-center-flutter/terms.html) | Legal pages (drafts for STPG review) |

## Features at a glance

- **Command center home** — truck hero, compass HUD, weather, GPS, GMRS channel, mission bar, guided tour, day/night/auto theme.
- **Navigation** — Google Maps (or OpenStreetMap/Esri without a key), convoy route through the mission stops, turn-by-turn list, spoken directions, automatic reroute, GPS accuracy badge.
- **Drive Mode** — big speed, heading, next turn, ETA, hazard/SOS buttons; keeps the screen on.
- **Live convoy** — every driver's position, leader detection, "you're falling behind" alerts.
- **Hazard pins** — mark washouts, deep sand, police… the convoy gets a spoken warning.
- **Comms** — dispatches, missions, field assistance / SOS beacon, GMRS channel sync.
- **Admin** — send dispatches, assistance command, parts-counter orders, alert overlays.
- **Trips** — GPX recording of the Coastal Convoy, history, share/export.
- **Push notifications** — dispatches, missions and SOS via Firebase (optional setup).

## Run locally

```bash
flutter pub get
flutter run                                   # Android / iOS device or simulator
flutter run -d chrome                         # web
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=...   # optional Google Maps (see docs/SETUP.md)
flutter run --dart-define=STPG_BACKEND=stpg   # use the original STPG backend instead of the dev one
```

## Builds (GitHub Actions)

Every push to `main` runs `.github/workflows/build.yml`:

| Job | Output |
|---|---|
| `android` | `flutter analyze` + release APK (artifact `stpg-command-center-apk`) |
| `ios` | unsigned iOS build (artifact `stpg-command-center-ios-unsigned`) |
| `web` | deploys the web app to GitHub Pages |

