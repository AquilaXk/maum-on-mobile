import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_design_system.dart';
import '../domain/legal_disclosures.dart';

class LegalDisclosureLinks extends StatelessWidget {
  const LegalDisclosureLinks({
    required this.keyPrefix,
    this.onOpenExternalUri,
    this.showAccountDeletionGuidance = true,
    super.key,
  });

  final String keyPrefix;
  final Future<bool> Function(Uri uri)? onOpenExternalUri;
  final bool showAccountDeletionGuidance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.center,
          children: [
            for (final link in LegalDisclosures.links)
              TextButton.icon(
                key: ValueKey('$keyPrefix-${link.id}-link'),
                onPressed: () => _open(link.parsedUri),
                icon: Icon(_iconFor(link.id), size: 18),
                label: Text(link.label),
              ),
          ],
        ),
        if (showAccountDeletionGuidance) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            LegalDisclosures.accountDeletionGuidance,
            key: ValueKey('$keyPrefix-account-deletion-guidance'),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _open(Uri uri) async {
    final launcher = onOpenExternalUri ??
        (Uri target) => launchUrl(
              target,
              mode: LaunchMode.externalApplication,
            );
    await launcher(uri);
  }
}

IconData _iconFor(String id) {
  return switch (id) {
    'privacy-policy' => Icons.privacy_tip_outlined,
    'terms' => Icons.article_outlined,
    'support' => Icons.support_agent_outlined,
    _ => Icons.open_in_new,
  };
}
