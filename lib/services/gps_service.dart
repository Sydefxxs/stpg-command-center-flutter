import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models.dart';

/// Live GPS feed for the UI (equivalent of the original `rememberLiveGps`).
class GpsService {
  GpsService._();
  static final instance = GpsService._();

  final ValueNotifier<LiveGps> live = ValueNotifier(const LiveGps());
  StreamSubscription<Position>? _sub;

  /// Last error (permission denied / unavailable), for the UI.
  final ValueNotifier<String?> error = ValueNotifier(null);

  /// Asks for permission (if needed) and starts streaming. Safe to call repeatedly.
  Future<void> start() async {
    if (_sub != null) return;
    try {
      if (!kIsWeb) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        final granted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
        if (!granted) {
          live.value = const LiveGps(hasPermission: false);
          error.value = 'LOCATION PERMISSION DENIED';
          return;
        }
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) _apply(last);
        } catch (_) {}
      }
      live.value = LiveGps(hasPermission: true, hasFix: live.value.hasFix,
          latitude: live.value.latitude, longitude: live.value.longitude);
      // On web this call itself shows the browser's "Allow location" prompt.
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0),
      ).listen(_apply, onError: (Object e) {
        error.value = 'LOCATION UNAVAILABLE // ALLOW LOCATION FOR THIS SITE';
        live.value = const LiveGps(hasPermission: false);
        _sub?.cancel();
        _sub = null;
      });
    } catch (e) {
      live.value = const LiveGps(hasPermission: false);
      error.value = 'LOCATION UNAVAILABLE';
    }
  }

  /// Try again after the user allows location.
  Future<void> retry() async {
    await stop();
    error.value = null;
    await start();
  }

  void _apply(Position p) {
    error.value = null;
    live.value = LiveGps(
      hasPermission: true,
      hasFix: true,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyFeet: (p.accuracy * 3.28084).round(),
      altitudeFeet: (p.altitude * 3.28084).round(),
      speedMph: p.speed >= 0 ? (p.speed * 2.23694).round() : null,
      bearingDegrees: p.heading >= 0 ? p.heading.round() : null,
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
