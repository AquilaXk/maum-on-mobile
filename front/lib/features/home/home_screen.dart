import 'package:flutter/material.dart';

import '../../app/supported_platforms.dart';
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
    required this.onLogout,
    super.key,
  });

  final String routeTitle;
  final String nickname;
  final HomeController homeController;
  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onLogout;

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

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeHeader(
                        routeTitle: widget.routeTitle,
                        nickname: widget.nickname,
                      ),
                      const SizedBox(height: 20),
                      _StatsSection(state: state),
                      const SizedBox(height: 16),
                      const _HealingQuote(),
                      const SizedBox(height: 16),
                      _ActionGrid(
                        onWriteDiary: widget.onWriteDiary,
                        onWriteLetter: widget.onWriteLetter,
                        onViewStory: widget.onViewStory,
                        onOpenConsultation: widget.onOpenConsultation,
                        onLogout: widget.onLogout,
                      ),
                      const SizedBox(height: 20),
                      _CategoryFilter(
                        selectedCategory: state.selectedCategory,
                        onSelected: widget.homeController.selectCategory,
                      ),
                      const SizedBox(height: 12),
                      _FeedSection(state: state),
                      const SizedBox(height: 20),
                      const _PlatformRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.routeTitle,
    required this.nickname,
  });

  final String routeTitle;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          routeTitle,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Maum On',
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          '$nickname님, 오늘의 마음을 이어가세요.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
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
          _InlineNotice(message: state.statsErrorMessage!),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatTile(
              label: '오늘 올라온 고민',
              value: _formatStatValue(
                stats?.todayWorryCount,
                state.isStatsLoading,
              ),
            ),
            _StatTile(
              label: '전달된 비밀 편지',
              value: _formatStatValue(
                stats?.todayLetterCount,
                state.isStatsLoading,
              ),
            ),
            _StatTile(
              label: '오늘의 기록',
              value: _formatStatValue(
                stats?.todayDiaryCount,
                state.isStatsLoading,
              ),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 156,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealingQuote extends StatelessWidget {
  const _HealingQuote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '조금 느려도 괜찮아요. 오늘의 마음을 하나씩 살펴보세요.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onWriteDiary,
    required this.onWriteLetter,
    required this.onViewStory,
    required this.onOpenConsultation,
    required this.onLogout,
  });

  final VoidCallback onWriteDiary;
  final VoidCallback onWriteLetter;
  final VoidCallback onViewStory;
  final VoidCallback onOpenConsultation;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
      spacing: 8,
      runSpacing: 8,
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
      return const _InlineNotice(message: '스토리를 불러오는 중입니다.');
    }

    if (state.feedErrorMessage != null) {
      return _InlineNotice(message: state.feedErrorMessage!);
    }

    if (state.isFeedEmpty) {
      return const _InlineNotice(message: '아직 공개된 스토리가 없습니다.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final story in state.visibleStories) ...[
          _StoryCard(story: story),
          const SizedBox(height: 10),
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
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              story.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              story.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message),
      ),
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final platform in supportedPlatforms)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Text(
                platform.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
