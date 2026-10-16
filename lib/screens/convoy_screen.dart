import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models.dart';
import '../services/convoy_service.dart';
import '../services/hazard_service.dart';
import '../services/heading_service.dart';
import '../services/mission_tracker.dart';
import '../services/route_guidance.dart';
import '../services/wake_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_map.dart';
import '../widgets/stpg_widgets.dart';

/// 04 // CONVOY — every driver sharing location, live on one map.
class ConvoyScreen extends StatefulWidget {
  const ConvoyScreen({super.key});

  @override
  State<ConvoyScreen> createState() => _ConvoyScreenState();
}

class _ConvoyScreenState extends State<ConvoyScreen> {
  final _map = StpgMapController();
  bool _satellite = true;

  @override
  void initState() {
    super.initState();
    WakeService.instance.hold('convoy');
  }

  @override
  void dispose() {
    WakeService.instance.release('convoy');
    super.dispose();
  }

  static double _miles(double lat1, double lng1, double lat2, double lng2) {
    const r = 3958.8; // earth radius in miles
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0, 1).toDouble()));
  }

  String _label(ConvoyDriver d) =>
      d.driverNumber != null ? '#${d.driverNumber.toString().padLeft(3, '0')}' : (d.name.isEmpty ? 'DRIVER' : d.name);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final svc = ConvoyService.instance;
    final narrow = MediaQuery.sizeOf(context).width < 900;

    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '04 // CONVOY',
          title: 'LIVE CONVOY',
          subtitle: 'STPG FIELD NETWORK // LIVE GPS',
          backLabel: '← BACK // COMMS',
          onBack: app.back,
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: svc.sharing,
              builder: (context, on, _) => StpgButton(
                on ? '● SHARING ON' : '○ SHARING OFF',
                color: on ? Stpg.green : Stpg.gray,
                onTap: () => svc.sharing.value = !on,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String?>(
          valueListenable: svc.error,
          builder: (context, err, _) => err == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StpgPanel(
                    borderColor: Stpg.red,
                    color: Stpg.alertPanel,
                    child: Text(err, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1.2)),
                  ),
                ),
        ),
        ValueListenableBuilder<List<ConvoyDriver>>(
          valueListenable: svc.drivers,
          builder: (context, drivers, _) => ValueListenableBuilder<List<Hazard>>(
            valueListenable: HazardService.instance.hazards,
            builder: (context, _, _) => _body(app, drivers, narrow),
          ),
        ),
      ]),
    );
  }

  Widget _body(AppState app, List<ConvoyDriver> drivers, bool narrow) {
    final me = app.gps;
    final myId = app.userId;
    final stops = MissionTracker.stops;
    final last = stops.last;
    final now = DateTime.now();

    // Leader = driver closest to the final convoy stop.
    ConvoyDriver? leader;
    double leaderDist = double.infinity;
    for (final d in drivers) {
      final dist = _miles(d.latitude, d.longitude, last.latitude, last.longitude);
      if (dist < leaderDist) {
        leaderDist = dist;
        leader = d;
      }
    }
    final myDistToEnd = me.hasFix ? _miles(me.latitude, me.longitude, last.latitude, last.longitude) : null;
    final behind = (leader != null && leader.userId != myId && myDistToEnd != null)
        ? RouteGuidance.instance.behindLeaderMiles.value
        : 0.0;

    final sorted = [...drivers]
      ..sort((a, b) {
        if (!me.hasFix) return a.name.compareTo(b.name);
        return _miles(me.latitude, me.longitude, a.latitude, a.longitude)
            .compareTo(_miles(me.latitude, me.longitude, b.latitude, b.longitude));
      });

    final center = me.hasFix
        ? LatLng(me.latitude, me.longitude)
        : (drivers.isNotEmpty ? LatLng(drivers.first.latitude, drivers.first.longitude) : LatLng(stops.first.latitude, stops.first.longitude));

    final markers = <StpgMapMarker>[
      for (final s in stops)
        StpgMapMarker(id: 'stop-${s.name}', point: LatLng(s.latitude, s.longitude), label: s.name, kind: StpgMarkerKind.stop),
      for (final d in drivers)
        if (d.userId != myId)
          StpgMapMarker(
            id: d.userId,
            point: LatLng(d.latitude, d.longitude),
            label: _label(d),
            kind: d.sos ? StpgMarkerKind.alert : StpgMarkerKind.driver,
            rotation: d.heading?.toDouble(),
          ),
      for (final h in HazardService.instance.hazards.value)
        StpgMapMarker(id: 'hz-${h.id}', point: LatLng(h.latitude, h.longitude), label: '⚠ ${h.kind}', kind: StpgMarkerKind.alert),
      if (me.hasFix)
        StpgMapMarker(
          id: 'me',
          point: LatLng(me.latitude, me.longitude),
          label: 'YOU',
          kind: StpgMarkerKind.self,
          rotation: HeadingService.instance.heading.value ?? me.bearingDegrees?.toDouble(),
        ),
    ];

    final mapCard = StpgPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: narrow ? 380 : 520,
          child: Stack(children: [
            Positioned.fill(
              child: StpgMap(center: center, zoom: 11, satellite: _satellite, markers: markers, controller: _map),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Wrap(spacing: 8, children: [
                _chip('SATELLITE', _satellite, () => setState(() => _satellite = true)),
                _chip('ROAD', !_satellite, () => setState(() => _satellite = false)),
              ]),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: StpgButton('FIT CONVOY', filled: true, height: 40, onTap: () {
                final pts = markers.map((m) => m.point).toList();
                if (pts.length > 1) _map.fitPoints(pts);
              }),
            ),
          ]),
        ),
      ),
    );

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (behind > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StpgPanel(
            borderColor: Stpg.orange,
            color: Stpg.activePanel,
            child: Text('YOU ARE ${behind.toStringAsFixed(1)} MI BEHIND THE LEADER',
                style: Stpg.label(size: 13, color: Stpg.orange, spacing: 1.2)),
          ),
        ),
      StpgPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHeader(icon: Icons.groups_outlined, title: 'DRIVERS // ${drivers.length}'),
          const SizedBox(height: 10),
          if (drivers.isEmpty)
            Text('NO DRIVERS SHARING LOCATION', style: Stpg.label(size: 12, spacing: 1.2))
          else
            for (final d in sorted) _driverRow(d, me, myId, leader, now),
        ]),
      ),
    ]);

    return ResponsiveSplit(main: mapCard, side: side, mainFlex: 3, sideFlex: 1);
  }

  Widget _driverRow(ConvoyDriver d, LiveGps me, String? myId, ConvoyDriver? leader, DateTime now) {
    final ageSecs = now.difference(d.updatedAt).inSeconds;
    final stale = ageSecs > StpgConfig.convoyStaleSeconds;
    final dist = me.hasFix ? _miles(me.latitude, me.longitude, d.latitude, d.longitude) : null;
    final isMe = d.userId == myId;
    return InkWell(
      onTap: () => _map.moveTo(LatLng(d.latitude, d.longitude), zoom: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    isMe ? 'YOU (${_label(d)})' : '${_label(d)}  ${d.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Stpg.title(size: 14, spacing: 0.8),
                  ),
                ),
                if (leader?.userId == d.userId) _badge('LEADER', Stpg.orange),
                if (d.sos) _badge('SOS', Stpg.red),
              ]),
              const SizedBox(height: 2),
              Text(
                '${dist == null || isMe ? '--' : dist.toStringAsFixed(1)} MI • ${d.speedMph ?? 0} MPH',
                style: Stpg.label(size: 11, spacing: 1),
              ),
            ]),
          ),
          Text(stale ? 'STALE ${ageSecs ~/ 60} MIN' : 'LIVE',
              style: Stpg.label(size: 11, color: stale ? Stpg.orange : Stpg.green, spacing: 1)),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color c) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: Stpg.label(size: 9, color: Colors.white, spacing: 1)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Material(
        color: selected ? Stpg.orange : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(label, style: Stpg.label(size: 11, color: selected ? Colors.white : Colors.black87, spacing: 1.2)),
          ),
        ),
      );
}
