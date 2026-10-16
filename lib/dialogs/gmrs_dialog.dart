import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stpg_widgets.dart';

/// "STPG COMMS // GMRS" dialog: shows the shared channel, admins can change it.
Future<void> showGmrsDialog(BuildContext context) {
  // Capture the app state before the dialog route is pushed.
  final app = AppScope.read(context);
  return showStpgDialog<void>(
    context,
    maxWidth: 560,
    builder: (ctx) => _GmrsBody(app: app),
  );
}

class _GmrsBody extends StatefulWidget {
  final AppState app;
  const _GmrsBody({required this.app});

  @override
  State<_GmrsBody> createState() => _GmrsBodyState();
}

class _GmrsBodyState extends State<_GmrsBody> {
  int? _selected;

  Future<void> _save(int ch) async {
    await widget.app.saveRadioChannel(ch);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final radio = app.radio;
        final current = radio.channel;
        final selected = _selected ?? current;
        final saving = radio.saving;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STPG COMMS // GMRS', style: Stpg.label(size: 12, color: Stpg.orange, spacing: 2.4)),
            const SizedBox(height: 10),
            Text('SHARED CHANNEL  ${current ?? '--'}', style: Stpg.title(size: 34)),
            const SizedBox(height: 4),
            Text(radio.syncLabel, style: Stpg.label(size: 11, spacing: 1.6)),
            if (app.isAdmin) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var ch = 1; ch <= 22; ch++)
                    _ChannelChip(
                      channel: ch,
                      selected: selected == ch,
                      onTap: saving ? null : () => setState(() => _selected = ch),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              StpgButton(
                saving ? 'SAVING…' : 'SAVE CHANNEL',
                filled: true,
                expand: true,
                onTap: (saving || selected == null) ? null : () => _save(selected),
              ),
              if (radio.notice != null) ...[
                const SizedBox(height: 10),
                Text(radio.notice!, style: Stpg.label(size: 12, color: Stpg.green, spacing: 0.6)),
              ],
              if (radio.saveError != null) ...[
                const SizedBox(height: 10),
                Text('Not saved: ${radio.saveError}', style: Stpg.label(size: 12, color: Stpg.red, spacing: 0.6)),
              ],
            ],
            const SizedBox(height: 16),
            Text('STPG admins set the shared channel. Drivers receive updates automatically.',
                style: Stpg.label(size: 12, spacing: 0.6, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Set your physical radio to the displayed channel. Channel sharing does not tune the radio.',
                style: Stpg.label(size: 12, spacing: 0.6, weight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: StpgButton('COMMS CENTER', filled: true, expand: true, onTap: () {
                  Navigator.of(context).pop();
                  app.go(CommandScreen.comms);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(child: StpgButton('CLOSE', expand: true, onTap: () => Navigator.of(context).pop())),
            ]),
          ],
        );
      },
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final int channel;
  final bool selected;
  final VoidCallback? onTap;
  const _ChannelChip({required this.channel, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Stpg.orange : (Stpg.day ? Colors.white : Stpg.deepPanel),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Stpg.orange : Stpg.border, width: 1.4),
          ),
          child: Text('$channel', style: Stpg.title(size: 16, color: selected ? Colors.white : Stpg.text, spacing: 0.5)),
        ),
      ),
    );
  }
}
