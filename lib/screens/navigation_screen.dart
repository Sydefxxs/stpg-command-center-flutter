import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/convoy_service.dart';
import '../services/directions_service.dart';
import '../services/mission_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_map.dart';
import '../widgets/stpg_widgets.dart';

const _fallbackCenter = LatLng(29.4252, -98.4946);

enum _MapStyle { onx, google }

Future<bool> _open(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String _dist(int meters) {
  final mi = meters / 1609.344;
  return mi >= 0.1 ? '${mi.toStringAsFixed(1)} MI' : '${(meters * 3.28084).round()} FT';
}

/// Live map + vehicle/directions panel + status tiles (FEATURES.md §2 Navigation).
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _map = StpgMapController();
  _MapStyle _style = _MapStyle.onx;
  bool _centeredOnFix = false;

  RouteResult? _route;
  bool _routing = false;
  String? _routeError;
  bool _showDirections = false;

  LatLng _centerFor(LiveGps gps) => gps.hasFix ? LatLng(gps.latitude, gps.longitude) : _fallbackCenter;

  void _recenter(LiveGps gps) => _map.moveTo(_centerFor(gps), zoom: 16);

  void _maybeCenterOnFirstFix(LiveGps gps) {
    if (_centeredOnFix || !gps.hasFix) return;
    _centeredOnFix = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recenter(gps);
    });
  }

  Future<void> _openOnx() async {
    if (await _open('onxoffroad://')) return;
    await _open('https://play.google.com/store/apps/details?id=onxmaps.offroad');
  }

  Future<void> _openGoogle(LiveGps gps) async {
    final c = _centerFor(gps);
    await _open('https://www.google.com/maps/search/?api=1&query=${c.latitude},${c.longitude}');
  }

  List<LatLng> get _stopPoints => [for (final s in MissionTracker.stops) LatLng(s.latitude, s.longitude)];

  Future<void> _buildRoute(LiveGps gps) async {
    setState(() {
      _routing = true;
      _routeError = null;
    });
    try {
      final r = await DirectionsService.route(_centerFor(gps), _stopPoints);
      if (!mounted) return;
      setState(() {
        _route = r;
        _showDirections = true;
      });
      if (r.points.length > 1) _map.fitPoints(r.points);
    } catch (e) {
      if (mounted) setState(() => _routeError = 'ROUTE ERROR // ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _clearRoute() => setState(() {
        _route = null;
        _routeError = null;
        _showDirections = false;
      });

  Future<void> _openRouteInGoogle(LiveGps gps) async {
    final o = _centerFor(gps);
    final stops = _stopPoints;
    final dest = stops.last;
    final way = stops.sublist(0, stops.length - 1).map((p) => '${p.latitude},${p.longitude}').join('%7C');
    await _open('https://www.google.com/maps/dir/?api=1&origin=${o.latitude},${o.longitude}'
        '&destination=${dest.latitude},${dest.longitude}&waypoints=$way&travelmode=driving');
  }

  /// Index of the next step: first step whose start is ahead (not already passed) of the driver.
  int _nextStep(LiveGps gps) {
    final r = _route;
    if (r == null || r.steps.isEmpty || !gps.hasFix) return 0;
    const dist = Distance();
    final me = LatLng(gps.latitude, gps.longitude);
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < r.steps.length; i++) {
      final d = dist.as(LengthUnit.Meter, me, r.steps[i].start);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    // If we're within ~400 m past the closest step's start, the next maneuver is the following one.
    return (bestD < 400 && best + 1 < r.steps.length) ? best + 1 : best;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final gps = app.gps;
    _maybeCenterOnFirstFix(gps);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final header = _Header(app: app);
    final tiles = _StatusTiles(app: app);
    final map = _buildMapCard(gps, app);
    final panel = _showDirections && _route != null ? _directionsPanel(gps) : _VehiclePanel(app: app);
    final toggle = _route == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(child: StpgButton('VEHICLE', filled: !_showDirections, expand: true, height: 38, onTap: () => setState(() => _showDirections = false))),
              const SizedBox(width: 8),
              Expanded(child: StpgButton('DIRECTIONS', filled: _showDirections, expand: true, height: 38, onTap: () => setState(() => _showDirections = true))),
            ]),
          );
    final tabs = _BottomTabs(app: app);

    return Container(
      color: Stpg.dark,
      child: SafeArea(
        child: wide
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(children: [
                  header,
                  const SizedBox(height: 14),
                  tiles,
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(flex: 7, child: map),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: SingleChildScrollView(child: Column(children: [toggle, panel]))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  tabs,
                ]),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  header,
                  const SizedBox(height: 14),
                  tiles,
                  const SizedBox(height: 14),
                  SizedBox(height: 420, child: map),
                  const SizedBox(height: 14),
                  toggle,
                  panel,
                  const SizedBox(height: 14),
                  tabs,
                ]),
              ),
      ),
    );
  }

  Widget _directionsPanel(LiveGps gps) {
    final r = _route!;
    final next = _nextStep(gps);
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('CONVOY ROUTE', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 6),
        Text('${(r.distanceMeters / 1609.344).toStringAsFixed(1)} MI • ${(r.durationSeconds / 60).round()} MIN',
            style: Stpg.title(size: 22)),
        Text('TO ${MissionTracker.stops.last.name.toUpperCase()}', style: Stpg.label(size: 11)),
        const SizedBox(height: 10),
        for (var i = 0; i < r.steps.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: i == next ? Stpg.activePanel : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: i == next ? Stpg.orange : Stpg.border),
            ),
            child: Row(children: [
              Expanded(
                child: Text(r.steps[i].instruction.toUpperCase(),
                    style: Stpg.label(size: 12, color: i == next ? Stpg.orange : Stpg.text, spacing: 0.8)),
              ),
              const SizedBox(width: 8),
              Text(_dist(r.steps[i].distanceMeters), style: Stpg.label(size: 11)),
            ]),
          ),
        const SizedBox(height: 8),
        StpgButton('OPEN IN GOOGLE MAPS', filled: true, expand: true, onTap: () => _openRouteInGoogle(gps)),
        const SizedBox(height: 8),
        StpgButton('CLEAR ROUTE', expand: true, onTap: _clearRoute),
      ]),
    );
  }

  Widget _buildMapCard(LiveGps gps, AppState app) {
    final stops = MissionTracker.stops;
    final speed = gps.speedMph ?? 0;
    final acc = gps.accuracyFeet;
    final satellite = _style == _MapStyle.onx;
    final r = _route;
    final next = r == null || r.steps.isEmpty ? null : r.steps[_nextStep(gps)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Stpg.black, width: 5),
        color: Stpg.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(children: [
          Positioned.fill(
            child: ValueListenableBuilder<List<ConvoyDriver>>(
              valueListenable: ConvoyService.instance.drivers,
              builder: (context, drivers, _) => StpgMap(
                center: _centerFor(gps),
                zoom: 16,
                satellite: satellite,
                controller: _map,
                lines: [if (r != null) StpgMapLine(points: r.points, color: Stpg.orange, width: 6)],
                markers: [
                  for (final s in stops)
                    StpgMapMarker(id: 'stop-${s.name}', point: LatLng(s.latitude, s.longitude), label: s.name),
                  for (final d in drivers)
                    if (d.userId != app.userId)
                      StpgMapMarker(
                        id: d.userId,
                        point: LatLng(d.latitude, d.longitude),
                        label: d.driverNumber != null ? '#${d.driverNumber.toString().padLeft(3, '0')}' : d.name,
                        kind: d.sos ? StpgMarkerKind.alert : StpgMarkerKind.driver,
                        rotation: d.heading?.toDouble(),
                      ),
                  if (gps.hasFix)
                    StpgMapMarker(
                      id: 'me',
                      point: LatLng(gps.latitude, gps.longitude),
                      label: 'YOU',
                      kind: StpgMarkerKind.self,
                      rotation: gps.bearingDegrees?.toDouble(),
                    ),
                ],
              ),
            ),
          ),
          // Next-maneuver banner
          if (next != null)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.sizeOf(context).width < 600 ? 116 : 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Stpg.orange, borderRadius: BorderRadius.circular(14)),
                child: Text('NEXT // ${next.instruction.toUpperCase()} • ${_dist(next.distanceMeters)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Stpg.label(size: 14, color: Colors.white, spacing: 1)),
              ),
            ),
          // Style chips
          Positioned(
            left: 12,
            top: 12,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _StyleChip(
                label: 'onX',
                selected: _style == _MapStyle.onx,
                onTap: () => setState(() => _style = _MapStyle.onx),
                onDoubleTap: _openOnx,
              ),
              const SizedBox(width: 8),
              _StyleChip(
                label: 'GOOGLE',
                selected: _style == _MapStyle.google,
                onTap: () => setState(() => _style = _MapStyle.google),
                onDoubleTap: () => _openGoogle(gps),
              ),
            ]),
          ),
          // Convoy route + recenter (second row on phones)
          Positioned(
            right: 12,
            top: MediaQuery.sizeOf(context).width < 600 ? 64 : 12,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              StpgButton(_routing ? 'ROUTING...' : 'CONVOY ROUTE',
                  filled: true, height: 42, onTap: _routing ? null : () => _buildRoute(gps)),
              const SizedBox(width: 8),
              Material(
                color: Colors.black.withValues(alpha: 0.7),
                shape: const CircleBorder(side: BorderSide(color: Stpg.orange, width: 1.5)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _recenter(gps),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(child: Text('◎', style: TextStyle(color: Stpg.orange, fontSize: 22, fontWeight: FontWeight.w900))),
                  ),
                ),
              ),
            ]),
          ),
          if (_routeError != null)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.sizeOf(context).width < 600 ? 116 : 64,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Stpg.red, borderRadius: BorderRadius.circular(12)),
                child: Text(_routeError!, style: Stpg.label(size: 12, color: Colors.white, spacing: 1)),
              ),
            ),
          // Attribution
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black.withValues(alpha: 0.5),
              child: Text(
                StpgConfig.hasGoogleMaps
                    ? '© Google'
                    : 'MAP DATA // OSM + ESRI — ADD GOOGLE KEY FOR GOOGLE MAPS',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
          ),
          // Footer overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('SPEED // $speed MPH',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('ACC ± ${acc ?? 0} FT',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  const _StyleChip({required this.label, required this.selected, required this.onTap, required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Stpg.orange : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Stpg.orange, width: 1.4),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : Stpg.orange,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            )),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppState app;
  const _Header({required this.app});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final brand = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('STPG', style: Stpg.title(size: narrow ? 26 : 32, color: Stpg.orange, spacing: 2)),
      const SizedBox(width: 12),
      Flexible(
        child: Text('SOUTH TEXAS PROVING GROUNDS',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: narrow ? 10 : 12, spacing: 2)),
      ),
    ]);
    final driver = Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text('DRIVER #${app.driverNumberText}', style: Stpg.title(size: narrow ? 15 : 18, color: Stpg.orange, spacing: 1.5)),
      const SizedBox(height: 2),
      Text(app.vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, spacing: 1.5)),
    ]);
    final home = StpgButton('⌂ COMMAND CENTER', height: 42, onTap: () => app.go(CommandScreen.home));

    if (narrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: brand), const SizedBox(width: 8), driver]),
        const SizedBox(height: 10),
        home,
      ]);
    }
    return Row(children: [
      Expanded(child: brand),
      const SizedBox(width: 16),
      driver,
      const SizedBox(width: 16),
      home,
    ]);
  }
}

class _StatusTiles extends StatelessWidget {
  final AppState app;
  const _StatusTiles({required this.app});

  @override
  Widget build(BuildContext context) {
    final locked = app.gps.hasFix;
    final active = app.trip.active;
    final items = <Widget>[
      _StatusTile(label: 'GPS', value: locked ? 'LOCKED' : 'ACQUIRING', color: locked ? Stpg.green : Stpg.orange),
      const _StatusTile(label: 'NETWORK', value: 'ONLINE', color: Stpg.green),
      const _StatusTile(label: 'VEHICLE', value: 'CONNECTED', color: Stpg.green),
      _StatusTile(label: 'MISSION', value: active ? 'ACTIVE' : 'STANDBY', color: active ? Stpg.green : Stpg.orange),
    ];
    if (MediaQuery.sizeOf(context).width < 600) {
      return Column(children: [
        Row(children: [Expanded(child: items[0]), const SizedBox(width: 10), Expanded(child: items[1])]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: items[2]), const SizedBox(width: 10), Expanded(child: items[3])]),
      ]);
    }
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: items[i]),
      ],
    ]);
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatusTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return StpgPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 10)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 13, color: color, spacing: 0.8)),
          ),
        ]),
      ]),
    );
  }
}

class _VehiclePanel extends StatelessWidget {
  final AppState app;
  const _VehiclePanel({required this.app});

  @override
  Widget build(BuildContext context) {
    final gps = app.gps;
    final alt = gps.altitudeFeet;
    final speed = gps.speedMph;
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('VEHICLE', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 6),
        Text(app.vehicleName, maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 22)),
        const SizedBox(height: 10),
        Divider(color: Stpg.border, height: 1),
        const LabeledValue('DRIVE MODE', 'NORMAL'),
        const LabeledValue('FUEL', '-- %'),
        const LabeledValue('RANGE', '--- MI'),
        LabeledValue('ALTITUDE', alt == null ? '--- FT' : '$alt FT'),
        LabeledValue('SPEED', '${speed ?? 0} MPH'),
      ]),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  final AppState app;
  const _BottomTabs({required this.app});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      const CommandTile(icon: StpgIcons.navigation, title: 'NAV', subtitle: 'LIVE MAP', selected: true),
      CommandTile(
        icon: StpgIcons.comms,
        title: 'COMMS',
        subtitle: 'DRIVERS / DISPATCH',
        onTap: () => app.go(CommandScreen.comms),
      ),
      CommandTile(
        icon: StpgIcons.vehicle,
        title: 'VEHICLE',
        subtitle: app.vehicleName,
        onTap: () => app.go(CommandScreen.vehicle),
      ),
      CommandTile(
        icon: StpgIcons.portal,
        title: 'PORTAL',
        subtitle: 'DRIVER PORTAL',
        onTap: () => _open(StpgConfig.driverPortalUrl),
      ),
    ];
    final narrow = MediaQuery.sizeOf(context).width < 900;
    if (narrow) {
      return Column(children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 10),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 10),
          Expanded(child: tiles[3]),
        ]),
      ]);
    }
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        Expanded(child: tiles[i]),
      ],
    ]);
  }
}
