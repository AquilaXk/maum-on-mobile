import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../domain/content_moderation_models.dart';

class ContentModerationFeedbackPanel extends StatelessWidget {
  const ContentModerationFeedbackPanel({
    required this.feedback,
    required this.onRetry,
    required this.onDismiss,
    super.key,
  });

  final ContentModerationFeedback feedback;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '콘텐츠 검수 차단 안내: ${feedback.title}. ${feedback.message}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: AppRadii.card,
          border: Border.all(color: colors.error.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.policy_outlined, color: colors.onErrorContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      feedback.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                feedback.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in feedback.guidanceItems) ...[
                _GuidanceBullet(text: item),
                const SizedBox(height: AppSpacing.xxs),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onDismiss,
                    child: Text(feedback.dismissActionLabel),
                  ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(feedback.primaryActionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceBullet extends StatelessWidget {
  const _GuidanceBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onErrorContainer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
