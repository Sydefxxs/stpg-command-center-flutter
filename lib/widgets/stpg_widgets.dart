import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Icons used across the app (the original drew custom vector icons per StpgIconType).
class StpgIcons {
  static const driver = Icons.badge_outlined;
  static const system = Icons.settings_input_antenna;
  static const gps = Icons.my_location;
  static const vehicle = Icons.directions_car_filled_outlined;
  static const weather = Icons.wb_sunny_outlined;
  static const comms = Icons.cell_tower;
  static const navigation = Icons.navigation_outlined;
  static const update = Icons.public;
  static const dispatch = Icons.campaign_outlined;
  static const assistance = Icons.add_box_outlined;
  static const missions = Icons.track_changes;
  static const emergency = Icons.warning_amber_rounded;
  static const portal = Icons.language;
  static const orders = Icons.shopping_cart_outlined;
}

/// Circular outlined icon badge (orange ring), like the original StpgCommandIcon.
class StpgIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const StpgIcon(this.icon, {super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Stpg.orange;
    return Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.6)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.75, color: c),
    );
  }
}

/// Rounded panel with a 1px border. [highlighted] gives the orange tour/selection glow.
class StpgPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final bool highlighted;
  final VoidCallback? onTap;
  final double radius;
  final double opacity;

  const StpgPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.color,
    this.highlighted = false,
    this.onTap,
    this.radius = 18,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final border = highlighted ? Stpg.orange : (borderColor ?? Stpg.border);
    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: padding,
      decoration: BoxDecoration(
        color: (color ?? Stpg.panel).withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: highlighted ? 2 : 1),
        boxShadow: highlighted
            ? [BoxShadow(color: Stpg.orange.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withValues(alpha: Stpg.day ? 0.06 : 0.3), blurRadius: 10)],
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: panel),
    );
  }
}

/// Orange icon + spaced uppercase title used at the top of every card.
class CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;
  const CardHeader({super.key, required this.icon, required this.title, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Stpg.orange;
    return Row(children: [
      StpgIcon(icon, size: 14, color: c),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: Stpg.label(size: 12, color: c, spacing: 2))),
      ?trailing,
    ]);
  }
}

/// "GPS ● READY" style row.
class StatusLine extends StatelessWidget {
  final String label;
  final String value;
  final bool? good; // true=green, false=red, null=orange
  final double size;
  const StatusLine(this.label, this.value, {super.key, this.good = true, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final c = good == null ? Stpg.orange : (good! ? Stpg.green : Stpg.red);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: Stpg.title(size: size, spacing: 1))),
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 6),
        Text(value, style: Stpg.label(size: size, color: c, spacing: 1)),
      ]),
    );
  }
}

/// Label above a big value (VehicleData / NavV2StatusTile style).
class LabeledValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double valueSize;
  const LabeledValue(this.label, this.value, {super.key, this.valueColor, this.valueSize = 18});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Stpg.label(size: 10)),
        const SizedBox(height: 4),
        Text(value, style: Stpg.title(size: valueSize, color: valueColor)),
      ]),
    );
  }
}

/// Outlined (default) or filled orange button with uppercase label.
class StpgButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final IconData? icon;
  final bool expand;
  final double height;
  const StpgButton(
    this.label, {
    super.key,
    this.onTap,
    this.filled = false,
    this.color,
    this.icon,
    this.expand = false,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Stpg.orange;
    final enabled = onTap != null;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: filled ? Colors.white : c), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: Stpg.label(size: 13, color: filled ? Colors.white : c, spacing: 1.8)),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: filled ? c : (Stpg.day ? Colors.white : Stpg.deepPanel),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c, width: 1.4),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Header used on every sub-screen: "02 // COMMS", big title, subtitle, back button.
class SubScreenHeader extends StatelessWidget {
  final String section;
  final String title;
  final String subtitle;
  final String backLabel;
  final VoidCallback onBack;
  final List<Widget> actions;
  const SubScreenHeader({
    super.key,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backLabel = '← BACK // COMMAND CENTER',
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(section, style: Stpg.label(size: 13, color: Stpg.orange, spacing: 2)),
      const SizedBox(height: 6),
      Text(title, style: Stpg.title(size: narrow ? 26 : 34)),
      const SizedBox(height: 6),
      Text(subtitle, style: Stpg.label(size: 12, spacing: 2)),
    ]);
    final buttons = Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      ...actions,
      StpgButton(backLabel, onTap: onBack, height: 52),
    ]);
    if (narrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 12), buttons]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: titleBlock), buttons]);
  }
}

/// Big bottom navigation tile (NAVIGATION / COMMS / VEHICLE / UPDATE APP).
class CommandTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool highlighted;
  final String? badge;
  final VoidCallback? onTap;
  const CommandTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.highlighted = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StpgPanel(
      onTap: onTap,
      highlighted: highlighted || selected,
      color: selected ? Stpg.activePanel : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        StpgIcon(icon, size: 26, color: selected ? Stpg.orange : Stpg.text),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Stpg.title(size: 22, color: selected ? Stpg.orange : Stpg.text)),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 10)),
          ]),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Stpg.red, borderRadius: BorderRadius.circular(10)),
            child: Text(badge!, style: Stpg.label(size: 11, color: Colors.white, spacing: 0.5)),
          ),
      ]),
    );
  }
}

/// Standard page wrapper for sub-screens: background color, safe area, scroll, padding.
class SubScreenScaffold extends StatelessWidget {
  final Widget child;
  const SubScreenScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Stpg.dark,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: MediaQuery.sizeOf(context).width < 600
              ? const EdgeInsets.fromLTRB(14, 12, 14, 24)
              : const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: child,
        ),
      ),
    );
  }
}

/// Orange-bordered modal used for all STPG dialogs.
Future<T?> showStpgDialog<T>(BuildContext context, {required Widget Function(BuildContext) builder, double maxWidth = 520}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Stpg.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Stpg.orange, width: 2),
          ),
          child: SingleChildScrollView(child: builder(ctx)),
        ),
      ),
    ),
  );
}

/// Two-column layout on wide screens, stacked on narrow screens.
class ResponsiveSplit extends StatelessWidget {
  final Widget main;
  final Widget side;
  final int mainFlex;
  final int sideFlex;
  const ResponsiveSplit({super.key, required this.main, required this.side, this.mainFlex = 2, this.sideFlex = 1});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 900) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, const SizedBox(height: 16), side]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: mainFlex, child: main),
      const SizedBox(width: 16),
      Expanded(flex: sideFlex, child: side),
    ]);
  }
}
