import 'package:flutter/material.dart';

import '../../app/supported_platforms.dart';
import '../../shared/ui/app_design_system.dart';
import 'application/home_controller.dart';
import 'domain/home_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.routeTitle,
    required this.nickname,
    required this.homeController,
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    required this.onLogout,
    this.isAdmin = false,
    this.unreadNotificationCount = 0,
    this.hasLiveNotificationConnection = false,
    this.onRefresh,
    this.onOpenOperations,
    super.key,
  });

  final String routeTitle;
  final String nickname;
  final HomeController homeController;
  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final bool isAdmin;
  final int unreadNotificationCount;
  final bool hasLiveNotificationConnection;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenOperations;

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

        return AppScreen(
          eyebrow: widget.routeTitle,
          title: 'Maum On',
          subtitle: '${widget.nickname}님, 오늘의 마음을 이어가세요.',
          onRefresh: widget.onRefresh ?? widget.homeController.load,
          actions: [
            _HomeNotificationHeaderButton(
              unreadCount: widget.unreadNotificationCount,
              onPressed: widget.onOpenNotifications,
            ),
          ],
          maxWidth: AppBreakpoints.compactContentMaxWidth,
          children: [
            _HealingQuote(
              summary: state.stats?.summary,
              onPrimaryAction: _openSurface,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StatsSection(state: state),
            const SizedBox(height: AppSpacing.lg),
            _ActionGrid(
              onWriteDiary: widget.onWriteDiary,
              onWriteLetter: widget.onWriteLetter,
              onViewStory: widget.onViewStory,
              onOpenConsultation: widget.onOpenConsultation,
              onOpenSettings: widget.onOpenSettings,
              onLogout: widget.onLogout,
              isAdmin: widget.isAdmin,
              onOpenOperations: widget.onOpenOperations,
            ),
            const SizedBox(height: AppSpacing.lg),
            _NotificationPriorityEntry(
              unreadCount: widget.unreadNotificationCount,
              hasLiveConnection: widget.hasLiveNotificationConnection,
              onOpenNotifications: widget.onOpenNotifications,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DraftContinuationSection(
              state: state,
              onContinue: _openSurface,
            ),
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
            const SizedBox(height: AppSpacing.xl),
            const _PlatformRow(),
          ],
        );
      },
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: AppRadii.card,
          border: Border.all(
            color: colors.foreground.withValues(alpha: 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
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
                  color: colors.foreground.withValues(alpha: 0.78),
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

class _HealingQuote extends StatelessWidget {
  const _HealingQuote({
    required this.summary,
    required this.onPrimaryAction,
  });

  final HomeSummary? summary;
  final ValueChanged<HomeActionSurface> onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final homeSummary = summary ?? const HomeSummary();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const ValueKey('home-primary-panel'),
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: AppRadii.chip,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.favorite_border,
                      color: colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    homeSummary.recoveryMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('home-primary-action-button'),
              onPressed: () =>
                  onPrimaryAction(homeSummary.primaryActionSurface),
              icon: const Icon(Icons.arrow_forward),
              label: Text(homeSummary.primaryActionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPriorityEntry extends StatelessWidget {
  const _NotificationPriorityEntry({
    required this.unreadCount,
    required this.hasLiveConnection,
    required this.onOpenNotifications,
  });

  final int unreadCount;
  final bool hasLiveConnection;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final liveLabel = hasLiveConnection ? '실시간 연결됨' : '알림 센터';
    final unreadLabel = hasUnread
        ? '읽지 않은 알림 ${_formatBadgeCount(unreadCount)}개'
        : '읽지 않은 알림 없음';

    final statusTone = hasUnread
        ? AppStatusTone.warning
        : hasLiveConnection
            ? AppStatusTone.success
            : AppStatusTone.neutral;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '알림/신고, $unreadLabel, $liveLabel',
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: const ValueKey('home-action-notifications'),
          borderRadius: AppRadii.card,
          onTap: onOpenNotifications,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadii.chip,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      hasUnread
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                      size: 22,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '알림/신고',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '$unreadLabel · $liveLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: AppStatusPill(
                    label: hasUnread ? '확인 필요' : liveLabel,
                    tone: statusTone,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
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
        message: '새 기록, 편지, 스토리, 상담을 바로 시작할 수 있습니다.',
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
    required this.onOpenSettings,
    required this.onLogout,
    required this.isAdmin,
    this.onOpenOperations,
  });

  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final bool isAdmin;
  final VoidCallback? onOpenOperations;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardAspectRatio = width < 390 ? 2.16 : 2.36;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('바로 시작', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
          childAspectRatio: cardAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _HomeActionCard(
              actionKey: const ValueKey('home-action-diary'),
              title: '다이어리 쓰기',
              subtitle: '오늘 마음 정리',
              icon: Icons.edit_note,
              tone: AppStatusTone.warning,
              onTap: onWriteDiary,
            ),
            _HomeActionCard(
              actionKey: const ValueKey('home-action-letter'),
              title: '편지 쓰기',
              subtitle: '조용히 전하기',
              icon: Icons.mail_outline,
              onTap: onWriteLetter,
            ),
            _HomeActionCard(
              actionKey: const ValueKey('home-action-story'),
              title: '스토리 보기',
              subtitle: '함께 읽기',
              icon: Icons.forum_outlined,
              tone: AppStatusTone.success,
              onTap: onViewStory,
            ),
            _HomeActionCard(
              actionKey: const ValueKey('home-action-consultation'),
              title: '상담하기',
              subtitle: '지금 대화하기',
              icon: Icons.chat_bubble_outline,
              onTap: onOpenConsultation,
            ),
          ],
        ),
        if (isAdmin && onOpenOperations != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey('home-operations-button'),
              onPressed: onOpenOperations,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('운영 검수'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('home-action-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('설정'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('home-action-logout'),
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.actionKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = AppStatusTone.neutral,
  });

  final Key actionKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _homeActionColors(theme.colorScheme, tone);

    return Card(
      margin: EdgeInsets.zero,
      color: colors.background,
      child: InkWell(
        key: actionKey,
        borderRadius: AppRadii.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: 0.10),
                  borderRadius: AppRadii.chip,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(icon, color: colors.foreground, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.foreground.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          ChoiceChip(
            key: ValueKey('home-category-${category.name}'),
            label: Text(category.label),
            selected: category == selectedCategory,
            onSelected: (_) => onSelected(category),
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
        if (stats?.summary.feedMessage.isNotEmpty == true) ...[
          AppNotice(message: stats!.summary.feedMessage),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final summary in summaries)
              ChoiceChip(
                key: ValueKey('home-category-summary-${summary.category.name}'),
                label: Text('${summary.label} ${summary.count}'),
                selected: selectedCategory == summary.category,
                onSelected: (_) => onSelected(summary.category),
              ),
          ],
        ),
      ],
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
            statusLabel: story.label,
            statusTone: AppStatusTone.success,
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
        message: '카테고리를 바꾸거나 잠시 뒤 다시 확인해 주세요.',
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

    return Card(
      key: ValueKey('home-feed-story-${story.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
          ],
        ),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final platform in supportedPlatforms)
          AppStatusPill(
            label: platform.toUpperCase(),
            tone: AppStatusTone.success,
          ),
      ],
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
  final isDark = colorScheme.brightness == Brightness.dark;

  return switch (tone) {
    AppStatusTone.success => _HomeActionColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
    AppStatusTone.warning => _HomeActionColors(
        background: isDark ? const Color(0xFF3A2B18) : const Color(0xFFFFF4DE),
        foreground: isDark ? const Color(0xFFFFD391) : const Color(0xFF62411B),
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
