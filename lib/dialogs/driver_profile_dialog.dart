import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/legal_links.dart';
import '../widgets/stpg_widgets.dart';

/// "FOUNDING DRIVER PROFILE" modal: badge, name, assigned vehicle, sign out.
Future<void> showDriverProfileDialog(BuildContext context) {
  return showStpgDialog<void>(
    context,
    maxWidth: 480,
    builder: (ctx) {
      final app = AppScope.of(ctx);
      final profile = app.driverProfile;
      final name = (profile?.fullName.trim().isNotEmpty ?? false) ? profile!.fullName.trim().toUpperCase() : '---';
      final vehicle = app.hasAssignedVehicle ? profile!.vehicle.trim().toUpperCase() : 'NO VEHICLE ASSIGNED';
      final photo = app.badgePhoto;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('FOUNDING DRIVER PROFILE', style: Stpg.title(size: 20, color: Stpg.orange, spacing: 1.6)),
          const SizedBox(height: 18),
          Text('DRIVER BADGE', style: Stpg.label(size: 10)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Stpg.deepPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Stpg.border),
            ),
            child: Row(children: [
              if (photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photo,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (c, e, s) => const SizedBox(width: 84, height: 84),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(app.driverNumberText, style: Stpg.title(size: 60, color: Stpg.orange, spacing: 2)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          LabeledValue('DRIVER NAME', name, valueSize: 18),
          LabeledValue(
            'ASSIGNED VEHICLE',
            vehicle,
            valueSize: 18,
            valueColor: app.hasAssignedVehicle ? null : Stpg.gray,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                app.signOut();
              },
              child: Text('SWITCH DRIVER / SIGN OUT', style: Stpg.label(size: 13, color: Stpg.red, spacing: 1.6)),
            ),
          ),
          const SizedBox(height: 8),
          StpgButton('CLOSE', expand: true, filled: true, onTap: () => Navigator.of(ctx).pop()),
          const SizedBox(height: 6),
          const LegalLinks(showDelete: true),
        ],
      );
    },
  );
}
