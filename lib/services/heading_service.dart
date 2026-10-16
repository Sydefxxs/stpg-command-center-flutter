import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gps_service.dart';
import 'heading/heading_stub.dart' if (dart.library.js_interop) 'heading/heading_web.dart' as platform;

/// Where the heading comes from.
enum HeadingSource { none, magnetic, gps }

/// Compass heading for the HUD: device magnetometer when available,
/// GPS course while driving (>= 3 mph) when the magnetometer is silent.
class HeadingService {
  HeadingService._();
  static final instance = HeadingService._();

  /// Heading 0–360 (null until the first reading).
  final ValueNotifier<double?> heading = ValueNotifier(null);

  /// Continuous (unwrapped) heading so animations take the short way round 359°→0°.
  final ValueNotifier<double> continuous = ValueNotifier(0);
  final ValueNotifier<HeadingSource> source = ValueNotifier(HeadingSource.none);

  StreamSubscription<double>? _sub;
  DateTime _lastMag = DateTime.fromMillisecondsSinceEpoch(0);
  bool _gpsListening = false;

  /// True on iPhone Safari until the user taps to allow motion & orientation access.
  bool get needsTap => platform.headingNeedsTap && source.value == HeadingSource.none;

  void start() {
    _sub ??= platform.platformHeadingStream()?.listen((h) {
      _lastMag = DateTime.now();
      _update(h, HeadingSource.magnetic);
    });
    if (!_gpsListening) {
      GpsService.instance.live.addListener(_onGps);
      _gpsListening = true;
    }
  }

  /// Call from a tap: asks Safari for compass permission, then starts listening.
  Future<bool> enable() async {
    final ok = await platform.requestHeadingPermission();
    await _sub?.cancel();
    _sub = null;
    start();
    return ok;
  }

  void _onGps() {
    final g = GpsService.instance.live.value;
    if (DateTime.now().difference(_lastMag).inSeconds < 3) return; // magnetometer is live
    final b = g.bearingDegrees;
    if (b != null && (g.speedMph ?? 0) >= 3) _update(b.toDouble(), HeadingSource.gps);
  }

  void _update(double raw, HeadingSource src) {
    final h = ((raw % 360) + 360) % 360;
    final prev = heading.value;
    // Light smoothing to stop the needle jittering.
    final smoothed = prev == null ? h : _wrap(prev + _diff(prev, h) * (src == HeadingSource.magnetic ? 0.3 : 0.6));
    heading.value = smoothed;
    continuous.value = continuous.value + _diff(_wrap(continuous.value), smoothed);
    source.value = src;
  }

  static double _wrap(double d) => ((d % 360) + 360) % 360;

  /// Signed shortest difference from a to b (-180..180).
  static double _diff(double a, double b) => ((b - a + 540) % 360) - 180;
}
