import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/mission_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

const _fallbackCenter = LatLng(29.4252, -98.4946);
const _satelliteUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const _streetUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

enum _MapStyle { onx, google }

Future<bool> _open(String url) async {
  try {
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Live map + vehicle panel + status tiles (FEATURES.md §2 Navigation).
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _controller = MapController();
  _MapStyle _style = _MapStyle.onx;
  bool _mapReady = false;
  bool _centeredOnFix = false;

  LatLng _centerFor(LiveGps gps) => gps.hasFix ? LatLng(gps.latitude, gps.longitude) : _fallbackCenter;

  void _recenter(LiveGps gps) {
    if (!_mapReady) return;
    try {
      _controller.move(_centerFor(gps), 16);
    } catch (_) {}
  }

  void _maybeCenterOnFirstFix(LiveGps gps) {
    if (_centeredOnFix || !gps.hasFix || !_mapReady) return;
    _centeredOnFix = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recenter(gps);
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final panel = _VehiclePanel(app: app);
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
                      Expanded(flex: 3, child: SingleChildScrollView(child: panel)),
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
                  panel,
                  const SizedBox(height: 14),
                  tabs,
                ]),
              ),
      ),
    );
  }

  Widget _buildMapCard(LiveGps gps, AppState app) {
    final center = _centerFor(gps);
    final stops = MissionTracker.stops;
    final speed = gps.speedMph ?? 0;
    final acc = gps.accuracyFeet;
    final satellite = _style == _MapStyle.onx;

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
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                onMapReady: () {
                  _mapReady = true;
                  if (gps.hasFix) {
                    _centeredOnFix = true;
                    _recenter(gps);
                  }
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey(satellite),
                  urlTemplate: satellite ? _satelliteUrl : _streetUrl,
                  userAgentPackageName: 'com.drivestpg.commandcenter',
                ),
                MarkerLayer(markers: [
                  for (final s in stops)
                    Marker(
                      point: LatLng(s.latitude, s.longitude),
                      width: 28,
                      height: 28,
                      child: Tooltip(
                        message: s.name,
                        child: const Icon(Icons.flag, color: Stpg.orange, size: 22, shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ]),
                      ),
                    ),
                  if (gps.hasFix)
                    Marker(
                      point: LatLng(gps.latitude, gps.longitude),
                      width: 44,
                      height: 44,
                      child: _Puck(bearing: gps.bearingDegrees),
                    ),
                ]),
              ],
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
          // Recenter
          Positioned(
            right: 12,
            top: 12,
            child: Material(
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
          ),
          // Attribution
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black.withValues(alpha: 0.5),
              child: const Text('© OpenStreetMap / Esri', style: TextStyle(color: Colors.white70, fontSize: 9)),
            ),
          ),
          // Footer overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
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
            bottom: 12,
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

class _Puck extends StatelessWidget {
  final int? bearing;
  const _Puck({this.bearing});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1E88E5);
    return Stack(alignment: Alignment.center, children: [
      if (bearing != null)
        Transform.rotate(
          angle: bearing! * math.pi / 180,
          child: const Align(
            alignment: Alignment.topCenter,
            child: Icon(Icons.arrow_drop_up, color: blue, size: 26),
          ),
        ),
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: blue.withValues(alpha: 0.25),
        ),
      ),
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: blue,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
    ]);
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
