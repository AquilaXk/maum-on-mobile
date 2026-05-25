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
          maxWidth: AppBreakpoints.compactContentMaxWidth,
          children: [
            _StatsSection(state: state),
            const SizedBox(height: AppSpacing.lg),
            const _HealingQuote(),
            const SizedBox(height: AppSpacing.lg),
            _ActionGrid(
              onWriteDiary: widget.onWriteDiary,
              onWriteLetter: widget.onWriteLetter,
              onViewStory: widget.onViewStory,
              onOpenConsultation: widget.onOpenConsultation,
              onOpenNotifications: widget.onOpenNotifications,
              onOpenSettings: widget.onOpenSettings,
              onLogout: widget.onLogout,
              isAdmin: widget.isAdmin,
              onOpenOperations: widget.onOpenOperations,
            ),
            const SizedBox(height: AppSpacing.xl),
            _CategoryFilter(
              selectedCategory: state.selectedCategory,
              onSelected: widget.homeController.selectCategory,
            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.statsErrorMessage != null) ...[
          AppNotice(message: state.statsErrorMessage!, tone: AppNoticeTone.error),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppMetricTile(
              label: '오늘 올라온 고민',
              value: _formatStatValue(
                stats?.todayWorryCount,
                state.isStatsLoading,
              ),
              tone: AppStatusTone.success,
            ),
            AppMetricTile(
              label: '전달된 비밀 편지',
              value: _formatStatValue(
                stats?.todayLetterCount,
                state.isStatsLoading,
              ),
            ),
            AppMetricTile(
              label: '오늘의 기록',
              value: _formatStatValue(
                stats?.todayDiaryCount,
                state.isStatsLoading,
              ),
              tone: AppStatusTone.warning,
            ),
          ],
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

class _HealingQuote extends StatelessWidget {
  const _HealingQuote();

  @override
  Widget build(BuildContext context) {
    return const AppNotice(
      message: '조금 느려도 괜찮아요. 오늘의 마음을 하나씩 살펴보세요.',
      tone: AppNoticeTone.success,
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    required this.onLogout,
    required this.isAdmin,
    this.onOpenOperations,
  });

  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final bool isAdmin;
  final VoidCallback? onOpenOperations;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        FilledButton(
          onPressed: onWriteDiary,
          child: const Text('다이어리 쓰기'),
        ),
        FilledButton.tonal(
          onPressed: onWriteLetter,
          child: const Text('편지 쓰기'),
        ),
        OutlinedButton(
          onPressed: onViewStory,
          child: const Text('스토리 보기'),
        ),
        FilledButton.tonalIcon(
          onPressed: onOpenConsultation,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('상담하기'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenNotifications,
          icon: const Icon(Icons.notifications_none),
          label: const Text('알림/신고'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('설정'),
        ),
        if (isAdmin && onOpenOperations != null)
          OutlinedButton.icon(
            key: const ValueKey('home-operations-button'),
            onPressed: onOpenOperations,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('운영 검수'),
          ),
        OutlinedButton(
          onPressed: onLogout,
          child: const Text('로그아웃'),
        ),
      ],
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

class _FeedSection extends StatelessWidget {
  const _FeedSection({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state.isFeedLoading) {
      return const AppNotice(message: '스토리를 불러오는 중입니다.');
    }

    if (state.feedErrorMessage != null) {
      return AppNotice(
        message: state.feedErrorMessage!,
        tone: AppNoticeTone.error,
      );
    }

    if (state.isFeedEmpty) {
      return const AppNotice(message: '아직 공개된 스토리가 없습니다.');
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
