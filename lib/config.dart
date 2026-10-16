/// Backend configuration recovered from the original STPG Command Center APK.
/// The publishable key is a public, client-side Supabase key (safe to ship).
class StpgConfig {
  /// Which backend to use: `dev` (your own STPG Dev Supabase project, default)
  /// or `stpg` (the original drivestpg.com backend). Switch with
  /// `--dart-define=STPG_BACKEND=stpg`.
  static const backend = String.fromEnvironment('STPG_BACKEND', defaultValue: 'dev');
  static const isDevBackend = backend != 'stpg';

  // Publishable keys are public client keys (safe to ship in the app).
  static const supabaseUrl = isDevBackend
      ? 'https://wofuesquilkkniswpikn.supabase.co'
      : 'https://zastfoacrnuhzztvgsck.supabase.co';
  static const supabasePublishableKey = isDevBackend
      ? 'sb_publishable_W32iiRvdkEo8qrgoPd9dig_LZi-rfJD'
      : 'sb_publishable_xRYBerR806xR2ibPwEOD5g_SEZ4nCmW';

  static const commandCenterUrl = 'https://www.drivestpg.com/command-center';
  static const driverPortalUrl = 'https://www.drivestpg.com/login';
  static const convoyRouteUrl =
      'https://maps.app.goo.gl/6b37own5WeShm4WS6?g_st=ac';

  /// Google Maps key, injected at build time:
  /// flutter run --dart-define=GOOGLE_MAPS_API_KEY=xxxx  (CI reads the GitHub secret).
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static bool get hasGoogleMaps => googleMapsApiKey.isNotEmpty;

  /// How often this device shares its position with the live convoy map.
  static const convoyShareSeconds = 10;
  /// A driver is shown as "STALE" after this many seconds without an update.
  static const convoyStaleSeconds = 120;
  /// SOS beacon update interval.
  static const sosBeaconSeconds = 30;

  static const imageIntervalMs = 8000;
  static const radioPollSeconds = 5;
  static const alertPollSeconds = 10;
}
