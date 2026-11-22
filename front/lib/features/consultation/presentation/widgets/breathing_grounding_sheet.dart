// Interactive 4-4-4-4 box breathing timer and 5-4-3-2-1 sensory grounding sheet.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/ui/app_design_system.dart';
import '../../../../theme/app_theme.dart';

Future<void> showBreathingGroundingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const BreathingGroundingSheet(),
  );
}

class BreathingGroundingSheet extends StatefulWidget {
  const BreathingGroundingSheet({super.key});

  @override
  State<BreathingGroundingSheet> createState() =>
      _BreathingGroundingSheetState();
}

class _BreathingGroundingSheetState extends State<BreathingGroundingSheet> {
  static const int _phaseSeconds = 4;
  static const List<_BreathingPhase> _phases = [
    _BreathingPhase(label: '들숨', instruction: '코로 천천히 숨을 들이마셔요'),
    _BreathingPhase(label: '멈춤', instruction: '들숨을 편안하게 잠시 머금어요'),
    _BreathingPhase(label: '날숨', instruction: '입으로 길고 부드럽게 내쉬어요'),
    _BreathingPhase(label: '멈춤', instruction: '숨을 비운 채 어깨 힘을 풀어요'),
  ];

  static const List<_GroundingPrompt> _groundingPrompts = [
    _GroundingPrompt(count: 5, sense: '시각', prompt: '주변에서 눈에 보이는 사물 5가지'),
    _GroundingPrompt(count: 4, sense: '촉각', prompt: '손이나 발에 닿는 감각 4가지'),
    _GroundingPrompt(count: 3, sense: '청각', prompt: '지금 공간에서 들리는 소리 3가지'),
    _GroundingPrompt(count: 2, sense: '후각', prompt: '코끝으로 느껴지는 냄새 2가지'),
    _GroundingPrompt(count: 1, sense: '미각·내면', prompt: '입안 감각이나 깊은 호흡 1가지'),
  ];

  Timer? _timer;
  bool _running = false;
  int _phaseIndex = 0;
  int _secondsLeft = _phaseSeconds;
  int _completedCycles = 0;
  final Set<int> _checkedSteps = <int>{};

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleBreathing() {
    if (_running) {
      _timer?.cancel();
      _timer = null;
      setState(() {
        _running = false;
      });
      return;
    }

    setState(() {
      _running = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft -= 1;
        } else {
          final nextPhase = (_phaseIndex + 1) % _phases.length;
          if (nextPhase == 0) {
            _completedCycles += 1;
          }
          _phaseIndex = nextPhase;
          _secondsLeft = _phaseSeconds;
        }
      });
    });
  }

  void _resetBreathing() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _running = false;
      _phaseIndex = 0;
      _secondsLeft = _phaseSeconds;
      _completedCycles = 0;
    });
  }

  void _toggleGroundingStep(int count) {
    setState(() {
      if (!_checkedSteps.add(count)) {
        _checkedSteps.remove(count);
      }
    });
  }

  double _targetCircleFactor() {
    if (!_running && _phaseIndex == 0 && _secondsLeft == _phaseSeconds) {
      return 0.72;
    }
    return switch (_phaseIndex) {
      0 => 0.72 + (0.28 * ((_phaseSeconds - _secondsLeft + 1) / _phaseSeconds)),
      1 => 1.0,
      2 => 1.0 - (0.28 * ((_phaseSeconds - _secondsLeft + 1) / _phaseSeconds)),
      _ => 0.72,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.maumTokens;
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final surface = tokens.surface;
    final cardSurface = tokens.elevatedSurface;
    final foreground = tokens.foreground;
    final secondary = tokens.mutedForeground;
    final accent = tokens.primary;
    final border = tokens.border;

    final currentPhase = _phases[_phaseIndex];
    final circleSize = 96 * _targetCircleFactor();

    return ColoredBox(
      color: surface,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '지금 이 자리로 돌아오는 연습',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '호흡과 주변 감각에 잠시 마음을 두어 보세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: '닫기',
                  child: IconButton(
                    key: const ValueKey('breathing-close-button'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: secondary),
                    tooltip: '닫기',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '4-4-4-4 박스 호흡',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$_completedCycles회 완료',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      height: 108,
                      child: Center(
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 650),
                          curve: Curves.easeInOut,
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: isDark ? 0.2 : 0.14),
                            border: Border.all(color: accent, width: 2),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentPhase.label,
                                  key: const ValueKey('breathing-phase-label'),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$_secondsLeft초',
                                  key: const ValueKey('breathing-seconds-label'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: foreground,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: AppTypography.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentPhase.instruction,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('breathing-toggle-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: accent,
                          foregroundColor: tokens.onPrimary,
                        ),
                        onPressed: _toggleBreathing,
                        icon: Icon(
                          _running
                              ? Icons.pause_rounded
                              : Icons.self_improvement_rounded,
                        ),
                        label: Text(_running ? '일시정지' : '호흡 시작'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('breathing-reset-button'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: foreground,
                          side: BorderSide(color: border),
                        ),
                        onPressed: _resetBreathing,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('초기화'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '5-4-3-2-1 감각 그라운딩',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_checkedSteps.length}/${_groundingPrompts.length} 확인',
                  key: const ValueKey('grounding-progress-label'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._groundingPrompts.map((step) {
              final checked = _checkedSteps.contains(step.count);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  checked: checked,
                  label: '${step.sense}, ${step.prompt}',
                  child: InkWell(
                    key: ValueKey('grounding-step-${step.count}'),
                    onTap: () => _toggleGroundingStep(step.count),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: checked ? cardSurface : surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: checked ? accent : border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked
                                  ? accent
                                  : accent.withValues(alpha: 0.12),
                            ),
                            child: Center(
                              child: checked
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: tokens.onPrimary,
                                    )
                                  : Text(
                                      '${step.count}',
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  step.sense,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: checked ? accent : secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  step.prompt,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: foreground,
                                    decoration: checked
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BreathingPhase {
  const _BreathingPhase({
    required this.label,
    required this.instruction,
  });

  final String label;
  final String instruction;
}

class _GroundingPrompt {
  const _GroundingPrompt({
    required this.count,
    required this.sense,
    required this.prompt,
  });

  final int count;
  final String sense;
  final String prompt;
}
