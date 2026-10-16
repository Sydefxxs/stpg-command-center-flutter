import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/mission_tracker.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

Future<void> showMissionControlsDialog(BuildContext context) {
  return showStpgDialog<void>(
    context,
    maxWidth: 560,
    builder: (_) => const _MissionControls(),
  );
}

class _MissionControls extends StatefulWidget {
  const _MissionControls();

  @override
  State<_MissionControls> createState() => _MissionControlsState();
}

class _MissionControlsState extends State<_MissionControls> {
  final _tracker = MissionTracker.instance;
  bool _starting = false;
  String _localError = '';
  String? _gpxPath;

  @override
  void initState() {
    super.initState();
    _refreshGpx();
  }

  Future<void> _refreshGpx() async {
    final p = await _tracker.latestGpxPath();
    if (mounted) setState(() => _gpxPath = p);
  }

  Future<bool> _openRoute() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(StpgConfig.convoyRouteUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return ok;
    setState(() => _localError =
        ok ? '' : 'Recording can continue, but no app was available to open the convoy route.');
    return ok;
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _localError = '';
    });
    final err = await _tracker.start();
    if (!mounted) return;
    setState(() => _starting = false);
    if (err == null) await _openRoute();
  }

  Future<void> _end() async {
    setState(() => _localError = '');
    await _tracker.end();
    await _refreshGpx();
  }

  Future<void> _export() async {
    final path = await _tracker.latestGpxPath();
    if (!mounted) return;
    if (path == null) {
      setState(() => _localError = 'No driven route file is available yet.');
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'application/gpx+xml')],
        text: 'STPG Coastal Convoy driven route',
      ));
    } catch (_) {
      if (mounted) setState(() => _localError = 'Could not open the share sheet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MissionTripState>(
      valueListenable: _tracker.state,
      builder: (context, s, _) {
        final busy = s.saving;
        final error = s.error.isNotEmpty ? s.error : _localError;
        final canExport = !s.active && !s.saving && s.gpxFileName.isNotEmpty && _gpxPath != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('STPG MISSION // COASTAL CONVOY',
                style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2.2)),
            const SizedBox(height: 10),
            Text(s.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Stpg.title(size: 34, spacing: 1.5)),
            const SizedBox(height: 6),
            Text(
              '${s.miles.toStringAsFixed(1)} MILES  •  ${missionDuration(s.elapsedSeconds)}',
              style: Stpg.label(size: 15, color: Stpg.text, spacing: 1.6),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < MissionTracker.stops.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i + 1}. ${MissionTracker.stops[i].name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Stpg.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 10),
            Text(
              s.active
                  ? 'Recording on this tablet, including while Maps is open. ${s.pointCount} GPS points recorded.'
                  : "Start recording, then open this run's route in Google Maps.",
              style: TextStyle(color: Stpg.gray, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(error,
                  style: TextStyle(color: Stpg.red, fontSize: 13, fontWeight: FontWeight.w800, height: 1.35)),
            ],
            const SizedBox(height: 16),
            if (s.active || s.saving)
              StpgButton(busy ? 'SAVING TRIP…' : 'END MISSION',
                  filled: true, expand: true, onTap: busy ? null : _end)
            else
              StpgButton(_starting ? 'STARTING…' : 'START MISSION',
                  filled: true, expand: true, onTap: _starting ? null : _start),
            const SizedBox(height: 10),
            StpgButton('OPEN CONVOY ROUTE', filled: true, expand: true, onTap: _openRoute),
            if (canExport) ...[
              const SizedBox(height: 10),
              StpgButton('EXPORT DRIVEN ROUTE (GPX)', filled: true, expand: true, onTap: _export),
            ] else if (s.active) ...[
              const SizedBox(height: 10),
              Text('Finish the mission before exporting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Stpg.gray, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 10),
            StpgButton('CLOSE', filled: true, expand: true, onTap: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }
}
