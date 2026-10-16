import 'dart:async';

import 'package:flutter/material.dart';

import '../api/supabase_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// 02B // MISSIONS: current Driver Portal mission and the driver's progress.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  StpgMission? _mission;
  bool _viewed = false;
  bool _completed = false;
  bool _loading = true;
  String? _error;

  bool _confirming = false;
  bool _completing = false;
  String? _updateError;
  Timer? _confirmTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
      _updateError = null;
      _confirming = false;
    });
    try {
      final mission = await app.authed((t) => SupabaseApi.fetchActiveMission(t));
      var viewed = false;
      var completed = false;
      if (mission != null) {
        final userId = await app.ensureUserId();
        final interaction =
            await app.authed((t) => SupabaseApi.fetchMissionInteraction(t, mission.id, userId));
        if (interaction == null) {
          try {
            await app.authed((t) => SupabaseApi.markMissionViewed(t, mission.id, userId));
            viewed = true;
          } catch (_) {
            viewed = false;
          }
        } else {
          viewed = interaction.firstViewedAt != null || interaction.completedAt != null;
          completed = interaction.completedAt != null;
        }
      }
      if (!mounted) return;
      setState(() {
        _mission = mission;
        _viewed = viewed;
        _completed = completed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onCompleteTap() async {
    final mission = _mission;
    if (mission == null || _completing || _completed) return;
    if (!_confirming) {
      setState(() {
        _confirming = true;
        _updateError = null;
      });
      _confirmTimer?.cancel();
      _confirmTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_completing) setState(() => _confirming = false);
      });
      return;
    }
    _confirmTimer?.cancel();
    final app = AppScope.read(context);
    setState(() {
      _completing = true;
      _confirming = false;
      _updateError = null;
    });
    try {
      final userId = await app.ensureUserId();
      await app.authed((t) => SupabaseApi.completeMissionInteraction(t, mission.id, userId));
      if (!mounted) return;
      setState(() {
        _completing = false;
        _completed = true;
        _viewed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _updateError = 'MISSION UPDATE ERROR // $e';
      });
    }
  }

  String _deadlineText(String raw) {
    if (raw.isEmpty || raw == 'null') return 'NO DEADLINE';
    final s = raw.replaceAll('T', ' ');
    return 'DEADLINE // ${s.length > 16 ? s.substring(0, 16) : s}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '02B // MISSIONS',
          title: 'STPG MISSIONS',
          subtitle: 'FIELD OBJECTIVES // DRIVER OPERATIONS',
          backLabel: '← BACK // COMMS',
          onBack: () => AppScope.read(context).back(),
        ),
        const SizedBox(height: 20),
        ResponsiveSplit(main: _mainPanel(), side: _sidePanels(app)),
      ]),
    );
  }

  Widget _mainPanel() {
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CURRENT MISSION', style: Stpg.title(size: 20, color: Stpg.orange)),
              const SizedBox(height: 4),
              Text('SUPABASE // DRIVER PORTAL SYNC',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.circle, size: 8, color: Stpg.green),
            const SizedBox(width: 6),
            Text('ONLINE', style: Stpg.label(size: 12, color: Stpg.green, spacing: 1.4)),
          ]),
        ]),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: StpgButton(_loading ? 'SYNCING...' : '↻ REFRESH MISSION', onTap: _loading ? null : _load),
        ),
        const SizedBox(height: 14),
        _body(),
        const SizedBox(height: 14),
        Text('DRIVER PORTAL MISSION FEED // CONNECTED',
            style: Stpg.label(size: 11, color: _error != null ? Stpg.red : Stpg.green, spacing: 1.6)),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return StpgPanel(
        color: Stpg.deepPanel,
        child: Row(children: [
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Stpg.orange)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('RECEIVING CURRENT STPG MISSION...', style: Stpg.label(size: 12, color: Stpg.orange)),
          ),
        ]),
      );
    }
    if (_error != null) {
      return StpgPanel(
        color: Stpg.alertPanel,
        borderColor: Stpg.red,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SYSTEM', style: Stpg.label(size: 12, color: Stpg.red, spacing: 2)),
          const SizedBox(height: 10),
          Text('MISSION CONNECTION ERROR', style: Stpg.title(size: 18, color: Stpg.red)),
          const SizedBox(height: 6),
          Text(_error!, style: Stpg.label(size: 12, color: Stpg.text, weight: FontWeight.w600, spacing: 0.4)),
        ]),
      );
    }
    final m = _mission;
    if (m == null) {
      return StpgPanel(
        color: Stpg.deepPanel,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('STANDBY', style: Stpg.label(size: 11, color: Stpg.orange, spacing: 2))),
            Text('AWAITING ORDERS', style: Stpg.label(size: 11, spacing: 1.4)),
          ]),
          const SizedBox(height: 10),
          Text('NO ACTIVE MISSION', style: Stpg.title(size: 22)),
          const SizedBox(height: 8),
          Text('MISSION BRIEF', style: Stpg.label(size: 11, spacing: 2)),
          const SizedBox(height: 4),
          Text(
            'Mission Control is online. No active mission is currently available from the STPG Driver Portal.',
            style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w500, spacing: 0.2),
          ),
        ]),
      );
    }
    final status = m.status.isEmpty || m.status == 'null' ? 'ACTIVE' : m.status.toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StpgPanel(
        color: Stpg.deepPanel,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(status,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, color: Stpg.orange, spacing: 2)),
            ),
            const SizedBox(width: 8),
            Text(_completed ? 'COMPLETE' : 'ACTIVE', style: Stpg.label(size: 11, spacing: 1.4)),
          ]),
          const SizedBox(height: 10),
          Text(m.title, style: Stpg.title(size: 24, spacing: 0.6)),
          const SizedBox(height: 12),
          Text('MISSION BRIEF', style: Stpg.label(size: 11, spacing: 2)),
          const SizedBox(height: 4),
          Text(m.instructions,
              style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w500, spacing: 0.2)),
          const SizedBox(height: 12),
          Text(_deadlineText(m.deadline), style: Stpg.label(size: 12, color: Stpg.orange, spacing: 1.6)),
        ]),
      ),
      const SizedBox(height: 12),
      _completeButton(),
      if (_updateError != null) ...[
        const SizedBox(height: 10),
        Text(_updateError!, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1.2)),
      ],
    ]);
  }

  Widget _completeButton() {
    if (_completed) {
      return StpgButton('MISSION COMPLETE', color: Stpg.green, expand: true, icon: Icons.check_circle_outline);
    }
    if (_completing) {
      return const StpgButton('SYNCING COMPLETION...', expand: true);
    }
    return StpgButton(
      _confirming ? 'TAP TO CONFIRM' : '✓ MARK MISSION COMPLETE',
      filled: _confirming,
      expand: true,
      onTap: _onCompleteTap,
    );
  }

  Widget _sidePanels(AppState app) {
    final hasMission = _mission != null;
    final String progress;
    final String progressStatus;
    if (_completed) {
      progress = 'MISSION COMPLETE';
      progressStatus = 'COMPLETE';
    } else if (_viewed) {
      progress = 'VIEWED';
      progressStatus = 'IN PROGRESS';
    } else {
      progress = 'NOT VIEWED';
      progressStatus = 'AWAITING ACTION';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sidePanel('MISSION STATUS', hasMission ? 'ACTIVE' : 'STANDBY', 'READY', Stpg.green),
      const SizedBox(height: 12),
      _sidePanel('DRIVER', 'AUTHENTICATED', 'ONLINE', Stpg.green),
      const SizedBox(height: 12),
      _sidePanel('YOUR PROGRESS', progress, progressStatus, _completed ? Stpg.green : Stpg.orange),
    ]);
  }

  Widget _sidePanel(String label, String value, String status, Color statusColor) {
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Stpg.label(size: 11, spacing: 2)),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 22)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.circle, size: 8, color: statusColor),
          const SizedBox(width: 6),
          Text(status, style: Stpg.label(size: 12, color: statusColor, spacing: 1.4)),
        ]),
      ]),
    );
  }
}
