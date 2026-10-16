import 'package:flutter/material.dart';

import '../dialogs/gmrs_dialog.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

const _tourTexts = [
  ('COMMAND CHANNEL', 'Receive STPG command updates and open the live Dispatch feed.'),
  ('ACTIVE RESPONSE COMMAND', 'Monitor active driver assistance requests and coordinate response.'),
  ('CURRENT ASSIGNMENT', 'Open your current STPG mission, instructions and mission status.'),
  ('FIELD ASSISTANCE', 'Send recovery or emergency assistance with your live GPS location.'),
];

class CommsScreen extends StatefulWidget {
  const CommsScreen({super.key});

  @override
  State<CommsScreen> createState() => _CommsScreenState();
}

class _CommsScreenState extends State<CommsScreen> {
  final _stackKey = GlobalKey();
  final _tileKeys = List.generate(4, (_) => GlobalKey());
  int _tourStep = -1;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final done = AppScope.read(context).prefs.getBool(AppState.kCommsTourDone) ?? false;
      if (!done) _setStep(0);
    });
  }

  void _setStep(int step) {
    setState(() {
      _tourStep = step;
      _hole = null;
    });
    if (step < 0) return;
    final ctx = _tileKeys[step].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0.2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(step));
  }

  void _measure(int step) {
    if (!mounted || _tourStep != step) return;
    final tileBox = _tileKeys[step].currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (tileBox == null || stackBox == null || !tileBox.attached || !stackBox.attached) return;
    final topLeft = stackBox.globalToLocal(tileBox.localToGlobal(Offset.zero));
    setState(() => _hole = (topLeft & tileBox.size).inflate(6));
  }

  void _finishTour() {
    AppScope.read(context).prefs.setBool(AppState.kCommsTourDone, true);
    _setStep(-1);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final tourOn = _tourStep >= 0;

    final tiles = <Widget>[
      _CommsTile(
        key: _tileKeys[0],
        icon: StpgIcons.dispatch,
        title: 'STPG DISPATCH',
        subtitle: 'COMMAND CHANNEL',
        status: 'READY',
        statusColor: Stpg.green,
        highlighted: tourOn && _tourStep == 0,
        onTap: () => app.go(CommandScreen.dispatch),
      ),
      _CommsTile(
        key: _tileKeys[1],
        icon: StpgIcons.assistance,
        title: 'STPG ASSISTANCE',
        subtitle: 'ACTIVE RESPONSE COMMAND',
        status: 'MONITOR',
        statusColor: Stpg.green,
        badge: (app.isAdmin && app.activeAssistance.isNotEmpty) ? '${app.activeAssistance.length}' : null,
        highlighted: tourOn && _tourStep == 1,
        onTap: () => app.go(CommandScreen.assistanceCommand),
      ),
      _CommsTile(
        key: _tileKeys[2],
        icon: StpgIcons.missions,
        title: 'MISSIONS',
        subtitle: 'CURRENT ASSIGNMENT',
        status: 'LIVE',
        statusColor: Stpg.orange,
        highlighted: tourOn && _tourStep == 2,
        onTap: () => app.go(CommandScreen.missions),
      ),
      _CommsTile(
        key: _tileKeys[3],
        icon: StpgIcons.emergency,
        title: 'TRAIL / EMERGENCY',
        subtitle: 'FIELD ASSISTANCE',
        status: 'READY',
        statusColor: Stpg.red,
        highlighted: tourOn && _tourStep == 3,
        onTap: () => app.go(CommandScreen.fieldAssistance),
      ),
      if (app.isAdmin)
        _CommsTile(
          icon: StpgIcons.orders,
          title: 'PARTS COUNTER',
          subtitle: 'ORDER COMMAND',
          status: 'ADMIN',
          statusColor: Stpg.orange,
          onTap: () => app.go(CommandScreen.orders),
        ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubScreenHeader(
          section: '02 // COMMS',
          title: 'DRIVER COMMUNICATIONS',
          subtitle: 'STPG FIELD NETWORK',
          backLabel: '← BACK // COMMAND CENTER',
          onBack: app.back,
          actions: [
            _ReplayPill(
              onTap: app.startHomeTour,
              onLongPress: () => _setStep(0),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StpgPanel(
          borderColor: Stpg.orange,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          onTap: () => showGmrsDialog(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('GMRS CHANNEL  ${app.radio.channel ?? '--'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 22, color: Stpg.orange)),
              ),
              const SizedBox(width: 12),
              Text(app.isAdmin ? 'SELECT CHANNEL' : 'VIEW CHANNEL', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2)),
            ]),
            const SizedBox(height: 4),
            Text(app.radio.syncLabel, style: Stpg.label(size: 10, spacing: 1.4)),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          const gap = 16.0;
          final w = wide ? (c.maxWidth - gap) / 2 : c.maxWidth;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        }),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('NETWORK // STPG', style: Stpg.label(size: 11, spacing: 2))),
          Text('DRIVER // ${app.driverNumberText}', style: Stpg.label(size: 11, color: Stpg.orange, spacing: 2)),
        ]),
      ],
    );

    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(child: SubScreenScaffold(child: content)),
        if (tourOn) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _ScrimPainter(_hole)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _TourCard(
                    step: _tourStep,
                    onSkip: _finishTour,
                    onBack: _tourStep > 0 ? () => _setStep(_tourStep - 1) : null,
                    onNext: () => _tourStep >= _tourTexts.length - 1 ? _finishTour() : _setStep(_tourStep + 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  _ScrimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(20)));
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

class _TourCard extends StatelessWidget {
  final int step;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  const _TourCard({required this.step, required this.onSkip, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final last = step >= _tourTexts.length - 1;
    final (head, body) = _tourTexts[step];
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Stpg.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Stpg.orange, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${step + 1} / ${_tourTexts.length}', style: Stpg.label(size: 11, color: Stpg.orange, spacing: 2)),
          const SizedBox(height: 6),
          Text('$head // $body', style: Stpg.title(size: 15, spacing: 0.6)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            StpgButton('SKIP', onTap: onSkip, height: 40),
            if (onBack != null) StpgButton('‹ BACK', onTap: onBack, height: 40),
            StpgButton(last ? 'FINISH TOUR ✓' : 'NEXT ›', filled: true, onTap: onNext, height: 40),
          ]),
        ]),
      ),
    );
  }
}

class _ReplayPill extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ReplayPill({required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Stpg.orange, width: 1.4),
          ),
          child: Text('REPLAY TOUR', style: Stpg.label(size: 11, color: Stpg.orange, spacing: 1.6)),
        ),
      ),
    );
  }
}

class _CommsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String? badge;
  final bool highlighted;
  final VoidCallback onTap;
  const _CommsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.badge,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return StpgPanel(
      onTap: onTap,
      highlighted: highlighted,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        StpgIcon(icon, size: 34),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.title(size: 22)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Stpg.label(size: 11, spacing: 1.8)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.circle, size: 9, color: statusColor),
              const SizedBox(width: 6),
              Text(status, style: Stpg.label(size: 12, color: statusColor, spacing: 1.6)),
            ]),
          ]),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Stpg.red, borderRadius: BorderRadius.circular(12)),
            child: Text(badge!, style: Stpg.label(size: 13, color: Colors.white, spacing: 0.5)),
          ),
      ]),
    );
  }
}
