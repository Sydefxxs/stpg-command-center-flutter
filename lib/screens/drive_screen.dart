import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dialogs/hazard_dialog.dart';
import '../models.dart';
import '../services/hazard_service.dart';
import '../services/route_guidance.dart';
import '../services/voice_service.dart';
import '../services/wake_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/compass_hud.dart';

IconData maneuverIcon(String instruction) {
  final s = instruction.toUpperCase();
  if (s.contains('U-TURN')) return Icons.u_turn_left;
  if (s.contains('ROUNDABOUT') || s.contains('ROTARY')) return Icons.roundabout_right;
  if (s.contains('ARRIVE') || s.contains('DESTINATION')) return Icons.flag;
  if (s.contains('MERGE')) return Icons.merge;
  final left = s.contains('LEFT'), right = s.contains('RIGHT');
  final slight = s.contains('SLIGHT') || s.contains('KEEP') || s.contains('FORK');
  final sharp = s.contains('SHARP');
  if (s.contains('EXIT') || s.contains('RAMP')) return left ? Icons.ramp_left : Icons.ramp_right;
  if (left) return sharp ? Icons.turn_sharp_left : (slight ? Icons.turn_slight_left : Icons.turn_left);
  if (right) return sharp ? Icons.turn_sharp_right : (slight ? Icons.turn_slight_right : Icons.turn_right);
  return Icons.straight;
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Big, glanceable dash view: speed, heading, next turn, ETA, hazards, convoy gap.
class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  @override
  void initState() {
    super.initState();
    WakeService.instance.hold('drive');
  }

  @override
  void dispose() {
    WakeService.instance.release('drive');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = RouteGuidance.instance;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            g.state,
            g.error,
            g.busy,
            g.behindLeaderMiles,
            HazardService.instance.hazards,
            VoiceService.instance.enabled,
          ]),
          builder: (context, _) => LayoutBuilder(builder: (context, c) {
            final landscape = c.maxWidth > c.maxHeight && c.maxWidth > 600;
            final pad = c.maxWidth < 600 ? 12.0 : 20.0;
            final top = _topBar(app);
            final turn = _turnCard(app, g.state.value);
            final speed = _speed(app.gps, c);
            final stats = _stats(g.state.value, g.behindLeaderMiles.value);
            final buttons = _buttons(app);
            final banners = _banners(g);
            final compass = CompassHud(width: (landscape ? c.maxWidth / 2 - pad * 2 : c.maxWidth - pad * 2).clamp(240.0, 520.0));
            return Padding(
              padding: EdgeInsets.all(pad),
              child: landscape
                  ? Column(children: [
                      top,
                      const SizedBox(height: 10),
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(
                            child: Column(children: [turn, ...banners, const Spacer(), stats]),
                          ),
                          SizedBox(width: pad),
                          Expanded(
                            child: Column(children: [compass, Expanded(child: speed), buttons]),
                          ),
                        ]),
                      ),
                    ])
                  : Column(children: [
                      top,
                      const SizedBox(height: 10),
                      turn,
                      ...banners,
                      const SizedBox(height: 10),
                      compass,
                      Expanded(child: speed),
                      stats,
                      const SizedBox(height: 12),
                      buttons,
                    ]),
            );
          }),
        ),
      ),
    );
  }

  Widget _topBar(AppState app) {
    final acc = app.gps.accuracyFeet;
    final fix = app.gps.hasFix;
    final c = !fix ? Stpg.red : (acc != null && acc <= 33 ? Stpg.green : (acc != null && acc <= 100 ? Stpg.orange : Stpg.red));
    final voice = VoiceService.instance.enabled.value;
    return Row(children: [
      _pill('← EXIT', onTap: app.back),
      const SizedBox(width: 10),
      Text('DRIVE MODE', style: Stpg.title(size: 16, color: Stpg.orange, spacing: 2)),
      const Spacer(),
      Icon(Icons.gps_fixed, color: c, size: 18),
      const SizedBox(width: 4),
      Text(fix ? '±${acc ?? '--'} FT' : 'NO FIX', style: Stpg.label(size: 11, color: c, spacing: 1)),
      const SizedBox(width: 10),
      _pill(voice ? '🔊 VOICE' : '🔇 MUTED', active: voice, onTap: () {
        HapticFeedback.selectionClick();
        VoiceService.instance.toggle();
      }),
    ]);
  }

  Widget _pill(String label, {bool active = false, VoidCallback? onTap}) => Material(
        color: active ? Stpg.orange : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label, style: Stpg.label(size: 12, color: Colors.white, spacing: 1.2)),
          ),
        ),
      );

  Widget _turnCard(AppState app, GuidanceState s) {
    final step = s.step;
    if (!s.active || step == null) {
      final busy = RouteGuidance.instance.busy.value;
      return Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: busy
              ? null
              : () {
                  VoiceService.instance.prime();
                  RouteGuidance.instance.startRoute(app.gps);
                },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Stpg.orange, width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.alt_route, color: Stpg.orange, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(busy ? 'ROUTING…' : 'START CONVOY ROUTE', style: Stpg.title(size: 20, color: Colors.white)),
                  Text('TURN-BY-TURN WITH VOICE', style: Stpg.label(size: 11, spacing: 1.2)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    final color = s.arrived ? Stpg.green : (s.offRoute ? Stpg.red : Stpg.orange);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(s.arrived ? Icons.flag : maneuverIcon(step.instruction), color: Colors.white, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              s.arrived ? 'ARRIVED' : (s.rerouting ? 'REROUTING…' : RouteGuidance.shortDist(s.metersToNext)),
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              s.arrived ? 'CONVOY DESTINATION REACHED' : step.instruction.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
          ]),
        ),
        IconButton(
          tooltip: 'End route',
          onPressed: RouteGuidance.instance.clear,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ]),
    );
  }

  List<Widget> _banners(RouteGuidance g) {
    final out = <Widget>[];
    void add(String text, Color c, IconData icon) => out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.18),
              border: Border.all(color: c, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: Stpg.label(size: 13, color: c, spacing: 1.2))),
            ]),
          ),
        ));
    if (g.error.value != null) add(g.error.value!, Stpg.red, Icons.error_outline);
    final hz = g.nearestHazardAhead();
    if (hz != null) {
      add('${hz.hazard.kind} AHEAD // ${RouteGuidance.shortDist(hz.meters)}', const Color(0xFFFFC107), hazardIcon(hz.hazard.kind));
    }
    final behind = g.behindLeaderMiles.value;
    if (behind >= 1) add('${behind.toStringAsFixed(1)} MI BEHIND CONVOY LEADER', Stpg.orange, Icons.groups_outlined);
    return out;
  }

  Widget _speed(LiveGps gps, BoxConstraints c) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${gps.speedMph ?? 0}',
              style: const TextStyle(color: Colors.white, fontSize: 150, fontWeight: FontWeight.w900, height: 1)),
          Text('MPH', style: Stpg.label(size: 18, color: Stpg.orange, spacing: 4)),
        ]),
      ),
    );
  }

  Widget _stats(GuidanceState s, double behind) {
    Widget cell(String label, String value) => Expanded(
          child: Column(children: [
            Text(label, style: Stpg.label(size: 10, spacing: 1.5)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Stpg.title(size: 22, color: Colors.white)),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        cell('REMAINING', s.active ? RouteGuidance.shortDist(s.metersRemaining) : '--'),
        cell('ARRIVE', s.active ? _clock(s.eta) : '--:--'),
        cell('TIME LEFT', s.active ? '${(s.secondsRemaining / 60).round()} MIN' : '--'),
      ]),
    );
  }

  Widget _buttons(AppState app) {
    Widget big(String label, IconData icon, Color c, VoidCallback onTap) => Expanded(
          child: Material(
            color: c,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap();
              },
              child: SizedBox(
                height: 64,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(width: 8),
                  Text(label, style: Stpg.label(size: 15, color: Colors.white, spacing: 1.5)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      big('HAZARD', Icons.warning_amber_rounded, const Color(0xFFB7791F), () => showHazardDialog(context)),
      const SizedBox(width: 12),
      big('MAP', Icons.map_outlined, Stpg.orange.withValues(alpha: 0.85), () => app.go(CommandScreen.navigation)),
      const SizedBox(width: 12),
      big('SOS', Icons.sos, Stpg.red, () => app.go(CommandScreen.fieldAssistance)),
    ]);
  }
}

