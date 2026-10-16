import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/mission_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_map.dart';
import '../widgets/stpg_widgets.dart';

/// 05 // TRIPS — history of recorded Coastal Convoy runs.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<MissionTripState>? _trips;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MissionTracker.instance.history();
    if (mounted) setState(() => _trips = list);
  }

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  String _date(int ms) {
    if (ms <= 0) return '--';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${_months[d.month - 1]} ${d.day}, ${d.year} • $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final trips = _trips;
    final totalMiles = trips?.fold<double>(0, (a, t) => a + t.miles) ?? 0;
    final totalSecs = trips?.fold<int>(0, (a, t) => a + t.elapsedSeconds) ?? 0;

    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '05 // TRIPS',
          title: 'TRIP HISTORY',
          subtitle: 'COASTAL CONVOY // DRIVEN ROUTES',
          backLabel: '← BACK // COMMS',
          onBack: app.back,
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _summary('TOTAL TRIPS', '${trips?.length ?? 0}'),
          _summary('TOTAL MILES', totalMiles.toStringAsFixed(1)),
          _summary('TOTAL TIME', missionDuration(totalSecs)),
        ]),
        const SizedBox(height: 16),
        if (kIsWeb)
          StpgPanel(
            child: Text('Trip history is stored on the tablet; not available in the web preview.',
                style: Stpg.label(size: 13, spacing: 0.5, weight: FontWeight.w600)),
          )
        else if (trips == null)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (trips.isEmpty)
          StpgPanel(
            child: Text('NO TRIPS RECORDED YET — START A MISSION FROM THE COMMAND CENTER.',
                style: Stpg.label(size: 13, spacing: 1.2)),
          )
        else
          ...trips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TripCard(
                  trip: t,
                  date: _date(t.startedAt),
                  expanded: _expanded == t.tripId,
                  onTap: () => setState(() => _expanded = _expanded == t.tripId ? null : t.tripId),
                  onDeleted: _load,
                ),
              )),
      ]),
    );
  }

  Widget _summary(String label, String value) => SizedBox(
        width: 200,
        child: StpgPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LabeledValue(label, value, valueColor: Stpg.orange, valueSize: 22),
        ),
      );
}

class _TripCard extends StatelessWidget {
  final MissionTripState trip;
  final String date;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  const _TripCard({
    required this.trip,
    required this.date,
    required this.expanded,
    required this.onTap,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final completed = trip.status == 'COMPLETED';
    return StpgPanel(
      onTap: onTap,
      highlighted: expanded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(date, style: Stpg.title(size: 17))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (completed ? Stpg.green : Stpg.orange).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: completed ? Stpg.green : Stpg.orange),
            ),
            child: Text(trip.status,
                style: Stpg.label(size: 11, color: completed ? Stpg.green : Stpg.orange, spacing: 1.2)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${trip.miles.toStringAsFixed(1)} MI • ${missionDuration(trip.elapsedSeconds)} • ${trip.pointCount} PTS',
            style: Stpg.label(size: 12, spacing: 1.2)),
        if (expanded) ...[
          const SizedBox(height: 12),
          _TripDetail(trip: trip, onDeleted: onDeleted),
        ],
      ]),
    );
  }
}

class _TripDetail extends StatefulWidget {
  final MissionTripState trip;
  final VoidCallback onDeleted;
  const _TripDetail({required this.trip, required this.onDeleted});

  @override
  State<_TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends State<_TripDetail> {
  final _controller = StpgMapController();
  List<List<LatLng>>? _segments;

  @override
  void initState() {
    super.initState();
    MissionTracker.instance.trackSegments(widget.trip.tripId).then((s) {
      if (!mounted) return;
      setState(() => _segments = s);
      final all = s.expand((e) => e).toList();
      if (all.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _controller.fitPoints(all));
      }
    });
  }

  Future<void> _export() async {
    final path = await MissionTracker.instance.gpxPath(widget.trip.tripId);
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPX file for this trip.')));
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: 'application/gpx+xml')],
      text: 'STPG Coastal Convoy driven route',
    ));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('DELETE TRIP?'),
        content: const Text('The recorded route and GPX file will be removed from this tablet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('KEEP')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok != true) return;
    await MissionTracker.instance.deleteTrip(widget.trip.tripId);
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final segs = _segments;
    final all = segs?.expand((e) => e).toList() ?? const <LatLng>[];
    final stops = MissionTracker.stops;
    final center = all.isNotEmpty ? all.first : LatLng(stops.first.latitude, stops.first.longitude);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 280,
          child: segs == null
              ? const Center(child: CircularProgressIndicator())
              : all.isEmpty
                  ? Center(child: Text('NO GPS POINTS RECORDED', style: Stpg.label(size: 12)))
                  : StpgMap(
                      center: center,
                      zoom: 12,
                      satellite: true,
                      showMyLocation: false,
                      controller: _controller,
                      lines: [for (final s in segs) StpgMapLine(points: s, color: Stpg.orange)],
                      markers: [
                        StpgMapMarker(id: 'start', point: all.first, label: 'START', kind: StpgMarkerKind.stop, color: Stpg.green),
                        StpgMapMarker(id: 'end', point: all.last, label: 'END', kind: StpgMarkerKind.stop, color: Stpg.red),
                      ],
                    ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        StpgButton('EXPORT GPX', filled: true, onTap: _export),
        StpgButton('DELETE', color: Stpg.red, onTap: _delete),
      ]),
    ]);
  }
}
