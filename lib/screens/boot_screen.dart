import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

const Color _bootGreen = Color(0xFF4CAF50);
const Color _bootGreenBright = Color(0xFF66FF66);
const Color _bootGray = Color(0xFF6B737D);

/// Boot sequence: status rows light up one at a time, then hands over to the
/// session check via [AppState.finishBoot].
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  static const _rows = <(String, String)>[
    ('DRIVER PROFILE', 'VERIFIED'),
    ('GPS SYSTEM', 'ONLINE'),
    ('NETWORK', 'ONLINE'),
    ('VEHICLE LINK', 'CONNECTED'),
    ('MISSION SYSTEM', 'STANDBY'),
    ('NAVIGATION', 'READY'),
  ];
  static const _totalMs = 2800;
  static const _stepMs = 350;

  late final AnimationController _c;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    unawaited(AppScope.read(context).finishBoot());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final elapsed = _c.value * _totalMs;
                    final lit = (elapsed ~/ _stepMs).clamp(0, _rows.length);
                    final done = lit >= _rows.length;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'STPG',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _bootGreen, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 8),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'RAPTOR COMMAND CENTER',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _bootGreen, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SYSTEM INITIALIZATION',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _bootGreen.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3),
                        ),
                        const SizedBox(height: 28),
                        for (var i = 0; i < _rows.length; i++) _row(_rows[i].$1, _rows[i].$2, i < lit),
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _c.value,
                            minHeight: 8,
                            backgroundColor: _bootGreen.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(_bootGreen),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          done ? 'ALL SYSTEMS OPERATIONAL' : 'INITIALIZING COMMAND SYSTEM...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: done ? _bootGreenBright : _bootGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, bool on) {
    final color = on ? _bootGreen : _bootGray;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            on ? value : 'CHECKING',
            maxLines: 1,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

/// Shown while the stored session is checked / refreshed.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Stpg.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'STPG',
                style: TextStyle(color: Stpg.orange, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 8),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Stpg.orange),
              ),
              const SizedBox(height: 18),
              Text(
                'CONNECTING TO COMMAND NETWORK...',
                textAlign: TextAlign.center,
                style: Stpg.label(size: 13, spacing: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
