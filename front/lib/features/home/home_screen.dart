import 'package:flutter/material.dart';

import '../../shared/ui/app_design_system.dart';
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
            _ActionGrid(
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
            const SizedBox(height: AppSpacing.xl),
            _CategoryOverview(
              stats: state.stats,
              selectedCategory: state.selectedCategory,
              onSelected: widget.homeController.selectCategory,
            ),
            const SizedBox(height: AppSpacing.md),
            _CategoryFilter(
              selectedCategory: state.selectedCategory,
              onSelected: widget.homeController.selectCategory,
            ),
            const SizedBox(height: AppSpacing.md),
            _PopularStorySection(stats: state.stats),
            const SizedBox(height: AppSpacing.md),
            _FeedSection(state: state),
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
        Row(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('오늘 요약', style: theme.textTheme.titleMedium),
          ],
        ),
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

            if (constraints.maxWidth < 460) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    Expanded(
                      child: _CompactHomeMetricTile(
                        label: items[index].label,
                        value: items[index].value,
                        tone: items[index].tone,
                      ),
                    ),
                    if (index != items.length - 1)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in items)
                  AppMetricTile(
                    label: item.label,
                    value: item.value,
                    tone: item.tone,
                  ),
              ],
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

class _CompactHomeMetricTile extends StatelessWidget {
  const _CompactHomeMetricTile({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _homeActionColors(theme.colorScheme, tone);

    return Semantics(
      label: '$label $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.foreground.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
          AppListRow(
            rowKey: ValueKey('home-draft-${draft.surface.name}'),
            title: draft.title,
            subtitle:
                '${draft.surface.label} · ${draft.preview} · ${_formatDraftDate(draft.updatedAt)}',
            statusLabel: draft.failed ? '전송 실패' : '임시 저장',
            statusTone:
                draft.failed ? AppStatusTone.warning : AppStatusTone.success,
            leadingIcon: _draftIcon(draft.surface),
            trailingIcon: Icons.play_arrow,
            onTap: () => onContinue(draft.surface),
            semanticLabel:
                '${draft.surface.label} 이어쓰기: ${draft.title}, ${draft.failed ? '전송 실패' : '임시 저장'}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
  });

  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('home-action-launcher'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.bolt_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('바로 시작', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Column(
          key: const ValueKey('home-primary-actions-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('home-primary-actions'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HomeQuickActionButton(
                    actionKey: const ValueKey('home-action-consultation'),
                    surfaceKey:
                        const ValueKey('home-action-consultation-primary'),
                    title: 'AI 상담',
                    icon: Icons.chat_bubble_outline,
                    tone: AppStatusTone.warning,
                    onTap: onOpenConsultation,
                  ),
                ),
                Expanded(
                  child: _HomeQuickActionButton(
                    actionKey: const ValueKey('home-action-diary'),
                    surfaceKey: const ValueKey('home-action-diary-surface'),
                    title: '기록',
                    icon: Icons.edit_note,
                    tone: AppStatusTone.warning,
                    onTap: onWriteDiary,
                  ),
                ),
                Expanded(
                  child: _HomeQuickActionButton(
                    actionKey: const ValueKey('home-action-letter'),
                    surfaceKey: const ValueKey('home-action-letter-surface'),
                    title: '편지',
                    icon: Icons.mail_outline,
                    onTap: onWriteLetter,
                  ),
                ),
                Expanded(
                  child: _HomeQuickActionButton(
                    actionKey: const ValueKey('home-action-story'),
                    surfaceKey: const ValueKey('home-action-story-surface'),
                    title: '스토리',
                    icon: Icons.forum_outlined,
                    tone: AppStatusTone.success,
                    onTap: onViewStory,
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

class _HomeQuickActionButton extends StatelessWidget {
  const _HomeQuickActionButton({
    required this.actionKey,
    required this.surfaceKey,
    required this.title,
    required this.icon,
    required this.onTap,
    this.tone = AppStatusTone.neutral,
  });

  final Key actionKey;
  final Key surfaceKey;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _homeActionColors(theme.colorScheme, tone);

    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkResponse(
                key: actionKey,
                onTap: onTap,
                radius: 32,
                containedInkWell: true,
                customBorder: const CircleBorder(),
                child: DecoratedBox(
                  key: surfaceKey,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Icon(icon, color: colors.foreground, size: 26),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w800,
                  ) ??
                  TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selectedCategory,
    required this.onSelected,
  });

  final HomeStoryCategory selectedCategory;
  final ValueChanged<HomeStoryCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in HomeStoryCategory.values)
          _HomeTextTab(
            key: ValueKey('home-category-${category.name}'),
            label: category.label,
            selected: category == selectedCategory,
            onTap: () => onSelected(category),
          ),
      ],
    );
  }
}

class _CategoryOverview extends StatelessWidget {
  const _CategoryOverview({
    required this.stats,
    required this.selectedCategory,
    required this.onSelected,
  });

  final HomeStats? stats;
  final HomeStoryCategory selectedCategory;
  final ValueChanged<HomeStoryCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final summaries = stats?.categorySummaries ?? const [];
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final summary in summaries)
              _HomeTextTab(
                key: ValueKey('home-category-summary-${summary.category.name}'),
                label: '${summary.label} ${summary.count}',
                selected: selectedCategory == summary.category,
                onTap: () => onSelected(summary.category),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeTextTab extends StatelessWidget {
  const _HomeTextTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                      ) ??
                      TextStyle(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 18,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          selected ? colorScheme.primary : Colors.transparent,
                      borderRadius: AppRadii.status,
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

class _PopularStorySection extends StatelessWidget {
  const _PopularStorySection({required this.stats});

  final HomeStats? stats;

  @override
  Widget build(BuildContext context) {
    final stories = stats?.popularStories ?? const [];
    if (stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('최근 인기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final story in stories) ...[
          AppListRow(
            rowKey: ValueKey('home-popular-story-${story.id}'),
            title: story.title,
            subtitle:
                '${story.label} · ${story.nickname} · 조회 ${story.viewCount}',
            leadingIcon: Icons.trending_up,
            trailingIcon: null,
            semanticLabel:
                '인기 스토리: ${story.title}, ${story.label}, 조회 ${story.viewCount}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({required this.state});

  final HomeState state;

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
          _StoryCard(story: story),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story});

  final HomeStory story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: ValueKey('home-feed-story-${story.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${story.category.label}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              story.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              story.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${story.authorNickname} · 조회 ${story.viewCount}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ],
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
  AppStatusTone tone,
) {
  return switch (tone) {
    AppStatusTone.success => const _HomeActionColors(
        background: Color(0xFFEAF6FF),
        foreground: Color(0xFF1F4D72),
      ),
    AppStatusTone.warning => const _HomeActionColors(
        background: Color(0xFFE8F1FF),
        foreground: Color(0xFF244C8A),
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
