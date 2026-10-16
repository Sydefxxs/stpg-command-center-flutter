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

  /// Asks for permission (if needed) and starts streaming. Safe to call repeatedly.
  Future<void> start() async {
    if (_sub != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      final granted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      if (!granted) {
        live.value = const LiveGps(hasPermission: false);
        return;
      }
      live.value = const LiveGps(hasPermission: true);
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _apply(last);
      } catch (_) {}
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0),
      ).listen(_apply, onError: (_) {});
    } catch (_) {
      live.value = const LiveGps(hasPermission: false);
    }
  }

  void _apply(Position p) {
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
