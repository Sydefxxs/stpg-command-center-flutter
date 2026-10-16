# STPG Raptor Command Center (Flutter)

Flutter rebuild of the STPG Command Center Android app, for **Android and iOS**.

- Feature spec, backend map and design tokens: [`docs/FEATURES.md`](docs/FEATURES.md)
- Backend: the existing STPG Supabase project (same driver logins as the Driver Portal)
- Maps: OpenStreetMap / Esri imagery via `flutter_map` (no Mapbox token needed)

## Run
```bash
flutter pub get
flutter run            # Android device/emulator or iOS simulator
flutter build apk      # Android APK in build/app/outputs/flutter-apk/
```

Every push to `main` builds an APK and an unsigned iOS build in GitHub Actions (see the Actions tab → latest run → Artifacts).

## Structure
```
lib/
  config.dart            Supabase URL/key, links, intervals
  theme.dart             STPG day/night colors and text styles
  models.dart            data classes
  api/                   Supabase REST + Open-Meteo weather
  state/app_state.dart   app-wide state (session, GPS, weather, radio, alerts, navigation)
  services/              live GPS, Coastal Convoy mission recorder (GPX)
  widgets/               shared STPG widgets, compass HUD
  screens/               boot, login, home, navigation, comms, dispatch, missions,
                         field assistance, assistance command, orders, vehicle
  dialogs/               driver profile, weather, GMRS, mission controls, admin alerts
```
