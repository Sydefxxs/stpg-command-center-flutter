import 'dart:async';

import 'package:flutter/material.dart';

import '../api/supabase_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// 02A // DISPATCH: live dispatch feed + admin composer.
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  List<StpgDispatch> _dispatches = const [];
  bool _loading = true;
  String? _error;

  bool _composerOpen = false;
  bool _sending = false;
  String? _composeMessage;
  bool _composeOk = false;
  final _subject = TextEditingController();
  final _body = TextEditingController();

  Timer? _timer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    final app = AppScope.read(context);
    if (!silent) setState(() => _loading = true);
    try {
      final list = await app.authed((t) => SupabaseApi.fetchDispatches(t));
      if (!mounted) return;
      setState(() {
        _dispatches = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _transmit() async {
    final subject = _subject.text.trim();
    final message = _body.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() {
        _composeMessage = 'SUBJECT AND MESSAGE REQUIRED';
        _composeOk = false;
      });
      return;
    }
    final app = AppScope.read(context);
    setState(() {
      _sending = true;
      _composeMessage = null;
    });
    try {
      await app.authed((t) => SupabaseApi.createAdminDispatch(t, subject, message));
      if (!mounted) return;
      _subject.clear();
      _body.clear();
      setState(() {
        _sending = false;
        _composeOk = true;
        _composeMessage = 'DISPATCH TRANSMITTED // ALL DRIVERS';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _composeOk = false;
        _composeMessage = 'TRANSMISSION FAILED // $e';
      });
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty || raw == 'null') return 'LIVE';
    final s = raw.replaceAll('T', ' ');
    return s.length > 16 ? s.substring(0, 16) : s;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isAdmin = app.isAdmin;
    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: '02A // DISPATCH',
          title: 'STPG DISPATCH',
          subtitle: 'COMMAND CHANNEL // FIELD OPERATIONS',
          backLabel: '← BACK // COMMS',
          onBack: () => AppScope.read(context).back(),
        ),
        const SizedBox(height: 20),
        ResponsiveSplit(
          mainFlex: 2,
          sideFlex: 1,
          main: _mainPanel(isAdmin),
          side: _sidePanels(app),
        ),
      ]),
    );
  }

  Widget _mainPanel(bool isAdmin) {
    final hasError = _error != null;
    final statusText = _loading ? 'SYNCING' : (hasError ? 'ERROR' : 'CONNECTED');
    final statusColor = _loading ? Stpg.orange : (hasError ? Stpg.red : Stpg.green);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StpgPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LIVE DISPATCH FEED', style: Stpg.title(size: 20, color: Stpg.orange)),
                const SizedBox(height: 4),
                Text('SUPABASE // STPG FIELD NETWORK',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, spacing: 1.6)),
              ]),
            ),
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 8, color: statusColor),
              const SizedBox(width: 6),
              Text(statusText, style: Stpg.label(size: 12, color: statusColor, spacing: 1.4)),
            ]),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 10, children: [
            StpgButton(_loading ? 'SYNCING...' : '↻ REFRESH DISPATCH', onTap: _loading ? null : () => _load()),
            if (isAdmin)
              StpgButton(
                _composerOpen ? '✕ CLOSE COMPOSER' : '+ SEND DISPATCH',
                filled: !_composerOpen,
                onTap: () => setState(() => _composerOpen = !_composerOpen),
              ),
          ]),
          if (isAdmin && _composerOpen) ...[
            const SizedBox(height: 14),
            _composer(),
          ],
          const SizedBox(height: 14),
          _feed(),
          const SizedBox(height: 14),
          Text(
            _error != null ? 'LIVE BACKEND FEED // ERROR' : 'LIVE BACKEND FEED // CONNECTED',
            style: Stpg.label(size: 11, color: _error != null ? Stpg.red : Stpg.green, spacing: 1.6),
          ),
        ]),
      ),
    ]);
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: Stpg.label(size: 11),
        floatingLabelStyle: Stpg.label(size: 12, color: Stpg.orange),
        filled: true,
        fillColor: Stpg.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Stpg.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Stpg.orange, width: 1.6),
        ),
      );

  Widget _composer() {
    return StpgPanel(
      color: Stpg.deepPanel,
      borderColor: Stpg.orange,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('COMMAND TRANSMISSION // ADMIN ONLY', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 12),
        TextField(
          controller: _subject,
          enabled: !_sending,
          textCapitalization: TextCapitalization.sentences,
          style: Stpg.title(size: 15, spacing: 0.4),
          decoration: _fieldDecoration('DISPATCH SUBJECT'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          enabled: !_sending,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w600, spacing: 0.3),
          decoration: _fieldDecoration('MESSAGE TO ALL DRIVERS'),
        ),
        const SizedBox(height: 12),
        StpgButton(
          _sending ? 'TRANSMITTING...' : '▲ TRANSMIT DISPATCH TO ALL DRIVERS',
          filled: true,
          expand: true,
          onTap: _sending ? null : _transmit,
        ),
        if (_composeMessage != null) ...[
          const SizedBox(height: 10),
          Text(_composeMessage!,
              style: Stpg.label(size: 12, color: _composeOk ? Stpg.green : Stpg.red, spacing: 1.2)),
        ],
      ]),
    );
  }

  Widget _feed() {
    if (_loading && _dispatches.isEmpty && _error == null) {
      return StpgPanel(
        color: Stpg.deepPanel,
        child: Row(children: [
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Stpg.orange)),
          const SizedBox(width: 12),
          Text('SYNCING...', style: Stpg.label(size: 12, color: Stpg.orange)),
        ]),
      );
    }
    if (_error != null) {
      return StpgPanel(
        color: Stpg.alertPanel,
        borderColor: Stpg.red,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('SYSTEM', style: Stpg.label(size: 12, color: Stpg.red, spacing: 2))),
            StpgButton('RETRY', color: Stpg.red, height: 38, onTap: _loading ? null : () => _load()),
          ]),
          const SizedBox(height: 10),
          Text('DISPATCH CONNECTION ERROR', style: Stpg.title(size: 18, color: Stpg.red)),
          const SizedBox(height: 6),
          Text(_error!, style: Stpg.label(size: 12, color: Stpg.text, weight: FontWeight.w600, spacing: 0.4)),
        ]),
      );
    }
    if (_dispatches.isEmpty) {
      return StpgPanel(
        color: Stpg.deepPanel,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NO ACTIVE DISPATCHES', style: Stpg.title(size: 18)),
          const SizedBox(height: 6),
          Text(
            'The command channel is online. No dispatch messages are currently available for this driver.',
            style: Stpg.label(size: 13, weight: FontWeight.w600, spacing: 0.3),
          ),
        ]),
      );
    }
    return Column(children: [
      for (final d in _dispatches) Padding(padding: const EdgeInsets.only(bottom: 10), child: _dispatchCard(d)),
    ]);
  }

  Widget _dispatchCard(StpgDispatch d) {
    final priority = (d.recipientType.isEmpty || d.recipientType == 'null' || d.recipientType.toLowerCase() == 'all')
        ? 'ALL DRIVERS'
        : d.recipientType.toUpperCase();
    return StpgPanel(
      color: Stpg.deepPanel,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(priority,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, color: Stpg.orange, spacing: 2)),
          ),
          const SizedBox(width: 8),
          Text(_formatTime(d.createdAt), style: Stpg.label(size: 11, spacing: 1)),
        ]),
        const SizedBox(height: 8),
        Text(d.subject, style: Stpg.title(size: 17, spacing: 0.5)),
        const SizedBox(height: 6),
        Text(d.message, style: Stpg.label(size: 14, color: Stpg.text, weight: FontWeight.w500, spacing: 0.2)),
      ]),
    );
  }

  Widget _sidePanels(AppState app) {
    final hasError = _error != null;
    final admin = app.isAdmin;
    final verifying = _loading && _dispatches.isEmpty && _error == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sidePanel('CHANNEL', 'STPG COMMAND', hasError ? 'ERROR' : 'CONNECTED', hasError ? Stpg.red : Stpg.green),
      const SizedBox(height: 12),
      _sidePanel(
        admin ? 'COMMAND ADMIN' : 'DRIVER',
        verifying ? 'VERIFYING' : 'AUTHENTICATED',
        'ONLINE',
        verifying ? Stpg.orange : Stpg.green,
      ),
      const SizedBox(height: 12),
      _sidePanel('DISPATCHES', '${_dispatches.length}', _loading ? 'SYNCING' : 'LIVE',
          _loading ? Stpg.orange : Stpg.green),
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
