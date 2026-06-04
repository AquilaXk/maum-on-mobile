import 'package:flutter/material.dart';

import 'brand_identity.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract final class AppBreakpoints {
  static const double compactContentMaxWidth = 520;
  static const double contentMaxWidth = 560;
}

abstract final class AppRadii {
  static const double xs = 6;
  static const double sm = 8;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(sm);
  static BorderRadius get chip => BorderRadius.circular(xs);
  static BorderRadius get status => BorderRadius.circular(pill);
}

enum AppNoticeTone { neutral, success, warning, error }

enum AppStateKind { loading, empty, error, permission, risk, success, neutral }

enum AppStatusTone { neutral, success, warning, danger }

class AppScreen extends StatelessWidget {
  const AppScreen({
    required this.title,
    required this.children,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.onRefresh,
    this.actions = const [],
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final RefreshCallback? onRefresh;
  final List<Widget> actions;
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scrollView = SingleChildScrollView(
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppScreenHeader(
                title: title,
                eyebrow: eyebrow,
                subtitle: subtitle,
                onBack: onBack,
                actions: actions,
              ),
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: onRefresh == null
            ? scrollView
            : RefreshIndicator(
                onRefresh: onRefresh!,
                child: scrollView,
              ),
      ),
    );
  }
}

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: '홈으로',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
              ],
              if (title == 'Maum On')
                const MaumOnBrandWordmark(height: 36)
              else
                Text(
                  title,
                  style: theme.textTheme.headlineMedium,
                ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            alignment: WrapAlignment.end,
            children: actions,
          ),
        ],
      ],
    );
  }
}

class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    this.tone = AppNoticeTone.neutral,
    super.key,
  });

  final String message;
  final AppNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _noticeColors(Theme.of(context).colorScheme, tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(colors.icon, color: colors.foreground, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.title,
    this.message,
    this.kind = AppStateKind.neutral,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  const AppStateView.loading({
    this.title = '불러오는 중입니다.',
    this.message,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  }) : kind = AppStateKind.loading;

  const AppStateView.empty({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  }) : kind = AppStateKind.empty;

  const AppStateView.error({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  }) : kind = AppStateKind.error;

  const AppStateView.permission({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  }) : kind = AppStateKind.permission;

  const AppStateView.risk({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  }) : kind = AppStateKind.risk;

  final String title;
  final String? message;
  final AppStateKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _stateColors(theme.colorScheme, kind);
    final stateDescription = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StateLead(kind: kind, colors: colors),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final describedState = semanticLabel == null
        ? stateDescription
        : Semantics(
            container: true,
            liveRegion: _stateLiveRegion(kind),
            label: semanticLabel,
            child: ExcludeSemantics(child: stateDescription),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            describedState,
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    required this.label,
    required this.value,
    this.tone = AppStatusTone.neutral,
    this.width = 176,
    super.key,
  });

  final String label;
  final String value;
  final AppStatusTone tone;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(Theme.of(context).colorScheme, tone);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 148,
        maxWidth: width,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: AppRadii.card,
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusTone = AppStatusTone.neutral,
    this.leadingIcon,
    this.trailingIcon = Icons.chevron_right,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
    this.rowKey,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? statusLabel;
  final AppStatusTone statusTone;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = statusLabel;

    return Semantics(
      key: rowKey,
      container: true,
      button: onTap != null,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(
        excluding: semanticLabel != null,
        child: Card(
          margin: EdgeInsets.zero,
          color: selected ? colorScheme.primaryContainer : null,
          child: InkWell(
            borderRadius: AppRadii.card,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leadingIcon != null) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.primary.withValues(alpha: 0.16)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadii.chip,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            leadingIcon,
                            size: 22,
                            color: selected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _softBreak(title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              _softBreak(subtitle!),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: AppStatusPill(
                          label: status,
                          tone: statusTone,
                        ),
                      ),
                    ],
                    if (trailingIcon != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        trailingIcon,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppDetailRow extends StatelessWidget {
  const AppDetailRow({
    required this.label,
    required this.value,
    this.semanticLabel,
    this.rowKey,
    super.key,
  });

  final String label;
  final String value;
  final String? semanticLabel;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? '-' : value;

    return Semantics(
      key: rowKey,
      container: true,
      label: semanticLabel ?? '$label, $displayValue',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _softBreak(displayValue),
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppConfirmActionButton extends StatelessWidget {
  const AppConfirmActionButton({
    required this.icon,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.confirmButtonLabel,
    required this.onConfirmed,
    this.cancelButtonLabel = '취소',
    this.enabled = true,
    this.buttonKey,
    this.confirmButtonKey,
    this.cancelButtonKey,
    this.semanticLabel,
    super.key,
  });

  final Widget icon;
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final String confirmButtonLabel;
  final Future<void> Function() onConfirmed;
  final String cancelButtonLabel;
  final bool enabled;
  final Key? buttonKey;
  final Key? confirmButtonKey;
  final Key? cancelButtonKey;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      key: buttonKey,
      onPressed: enabled ? () => _confirm(context) : null,
      icon: icon,
      label: Text(label),
    );

    if (semanticLabel == null) {
      return button;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: button),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(confirmTitle),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              key: cancelButtonKey,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelButtonLabel),
            ),
            FilledButton(
              key: confirmButtonKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmButtonLabel),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await onConfirmed();
    }
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    required this.label,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(Theme.of(context).colorScheme, tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.status,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _softBreak(String value) {
  return value.replaceAllMapped(RegExp(r'([@._/\-])'), (match) {
    return '${match.group(0) ?? ''}\u{200B}';
  });
}

_ToneColors _noticeColors(ColorScheme colorScheme, AppNoticeTone tone) {
  return switch (tone) {
    AppNoticeTone.neutral => _ToneColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
        icon: Icons.info_outline,
      ),
    AppNoticeTone.success => _ToneColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        border: colorScheme.secondary.withValues(alpha: 0.28),
        icon: Icons.check_circle_outline,
      ),
    AppNoticeTone.warning => _ToneColors(
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        border: colorScheme.tertiary.withValues(alpha: 0.28),
        icon: Icons.warning_amber_outlined,
      ),
    AppNoticeTone.error => _ToneColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.28),
        icon: Icons.error_outline,
      ),
  };
}

_ToneColors _statusColors(ColorScheme colorScheme, AppStatusTone tone) {
  return switch (tone) {
    AppStatusTone.neutral => _ToneColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
        icon: Icons.info_outline,
      ),
    AppStatusTone.success => _ToneColors(
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
        border: colorScheme.primary.withValues(alpha: 0.28),
        icon: Icons.check_circle_outline,
      ),
    AppStatusTone.warning => _ToneColors(
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        border: colorScheme.tertiary.withValues(alpha: 0.28),
        icon: Icons.warning_amber_outlined,
      ),
    AppStatusTone.danger => _ToneColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.28),
        icon: Icons.error_outline,
      ),
  };
}

_ToneColors _stateColors(ColorScheme colorScheme, AppStateKind kind) {
  return switch (kind) {
    AppStateKind.loading => _ToneColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
        icon: Icons.hourglass_empty,
      ),
    AppStateKind.empty => _ToneColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
        icon: Icons.inbox_outlined,
      ),
    AppStateKind.error => _ToneColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.28),
        icon: Icons.error_outline,
      ),
    AppStateKind.permission => _ToneColors(
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        border: colorScheme.tertiary.withValues(alpha: 0.28),
        icon: Icons.lock_outline,
      ),
    AppStateKind.risk => _ToneColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.28),
        icon: Icons.health_and_safety_outlined,
      ),
    AppStateKind.success => _ToneColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        border: colorScheme.secondary.withValues(alpha: 0.28),
        icon: Icons.check_circle_outline,
      ),
    AppStateKind.neutral => _ToneColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
        icon: Icons.info_outline,
      ),
  };
}

bool _stateLiveRegion(AppStateKind kind) {
  return kind == AppStateKind.loading ||
      kind == AppStateKind.error ||
      kind == AppStateKind.permission;
}

class _StateLead extends StatelessWidget {
  const _StateLead({
    required this.kind,
    required this.colors,
  });

  final AppStateKind kind;
  final _ToneColors colors;

  @override
  Widget build(BuildContext context) {
    if (kind == AppStateKind.loading) {
      return SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: colors.foreground,
        ),
      );
    }

    return Icon(colors.icon, color: colors.foreground, size: 22);
  }
}

class _ToneColors {
  const _ToneColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}
