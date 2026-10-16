import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// Full-screen dim layer with a centered bordered card.
class _AlertShell extends StatelessWidget {
  final Color border;
  final List<Widget> children;
  const _AlertShell({required this.border, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Stpg.alertPanel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _line(String text, {Color? color, double size = 13}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: Stpg.label(size: size, color: color, spacing: 1.2)),
    );

class AssistanceAlertOverlay extends StatelessWidget {
  final StpgAssistanceRequest request;
  final VoidCallback onView;
  final VoidCallback onDismiss;
  const AssistanceAlertOverlay({super.key, required this.request, required this.onView, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final msg = request.message.trim();
    return _AlertShell(border: Stpg.red, children: [
      Text('⚠ STPG ASSISTANCE ALERT', style: Stpg.label(size: 13, color: Stpg.red, spacing: 2.4)),
      const SizedBox(height: 10),
      Text('DRIVER NEEDS ASSISTANCE', style: Stpg.title(size: 28)),
      const SizedBox(height: 6),
      Text(request.requestType.toUpperCase(), style: Stpg.title(size: 18, color: Stpg.orange)),
      if (msg.isNotEmpty) _line(msg, color: Stpg.text),
      _line('GPS LOCATION RECEIVED // ${request.latitude.toStringAsFixed(6)}, ${request.longitude.toStringAsFixed(6)}'),
      const SizedBox(height: 20),
      StpgButton('VIEW REQUEST', filled: true, color: Stpg.red, expand: true, height: 52, onTap: onView),
      const SizedBox(height: 10),
      StpgButton('DISMISS', expand: true, onTap: onDismiss),
      const SizedBox(height: 12),
      Text('DISMISS DOES NOT RESOLVE THE REQUEST',
          textAlign: TextAlign.center, style: Stpg.label(size: 10, spacing: 1.4)),
    ]);
  }
}

class StoreOrderAlertOverlay extends StatelessWidget {
  final StpgStoreOrder order;
  final VoidCallback onView;
  final VoidCallback onDismiss;
  const StoreOrderAlertOverlay({super.key, required this.order, required this.onView, required this.onDismiss});

  String _or(String v) => v.trim().isEmpty ? '--' : v.trim();

  @override
  Widget build(BuildContext context) {
    return _AlertShell(border: Stpg.orange, children: [
      Text('🛒 STPG NEW ORDER', style: Stpg.label(size: 13, color: Stpg.orange, spacing: 2.4)),
      const SizedBox(height: 10),
      Text('PARTS COUNTER ORDER', style: Stpg.title(size: 28)),
      const SizedBox(height: 6),
      Text(_or(order.productName).toUpperCase(), style: Stpg.title(size: 18, color: Stpg.orange)),
      _line('CUSTOMER // ${_or(order.customerName)}'),
      _line('QTY // ${order.quantity}'),
      _line('VENDOR // ${_or(order.vendor)}'),
      _line('PAYMENT // VERIFY QUICKBOOKS', color: Stpg.orange),
      const SizedBox(height: 20),
      StpgButton('VIEW ORDER', filled: true, expand: true, height: 52, onTap: onView),
      const SizedBox(height: 10),
      StpgButton('DISMISS', expand: true, onTap: onDismiss),
      const SizedBox(height: 12),
      Text('DISMISS DOES NOT CHANGE ORDER OR PAYMENT STATUS',
          textAlign: TextAlign.center, style: Stpg.label(size: 10, spacing: 1.4)),
    ]);
  }
}
