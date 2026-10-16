import 'package:flutter/material.dart';

import '../services/heading_service.dart';
import '../theme.dart';

/// Horizontal heading tape with a fixed center marker and a degree readout.
/// Driven by [HeadingService] (phone compass, or GPS course while driving).
class CompassHud extends StatelessWidget {
  /// Kept for compatibility; the HUD now reads [HeadingService] directly.
  final int? headingDegrees;
  final double width;
  const CompassHud({super.key, this.headingDegrees, this.width = 300});

  static const _cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  static String cardinal(double h) => _cardinals[((h + 22.5) % 360 ~/ 45) % 8];

  @override
  Widget build(BuildContext context) {
    final svc = HeadingService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([svc.continuous, svc.source]),
      builder: (context, _) {
        final hasHeading = svc.heading.value != null;
        final h = svc.heading.value ?? 0;
        final src = svc.source.value;
        return GestureDetector(
          onTap: svc.needsTap ? () => svc.enable() : null,
          child: Semantics(
            label: hasHeading ? 'Heading ${h.round()} degrees ${cardinal(h)}' : 'Compass inactive',
            child: Container(
              width: width,
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 44,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: svc.continuous.value),
                      duration: const Duration(milliseconds: 250),
                      builder: (context, value, _) => CustomPaint(
                        size: Size(width, 44),
                        painter: _TapePainter(heading: ((value % 360) + 360) % 360, active: hasHeading),
                      ),
                    ),
                  ),
                ),
                if (svc.needsTap)
                  Text('TAP TO ENABLE COMPASS', style: Stpg.label(size: 11, color: Stpg.orange, spacing: 1.6))
                else
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      hasHeading ? '${h.round().toString().padLeft(3, '0')}° ${cardinal(h)}' : '---°',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: src == HeadingSource.none ? Colors.white38 : Stpg.orange),
                      ),
                      child: Text(
                        switch (src) {
                          HeadingSource.magnetic => 'MAG',
                          HeadingSource.gps => 'GPS',
                          HeadingSource.none => 'NO SIGNAL',
                        },
                        style: TextStyle(
                          color: src == HeadingSource.none ? Colors.white54 : Stpg.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _TapePainter extends CustomPainter {
  final double heading;
  final bool active;
  _TapePainter({required this.heading, required this.active});

  static const double _pxPerDeg = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final tick = Paint()..color = Colors.white.withValues(alpha: active ? 0.6 : 0.3);
    for (var deg = 0; deg < 360; deg += 5) {
      var diff = ((deg - heading + 540) % 360) - 180;
      final x = cx + diff * _pxPerDeg;
      if (x < 4 || x > size.width - 4) continue;
      final major = deg % 15 == 0;
      tick.strokeWidth = major ? 1.5 : 1;
      canvas.drawLine(Offset(x, size.height - (major ? 12 : 7)), Offset(x, size.height - 2), tick);
      if (deg % 45 == 0) {
        final label = CompassHud._cardinals[deg ~/ 45];
        final cardinal = deg % 90 == 0;
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: cardinal ? 18 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: deg == 0
                  ? Stpg.orange
                  : (cardinal ? const Color(0xFFE2E6EC) : const Color(0xFF9DA5B0)).withValues(alpha: active ? 1 : 0.5),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, cardinal ? 8 : 12));
      }
    }
    // Fixed center marker (lubber line)
    final marker = Paint()..color = Stpg.orange;
    final path = Path()
      ..moveTo(cx - 7, 0)
      ..lineTo(cx + 7, 0)
      ..lineTo(cx, 8)
      ..close();
    canvas.drawPath(path, marker);
    canvas.drawRect(Rect.fromLTWH(cx - 1, size.height - 14, 2, 14), marker);
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.heading != heading || old.active != active;
}
