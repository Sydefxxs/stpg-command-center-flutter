import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/supabase_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/sos_panel.dart';
import '../widgets/stpg_widgets.dart';

/// 02C // FIELD ASSISTANCE — driver-facing request / share location / 911 screen.
class FieldAssistanceScreen extends StatefulWidget {
  const FieldAssistanceScreen({super.key});

  @override
  State<FieldAssistanceScreen> createState() => _FieldAssistanceScreenState();
}

class _FieldAssistanceScreenState extends State<FieldAssistanceScreen> {
  static const _types = ['RECOVERY', 'STUCK', 'MECHANICAL', 'FLAT TIRE', 'OTHER'];

  final _message = TextEditingController();
  StpgAssistanceRequest? _active;
  bool _loading = true;
  bool _sending = false;
  bool _cancelling = false;
  String? _error;
  String _type = 'RECOVERY';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String _err(Object e) => e is SupabaseException ? e.message : e.toString();

  Future<void> _load() async {
    final app = AppScope.read(context);
    if (mounted) setState(() => _loading = true);
    try {
      final userId = await app.ensureUserId();
      final req = await app.authed((t) => SupabaseApi.fetchActiveAssistanceRequest(t, userId));
      if (!mounted) return;
      setState(() {
        _active = req;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'SYSTEM ERROR // ${_err(e)}';
      });
    }
  }

  Future<void> _send() async {
    final app = AppScope.read(context);
    final gps = app.gps;
    if (!gps.hasFix || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final userId = await app.ensureUserId();
      await app.authed((t) =>
          SupabaseApi.createAssistanceRequest(t, userId, _type, _message.text.trim(), gps.latitude, gps.longitude));
      if (!mounted) return;
      _message.clear();
      setState(() => _sending = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'SYSTEM ERROR // ${_err(e)}';
      });
    }
  }

  Future<void> _cancel() async {
    final req = _active;
    if (req == null || _cancelling) return;
    final app = AppScope.read(context);
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await app.authed((t) => SupabaseApi.cancelAssistanceRequest(t, req.id));
      if (!mounted) return;
      setState(() => _cancelling = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = 'SYSTEM ERROR // ${_err(e)}';
      });
    }
  }

  Future<void> _share(LiveGps gps) async {
    final lat = gps.latitude.toStringAsFixed(6);
    final lng = gps.longitude.toStringAsFixed(6);
    await SharePlus.instance.share(ShareParams(
      text: 'STPG DRIVER LOCATION\n$lat, $lng\nhttps://www.google.com/maps/search/?api=1&query=$lat,$lng',
    ));
  }

  Future<void> _emergency() async {
    final ok = await showStpgDialog<bool>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('EMERGENCY // 911', style: Stpg.title(size: 22, color: Stpg.red)),
        const SizedBox(height: 12),
        Text('This opens your phone dialer with 911. Press call yourself to connect.',
            style: Stpg.label(size: 12, spacing: 1)),
        const SizedBox(height: 20),
        StpgButton('OPEN EMERGENCY DIALER', filled: true, color: Stpg.red, expand: true, onTap: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 10),
        StpgButton('CANCEL', expand: true, onTap: () => Navigator.of(ctx).pop(false)),
      ]),
    );
    if (ok == true) {
      await launchUrl(Uri.parse('tel:911'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final gps = app.gps;

    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '02C // FIELD ASSISTANCE',
          title: 'TRAIL / EMERGENCY',
          subtitle: 'STPG FIELD SUPPORT // LIVE GPS',
          backLabel: '← BACK // COMMS',
          onBack: app.back,
        ),
        const SizedBox(height: 18),
        _statusRow(gps),
        const SizedBox(height: 16),
        const SosPanel(),
        const SizedBox(height: 16),
        ResponsiveSplit(
          mainFlex: 2,
          sideFlex: 1,
          main: _mainPanel(gps),
          side: _sidePanels(app, gps),
        ),
      ]),
    );
  }

  Widget _statusRow(LiveGps gps) {
    final locked = gps.hasFix;
    String coord(double v) => locked ? v.toStringAsFixed(5) : '--';
    final tiles = <Widget>[
      _MiniTile('GPS', locked ? '● LOCKED' : 'ACQUIRING', valueColor: locked ? Stpg.green : Stpg.orange),
      _MiniTile('LAT', coord(gps.latitude)),
      _MiniTile('LONG', coord(gps.longitude)),
      _MiniTile('ALT', gps.altitudeFeet != null ? '${gps.altitudeFeet} FT' : '-- FT'),
    ];
    return Row(children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: tiles[i]),
      ],
    ]);
  }

  Widget _mainPanel(LiveGps gps) {
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CardHeader(icon: StpgIcons.assistance, title: 'STPG ASSISTANCE REQUEST'),
        const SizedBox(height: 14),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('SYNCING WITH STPG COMMAND...', style: Stpg.label(size: 13, color: Stpg.orange, spacing: 2)),
          )
        else if (_active != null)
          _activeCard(_active!)
        else
          _requestForm(gps),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1)),
        ],
        const SizedBox(height: 14),
        Text(
          gps.hasFix
              ? 'LIVE GPS // ${gps.latitude.toStringAsFixed(6)}, ${gps.longitude.toStringAsFixed(6)} // ${gps.accuracyFeet ?? '--'} FT ACCURACY'
              : 'LIVE GPS // ACQUIRING POSITION',
          style: Stpg.label(size: 11, color: gps.hasFix ? Stpg.green : Stpg.gray, spacing: 1.2),
        ),
      ]),
    );
  }

  Widget _activeCard(StpgAssistanceRequest r) {
    final msg = r.message.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Stpg.activePanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Stpg.orange, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ASSISTANCE ACTIVE', style: Stpg.title(size: 22, color: Stpg.orange)),
          const SizedBox(height: 6),
          Text('STPG COMMAND HAS YOUR REQUEST', style: Stpg.label(size: 12, spacing: 1.6)),
          const SizedBox(height: 12),
          Text('TYPE // ${r.requestType.toUpperCase()}', style: Stpg.title(size: 15)),
          const SizedBox(height: 4),
          Text('GPS // ${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}',
              style: Stpg.label(size: 12, spacing: 1)),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(msg, style: Stpg.label(size: 13, color: Stpg.text, weight: FontWeight.w600, spacing: 0.4)),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      StpgButton(
        _cancelling ? 'CANCELLING...' : '✕ CANCEL REQUEST',
        color: Stpg.red,
        expand: true,
        onTap: _cancelling ? null : _cancel,
      ),
    ]);
  }

  Widget _requestForm(LiveGps gps) {
    final canSend = gps.hasFix && !_sending;
    final label = _sending
        ? 'TRANSMITTING TO STPG COMMAND...'
        : (gps.hasFix ? '⚠ SEND ASSISTANCE REQUEST' : 'WAITING FOR GPS LOCK...');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('WHAT DO YOU NEED?', style: Stpg.title(size: 18)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 520 ? 3 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final t in _types)
            SizedBox(
              width: w,
              child: _TypeChip(label: t, selected: _type == t, onTap: () => setState(() => _type = t)),
            ),
        ]);
      }),
      const SizedBox(height: 14),
      TextField(
        controller: _message,
        minLines: 2,
        maxLines: 4,
        style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w600, spacing: 0.5),
        decoration: InputDecoration(
          hintText: 'MESSAGE // WHAT HAPPENED?',
          hintStyle: Stpg.label(size: 12, spacing: 1.4),
          filled: true,
          fillColor: Stpg.deepPanel,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Stpg.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Stpg.orange, width: 1.6)),
        ),
      ),
      const SizedBox(height: 14),
      StpgButton(label, filled: true, expand: true, height: 54, onTap: canSend ? _send : null),
    ]);
  }

  Widget _sidePanels(AppState app, LiveGps gps) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StpgPanel(
        onTap: gps.hasFix ? () => _share(gps) : null,
        child: _SidePanelBody(
          icon: StpgIcons.gps,
          title: 'SHARE MY LOCATION',
          subtitle: 'GPS COORDINATES // SEND',
          status: '● READY',
          statusColor: Stpg.green,
        ),
      ),
      const SizedBox(height: 12),
      StpgPanel(
        onTap: () => app.go(CommandScreen.navigation),
        child: const _SidePanelBody(
          icon: StpgIcons.navigation,
          title: 'OPEN NAVIGATION',
          subtitle: 'ONX OFFROAD // GOOGLE MAPS',
          status: '● READY',
          statusColor: Stpg.green,
        ),
      ),
      const SizedBox(height: 12),
      StpgPanel(
        borderColor: Stpg.red,
        onTap: _emergency,
        child: const _SidePanelBody(
          icon: StpgIcons.emergency,
          title: 'EMERGENCY // 911',
          subtitle: 'OPEN EMERGENCY DIALER',
          status: '● ARMED',
          statusColor: Stpg.red,
          accent: Stpg.red,
        ),
      ),
    ]);
  }
}

class _MiniTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MiniTile(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return StpgPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Stpg.label(size: 10)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: Stpg.title(size: 16, color: valueColor, spacing: 0.8)),
        ),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Stpg.orange : (Stpg.day ? Colors.white : Stpg.deepPanel),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Stpg.orange : Stpg.border, width: 1.4),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Stpg.label(size: 12, color: selected ? Colors.white : Stpg.text, spacing: 1.4)),
        ),
      ),
    );
  }
}

class _SidePanelBody extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, status;
  final Color statusColor;
  final Color? accent;
  const _SidePanelBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      StpgIcon(icon, size: 22, color: accent ?? Stpg.orange),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 16, color: accent)),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 10)),
        ]),
      ),
      const SizedBox(width: 8),
      Text(status, style: Stpg.label(size: 11, color: statusColor, spacing: 1)),
    ]);
  }
}
