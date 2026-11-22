// Canonical semantic surface, status, and 5-stage mood color tokens.
import 'package:flutter/material.dart';

import '../shared/ui/brand_identity.dart';

@immutable
class MaumTokens extends ThemeExtension<MaumTokens> {
  const MaumTokens({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.elevatedSurface,
    required this.foreground,
    required this.mutedForeground,
    required this.primary,
    required this.onPrimary,
    required this.border,
    required this.softTint,
    required this.codeBlockBackground,
    required this.codeBlockBorder,
    required this.statusSuccessBg,
    required this.statusSuccessFg,
    required this.statusSuccessDot,
    required this.statusWarningBg,
    required this.statusWarningFg,
    required this.statusWarningDot,
    required this.statusDangerBg,
    required this.statusDangerFg,
    required this.statusDangerDot,
    required this.statusInfoBg,
    required this.statusInfoFg,
    required this.statusNeutralBg,
    required this.statusNeutralFg,
    required this.statusNeutralDot,
    required this.quickActionSkyBg,
    required this.quickActionSkyFg,
    required this.quickActionBlueBg,
    required this.quickActionBlueFg,
  });

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color elevatedSurface;
  final Color foreground;
  final Color mutedForeground;
  final Color primary;
  final Color onPrimary;
  final Color border;
  final Color softTint;
  final Color codeBlockBackground;
  final Color codeBlockBorder;

  final Color statusSuccessBg;
  final Color statusSuccessFg;
  final Color statusSuccessDot;
  final Color statusWarningBg;
  final Color statusWarningFg;
  final Color statusWarningDot;
  final Color statusDangerBg;
  final Color statusDangerFg;
  final Color statusDangerDot;
  final Color statusInfoBg;
  final Color statusInfoFg;
  final Color statusNeutralBg;
  final Color statusNeutralFg;
  final Color statusNeutralDot;

  final Color quickActionSkyBg;
  final Color quickActionSkyFg;
  final Color quickActionBlueBg;
  final Color quickActionBlueFg;

  static Color moodBackground(int score) {
    return switch (score) {
      1 => const Color(0xFFDC2626),
      2 => const Color(0xFFC2410C),
      3 => const Color(0xFFEAB308),
      4 => const Color(0xFF0369A1),
      5 => AppBrandColors.primaryBlue,
      _ => AppBrandColors.primaryBlue,
    };
  }

  static Color moodForeground(int score) {
    return switch (score) {
      3 => const Color(0xFF1E293B),
      _ => Colors.white,
    };
  }

  static Color moodColor(int score) => moodBackground(score);

  static String moodLabel(int score) {
    return switch (score) {
      1 => '매우 힘듦',
      2 => '지침',
      3 => '보통',
      4 => '좋음',
      5 => '매우 좋음',
      _ => '보통',
    };
  }

  static const MaumTokens light = MaumTokens(
    background: AppBrandColors.backgroundBlue,
    surface: AppBrandColors.surface,
    surfaceStrong: AppBrandColors.surfaceStrong,
    elevatedSurface: AppBrandColors.backgroundBlue,
    foreground: AppBrandColors.foreground,
    mutedForeground: AppBrandColors.mutedForeground,
    primary: AppBrandColors.primaryBlue,
    onPrimary: Colors.white,
    border: AppBrandColors.borderSoft,
    softTint: AppBrandColors.backgroundBlue,
    codeBlockBackground: Color(0xFFEFF6FF),
    codeBlockBorder: AppBrandColors.borderSoft,
    statusSuccessBg: Color(0xFFDCFCE7),
    statusSuccessFg: Color(0xFF166534),
    statusSuccessDot: Color(0xFF16A34A),
    statusWarningBg: Color(0xFFFEF3C7),
    statusWarningFg: Color(0xFF92400E),
    statusWarningDot: Color(0xFFD97706),
    statusDangerBg: Color(0xFFFEE2E2),
    statusDangerFg: Color(0xFF991B1B),
    statusDangerDot: Color(0xFFDC2626),
    statusInfoBg: Color(0xFFEAF6FF),
    statusInfoFg: Color(0xFF1F3150),
    statusNeutralBg: Color(0xFFF1F5F9),
    statusNeutralFg: Color(0xFF334155),
    statusNeutralDot: Color(0xFF64748B),
    quickActionSkyBg: Color(0xFFEAF6FF),
    quickActionSkyFg: Color(0xFF1F4D72),
    quickActionBlueBg: Color(0xFFE8F1FF),
    quickActionBlueFg: Color(0xFF244C8A),
  );

  static const MaumTokens dark = MaumTokens(
    background: Color(0xFF18191D),
    surface: Color(0xFF212529),
    surfaceStrong: Color(0xFF2A2E33),
    elevatedSurface: Color(0xFF2A2E33),
    foreground: Color(0xFFF8F9FA),
    mutedForeground: Color(0xFFADB5BD),
    primary: Color(0xFF8E9CE6),
    onPrimary: Color(0xFF141824),
    border: Color(0xFF343A40),
    softTint: Color(0xFF283054),
    codeBlockBackground: Color(0xFF18191D),
    codeBlockBorder: Color(0xFF343A40),
    statusSuccessBg: Color(0xFF143524),
    statusSuccessFg: Color(0xFF86EFAC),
    statusSuccessDot: Color(0xFF4ADE80),
    statusWarningBg: Color(0xFF3A2E1E),
    statusWarningFg: Color(0xFFFDE68A),
    statusWarningDot: Color(0xFFFBBF24),
    statusDangerBg: Color(0xFF3B1B22),
    statusDangerFg: Color(0xFFFECACA),
    statusDangerDot: Color(0xFFF87171),
    statusInfoBg: Color(0xFF253042),
    statusInfoFg: Color(0xFFDCEBFF),
    statusNeutralBg: Color(0xFF2A2E33),
    statusNeutralFg: Color(0xFFADB5BD),
    statusNeutralDot: Color(0xFFADB5BD),
    quickActionSkyBg: Color(0xFF163547),
    quickActionSkyFg: Color(0xFFBAE6FD),
    quickActionBlueBg: Color(0xFF1A2F4F),
    quickActionBlueFg: Color(0xFFBFDBFE),
  );

  @override
  MaumTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceStrong,
    Color? elevatedSurface,
    Color? foreground,
    Color? mutedForeground,
    Color? primary,
    Color? onPrimary,
    Color? border,
    Color? softTint,
    Color? codeBlockBackground,
    Color? codeBlockBorder,
    Color? statusSuccessBg,
    Color? statusSuccessFg,
    Color? statusSuccessDot,
    Color? statusWarningBg,
    Color? statusWarningFg,
    Color? statusWarningDot,
    Color? statusDangerBg,
    Color? statusDangerFg,
    Color? statusDangerDot,
    Color? statusInfoBg,
    Color? statusInfoFg,
    Color? statusNeutralBg,
    Color? statusNeutralFg,
    Color? statusNeutralDot,
    Color? quickActionSkyBg,
    Color? quickActionSkyFg,
    Color? quickActionBlueBg,
    Color? quickActionBlueFg,
  }) {
    return MaumTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      border: border ?? this.border,
      softTint: softTint ?? this.softTint,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      codeBlockBorder: codeBlockBorder ?? this.codeBlockBorder,
      statusSuccessBg: statusSuccessBg ?? this.statusSuccessBg,
      statusSuccessFg: statusSuccessFg ?? this.statusSuccessFg,
      statusSuccessDot: statusSuccessDot ?? this.statusSuccessDot,
      statusWarningBg: statusWarningBg ?? this.statusWarningBg,
      statusWarningFg: statusWarningFg ?? this.statusWarningFg,
      statusWarningDot: statusWarningDot ?? this.statusWarningDot,
      statusDangerBg: statusDangerBg ?? this.statusDangerBg,
      statusDangerFg: statusDangerFg ?? this.statusDangerFg,
      statusDangerDot: statusDangerDot ?? this.statusDangerDot,
      statusInfoBg: statusInfoBg ?? this.statusInfoBg,
      statusInfoFg: statusInfoFg ?? this.statusInfoFg,
      statusNeutralBg: statusNeutralBg ?? this.statusNeutralBg,
      statusNeutralFg: statusNeutralFg ?? this.statusNeutralFg,
      statusNeutralDot: statusNeutralDot ?? this.statusNeutralDot,
      quickActionSkyBg: quickActionSkyBg ?? this.quickActionSkyBg,
      quickActionSkyFg: quickActionSkyFg ?? this.quickActionSkyFg,
      quickActionBlueBg: quickActionBlueBg ?? this.quickActionBlueBg,
      quickActionBlueFg: quickActionBlueFg ?? this.quickActionBlueFg,
    );
  }

  @override
  MaumTokens lerp(covariant ThemeExtension<MaumTokens>? other, double t) {
    if (other is! MaumTokens) {
      return this;
    }
    return MaumTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceStrong:
          Color.lerp(surfaceStrong, other.surfaceStrong, t) ?? surfaceStrong,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t) ??
          elevatedSurface,
      foreground: Color.lerp(foreground, other.foreground, t) ?? foreground,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t) ??
          mutedForeground,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      border: Color.lerp(border, other.border, t) ?? border,
      softTint: Color.lerp(softTint, other.softTint, t) ?? softTint,
      codeBlockBackground:
          Color.lerp(codeBlockBackground, other.codeBlockBackground, t) ??
              codeBlockBackground,
      codeBlockBorder: Color.lerp(codeBlockBorder, other.codeBlockBorder, t) ??
          codeBlockBorder,
      statusSuccessBg: Color.lerp(statusSuccessBg, other.statusSuccessBg, t) ??
          statusSuccessBg,
      statusSuccessFg: Color.lerp(statusSuccessFg, other.statusSuccessFg, t) ??
          statusSuccessFg,
      statusSuccessDot:
          Color.lerp(statusSuccessDot, other.statusSuccessDot, t) ??
              statusSuccessDot,
      statusWarningBg: Color.lerp(statusWarningBg, other.statusWarningBg, t) ??
          statusWarningBg,
      statusWarningFg: Color.lerp(statusWarningFg, other.statusWarningFg, t) ??
          statusWarningFg,
      statusWarningDot:
          Color.lerp(statusWarningDot, other.statusWarningDot, t) ??
              statusWarningDot,
      statusDangerBg:
          Color.lerp(statusDangerBg, other.statusDangerBg, t) ?? statusDangerBg,
      statusDangerFg:
          Color.lerp(statusDangerFg, other.statusDangerFg, t) ?? statusDangerFg,
      statusDangerDot: Color.lerp(statusDangerDot, other.statusDangerDot, t) ??
          statusDangerDot,
      statusInfoBg:
          Color.lerp(statusInfoBg, other.statusInfoBg, t) ?? statusInfoBg,
      statusInfoFg:
          Color.lerp(statusInfoFg, other.statusInfoFg, t) ?? statusInfoFg,
      statusNeutralBg: Color.lerp(statusNeutralBg, other.statusNeutralBg, t) ??
          statusNeutralBg,
      statusNeutralFg: Color.lerp(statusNeutralFg, other.statusNeutralFg, t) ??
          statusNeutralFg,
      statusNeutralDot:
          Color.lerp(statusNeutralDot, other.statusNeutralDot, t) ??
              statusNeutralDot,
      quickActionSkyBg:
          Color.lerp(quickActionSkyBg, other.quickActionSkyBg, t) ??
              quickActionSkyBg,
      quickActionSkyFg:
          Color.lerp(quickActionSkyFg, other.quickActionSkyFg, t) ??
              quickActionSkyFg,
      quickActionBlueBg:
          Color.lerp(quickActionBlueBg, other.quickActionBlueBg, t) ??
              quickActionBlueBg,
      quickActionBlueFg:
          Color.lerp(quickActionBlueFg, other.quickActionBlueFg, t) ??
              quickActionBlueFg,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MaumTokens &&
        other.background == background &&
        other.surface == surface &&
        other.surfaceStrong == surfaceStrong &&
        other.elevatedSurface == elevatedSurface &&
        other.foreground == foreground &&
        other.mutedForeground == mutedForeground &&
        other.primary == primary &&
        other.onPrimary == onPrimary &&
        other.border == border &&
        other.softTint == softTint &&
        other.codeBlockBackground == codeBlockBackground &&
        other.codeBlockBorder == codeBlockBorder &&
        other.statusSuccessBg == statusSuccessBg &&
        other.statusSuccessFg == statusSuccessFg &&
        other.statusSuccessDot == statusSuccessDot &&
        other.statusWarningBg == statusWarningBg &&
        other.statusWarningFg == statusWarningFg &&
        other.statusWarningDot == statusWarningDot &&
        other.statusDangerBg == statusDangerBg &&
        other.statusDangerFg == statusDangerFg &&
        other.statusDangerDot == statusDangerDot &&
        other.statusInfoBg == statusInfoBg &&
        other.statusInfoFg == statusInfoFg &&
        other.statusNeutralBg == statusNeutralBg &&
        other.statusNeutralFg == statusNeutralFg &&
        other.statusNeutralDot == statusNeutralDot &&
        other.quickActionSkyBg == quickActionSkyBg &&
        other.quickActionSkyFg == quickActionSkyFg &&
        other.quickActionBlueBg == quickActionBlueBg &&
        other.quickActionBlueFg == quickActionBlueFg;
  }

  @override
  int get hashCode => Object.hashAll([
        background,
        surface,
        surfaceStrong,
        elevatedSurface,
        foreground,
        mutedForeground,
        primary,
        onPrimary,
        border,
        softTint,
        codeBlockBackground,
        codeBlockBorder,
        statusSuccessBg,
        statusSuccessFg,
        statusSuccessDot,
        statusWarningBg,
        statusWarningFg,
        statusWarningDot,
        statusDangerBg,
        statusDangerFg,
        statusDangerDot,
        statusInfoBg,
        statusInfoFg,
        statusNeutralBg,
        statusNeutralFg,
        statusNeutralDot,
        quickActionSkyBg,
        quickActionSkyFg,
        quickActionBlueBg,
        quickActionBlueFg,
      ]);
}

extension MaumTokensBuildContext on BuildContext {
  MaumTokens get maumTokens {
    final theme = Theme.of(this);
    return theme.extension<MaumTokens>() ??
        (theme.brightness == Brightness.dark
            ? MaumTokens.dark
            : MaumTokens.light);
  }
}
