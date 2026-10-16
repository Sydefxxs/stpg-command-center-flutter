import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

/// "PRIVACY • TERMS • DELETE ACCOUNT" links (required by the app stores).
class LegalLinks extends StatelessWidget {
  final bool showDelete;
  const LegalLinks({super.key, this.showDelete = false});

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String url) => TextButton(
          onPressed: () => _open(url),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(label, style: Stpg.label(size: 10.5, color: Stpg.gray, spacing: 1.4)),
        );
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      link('PRIVACY', StpgConfig.privacyUrl),
      Text('•', style: Stpg.label(size: 10, color: Stpg.gray)),
      link('TERMS', StpgConfig.termsUrl),
      if (showDelete) ...[
        Text('•', style: Stpg.label(size: 10, color: Stpg.gray)),
        link('DELETE ACCOUNT', '${StpgConfig.privacyUrl}#delete-account'),
      ],
    ]);
  }
}
