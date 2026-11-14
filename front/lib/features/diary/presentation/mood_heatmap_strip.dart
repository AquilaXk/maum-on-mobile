import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../domain/mood_year_bitmap.dart';

const int _heatmapWeeks = 12;
const int _heatmapDaysPerWeek = 7;
const int _heatmapWindowDays = _heatmapWeeks * _heatmapDaysPerWeek; // 84 days

/// Renders a single-canvas 12-week (84-day) emotional activity strip backed by
/// [MoodYearBitmap] bit-packed indices with zero per-cell widget allocations.
class MoodHeatmapStrip extends StatelessWidget {
  const MoodHeatmapStrip({
    required this.bitmapsByYear,
    required this.anchorDate,
    this.selectedDate,
    this.onSelectDate,
    super.key,
  });

  final Map<int, MoodYearBitmap> bitmapsByYear;
  final DateTime anchorDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onSelectDate;

  @override
  Widget build(BuildContext context) {
    final normalizedAnchor =
        DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final normalizedSelected = selectedDate == null
        ? null
        : DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    final gridStartDate = _computeGridStartDate(normalizedAnchor);
    final summary = _summarizeWindow(
      bitmapsByYear: bitmapsByYear,
      gridStartDate: gridStartDate,
      anchorDate: normalizedAnchor,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avgMoodLabel = summary.averageMood == null
        ? '기록 ${summary.recordedDays}일'
        : '평균 기분 ${summary.averageMood!.toStringAsFixed(1)}점';
    final semanticSummary =
        '최근 12주 감정 흐름, 기록 ${summary.recordedDays}일, 연속 ${summary.streakDays}일'
        '${summary.averageMood == null ? '' : ', 평균 기분 ${summary.averageMood!.toStringAsFixed(1)}점'}';

    return Semantics(
      key: const ValueKey('diary-mood-heatmap-strip'),
      container: true,
      label: semanticSummary,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadii.card,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '최근 12주 감정 흐름',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      _HeatmapStatBadge(
                        label: '연속 ${summary.streakDays}일',
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                      ),
                      _HeatmapStatBadge(
                        label: avgMoodLabel,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 320.0;
                    const spacing = 4.0;
                    final rawCellSize =
                        (availableWidth - spacing * (_heatmapWeeks - 1)) /
                            _heatmapWeeks;
                    final cellSize = rawCellSize.clamp(10.0, 22.0);
                    final canvasWidth =
                        cellSize * _heatmapWeeks + spacing * (_heatmapWeeks - 1);
                    final canvasHeight = cellSize * _heatmapDaysPerWeek +
                        spacing * (_heatmapDaysPerWeek - 1);

                    final canvasWidget = RepaintBoundary(
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: CustomPaint(
                          painter: _MoodHeatmapPainter(
                            bitmapsByYear: bitmapsByYear,
                            gridStartDate: gridStartDate,
                            anchorDate: normalizedAnchor,
                            selectedDate: normalizedSelected,
                            cellSize: cellSize,
                            cellSpacing: spacing,
                            colorScheme: colorScheme,
                            brightness: theme.brightness,
                          ),
                        ),
                      ),
                    );

                    if (onSelectDate == null) {
                      return Center(child: canvasWidget);
                    }

                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final pitch = cellSize + spacing;
                          final col = details.localPosition.dx ~/ pitch;
                          final row = details.localPosition.dy ~/ pitch;
                          if (col < 0 ||
                              col >= _heatmapWeeks ||
                              row < 0 ||
                              row >= _heatmapDaysPerWeek) {
                            return;
                          }
                          final tappedDate = DateTime(
                            gridStartDate.year,
                            gridStartDate.month,
                            gridStartDate.day + col * _heatmapDaysPerWeek + row,
                          );
                          if (!tappedDate.isAfter(normalizedAnchor)) {
                            onSelectDate!(tappedDate);
                          }
                        },
                        child: canvasWidget,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapStatBadge extends StatelessWidget {
  const _HeatmapStatBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.status,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 3,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _MoodHeatmapPainter extends CustomPainter {
  _MoodHeatmapPainter({
    required this.bitmapsByYear,
    required this.gridStartDate,
    required this.anchorDate,
    required this.selectedDate,
    required this.cellSize,
    required this.cellSpacing,
    required this.colorScheme,
    required this.brightness,
  });

  final Map<int, MoodYearBitmap> bitmapsByYear;
  final DateTime gridStartDate;
  final DateTime anchorDate;
  final DateTime? selectedDate;
  final double cellSize;
  final double cellSpacing;
  final ColorScheme colorScheme;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final emptyColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final futureColor = emptyColor.withValues(alpha: 0.25);
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final selectedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = colorScheme.onSurface;
    final cellRadius = Radius.circular(cellSize >= 16 ? 4.0 : 3.0);
    final pitch = cellSize + cellSpacing;

    var cursor = gridStartDate;
    for (var col = 0; col < _heatmapWeeks; col += 1) {
      final dx = col * pitch;
      for (var row = 0; row < _heatmapDaysPerWeek; row += 1) {
        final dy = row * pitch;
        final rect = Rect.fromLTWH(dx, dy, cellSize, cellSize);
        final rrect = RRect.fromRectAndRadius(rect, cellRadius);

        if (cursor.isAfter(anchorDate)) {
          fillPaint.color = futureColor;
        } else {
          final bitmap = bitmapsByYear[cursor.year];
          if (bitmap != null && bitmap.hasEntry(cursor)) {
            final score = bitmap.moodScore(cursor);
            if (score != null) {
              fillPaint.color = heatmapMoodColor(score);
            } else {
              final count = bitmap.entryCount(cursor);
              final alpha = switch (count) {
                >= 3 => 0.95,
                2 => 0.72,
                _ => 0.48,
              };
              fillPaint.color = colorScheme.primary.withValues(alpha: alpha);
            }
          } else {
            fillPaint.color = emptyColor;
          }
        }

        canvas.drawRRect(rrect, fillPaint);

        if (selectedDate != null &&
            cursor.year == selectedDate!.year &&
            cursor.month == selectedDate!.month &&
            cursor.day == selectedDate!.day) {
          canvas.drawRRect(rrect, selectedPaint);
        }

        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoodHeatmapPainter oldDelegate) {
    return !identical(oldDelegate.bitmapsByYear, bitmapsByYear) ||
        oldDelegate.anchorDate != anchorDate ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.brightness != brightness ||
        oldDelegate.colorScheme.primary != colorScheme.primary;
  }
}

Color heatmapMoodColor(int moodScore) {
  return switch (moodScore) {
    1 => const Color(0xFFEF4444),
    2 => const Color(0xFFF97316),
    3 => const Color(0xFFEAB308),
    4 => const Color(0xFF0284C7),
    5 => const Color(0xFF5C6BC0),
    _ => const Color(0xFF5C6BC0),
  };
}

DateTime _computeGridStartDate(DateTime anchorDate) {
  final sundayOffset =
      anchorDate.weekday == DateTime.sunday ? 0 : anchorDate.weekday;
  final totalBackDays = (_heatmapWeeks - 1) * _heatmapDaysPerWeek + sundayOffset;
  return DateTime(
    anchorDate.year,
    anchorDate.month,
    anchorDate.day - totalBackDays,
  );
}

({int recordedDays, int streakDays, double? averageMood}) _summarizeWindow({
  required Map<int, MoodYearBitmap> bitmapsByYear,
  required DateTime gridStartDate,
  required DateTime anchorDate,
}) {
  var recorded = 0;
  var moodSum = 0;
  var moodDays = 0;

  var cursor = gridStartDate;
  for (var i = 0; i < _heatmapWindowDays; i += 1) {
    if (cursor.isAfter(anchorDate)) {
      break;
    }
    final bitmap = bitmapsByYear[cursor.year];
    if (bitmap != null && bitmap.hasEntry(cursor)) {
      recorded += 1;
      final score = bitmap.moodScore(cursor);
      if (score != null) {
        moodSum += score;
        moodDays += 1;
      }
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }

  final streak = _computeActiveStreakAcrossYears(bitmapsByYear, anchorDate);

  return (
    recordedDays: recorded,
    streakDays: streak,
    averageMood: moodDays == 0 ? null : moodSum / moodDays,
  );
}

int _computeActiveStreakAcrossYears(
  Map<int, MoodYearBitmap> bitmapsByYear,
  DateTime anchorDate,
) {
  var cursor = anchorDate;
  final todayBitmap = bitmapsByYear[cursor.year];
  if (todayBitmap == null || !todayBitmap.hasEntry(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }

  var streak = 0;
  while (true) {
    final bitmap = bitmapsByYear[cursor.year];
    if (bitmap == null) {
      break;
    }
    final dayIdx = dayOfYearIndex(cursor.year, cursor.month, cursor.day);
    final part = bitmap.currentStreakAt(dayIdx);
    if (part == 0) {
      break;
    }
    streak += part;
    if (part <= dayIdx) {
      break;
    }
    cursor = DateTime(cursor.year - 1, 12, 31);
  }
  return streak;
}
