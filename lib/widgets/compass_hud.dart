import 'package:flutter/material.dart';

import '../theme.dart';

/// Horizontal compass strip. Cardinal letters slide with the GPS heading
/// (N is orange with a small ▲ marker above it). A translucent dark backing
/// keeps it readable over bright background photos.
class CompassHud extends StatelessWidget {
  final int? headingDegrees;
  const CompassHud({super.key, this.headingDegrees});

  static const double _width = 300;
  static const double _height = 54;
  static const double _pixelsPerDegree = 1.5;

  @override
  Widget build(BuildContext context) {
    final heading = (((headingDegrees ?? 0) % 360) + 360) % 360;
    final children = <Widget>[];

    for (var deg = 0; deg < 360; deg += 15) {
      final diff = ((deg - heading + 540) % 360) - 180;
      final x = _width / 2 + diff * _pixelsPerDegree;
      if (x < 12 || x > _width - 12) continue;

      final isCardinal = deg % 90 == 0;
      final isInter = deg % 45 == 0 && !isCardinal;

      if (!isCardinal && !isInter) {
        children.add(Positioned(
          left: x - 0.5,
          bottom: 7,
          child: Container(width: 1, height: 6, color: Colors.white.withValues(alpha: 0.55)),
        ));
        continue;
      }

      final label = switch (deg) {
        0 => 'N',
        45 => 'NE',
        90 => 'E',
        135 => 'SE',
        180 => 'S',
        225 => 'SW',
        270 => 'W',
        _ => 'NW',
      };
      final isNorth = deg == 0;
      children.add(Positioned(
        left: x - 18,
        top: 4,
        width: 36,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 11,
            child: isNorth
                ? const Text('▲', style: TextStyle(fontSize: 9, height: 1.2, color: Stpg.orange, fontWeight: FontWeight.w900))
                : null,
          ),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: isCardinal ? 22 : 12,
              height: isCardinal ? 1.15 : 1.9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: isNorth
                  ? Stpg.orange
                  : (isCardinal ? const Color(0xFFE2E6EC) : const Color(0xFF9DA5B0)),
            ),
          ),
        ]),
      ));
    }

    return Semantics(
      label: 'Compass heading $heading degrees',
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(children: children),
        ),
      ),
    );
  }
}
