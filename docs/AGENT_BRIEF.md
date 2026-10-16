# Agent brief — STPG Command Center Flutter rebuild

Project root: `/home/claude/app` (Flutter app, package name `stpg_command_center`). There is NO Flutter SDK here — you cannot compile. Write careful, idiomatic Dart 3 / Flutter 3.35+ code that will pass `flutter analyze`:
- Use `Color.withValues(alpha: x)` (not `withOpacity`), `PopScope` not `WillPopScope`, switch expressions OK.
- Check `mounted` / `context.mounted` after every `await` before using `context` or `setState`.
- No new packages. Allowed imports: flutter, `http`, `shared_preferences`, `geolocator`, `flutter_map` (v8 API: `FlutterMap(options: MapOptions(initialCenter:, initialZoom:), children: [TileLayer(urlTemplate:, userAgentPackageName: 'com.drivestpg.commandcenter'), MarkerLayer(markers: [Marker(point:, width:, height:, child:)])])`, `MapController`), `latlong2` (`LatLng`), `url_launcher` (`launchUrl(Uri, mode: LaunchMode.externalApplication)`, `canLaunchUrl`), `path_provider`, `share_plus` (v11+: `SharePlus.instance.share(ShareParams(text:, files: [XFile(path)]))`).
- Relative imports inside lib (e.g. `import '../state/app_state.dart';`).

## Read first (do not edit these — they belong to the lead)
- `docs/FEATURES.md` — the spec. Read §1–§5 sections for your screens plus §7 walkthrough rows and §8 bugs/improvements that touch your screens. Every on-screen string must match the spec exactly.
- `lib/state/app_state.dart` — `AppState` (get with `AppScope.of(context)` in build, `AppScope.read(context)` in callbacks). Navigation: `app.go(CommandScreen.x)`, `app.back()`. Data: `app.gps`, `app.weather`, `app.radio`, `app.isAdmin`, `app.driverProfile`, `app.driverNumberText`, `app.vehicleName`, `app.trip`, `app.token`, `app.ensureUserId()`, `app.authed((token) => SupabaseApi.x(token, ...))` (auto-refreshes expired JWT — always use this for API calls).
- `lib/widgets/stpg_widgets.dart` — `StpgPanel`, `CardHeader`, `StatusLine`, `LabeledValue`, `StpgButton`, `SubScreenHeader`, `CommandTile`, `StpgIcon`, `StpgIcons`, `SubScreenScaffold`, `showStpgDialog`, `ResponsiveSplit`. Use these; add private widgets inside your own files if you need more.
- `lib/theme.dart` (`Stpg.orange/green/red`, day/night getters `Stpg.panel/text/gray/border/dark/black/deepPanel/alertPanel/activePanel`, `Stpg.label()`, `Stpg.title()`), `lib/models.dart`, `lib/api/supabase_api.dart`, `lib/api/weather_api.dart`, `lib/config.dart`, `lib/services/mission_tracker.dart` (public API), `lib/services/gps_service.dart`.

## Rules
- Edit ONLY the files assigned to you. Keep the public class names the router uses (see `lib/main.dart`).
- Layout: primary target is a landscape tablet (~1280×800); must also work on a phone in portrait (stack columns under 900 px wide; use `SubScreenScaffold` which scrolls). No overflow errors: prefer `Flexible`/`Expanded`, `maxLines` + ellipsis.
- Loading / empty / error states with the spec's exact texts. Errors from `SupabaseException` show as `'… // ${e.message}'` style texts from the spec.
- Fix the bugs listed in FEATURES.md §8 that touch your screens (e.g. never show "null", back buttons go to the right parent screen via `app.back()`).
- Match the look: uppercase labels, heavy weights, wide letter-spacing, rounded panels, orange accents, day/night colors via `Stpg` getters (read them inside build so theme changes apply).
- When done, reply with ≤10 lines: files written, anything stubbed/assumed, any change you need in a lead-owned file. Do not paste code back.
