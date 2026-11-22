// Bento dashboard & daily mood check-in hero surface layout.
import 'package:flutter/material.dart';

import '../../shared/ui/app_design_system.dart';
import '../../theme/app_theme.dart';
import 'application/home_controller.dart';
import 'domain/home_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.nickname,
    required this.homeController,
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    this.unreadNotificationCount = 0,
    this.hasLiveNotificationConnection = false,
    this.onRefresh,
    super.key,
  });

  final String nickname;
  final HomeController homeController;
  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final int unreadNotificationCount;
  final bool hasLiveNotificationConnection;
  final Future<void> Function()? onRefresh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeController != widget.homeController) {
      _loadIfNeeded();
    }
  }

  void _loadIfNeeded() {
    if (!widget.homeController.state.hasLoaded) {
      Future<void>.microtask(widget.homeController.load);
    }
  }

  void _openSurface(HomeActionSurface surface) {
    switch (surface) {
      case HomeActionSurface.diary:
        widget.onWriteDiary();
        break;
      case HomeActionSurface.story:
        widget.onViewStory();
        break;
      case HomeActionSurface.letter:
        widget.onWriteLetter();
        break;
      case HomeActionSurface.consultation:
        widget.onOpenConsultation();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.homeController,
      builder: (context, _) {
        final state = widget.homeController.state;
        final showDraftContinuation = _shouldShowDraftContinuation(state);

        return AppScreen(
          title: 'Maum On',
          onRefresh: widget.onRefresh ?? widget.homeController.load,
          actions: [
            _HomeNotificationHeaderButton(
              unreadCount: widget.unreadNotificationCount,
              onPressed: widget.onOpenNotifications,
            ),
            _HomeSettingsHeaderButton(onPressed: widget.onOpenSettings),
          ],
          maxWidth: AppBreakpoints.compactContentMaxWidth,
          children: [
            _MoodCheckinHeroCard(
              nickname: widget.nickname,
              stats: state.stats,
              onWriteDiary: widget.onWriteDiary,
              onOpenConsultation: widget.onOpenConsultation,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionGrid(
              stats: state.stats,
              hasLiveNotificationConnection:
                  widget.hasLiveNotificationConnection,
              onWriteDiary: widget.onWriteDiary,
              onWriteLetter: widget.onWriteLetter,
              onViewStory: widget.onViewStory,
              onOpenConsultation: widget.onOpenConsultation,
            ),
            if (showDraftContinuation) ...[
              const SizedBox(height: AppSpacing.lg),
              _DraftContinuationSection(
                state: state,
                onContinue: _openSurface,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _StatsSection(state: state),
            const SizedBox(height: AppSpacing.lg),
            _PopularStorySection(
              stats: state.stats,
              onStoryTap: widget.onViewStory,
            ),
            if ((state.stats?.popularStories ?? const []).isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            _SegmentedCategoryBar(
              stats: state.stats,
              selectedCategory: state.selectedCategory,
              onSelected: widget.homeController.selectCategory,
            ),
            const SizedBox(height: AppSpacing.md),
            _FeedSection(
              state: state,
              onStoryTap: widget.onViewStory,
            ),
          ],
        );
      },
    );
  }
}

bool _shouldShowDraftContinuation(HomeState state) {
  return state.isDraftLoading ||
      state.draftErrorMessage != null ||
      state.drafts.isNotEmpty;
}

class _MoodCheckinHeroCard extends StatelessWidget {
  const _MoodCheckinHeroCard({
    required this.nickname,
    required this.stats,
    required this.onWriteDiary,
    required this.onOpenConsultation,
  });

  final String nickname;
  final HomeStats? stats;
  final VoidCallback onWriteDiary;
  final VoidCallback onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.maumTokens;
    final isDark = theme.brightness == Brightness.dark;
    final summaryText = stats?.summary.recoveryMessage.trim() ?? '';

    return MaumShadThemeScope(
      child: ShadCard(
        key: const ValueKey('home-checkin-hero-card'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: isDark
            ? colorScheme.primaryContainer.withValues(alpha: 0.42)
            : tokens.surfaceStrong,
        border: ShadBorder.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1,
        ),
        rowMainAxisSize: MainAxisSize.max,
        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$nickname님, 오늘 마음은 어떤가요?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (summaryText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                summaryText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var index = 0;
                    index < _moodCheckinOptions.length;
                    index++) ...[
                  Expanded(
                    child: _MoodScoreButton(
                      option: _moodCheckinOptions[index],
                      onTap: onWriteDiary,
                    ),
                  ),
                  if (index != _moodCheckinOptions.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                key: const ValueKey('home-hero-consultation-cta'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onPressed: onOpenConsultation,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('AI 상담 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodScoreButton extends StatelessWidget {
  const _MoodScoreButton({
    required this.option,
    required this.onTap,
  });

  final _MoodOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '기분 ${option.score}점 ${option.label} 기록하기',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: option.color,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: ValueKey('home-mood-checkin-${option.score}'),
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${option.score}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: option.foreground,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        option.shortLabel,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: option.foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ),
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

class _MoodOption {
  const _MoodOption({
    required this.score,
    required this.shortLabel,
  });

  final int score;
  final String shortLabel;

  String get label => MaumTokens.moodLabel(score);
  Color get color => MaumTokens.moodBackground(score);
  Color get foreground => MaumTokens.moodForeground(score);
}

const List<_MoodOption> _moodCheckinOptions = [
  _MoodOption(score: 1, shortLabel: '버거움'),
  _MoodOption(score: 2, shortLabel: '지침'),
  _MoodOption(score: 3, shortLabel: '보통'),
  _MoodOption(score: 4, shortLabel: '편안'),
  _MoodOption(score: 5, shortLabel: '가벼움'),
];

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.stats,
    required this.hasLiveNotificationConnection,
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
  });

  final HomeStats? stats;
  final bool hasLiveNotificationConnection;
  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('home-action-launcher'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('마음 공간', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Column(
          key: const ValueKey('home-primary-actions-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              key: const ValueKey('home-primary-actions'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BentoActionTile(
                          actionKey:
                              const ValueKey('home-action-consultation'),
                          surfaceKey: const ValueKey(
                            'home-action-consultation-primary',
                          ),
                          title: 'AI 상담',
                          subtitle: '24시간 대화',
                          icon: Icons.chat_bubble_outline,
                          tone: AppStatusTone.warning,
                          onTap: onOpenConsultation,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _BentoActionTile(
                          actionKey: const ValueKey('home-action-diary'),
                          surfaceKey:
                              const ValueKey('home-action-diary-surface'),
                          title: '기록',
                          subtitle: '감정 기록',
                          icon: Icons.edit_note,
                          tone: AppStatusTone.warning,
                          onTap: onWriteDiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BentoActionTile(
                          actionKey: const ValueKey('home-action-letter'),
                          surfaceKey:
                              const ValueKey('home-action-letter-surface'),
                          title: '편지',
                          subtitle: '익명 우편함',
                          icon: Icons.mail_outline,
                          onTap: onWriteLetter,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _BentoActionTile(
                          actionKey: const ValueKey('home-action-story'),
                          surfaceKey:
                              const ValueKey('home-action-story-surface'),
                          title: '스토리',
                          subtitle: '공감 피드',
                          icon: Icons.forum_outlined,
                          tone: AppStatusTone.success,
                          onTap: onViewStory,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _BentoActionTile extends StatelessWidget {
  const _BentoActionTile({
    required this.actionKey,
    required this.surfaceKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = AppStatusTone.neutral,
  });

  final Key actionKey;
  final Key surfaceKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _homeActionColors(colorScheme, context.maumTokens, tone);

    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MaumShadThemeScope(
          child: ShadCard(
            padding: EdgeInsets.zero,
            rowMainAxisSize: MainAxisSize.max,
            columnCrossAxisAlignment: CrossAxisAlignment.stretch,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: actionKey,
                borderRadius: AppRadii.card,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        key: surfaceKey,
                        dimension: 28,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            icon,
                            color: colors.foreground,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('home-stats-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('오늘의 흐름', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        if (state.statsErrorMessage != null) ...[
          AppNotice(
            message: state.statsErrorMessage!,
            tone: AppNoticeTone.error,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final items = [
              _HomeMetricData(
                label: '오늘의 기록',
                value: _formatStatValue(
                  stats?.todayDiaryCount,
                  state.isStatsLoading,
                ),
                tone: AppStatusTone.warning,
              ),
              _HomeMetricData(
                label: '전달된 비밀 편지',
                value: _formatStatValue(
                  stats?.todayLetterCount,
                  state.isStatsLoading,
                ),
              ),
              _HomeMetricData(
                label: '오늘 올라온 고민',
                value: _formatStatValue(
                  stats?.todayWorryCount,
                  state.isStatsLoading,
                ),
                tone: AppStatusTone.success,
              ),
            ];

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    Expanded(
                      child: _PulseMetricCard(
                        label: items[index].label,
                        value: items[index].value,
                        tone: items[index].tone,
                        compact: isCompact,
                      ),
                    ),
                    if (index != items.length - 1)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatStatValue(int? value, bool isLoading) {
    if (isLoading) {
      return '...';
    }

    return (value ?? 0).toString();
  }
}

class _HomeMetricData {
  const _HomeMetricData({
    required this.label,
    required this.value,
    this.tone = AppStatusTone.neutral,
  });

  final String label;
  final String value;
  final AppStatusTone tone;
}

class _PulseMetricCard extends StatelessWidget {
  const _PulseMetricCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.compact,
  });

  final String label;
  final String value;
  final AppStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _homeActionColors(theme.colorScheme, context.maumTokens, tone);

    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: MaumShadThemeScope(
          child: ShadCard(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            backgroundColor: colors.background,
            border: ShadBorder.all(
              color: colors.foreground.withValues(alpha: 0.16),
              width: 1,
            ),
            rowMainAxisSize: MainAxisSize.max,
            columnCrossAxisAlignment: CrossAxisAlignment.stretch,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.foreground.withValues(alpha: 0.86),
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.foreground,
                      fontSize: compact ? 19 : 22,
                      fontWeight: FontWeight.w900,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNotificationHeaderButton extends StatelessWidget {
  const _HomeNotificationHeaderButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeText = _formatBadgeCount(unreadCount);

    return IconButton(
      key: const ValueKey('home-header-notification-button'),
      tooltip: unreadCount > 0 ? '읽지 않은 알림 $badgeText' : '알림/신고',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unreadCount > 0)
            PositionedDirectional(
              end: -8,
              top: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: AppRadii.status,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: 1,
                  ),
                  child: Text(
                    badgeText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onError,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeSettingsHeaderButton extends StatelessWidget {
  const _HomeSettingsHeaderButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('home-header-settings-button'),
      tooltip: '설정',
      onPressed: onPressed,
      icon: const Icon(Icons.settings_outlined),
    );
  }
}

class _DraftContinuationSection extends StatelessWidget {
  const _DraftContinuationSection({
    required this.state,
    required this.onContinue,
  });

  final HomeState state;
  final ValueChanged<HomeActionSurface> onContinue;

  @override
  Widget build(BuildContext context) {
    if (state.isDraftLoading) {
      return const AppStateView.loading(
        title: '이어쓸 내용을 확인하는 중입니다.',
        semanticLabel: '홈 임시 저장 내용을 확인하는 중',
      );
    }

    if (state.draftErrorMessage != null) {
      return AppStateView.error(
        title: '이어쓰기 내용을 불러오지 못했습니다.',
        message: state.draftErrorMessage!,
        semanticLabel: '홈 임시 저장 내용 오류',
      );
    }

    if (state.drafts.isEmpty) {
      return const AppStateView.empty(
        title: '이어쓸 내용이 없습니다.',
        semanticLabel: '홈 이어쓰기 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('이어쓰기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final draft in state.drafts) ...[
          MaumShadThemeScope(
            child: ShadCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              rowMainAxisSize: MainAxisSize.max,
              columnCrossAxisAlignment: CrossAxisAlignment.stretch,
              child: Material(
                type: MaterialType.transparency,
                child: AppListRow(
                  rowKey: ValueKey('home-draft-${draft.surface.name}'),
                  title: draft.title,
                  subtitle: [
                    if (draft.failed) '전송 실패',
                    draft.surface.label,
                    draft.preview,
                    _formatDraftDate(draft.updatedAt),
                  ].join(' · '),
                  statusLabel: draft.failed ? '전송 실패' : '임시 저장',
                  statusTone:
                      draft.failed ? AppStatusTone.danger : AppStatusTone.warning,
                  leadingIcon: _draftIcon(draft.surface),
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () => onContinue(draft.surface),
                  semanticLabel:
                      '${draft.surface.label} 이어쓰기: ${draft.title}, ${draft.failed ? '전송 실패' : '임시 저장'}',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _SegmentedCategoryBar extends StatelessWidget {
  const _SegmentedCategoryBar({
    required this.stats,
    required this.selectedCategory,
    required this.onSelected,
  });

  final HomeStats? stats;
  final HomeStoryCategory selectedCategory;
  final ValueChanged<HomeStoryCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summariesByCategory = <HomeStoryCategory, HomeCategorySummary>{
      for (final summary in stats?.categorySummaries ?? const [])
        summary.category: summary,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final category in HomeStoryCategory.values)
              _SegmentedCategoryTab(
                key: ValueKey('home-category-${category.name}'),
                category: category,
                summary: summariesByCategory[category],
                selected: category == selectedCategory,
                onTap: () => onSelected(category),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedCategoryTab extends StatelessWidget {
  const _SegmentedCategoryTab({
    required this.category,
    required this.summary,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final HomeStoryCategory category;
  final HomeCategorySummary? summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
    final semanticLabel = summary == null
        ? category.label
        : '${category.label} ${summary!.count}';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    if (summary != null) ...[
                      const SizedBox(width: 6),
                      DecoratedBox(
                        key: ValueKey(
                          'home-category-summary-${summary!.category.name}',
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.surface
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadii.status,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            '${summary!.count}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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

class _PopularStorySection extends StatelessWidget {
  const _PopularStorySection({
    required this.stats,
    required this.onStoryTap,
  });

  final HomeStats? stats;
  final VoidCallback onStoryTap;

  @override
  Widget build(BuildContext context) {
    final stories = stats?.popularStories ?? const [];
    if (stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('최근 인기', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final story in stories) ...[
          Semantics(
            button: true,
            label:
                '인기 스토리: ${story.title}, ${story.label}, 조회 ${story.viewCount}',
            onTap: onStoryTap,
            child: ExcludeSemantics(
              child: MaumShadThemeScope(
                child: ShadCard(
                  padding: EdgeInsets.zero,
                  rowMainAxisSize: MainAxisSize.max,
                  columnCrossAxisAlignment: CrossAxisAlignment.stretch,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: ValueKey('home-popular-story-${story.id}'),
                      borderRadius: AppRadii.card,
                      onTap: onStoryTap,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${story.label}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              story.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${story.nickname} · 조회 ${story.viewCount}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.state,
    required this.onStoryTap,
  });

  final HomeState state;
  final VoidCallback onStoryTap;

  @override
  Widget build(BuildContext context) {
    if (state.isFeedLoading) {
      return const AppStateView.loading(
        title: '스토리를 불러오는 중입니다.',
        semanticLabel: '홈 공개 스토리 목록을 불러오는 중',
      );
    }

    if (state.feedErrorMessage != null) {
      return AppStateView.error(
        title: '스토리를 불러오지 못했습니다.',
        message: state.feedErrorMessage!,
        semanticLabel: '홈 공개 스토리 목록 오류',
      );
    }

    if (state.isFeedEmpty) {
      return const AppStateView.empty(
        title: '아직 공개된 스토리가 없습니다.',
        semanticLabel: '홈 공개 스토리 목록 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final story in state.visibleStories) ...[
          _StoryCard(story: story, onTap: onStoryTap),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onTap,
  });

  final HomeStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return KeyedSubtree(
      key: ValueKey('home-feed-story-${story.id}'),
      child: Semantics(
        button: true,
        label:
            '홈 공개 스토리: ${story.title}, ${story.category.label}, ${story.authorNickname}, 조회 ${story.viewCount}',
        onTap: onTap,
        child: ExcludeSemantics(
          child: MaumShadThemeScope(
            child: ShadCard(
              padding: EdgeInsets.zero,
              rowMainAxisSize: MainAxisSize.max,
              columnCrossAxisAlignment: CrossAxisAlignment.stretch,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: AppRadii.card,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShadBadge.secondary(
                          backgroundColor: colorScheme.primaryContainer,
                          hoverBackgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text('#${story.category.label}'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          story.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${story.authorNickname} · 조회 ${story.viewCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _draftIcon(HomeActionSurface surface) {
  return switch (surface) {
    HomeActionSurface.diary => Icons.edit_note,
    HomeActionSurface.story => Icons.forum_outlined,
    HomeActionSurface.letter => Icons.mail_outline,
    HomeActionSurface.consultation => Icons.chat_bubble_outline,
  };
}

String _formatDraftDate(DateTime updatedAt) {
  if (updatedAt.millisecondsSinceEpoch == 0) {
    return '시간 없음';
  }
  final local = updatedAt.toLocal();
  return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatBadgeCount(int count) {
  if (count > 99) {
    return '99+';
  }
  return count.toString();
}

_HomeActionColors _homeActionColors(
  ColorScheme colorScheme,
  MaumTokens tokens,
  AppStatusTone tone,
) {
  return switch (tone) {
    AppStatusTone.success => _HomeActionColors(
        background: tokens.quickActionSkyBg,
        foreground: tokens.quickActionSkyFg,
      ),
    AppStatusTone.warning => _HomeActionColors(
        background: tokens.quickActionBlueBg,
        foreground: tokens.quickActionBlueFg,
      ),
    AppStatusTone.danger => _HomeActionColors(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      ),
    AppStatusTone.neutral => _HomeActionColors(
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
  };
}

class _HomeActionColors {
  const _HomeActionColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
