import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import 'convoy_service.dart';
import 'directions_service.dart';
import 'gps_service.dart';
import 'hazard_service.dart';
import 'heading_service.dart';
import 'mission_tracker.dart';
import 'voice_service.dart';
import 'wake_service.dart';

/// Live progress along the active route.
class GuidanceState {
  final RouteResult? route;
  final int nextStep;
  final double metersToNext;
  final double metersRemaining;
  final int secondsRemaining;
  final bool offRoute;
  final bool rerouting;
  final bool arrived;
  const GuidanceState({
    this.route,
    this.nextStep = 0,
    this.metersToNext = 0,
    this.metersRemaining = 0,
    this.secondsRemaining = 0,
    this.offRoute = false,
    this.rerouting = false,
    this.arrived = false,
  });

  bool get active => route != null;
  RouteStep? get step => route == null || route!.steps.isEmpty ? null : route!.steps[nextStep];
  DateTime get eta => DateTime.now().add(Duration(seconds: secondsRemaining));
}

/// Turn-by-turn engine shared by the Navigation screen and Drive Mode:
/// tracks progress, speaks upcoming turns, reroutes when you leave the route,
/// warns about hazard pins ahead and about falling behind the convoy leader.
class RouteGuidance {
  RouteGuidance._();
  static final instance = RouteGuidance._();

  final ValueNotifier<GuidanceState> state = ValueNotifier(const GuidanceState());
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);

  /// Miles behind the convoy leader (0 when leading / unknown).
  final ValueNotifier<double> behindLeaderMiles = ValueNotifier(0);

  static const _dist = Distance();
  static const _offRouteMeters = 75.0;
  static const _stopReachedMeters = 150.0;

  List<LatLng> _pts = const [];
  List<double> _cum = const [];
  List<double> _stepAt = const [];
  List<LatLng> _remainingStops = const [];
  int _offCount = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _spoken = {};
  final Set<String> _hazardsWarned = {};
  DateTime _lastBehindCall = DateTime.fromMillisecondsSinceEpoch(0);
  bool _listening = false;

  /// Starts listening to GPS (call once after sign-in).
  void start() {
    if (_listening) return;
    _listening = true;
    GpsService.instance.live.addListener(_onFix);
    ConvoyService.instance.drivers.addListener(_onConvoy);
  }

  List<LatLng> get missionStops => [for (final s in MissionTracker.stops) LatLng(s.latitude, s.longitude)];

  /// Builds a route from the current position through [stops] (defaults to the mission stops).
  Future<void> startRoute(LiveGps gps, {List<LatLng>? stops, LatLng? fallbackOrigin}) async {
    final targets = stops ?? missionStops;
    final origin = gps.hasFix ? LatLng(gps.latitude, gps.longitude) : fallbackOrigin;
    if (origin == null || targets.isEmpty) {
      error.value = 'ROUTE ERROR // NO GPS FIX';
      return;
    }
    busy.value = true;
    error.value = null;
    try {
      final r = await DirectionsService.route(origin, targets);
      _remainingStops = List.of(targets);
      _load(r);
      final mi = r.distanceMeters / 1609.344;
      VoiceService.instance.speak(
          'Route ready. ${mi.toStringAsFixed(mi < 10 ? 1 : 0)} miles, about ${_minutes(r.durationSeconds)}.',
          force: true);
      WakeService.instance.hold('route');
    } catch (e) {
      error.value = 'ROUTE ERROR // ${e.toString().replaceFirst('Exception: ', '')}';
    } finally {
      busy.value = false;
    }
  }

  void clear() {
    _pts = const [];
    _cum = const [];
    _stepAt = const [];
    _remainingStops = const [];
    _spoken.clear();
    state.value = const GuidanceState();
    error.value = null;
    WakeService.instance.release('route');
  }

  void _load(RouteResult r) {
    _pts = r.points;
    final cum = List<double>.filled(_pts.length, 0);
    for (var i = 1; i < _pts.length; i++) {
      cum[i] = cum[i - 1] + _dist.as(LengthUnit.Meter, _pts[i - 1], _pts[i]);
    }
    _cum = cum;
    _stepAt = [for (final s in r.steps) _project(s.start).along];
    _spoken.clear();
    _offCount = 0;
    state.value = GuidanceState(route: r, metersRemaining: cum.isEmpty ? 0 : cum.last, secondsRemaining: r.durationSeconds);
    final g = GpsService.instance.live.value;
    if (g.hasFix) _onFix();
  }

  /// Closest point on the polyline: distance off-route and distance along the route.
  ({double off, double along}) _project(LatLng p) {
    if (_pts.length < 2) return (off: 0, along: 0);
    final cosLat = math.cos(p.latitude * math.pi / 180);
    const mPerDeg = 111320.0;
    var bestOff = double.infinity, bestAlong = 0.0;
    for (var i = 0; i < _pts.length - 1; i++) {
      final a = _pts[i], b = _pts[i + 1];
      final ax = (a.longitude - p.longitude) * mPerDeg * cosLat, ay = (a.latitude - p.latitude) * mPerDeg;
      final bx = (b.longitude - p.longitude) * mPerDeg * cosLat, by = (b.latitude - p.latitude) * mPerDeg;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final px = ax + t * dx, py = ay + t * dy;
      final d = math.sqrt(px * px + py * py);
      if (d < bestOff) {
        bestOff = d;
        bestAlong = _cum[i] + t * (_cum[i + 1] - _cum[i]);
      }
    }
    return (off: bestOff, along: bestAlong);
  }

  void _onFix() {
    final g = GpsService.instance.live.value;
    if (!g.hasFix) return;
    final me = LatLng(g.latitude, g.longitude);
    _checkHazards(me, g);
    final s = state.value;
    final r = s.route;
    if (r == null || _pts.length < 2) return;

    // Drop mission stops we've reached so a reroute doesn't send us back.
    _remainingStops = [
      for (final st in _remainingStops)
        if (_dist.as(LengthUnit.Meter, me, st) > _stopReachedMeters) st
    ];

    final pr = _project(me);
    final total = _cum.last;
    final remaining = math.max(0.0, total - pr.along);
    var next = r.steps.length - 1;
    for (var i = 0; i < _stepAt.length; i++) {
      if (_stepAt[i] > pr.along + 10) {
        next = i;
        break;
      }
    }
    final toNext = r.steps.isEmpty ? remaining : math.max(0.0, _stepAt[next] - pr.along);
    final arrived = remaining < 60 || _remainingStops.isEmpty;

    // Off-route: several consecutive accurate fixes far from the line.
    final accurate = (g.accuracyFeet ?? 999) < 160;
    if (pr.off > _offRouteMeters && accurate && !arrived) {
      _offCount++;
    } else {
      _offCount = 0;
    }
    final offRoute = _offCount >= 3;

    state.value = GuidanceState(
      route: r,
      nextStep: next,
      metersToNext: toNext,
      metersRemaining: remaining,
      secondsRemaining: total == 0 ? 0 : (r.durationSeconds * remaining / total).round(),
      offRoute: offRoute,
      rerouting: s.rerouting,
      arrived: arrived,
    );

    if (arrived) {
      if (_spoken.add('arrived')) VoiceService.instance.speak('You have arrived at ${MissionTracker.stops.last.name}.');
      return;
    }
    if (offRoute) {
      _reroute(g);
      return;
    }
    _announce(next, toNext, r.steps.isEmpty ? null : r.steps[next], g.speedMph ?? 0);
  }

  void _announce(int i, double meters, RouteStep? step, int mph) {
    if (step == null) return;
    final text = _speakable(step.instruction);
    // Lead distance scales with speed: highway gets an earlier heads-up.
    final far = mph > 50 ? 1600.0 : 800.0;
    if (meters < 60) {
      if (_spoken.add('$i-now')) VoiceService.instance.speak('$text now');
    } else if (meters < 250) {
      if (_spoken.add('$i-near')) {
        _spoken.add('$i-far');
        VoiceService.instance.speak('In ${_spokenDist(meters)}, $text');
      }
    } else if (meters < far) {
      if (_spoken.add('$i-far')) VoiceService.instance.speak('In ${_spokenDist(meters)}, $text');
    }
  }

  Future<void> _reroute(LiveGps g) async {
    if (state.value.rerouting) return;
    if (DateTime.now().difference(_lastReroute).inSeconds < 20) return;
    if (_remainingStops.isEmpty) return;
    _lastReroute = DateTime.now();
    state.value = GuidanceState(
      route: state.value.route,
      nextStep: state.value.nextStep,
      metersToNext: state.value.metersToNext,
      metersRemaining: state.value.metersRemaining,
      secondsRemaining: state.value.secondsRemaining,
      offRoute: true,
      rerouting: true,
    );
    VoiceService.instance.speak('Off route. Recalculating.');
    try {
      final r = await DirectionsService.route(LatLng(g.latitude, g.longitude), _remainingStops);
      if (state.value.route == null) return; // cleared meanwhile
      _load(r);
    } catch (_) {
      final s = state.value;
      state.value = GuidanceState(
        route: s.route,
        nextStep: s.nextStep,
        metersToNext: s.metersToNext,
        metersRemaining: s.metersRemaining,
        secondsRemaining: s.secondsRemaining,
        offRoute: true,
      );
    }
  }

  // ---------------------------------------------------------------- hazards

  /// Speaks a warning once per hazard when it's within ~500 m and roughly ahead.
  void _checkHazards(LatLng me, LiveGps g) {
    final heading = HeadingService.instance.heading.value ?? g.bearingDegrees?.toDouble();
    for (final h in HazardService.instance.hazards.value) {
      if (_hazardsWarned.contains(h.id)) continue;
      final p = LatLng(h.latitude, h.longitude);
      final d = _dist.as(LengthUnit.Meter, me, p);
      if (d > 500) continue;
      if (heading != null && d > 60) {
        final brg = (_dist.bearing(me, p) + 360) % 360;
        final diff = ((brg - heading + 540) % 360) - 180;
        if (diff.abs() > 70) continue; // behind us
      }
      _hazardsWarned.add(h.id);
      VoiceService.instance.speak('Caution. ${h.kind.toLowerCase()} reported ahead, ${_spokenDist(d)}.');
    }
  }

  /// Meters to the nearest reported hazard roughly ahead (for the Drive Mode banner).
  ({Hazard hazard, double meters})? nearestHazardAhead() {
    final g = GpsService.instance.live.value;
    if (!g.hasFix) return null;
    final me = LatLng(g.latitude, g.longitude);
    final heading = HeadingService.instance.heading.value ?? g.bearingDegrees?.toDouble();
    ({Hazard hazard, double meters})? best;
    for (final h in HazardService.instance.hazards.value) {
      final p = LatLng(h.latitude, h.longitude);
      final d = _dist.as(LengthUnit.Meter, me, p);
      if (d > 1600) continue;
      if (heading != null && d > 60) {
        final diff = ((((_dist.bearing(me, p) + 360) % 360) - heading + 540) % 360) - 180;
        if (diff.abs() > 70) continue;
      }
      if (best == null || d < best.meters) best = (hazard: h, meters: d);
    }
    return best;
  }

  // ---------------------------------------------------------------- convoy

  void _onConvoy() {
    final g = GpsService.instance.live.value;
    final drivers = ConvoyService.instance.drivers.value;
    if (!g.hasFix || drivers.isEmpty) {
      behindLeaderMiles.value = 0;
      return;
    }
    final last = MissionTracker.stops.last;
    final end = LatLng(last.latitude, last.longitude);
    final now = DateTime.now();
    double? leaderDist;
    for (final d in drivers) {
      if (now.difference(d.updatedAt).inSeconds > 120) continue;
      final m = _dist.as(LengthUnit.Meter, LatLng(d.latitude, d.longitude), end);
      if (leaderDist == null || m < leaderDist) leaderDist = m;
    }
    if (leaderDist == null) {
      behindLeaderMiles.value = 0;
      return;
    }
    final mine = _dist.as(LengthUnit.Meter, LatLng(g.latitude, g.longitude), end);
    final behind = math.max(0.0, (mine - leaderDist) / 1609.344);
    behindLeaderMiles.value = behind;
    if (behind >= 2 && now.difference(_lastBehindCall).inMinutes >= 5) {
      _lastBehindCall = now;
      VoiceService.instance.speak('You are ${behind.toStringAsFixed(1)} miles behind the convoy leader.');
    }
  }

  // ---------------------------------------------------------------- text helpers

  static String _minutes(int secs) {
    final m = (secs / 60).round();
    if (m < 60) return '$m minutes';
    return '${m ~/ 60} hours ${m % 60} minutes';
  }

  static String _spokenDist(double meters) {
    final ft = meters * 3.28084;
    if (ft < 1000) return '${((ft / 50).round() * 50).clamp(50, 1000)} feet';
    final mi = meters / 1609.344;
    if (mi < 0.35) return 'a quarter mile';
    if (mi < 0.7) return 'half a mile';
    if (mi < 1.2) return '1 mile';
    return '${mi.toStringAsFixed(1)} miles';
  }

  static String _speakable(String instruction) =>
      instruction.toLowerCase().replaceAll(' - ', ', ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Short readable distance for banners.
  static String shortDist(double meters) {
    final mi = meters / 1609.344;
    return mi >= 0.1 ? '${mi.toStringAsFixed(mi < 10 ? 1 : 0)} MI' : '${(meters * 3.28084).round()} FT';
  }
}
