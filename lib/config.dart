/// Backend configuration recovered from the original STPG Command Center APK.
/// The publishable key is a public, client-side Supabase key (safe to ship).
class StpgConfig {
  static const supabaseUrl = 'https://zastfoacrnuhzztvgsck.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_xRYBerR806xR2ibPwEOD5g_SEZ4nCmW';

  static const commandCenterUrl = 'https://www.drivestpg.com/command-center';
  static const driverPortalUrl = 'https://www.drivestpg.com/login';
  static const convoyRouteUrl =
      'https://maps.app.goo.gl/6b37own5WeShm4WS6?g_st=ac';

  static const imageIntervalMs = 8000;
  static const radioPollSeconds = 5;
  static const alertPollSeconds = 10;
}
