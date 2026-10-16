# Branches — the project in parts

`main` always has the latest complete app. Each `part-*` branch is a snapshot of the app at the end of one milestone, so you can check out, build and compare any stage on its own. They build on each other in order (part 2 contains part 1, and so on).

| Branch | Milestone | Main additions |
|---|---|---|
| `part-1-core-app` | Flutter rebuild of the original app | All original screens (home, navigation, comms, dispatch, missions, field assistance, assistance command, orders, vehicle), dialogs, guided tours, day/night theme, Supabase login, GPX mission recorder, CI for Android + iOS |
| `part-2-maps-convoy-push-sos` | Upgrades | Google Maps + directions, live convoy map, push notifications (Firebase + Supabase Edge Function), SOS beacon, trip history; CI fixes (notifications API, Kotlin DSL, desugaring) |
| `part-3-dev-backend-routes-api` | Own backend | Full Supabase schema for a fresh project (`000`), dev/STPG backend switch, Google Routes API (replaces the retired Directions API) with OSRM fallback, Maps key from GitHub secret |
| `part-4-web-app-phone-layout` | iPhone web app | Web build + GitHub Pages deploy, PWA icons, GPS on iPhone Safari, location retry bar, weather fallback, compact phone layouts |
| `part-5-compass` | Real compass | Magnetometer (Android/iOS) and DeviceOrientation (web, iPhone tap-to-enable), GPS-course fallback, smoothing, degree readout, responsive width |
| `part-6-drive-mode-hazards` | Driving features | Drive Mode, voice turn-by-turn, off-route reroute, hazard pins (`003`), convoy-gap alerts, keep-awake, GPS accuracy colors, haptics |
| `docs-documentation` | Documentation | This documentation set (README, user guide, architecture, backend, setup, changelog) |

## Working with them

```bash
git fetch origin
git checkout part-5-compass        # build/run that stage
git diff part-4-web-app-phone-layout part-5-compass --stat   # what a part changed
```

Compare on GitHub: `https://github.com/Sydefxxs/stpg-command-center-flutter/compare/<older>...<newer>`

New work: branch from `main` (`git checkout -b feature/<name> main`) and open a pull request — the CI runs the Android and iOS builds on every PR.
