import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// Raptor Vehicle Center (placeholder data until an OBD-II link exists).
class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final name = app.hasAssignedVehicle ? app.vehicleName : '2025 FORD RAPTOR 37';
    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '03 // VEHICLE',
          title: 'RAPTOR VEHICLE CENTER',
          subtitle: name,
          backLabel: '← BACK // COMMAND CENTER',
          onBack: app.back,
        ),
        const SizedBox(height: 20),
        ResponsiveSplit(
          mainFlex: 3,
          sideFlex: 2,
          main: StpgPanel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VEHICLE STATUS', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
              const SizedBox(height: 10),
              const LabeledValue('DRIVE MODE', 'NORMAL', valueSize: 26),
              const LabeledValue('FUEL LEVEL', '-- %', valueSize: 26),
              const LabeledValue('EST. RANGE', '--- MI', valueSize: 26),
              LabeledValue('ALTITUDE', '${app.gps.altitudeFeet ?? 0} FT', valueSize: 26),
              LabeledValue('GPS SPEED', '${app.gps.speedMph ?? 0} MPH', valueSize: 26),
              const SizedBox(height: 10),
              Text('LIVE VEHICLE DATA // FUTURE LINK', style: Stpg.label(size: 10)),
            ]),
          ),
          side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            _SystemPanel(title: 'POWERTRAIN', detail: 'ENGINE / TRANSMISSION', status: '● READY', ready: true),
            SizedBox(height: 14),
            _SystemPanel(title: 'OFF-ROAD SYSTEMS', detail: 'TERRAIN / SUSPENSION', status: '● READY', ready: true),
            SizedBox(height: 14),
            _SystemPanel(title: 'AUXILIARY', detail: 'LIGHTING / ACCESSORIES', status: '● STANDBY', ready: false),
          ]),
        ),
      ]),
    );
  }
}

class _SystemPanel extends StatelessWidget {
  final String title, detail, status;
  final bool ready;
  const _SystemPanel({required this.title, required this.detail, required this.status, required this.ready});

  @override
  Widget build(BuildContext context) {
    return StpgPanel(
      onTap: () => showStpgDialog<void>(
        context,
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$title // DIAGNOSTICS', style: Stpg.title(size: 20, color: Stpg.orange)),
          const SizedBox(height: 12),
          Text('Live vehicle data link coming soon. Connect an OBD-II adapter in a future update.',
              style: Stpg.label(size: 13, weight: FontWeight.w600, spacing: 0.5)),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: StpgButton('CLOSE', onTap: () => Navigator.of(ctx).pop()),
          ),
        ]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 8),
        Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 18)),
        const SizedBox(height: 8),
        Text(status, style: Stpg.label(size: 13, color: ready ? Stpg.green : Stpg.orange, spacing: 1.5)),
      ]),
    );
  }
}
