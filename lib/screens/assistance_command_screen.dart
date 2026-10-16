import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/supabase_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// 02C // ASSISTANCE COMMAND — admin response console.
class AssistanceCommandScreen extends StatefulWidget {
  const AssistanceCommandScreen({super.key});

  @override
  State<AssistanceCommandScreen> createState() => _AssistanceCommandScreenState();
}

class _AssistanceCommandScreenState extends State<AssistanceCommandScreen> {
  List<StpgAssistanceRequest> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<String> _resolving = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppScope.read(context).isAdmin) {
        _load();
        _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final app = AppScope.read(context);
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final list = await app.authed((t) => SupabaseApi.fetchAllActiveAssistanceRequests(t));
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'SYSTEM ERROR // ${e is SupabaseException ? e.message : e}';
      });
    }
  }

  Future<void> _resolve(StpgAssistanceRequest r) async {
    if (_resolving.contains(r.id)) return;
    final app = AppScope.read(context);
    setState(() => _resolving.add(r.id));
    try {
      await app.authed((t) => SupabaseApi.resolveAssistanceRequest(t, r.id));
      if (!mounted) return;
      setState(() => _resolving.remove(r.id));
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving.remove(r.id);
        _error = 'SYSTEM ERROR // ${e is SupabaseException ? e.message : e}';
      });
    }
  }

  Future<void> _navigate(StpgAssistanceRequest r) async {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${r.latitude},${r.longitude}'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '--';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '02C // ASSISTANCE COMMAND',
          title: 'STPG ASSISTANCE',
          subtitle: 'ACTIVE RESPONSE // ADMIN CONTROL',
          backLabel: '← BACK // COMMS',
          onBack: app.back,
        ),
        const SizedBox(height: 18),
        if (!app.isAdmin) _denied() else _console(),
      ]),
    );
  }

  Widget _denied() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Stpg.alertPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Stpg.red, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ADMIN ACCESS REQUIRED', style: Stpg.title(size: 22, color: Stpg.red)),
        const SizedBox(height: 8),
        Text('This response console is restricted to STPG Command accounts.',
            style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w600, spacing: 0.4)),
      ]),
    );
  }

  Widget _console() {
    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeader(
          icon: StpgIcons.assistance,
          title: 'ACTIVE ASSISTANCE REQUESTS',
          trailing: IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(),
            icon: Icon(Icons.refresh, color: Stpg.orange),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!, style: Stpg.label(size: 12, color: Stpg.red, spacing: 1)),
          const SizedBox(height: 12),
        ],
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('SYNCING ASSISTANCE NETWORK...', style: Stpg.label(size: 13, color: Stpg.orange, spacing: 2)),
          )
        else if (_requests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No active STPG assistance requests.',
                style: Stpg.label(size: 14, weight: FontWeight.w600, spacing: 0.4)),
          )
        else
          for (final r in _requests) ...[
            _requestCard(r),
            const SizedBox(height: 12),
          ],
      ]),
    );
  }

  Widget _requestCard(StpgAssistanceRequest r) {
    final busy = _resolving.contains(r.id);
    final msg = r.message.trim();
    final shortId = r.userId.length > 8 ? r.userId.substring(0, 8) : r.userId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Stpg.alertPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Stpg.red, width: 1.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('⚠ ${r.requestType.toUpperCase()}', style: Stpg.title(size: 20, color: Stpg.red)),
        const SizedBox(height: 6),
        Text('ACTIVE // ${_time(r.createdAt)}', style: Stpg.label(size: 11, color: Stpg.orange)),
        const SizedBox(height: 6),
        Text('DRIVER ID // $shortId', style: Stpg.label(size: 12, spacing: 1)),
        const SizedBox(height: 6),
        Text(msg.isEmpty ? 'NO MESSAGE PROVIDED' : msg,
            style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w600, spacing: 0.4)),
        const SizedBox(height: 6),
        Text('GPS // ${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}',
            style: Stpg.label(size: 12, spacing: 1)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          StpgButton('NAVIGATE TO DRIVER', icon: Icons.navigation_outlined, onTap: () => _navigate(r)),
          StpgButton(busy ? 'RESOLVING...' : '✓ MARK RESOLVED',
              filled: true, color: Stpg.green, onTap: busy ? null : () => _resolve(r)),
        ]),
      ]),
    );
  }
}
