import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class _Pt {
  final double lat, lng;
  final int timeMs, segment;
  const _Pt(this.lat, this.lng, this.timeMs, this.segment);
}

/// Sample filter implementing the Coastal Convoy recording rules.
class _Accumulator {
  static const _earthR = 6371008.8;

  _Pt? last;
  double lastAccuracy = 0;
  int segment = 0;
  double distance = 0;

  void reset() {
    last = null;
    lastAccuracy = 0;
    segment = 0;
    distance = 0;
  }

  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthR * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Returns the accepted point, or null if rejected.
  _Pt? accept(Position p, int nowMs) {
    final acc = p.accuracy;
    if (acc.isNaN || acc > 50) return null;
    final timeMs = p.timestamp.millisecondsSinceEpoch;
    if (nowMs - timeMs > 15000) return null;
    final prev = last;
    if (prev == null) {
      final pt = _Pt(p.latitude, p.longitude, timeMs, segment);
      last = pt;
      lastAccuracy = acc;
      return pt;
    }
    final dt = timeMs - prev.timeMs;
    if (dt < 2000) return null;
    if (dt > 30000) {
      segment++;
      final pt = _Pt(p.latitude, p.longitude, timeMs, segment);
      last = pt;
      lastAccuracy = acc;
      return pt;
    }
    final speed = p.speed;
    if (!speed.isNaN && speed > 85) return null;
    final d = haversine(prev.lat, prev.lng, p.latitude, p.longitude);
    if (d < math.max(5.0, 0.7 * math.max(acc, lastAccuracy))) return null;
    if (!speed.isNaN && speed >= 0 && speed < 1 && d < 15) return null;
    distance += d;
    final pt = _Pt(p.latitude, p.longitude, timeMs, segment);
    last = pt;
    lastAccuracy = acc;
    return pt;
  }
}

class MissionTracker {
  MissionTracker._();
  static final instance = MissionTracker._();

  static const title = 'COASTAL CONVOY';
  static const stops = <ConvoyStop>[
    ConvoyStop('Hacienda Ford', 26.3055915, -98.1961975),
    ConvoyStop('TEX BEST Travel Center', 26.0154662, -97.4819084),
    ConvoyStop('South Padre Island Convention Center', 26.1410463, -97.1751285),
    ConvoyStop('Cameron County Beach Access #6', 26.2073291, -97.1787862),
  ];

  /// Current trip state; UI listens to this.
  final ValueNotifier<MissionTripState> state = ValueNotifier(const MissionTripState());

  final _Accumulator _acc = _Accumulator();
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Future<void> _writeChain = Future<void>.value();
  int _sinceSave = 0;
  bool _finishing = false;

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/mission_trips');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> _saveState() async {
    if (kIsWeb) return;
    try {
      final d = await _dir();
      final tmp = File('${d.path}/latest.json.tmp');
      await tmp.writeAsString(jsonEncode(state.value.toJson()), flush: true);
      await tmp.rename('${d.path}/latest.json');
    } catch (_) {}
  }

  /// Load latest.json; mark interrupted trips. Called once at app start.
  Future<void> restore() async {
    if (kIsWeb) return;
    try {
      final d = await _dir();
      final f = File('${d.path}/latest.json');
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map<String, dynamic>) return;
      var s = MissionTripState.fromJson(j);
      if (s.active || s.saving) {
        var gpxName = s.gpxFileName;
        if (s.tripId.isNotEmpty) {
          try {
            gpxName = await _writeGpx(s.tripId, s.startedAt);
          } catch (_) {}
        }
        s = s.copyWith(
          active: false,
          saving: false,
          status: 'INTERRUPTED',
          gpxFileName: gpxName,
          error: 'Recording was interrupted. The saved portion is available; start a new mission to continue.',
        );
        state.value = s;
        await _saveState();
      } else {
        state.value = s;
      }
    } catch (_) {}
  }

  /// Start recording. Returns an error message, or null on success.
  Future<String?> start() async {
    if (kIsWeb) return 'Mission recording is not available on web.';
    if (state.value.active || state.value.saving) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fail("Turn on the tablet's Location setting, then tap Start Mission again.");
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return _fail('Allow precise location to record your driven route.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final tripId = 'Coastal_Convoy_$now';
      _acc.reset();
      _sinceSave = 0;
      _finishing = false;
      _writeChain = Future<void>.value();
      final d = await _dir();
      await File('${d.path}/$tripId.csv').writeAsString('', flush: true);

      state.value = MissionTripState(
        tripId: tripId,
        active: true,
        status: 'ACQUIRING GPS',
        startedAt: now,
      );
      await _saveState();

      final LocationSettings settings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'STPG • Coastal Convoy recording',
            notificationText: 'Recording your driven route',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        settings = AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 2,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      } else {
        settings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2);
      }

      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        _onPosition,
        onError: (Object _) {
          _finish('INTERRUPTED', 'Location updates stopped. Recording stopped.');
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final s = state.value;
        if (!s.active) return;
        final secs = ((DateTime.now().millisecondsSinceEpoch - s.startedAt) / 1000).floor();
        state.value = s.copyWith(elapsedSeconds: math.max(0, secs));
      });
      return null;
    } catch (e) {
      await _cancelSources();
      return _fail('Could not start recording. $e');
    }
  }

  String _fail(String message) {
    state.value = state.value.copyWith(active: false, saving: false, error: message);
    return message;
  }

  Future<void> _cancelSources() async {
    _timer?.cancel();
    _timer = null;
    final s = _sub;
    _sub = null;
    try {
      await s?.cancel();
    } catch (_) {}
  }

  void _onPosition(Position p) {
    if (!state.value.active || _finishing) return;
    final pt = _acc.accept(p, DateTime.now().millisecondsSinceEpoch);
    if (pt == null) return;
    final tripId = state.value.tripId;
    final line = '${pt.lat},${pt.lng},${pt.timeMs},${pt.segment}\n';
    _writeChain = _writeChain.then((_) async {
      if (_finishing) return;
      final d = await _dir();
      await File('${d.path}/$tripId.csv').writeAsString(line, mode: FileMode.append, flush: true);
    }).catchError((Object _) {
      _finish('INTERRUPTED', 'Route storage failed. Recording stopped.');
    });
    state.value = state.value.copyWith(
      status: 'ACTIVE',
      distanceMeters: _acc.distance,
      pointCount: state.value.pointCount + 1,
      error: '',
    );
    _sinceSave++;
    if (_sinceSave >= 10) {
      _sinceSave = 0;
      _saveState();
    }
  }

  Future<void> _finish(String status, String error) async {
    if (_finishing) return;
    _finishing = true;
    await _cancelSources();
    var gpxName = state.value.gpxFileName;
    try {
      if (state.value.tripId.isNotEmpty) {
        gpxName = await _writeGpx(state.value.tripId, state.value.startedAt);
      }
    } catch (_) {}
    state.value = state.value.copyWith(
      active: false,
      saving: false,
      status: status,
      gpxFileName: gpxName,
      error: error,
    );
    await _saveState();
  }

  /// Stop recording, write GPX. Returns an error message, or null on success.
  Future<String?> end() async {
    if (kIsWeb) return null;
    if (!state.value.active) return null;
    _finishing = true;
    await _cancelSources();
    state.value = state.value.copyWith(saving: true, status: 'COMPLETED');
    try {
      await _writeChain;
    } catch (_) {}
    String? err;
    var gpxName = state.value.gpxFileName;
    try {
      gpxName = await _writeGpx(state.value.tripId, state.value.startedAt);
    } catch (_) {
      err = 'GPX export failed; the recorded points remain on this tablet.';
    }
    state.value = state.value.copyWith(
      active: false,
      saving: false,
      status: 'COMPLETED',
      gpxFileName: gpxName,
      error: err ?? '',
    );
    await _saveState();
    return err;
  }

  /// Absolute path of the latest GPX file, or null.
  Future<String?> latestGpxPath() async {
    if (kIsWeb) return null;
    final name = state.value.gpxFileName;
    if (name.isEmpty) return null;
    try {
      final d = await _dir();
      final f = File('${d.path}/$name');
      return await f.exists() ? f.path : null;
    } catch (_) {
      return null;
    }
  }

  // ---- GPX ----

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _utc(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
  }

  /// Builds `<tripId>.gpx` from the CSV; returns the file name.
  Future<String> _writeGpx(String tripId, int startedAt) async {
    final d = await _dir();
    final csv = File('${d.path}/$tripId.csv');
    final points = <_Pt>[];
    if (await csv.exists()) {
      for (final line in await csv.readAsLines()) {
        final p = line.split(',');
        if (p.length < 4) continue;
        final lat = double.tryParse(p[0]);
        final lng = double.tryParse(p[1]);
        final t = int.tryParse(p[2]);
        final seg = int.tryParse(p[3]);
        if (lat == null || lng == null || t == null || seg == null) continue;
        points.add(_Pt(lat, lng, t, seg));
      }
    }
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="STPG Command Center" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <metadata>')
      ..writeln('    <name>STPG Coastal Convoy</name>')
      ..writeln('    <time>${_utc(startedAt)}</time>')
      ..writeln('  </metadata>');
    for (final s in stops) {
      b
        ..writeln('  <wpt lat="${s.latitude}" lon="${s.longitude}">')
        ..writeln('    <name>${_esc(s.name)}</name>')
        ..writeln('  </wpt>');
    }
    b
      ..writeln('  <trk>')
      ..writeln('    <name>Driven route</name>');
    int? curSeg;
    for (final p in points) {
      if (curSeg != p.segment) {
        if (curSeg != null) b.writeln('    </trkseg>');
        b.writeln('    <trkseg>');
        curSeg = p.segment;
      }
      b
        ..writeln('      <trkpt lat="${p.lat}" lon="${p.lng}">')
        ..writeln('        <time>${_utc(p.timeMs)}</time>')
        ..writeln('      </trkpt>');
    }
    if (curSeg != null) b.writeln('    </trkseg>');
    b
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    final name = '$tripId.gpx';
    await File('${d.path}/$name').writeAsString(b.toString(), flush: true);
    return name;
  }
}
