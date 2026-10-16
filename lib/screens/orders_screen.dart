import 'package:flutter/material.dart';

import '../api/supabase_api.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// Admin-only parts counter order feed.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<StpgStoreOrder> _orders = const [];
  bool _loading = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (AppScope.read(context).isAdmin) _load();
    }
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await app.authed((t) => SupabaseApi.fetchRecentStoreOrders(t, limit: 25));
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } on SupabaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SubScreenScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubScreenHeader(
          section: 'ADMIN // ORDERS',
          title: 'STPG PARTS COUNTER',
          subtitle: 'ORDER COMMAND',
          backLabel: '← BACK // COMMS',
          onBack: app.back,
          actions: [
            if (app.isAdmin) StpgButton('REFRESH', icon: Icons.refresh, height: 52, onTap: _loading ? null : _load),
          ],
        ),
        const SizedBox(height: 20),
        if (!app.isAdmin)
          StpgPanel(
            borderColor: Stpg.red,
            color: Stpg.alertPanel,
            child: Text('ADMIN ACCESS REQUIRED', style: Stpg.title(size: 18, color: Stpg.red)),
          )
        else ...[
          StpgPanel(
            borderColor: Stpg.orange,
            padding: const EdgeInsets.all(14),
            child: Text('ADMIN ONLY // PAYMENT MUST BE VERIFIED IN QUICKBOOKS',
                style: Stpg.label(size: 12, color: Stpg.orange, spacing: 1.6)),
          ),
          const SizedBox(height: 16),
          _body(),
        ],
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return StpgPanel(child: Text('SYNCING ORDERS...', style: Stpg.label(size: 13, spacing: 2)));
    }
    if (_error != null) {
      return StpgPanel(
        borderColor: Stpg.red,
        color: Stpg.alertPanel,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ORDER FEED OFFLINE', style: Stpg.title(size: 18, color: Stpg.red)),
          const SizedBox(height: 6),
          Text('ORDER FEED ERROR // $_error', style: Stpg.label(size: 12)),
        ]),
      );
    }
    if (_orders.isEmpty) {
      return StpgPanel(child: Text('NO STORE ORDERS FOUND', style: Stpg.label(size: 13, spacing: 2)));
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 800 ? 2 : 1;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final o in _orders) SizedBox(width: w, child: _OrderCard(order: o))],
      );
    });
  }
}

String _or(String s) => s.trim().isEmpty ? '--' : s.trim();

class _OrderCard extends StatelessWidget {
  final StpgStoreOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final cityLine = [
      o.city.trim(),
      [o.state.trim(), o.postalCode.trim()].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');
    final address = [o.customerAddress.trim(), cityLine, o.country.trim()].where((s) => s.isNotEmpty).join(', ');
    final contact = [o.email.trim(), o.phone.trim()].where((s) => s.isNotEmpty).join(' · ');

    final pay = o.paymentStatus.trim().toLowerCase();
    final paid = pay == 'paid' || pay == 'verified';
    final needsVerify = pay.isEmpty || pay == 'pending' || pay == 'unpaid';
    final payText = needsVerify ? 'VERIFY QUICKBOOKS' : o.paymentStatus.trim().toUpperCase();
    final payColor = paid ? Stpg.green : (needsVerify ? Stpg.orange : Stpg.gray);

    final created = o.createdAt.replaceFirst('T', ' ');
    final createdText = created.length > 16 ? created.substring(0, 16) : created;

    return StpgPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PARTS COUNTER ORDER', style: Stpg.label(size: 10, color: Stpg.orange, spacing: 2)),
        const SizedBox(height: 6),
        Text(_or(o.productName), maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 22)),
        const SizedBox(height: 4),
        Text('QTY ${o.quantity}', style: Stpg.label(size: 12, color: Stpg.text)),
        const SizedBox(height: 10),
        Text('CUSTOMER // ${_or(o.customerName).toUpperCase()}',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 12, color: Stpg.text)),
        const SizedBox(height: 4),
        Text(_or(address), maxLines: 3, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(_or(contact), maxLines: 2, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('VENDOR // ${_or(o.vendor).toUpperCase()}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip('ORDER // ${_or(o.orderStatus).toUpperCase()}', Stpg.gray),
          _Chip('PAYMENT // ${o.paymentStatus.trim().isEmpty ? 'VERIFY QUICKBOOKS' : payText}', payColor),
        ]),
        const SizedBox(height: 10),
        Text(_or(createdText), style: Stpg.label(size: 11)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(text, style: Stpg.label(size: 11, color: color, spacing: 1)),
      );
}
