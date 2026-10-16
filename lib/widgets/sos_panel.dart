import 'package:flutter/material.dart';

import '../services/sos_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Big red SOS control: hold 2 s to start a live-location beacon; tap CANCEL to stop.
class SosPanel extends StatefulWidget {
  const SosPanel({super.key});

  @override
  State<SosPanel> createState() => _SosPanelState();
}

class _SosPanelState extends State<SosPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _send();
        });
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    _hold.reset();
    final app = AppScope.read(context);
    setState(() {
      _working = true;
      _error = null;
    });
    final err = await SosService.instance.start(app);
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = err;
    });
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('CANCEL SOS?'),
        content: const Text('STPG Command will stop receiving your live location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('KEEP SOS ON')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('CANCEL SOS')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _working = true);
    final err = await SosService.instance.stop(AppScope.read(context));
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = err;
    });
  }

  String _time(DateTime? t) {
    if (t == null) return '--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: SosService.instance.active,
      builder: (context, active, _) {
        final body = active ? _activeBody(app) : _idleBody();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: active ? Stpg.red : Stpg.alertPanel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Stpg.red, width: 2),
          ),
          child: body,
        );
      },
    );
  }

  Widget _idleBody() {
    final button = GestureDetector(
      onLongPressStart: (_) {
        if (!_working) _hold.forward(from: 0);
      },
      onLongPressEnd: (_) {
        if (_hold.status != AnimationStatus.completed) _hold.reset();
      },
      child: SizedBox(
        width: 96,
        height: 96,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(
                value: _working ? null : _hold.value,
                strokeWidth: 6,
                color: Colors.white,
                backgroundColor: Stpg.red.withValues(alpha: 0.25),
              ),
            ),
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(color: Stpg.red, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('SOS', style: Stpg.title(size: 24, color: Colors.white, spacing: 2)),
            ),
          ]),
        ),
      ),
    );
    return Row(children: [
      button,
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SOS // LIVE LOCATION BEACON', style: Stpg.label(size: 12, color: Stpg.red, spacing: 2)),
          const SizedBox(height: 6),
          Text('HOLD 2 SECONDS TO SEND SOS', style: Stpg.title(size: 18)),
          const SizedBox(height: 6),
          Text('STPG Command gets your position every 30 seconds until you cancel or they resolve it.',
              style: Stpg.label(size: 11, spacing: 0.5, weight: FontWeight.w600)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1)),
          ],
        ]),
      ),
    ]);
  }

  Widget _activeBody(AppState app) {
    final g = app.gps;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.sos, color: Colors.white, size: 30),
        const SizedBox(width: 10),
        Expanded(child: Text('SOS ACTIVE // BEACON EVERY 30 S', style: Stpg.title(size: 20, color: Colors.white))),
      ]),
      const SizedBox(height: 8),
      ValueListenableBuilder<DateTime?>(
        valueListenable: SosService.instance.lastSent,
        builder: (context, t, _) =>
            Text('LAST SENT // ${_time(t)}', style: Stpg.label(size: 12, color: Colors.white, spacing: 1.5)),
      ),
      const SizedBox(height: 4),
      Text(
        g.hasFix
            ? 'LIVE GPS // ${g.latitude.toStringAsFixed(6)}, ${g.longitude.toStringAsFixed(6)}'
            : 'LIVE GPS // ACQUIRING POSITION',
        style: Stpg.label(size: 12, color: Colors.white, spacing: 1.5),
      ),
      if (_error != null) ...[
        const SizedBox(height: 6),
        Text(_error!, style: Stpg.label(size: 12, color: Colors.white, spacing: 1)),
      ],
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _working ? null : _cancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Text(_working ? 'CANCELLING...' : '✕ CANCEL SOS',
            style: Stpg.label(size: 13, color: Colors.white, spacing: 1.8)),
      ),
    ]);
  }
}
