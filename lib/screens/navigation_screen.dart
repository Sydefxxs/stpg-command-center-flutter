import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/convoy_service.dart';
import '../services/directions_service.dart';
import '../dialogs/hazard_dialog.dart';
import '../services/hazard_service.dart';
import '../services/heading_service.dart';
import '../services/route_guidance.dart';
import '../services/voice_service.dart';
import '../services/mission_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_map.dart';
import '../widgets/stpg_widgets.dart';
import 'drive_screen.dart';

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

  bool _showDirections = false;
  RouteGuidance get _g => RouteGuidance.instance;
  RouteResult? get _route => _g.state.value.route;
  bool get _routing => _g.busy.value;
  String? get _routeError => _g.error.value;

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
    VoiceService.instance.prime();
    await _g.startRoute(gps, fallbackOrigin: _fallbackCenter);
    final r = _route;
    if (!mounted || r == null) return;
    setState(() => _showDirections = true);
    if (r.points.length > 1) _map.fitPoints(r.points);
  }

  void _clearRoute() {
    _g.clear();
    setState(() => _showDirections = false);
  }

  Future<void> _openRouteInGoogle(LiveGps gps) async {
    final o = _centerFor(gps);
    final stops = _stopPoints;
    final dest = stops.last;
    final way = stops.sublist(0, stops.length - 1).map((p) => '${p.latitude},${p.longitude}').join('%7C');
    await _open('https://www.google.com/maps/dir/?api=1&origin=${o.latitude},${o.longitude}'
        '&destination=${dest.latitude},${dest.longitude}&waypoints=$way&travelmode=driving');
  }

  int _nextStep(LiveGps gps) => _g.state.value.nextStep;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_g.state, _g.busy, _g.error, HazardService.instance.hazards, VoiceService.instance.enabled]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
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

  void _hazardDetails(String id, AppState app) {
    final h = HazardService.instance.hazards.value.where((e) => e.id == id).firstOrNull;
    if (h == null) return;
    final age = DateTime.now().difference(h.createdAt);
    final ago = age.inMinutes < 60 ? '${age.inMinutes} MIN AGO' : '${age.inHours} HR AGO';
    final mine = h.userId == app.userId;
    showStpgDialog(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(hazardIcon(h.kind), color: Stpg.orange, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(h.kind, style: Stpg.title(size: 22, color: Stpg.orange))),
          ]),
          const SizedBox(height: 8),
          Text('REPORTED $ago${h.driverName == null ? '' : ' BY ${h.driverName!.toUpperCase()}'}', style: Stpg.label(size: 12)),
          if (h.note != null) ...[const SizedBox(height: 8), Text(h.note!, style: Stpg.label(size: 13, color: Stpg.text))],
          const SizedBox(height: 16),
          if (mine || app.isAdmin)
            StpgButton('REMOVE PIN', color: Stpg.red, expand: true, onTap: () {
              HazardService.instance.remove(h.id);
              Navigator.of(ctx).pop();
            }),
          const SizedBox(height: 8),
          StpgButton('CLOSE', expand: true, onTap: () => Navigator.of(ctx).pop()),
        ]));
  }

  Widget _directionsPanel(LiveGps gps) {
    final r = _route!;
    final next = _nextStep(gps);
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('CONVOY ROUTE', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 6),
        Text('${RouteGuidance.shortDist(_g.state.value.metersRemaining)} • ${(_g.state.value.secondsRemaining / 60).round()} MIN',
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
        StpgButton('▶ DRIVE MODE', filled: true, expand: true, onTap: () => AppScope.of(context).go(CommandScreen.drive)),
        const SizedBox(height: 8),
        StpgButton('OPEN IN GOOGLE MAPS', expand: true, onTap: () => _openRouteInGoogle(gps)),
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
    final gs = _g.state.value;
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
                onMarkerTap: (m) {
                  if (m.id.startsWith('hz-')) _hazardDetails(m.id.substring(3), app);
                },
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
                  for (final h in HazardService.instance.hazards.value)
                    StpgMapMarker(
                      id: 'hz-${h.id}',
                      point: LatLng(h.latitude, h.longitude),
                      label: '⚠ ${h.kind}',
                      kind: StpgMarkerKind.alert,
                    ),
                  if (gps.hasFix)
                    StpgMapMarker(
                      id: 'me',
                      point: LatLng(gps.latitude, gps.longitude),
                      label: 'YOU',
                      kind: StpgMarkerKind.self,
                      rotation: HeadingService.instance.heading.value ?? gps.bearingDegrees?.toDouble(),
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
                decoration: BoxDecoration(
                    color: gs.offRoute ? Stpg.red : (gs.arrived ? Stpg.green : Stpg.orange),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(gs.arrived ? Icons.flag : maneuverIcon(next.instruction), color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        gs.arrived
                            ? 'ARRIVED // ${MissionTracker.stops.last.name.toUpperCase()}'
                            : gs.rerouting
                                ? 'OFF ROUTE // RECALCULATING…'
                                : '${RouteGuidance.shortDist(gs.metersToNext)} // ${next.instruction.toUpperCase()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Stpg.label(size: 14, color: Colors.white, spacing: 1)),
                  ),
                ]),
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
          // Action rail: drive mode, hazard pin, voice
          Positioned(
            left: 10,
            bottom: 70,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _RoundAction(icon: Icons.speed, tooltip: 'Drive mode', onTap: () => app.go(CommandScreen.drive)),
              const SizedBox(height: 10),
              _RoundAction(
                  icon: Icons.warning_amber_rounded,
                  tooltip: 'Mark hazard',
                  color: const Color(0xFFFFC107),
                  onTap: () => showHazardDialog(context)),
              const SizedBox(height: 10),
              _RoundAction(
                icon: VoiceService.instance.enabled.value ? Icons.volume_up : Icons.volume_off,
                tooltip: 'Voice guidance',
                onTap: VoiceService.instance.toggle,
              ),
            ]),
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
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: accuracyColor(gps)),
                const SizedBox(width: 6),
                Text('ACC ± ${acc ?? '--'} FT',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ]),
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
      _StatusTile(
          label: 'GPS',
          value: locked ? '±${app.gps.accuracyFeet ?? '--'} FT' : 'ACQUIRING',
          color: locked ? accuracyColor(app.gps) : Stpg.orange),
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


/// Green ≤ 33 ft, orange ≤ 100 ft, red otherwise.
Color accuracyColor(LiveGps g) {
  final a = g.accuracyFeet;
  if (!g.hasFix || a == null) return Stpg.red;
  return a <= 33 ? Stpg.green : (a <= 100 ? Stpg.orange : Stpg.red);
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap, this.color = Stpg.orange});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        shape: CircleBorder(side: BorderSide(color: color, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: color, size: 24)),
        ),
      ),
    );
  }
}
