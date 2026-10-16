import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// App configuration. Values marked "build setting" are passed with
/// `--dart-define=NAME=value` (CI reads them from GitHub secrets/variables).
/// See docs/SETUP.md for where each value comes from.
class StpgConfig {
  /// `dev` = STPG Dev Supabase project (default), `stpg` = drivestpg.com backend.
  static const backend = String.fromEnvironment('STPG_BACKEND', defaultValue: 'dev');
  static const isDevBackend = backend != 'stpg';

  // Publishable keys are public client keys; table access is enforced by row-level security.
  static const supabaseUrl = isDevBackend
      ? 'https://wofuesquilkkniswpikn.supabase.co'
      : 'https://zastfoacrnuhzztvgsck.supabase.co';
  static const supabasePublishableKey = isDevBackend
      ? 'sb_publishable_W32iiRvdkEo8qrgoPd9dig_LZi-rfJD'
      : 'sb_publishable_xRYBerR806xR2ibPwEOD5g_SEZ4nCmW';

  static const commandCenterUrl = 'https://www.drivestpg.com/command-center';
  static const driverPortalUrl = 'https://www.drivestpg.com/login';
  static const convoyRouteUrl = 'https://maps.app.goo.gl/6b37own5WeShm4WS6?g_st=ac';

  /// Legal pages (hosted with the web app on GitHub Pages).
  static const privacyUrl = 'https://sydefxxs.github.io/stpg-command-center-flutter/privacy.html';
  static const termsUrl = 'https://sydefxxs.github.io/stpg-command-center-flutter/terms.html';

  /// Build setting. Empty = OpenStreetMap/Esri maps and free OSRM routing.
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static bool get hasGoogleMaps => googleMapsApiKey.isNotEmpty;

  // Firebase (push notifications). Build settings; all empty = push disabled.
  static const _fbApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _fbProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _fbSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _fbAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _fbIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _fbIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? get firebaseOptions {
    if (kIsWeb || _fbApiKey.isEmpty || _fbProjectId.isEmpty || _fbSenderId.isEmpty) return null;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final appId = ios ? _fbIosAppId : _fbAndroidAppId;
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: _fbApiKey,
      appId: appId,
      messagingSenderId: _fbSenderId,
      projectId: _fbProjectId,
      iosBundleId: ios && _fbIosBundleId.isNotEmpty ? _fbIosBundleId : null,
    );
  }

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
