import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/hazard_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

IconData hazardIcon(String kind) => switch (kind) {
      'WASHOUT' => Icons.water_damage_outlined,
      'DEEP SAND' => Icons.landscape_outlined,
      'MUD' => Icons.terrain,
      'ROCKS' => Icons.filter_hdr_outlined,
      'WATER CROSSING' => Icons.water,
      'LIVESTOCK' => Icons.pets,
      'DEBRIS' => Icons.construction,
      'POLICE' => Icons.local_police_outlined,
      _ => Icons.warning_amber_rounded,
    };

/// One-tap hazard pin at the driver's current spot.
Future<void> showHazardDialog(BuildContext context) {
  return showStpgDialog(
    context,
    maxWidth: 560,
    builder: (ctx) => const _HazardPicker(),
  );
}

class _HazardPicker extends StatefulWidget {
  const _HazardPicker();

  @override
  State<_HazardPicker> createState() => _HazardPickerState();
}

class _HazardPickerState extends State<_HazardPicker> {
  bool _sending = false;
  String? _error;

  Future<void> _drop(String kind) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await HazardService.instance.drop(kind);
    if (!mounted) return;
    if (err == null) {
      VoiceService.instance.speak('${kind.toLowerCase()} marked for the convoy.', force: true);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 500;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('MARK HAZARD', style: Stpg.title(size: 22, color: Stpg.orange, spacing: 1.5)),
      const SizedBox(height: 4),
      Text('PINS YOUR CURRENT SPOT FOR THE WHOLE CONVOY // 12 HRS', style: Stpg.label(size: 11, spacing: 1.2)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: narrow ? 2 : 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: narrow ? 2.1 : 1.8,
        children: [
          for (final k in HazardService.kinds)
            StpgPanel(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onTap: _sending ? null : () => _drop(k),
              child: Row(children: [
                Icon(hazardIcon(k), color: Stpg.orange, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(k, maxLines: 2, style: Stpg.label(size: 12, color: Stpg.text, spacing: 1))),
              ]),
            ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1)),
      ],
      const SizedBox(height: 16),
      StpgButton(_sending ? 'SENDING…' : 'CANCEL', expand: true, onTap: () => Navigator.of(context).pop()),
    ]);
  }
}
