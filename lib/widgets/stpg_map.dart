import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../theme.dart';

enum StpgMarkerKind { self, driver, stop, alert }

class StpgMapMarker {
  final String id;
  final LatLng point;
  final String label;
  final StpgMarkerKind kind;
  final Color? color;
  final double? rotation; // heading degrees
  const StpgMapMarker({required this.id, required this.point, this.label = '', this.kind = StpgMarkerKind.stop, this.color, this.rotation});
}

class StpgMapLine {
  final List<LatLng> points;
  final Color color;
  final double width;
  const StpgMapLine({required this.points, required this.color, this.width = 5});
}

class StpgMapController {
  void Function(LatLng p, double? zoom)? _move;
  void Function(List<LatLng> pts)? _fit;
  void moveTo(LatLng p, {double? zoom}) => _move?.call(p, zoom);
  void fitPoints(List<LatLng> pts) => _fit?.call(pts);
  // ignore: library_private_types_in_public_api, use_setters_to_change_properties
  void attach(void Function(LatLng, double?) move, void Function(List<LatLng>) fit) {
    _move = move;
    _fit = fit;
  }
}

const _satelliteUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const _streetUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Google Maps when a key is configured (Android/iOS), otherwise flutter_map tiles.
class StpgMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final bool satellite;
  final List<StpgMapMarker> markers;
  final List<StpgMapLine> lines;
  final bool showMyLocation;
  final StpgMapController? controller;
  final void Function(StpgMapMarker marker)? onMarkerTap;
  const StpgMap({
    super.key,
    required this.center,
    this.zoom = 15,
    this.satellite = true,
    this.markers = const [],
    this.lines = const [],
    this.showMyLocation = true,
    this.controller,
    this.onMarkerTap,
  });

  @override
  State<StpgMap> createState() => _StpgMapState();
}

class _StpgMapState extends State<StpgMap> {
  final MapController _fmController = MapController();
  gm.GoogleMapController? _gmController;
  bool _fmReady = false;

  bool get _useGoogle => StpgConfig.hasGoogleMaps && !kIsWeb;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant StpgMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _attach();
  }

  void _attach() {
    widget.controller?.attach(_move, _fit);
  }

  gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  void _move(LatLng p, double? zoom) {
    if (_useGoogle) {
      final c = _gmController;
      if (c == null) return;
      c.animateCamera(zoom == null
          ? gm.CameraUpdate.newLatLng(_g(p))
          : gm.CameraUpdate.newLatLngZoom(_g(p), zoom));
      return;
    }
    if (!_fmReady) return;
    try {
      _fmController.move(p, zoom ?? _fmController.camera.zoom);
    } catch (_) {}
  }

  void _fit(List<LatLng> pts) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _move(pts.first, null);
      return;
    }
    if (_useGoogle) {
      final c = _gmController;
      if (c == null) return;
      var minLat = pts.first.latitude, maxLat = minLat;
      var minLng = pts.first.longitude, maxLng = minLng;
      for (final p in pts) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
      c.animateCamera(gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(southwest: gm.LatLng(minLat, minLng), northeast: gm.LatLng(maxLat, maxLng)),
        60,
      ));
      return;
    }
    if (!_fmReady) return;
    try {
      _fmController.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(60)));
    } catch (_) {}
  }

  @override
  void dispose() {
    _gmController?.dispose();
    _fmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _useGoogle ? _buildGoogle() : _buildFlutterMap();

  // ---------------- Google ----------------

  double _hue(StpgMapMarker m) {
    switch (m.kind) {
      case StpgMarkerKind.self:
        return gm.BitmapDescriptor.hueAzure;
      case StpgMarkerKind.alert:
        return gm.BitmapDescriptor.hueRed;
      case StpgMarkerKind.driver:
      case StpgMarkerKind.stop:
        final c = m.color;
        if (c != null) return HSVColor.fromColor(c).hue;
        return gm.BitmapDescriptor.hueOrange;
    }
  }

  Widget _buildGoogle() {
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: _g(widget.center), zoom: widget.zoom),
      mapType: widget.satellite ? gm.MapType.hybrid : gm.MapType.normal,
      trafficEnabled: !widget.satellite,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: {
        for (final m in widget.markers)
          gm.Marker(
            markerId: gm.MarkerId(m.id),
            position: _g(m.point),
            rotation: m.rotation ?? 0,
            infoWindow: gm.InfoWindow(title: m.label),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(_hue(m)),
            onTap: () => widget.onMarkerTap?.call(m),
          ),
      },
      polylines: {
        for (var i = 0; i < widget.lines.length; i++)
          gm.Polyline(
            polylineId: gm.PolylineId('line$i'),
            points: [for (final p in widget.lines[i].points) _g(p)],
            color: widget.lines[i].color,
            width: widget.lines[i].width.round(),
          ),
      },
      onMapCreated: (c) => _gmController = c,
    );
  }

  // ---------------- flutter_map ----------------

  Widget _buildFlutterMap() {
    return FlutterMap(
      mapController: _fmController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        onMapReady: () => _fmReady = true,
      ),
      children: [
        TileLayer(
          key: ValueKey(widget.satellite),
          urlTemplate: widget.satellite ? _satelliteUrl : _streetUrl,
          userAgentPackageName: 'com.drivestpg.commandcenter',
        ),
        PolylineLayer(polylines: [
          for (final l in widget.lines)
            if (l.points.length > 1)
              Polyline(
                points: l.points,
                color: l.color,
                strokeWidth: l.width,
                borderColor: Colors.black54,
                borderStrokeWidth: 1.5,
              ),
        ]),
        MarkerLayer(markers: [
          for (final m in widget.markers)
            Marker(
              point: m.point,
              width: m.kind == StpgMarkerKind.stop || m.kind == StpgMarkerKind.driver ? 96 : 56,
              height: m.kind == StpgMarkerKind.stop ? 52 : 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMarkerTap == null ? null : () => widget.onMarkerTap!(m),
                child: _markerWidget(m),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _markerWidget(StpgMapMarker m) {
    switch (m.kind) {
      case StpgMarkerKind.self:
        return _Puck(bearing: m.rotation);
      case StpgMarkerKind.driver:
        return Center(child: _DriverDot(label: m.label, color: m.color ?? Stpg.orange));
      case StpgMarkerKind.stop:
        return _StopFlag(label: m.label, color: m.color ?? Stpg.orange);
      case StpgMarkerKind.alert:
        return _SosPulse(label: m.label);
    }
  }
}

class _Puck extends StatelessWidget {
  final double? bearing;
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: blue.withValues(alpha: 0.25)),
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

class _DriverDot extends StatelessWidget {
  final String label;
  final Color color;
  const _DriverDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}

class _StopFlag extends StatelessWidget {
  final String label;
  final Color color;
  const _StopFlag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.flag, color: color, size: 24, shadows: const [Shadow(color: Colors.black87, blurRadius: 4)]),
      if (label.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
    ]);
  }
}

class _SosPulse extends StatefulWidget {
  final String label;
  const _SosPulse({required this.label});

  @override
  State<_SosPulse> createState() => _SosPulseState();
}

class _SosPulseState extends State<_SosPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final t = _ac.value;
        return Stack(alignment: Alignment.center, children: [
          Container(
            width: 24 + 28 * t,
            height: 24 + 28 * t,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Stpg.red.withValues(alpha: 0.45 * (1 - t))),
          ),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Stpg.red,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
            ),
            child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ]);
      },
    );
  }
}
