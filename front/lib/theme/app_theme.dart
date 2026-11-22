// Light Sky-Blue & Dark Slate-Periwinkle Material and surface theme tokens.
import 'package:flutter/material.dart';

import '../shared/ui/brand_identity.dart';
import '../shared/ui/shad_primitives.dart';

export '../shared/ui/shad_primitives.dart';

ThemeData buildAppTheme() {
  return _buildTheme();
}

ThemeData buildDarkAppTheme() {
  return _buildDarkTheme();
}

ShadThemeData buildMaumShadThemeData(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark
      ? const ShadColorScheme(
          background: Color(0xFF18191D),
          foreground: Color(0xFFF8F9FA),
          card: Color(0xFF212529),
          cardForeground: Color(0xFFF8F9FA),
          popover: Color(0xFF2A2E33),
          popoverForeground: Color(0xFFF8F9FA),
          primary: Color(0xFF8E9CE6),
          primaryForeground: Color(0xFF141824),
          secondary: Color(0xFF2A2E33),
          secondaryForeground: Color(0xFFF8F9FA),
          muted: Color(0xFF2A2E33),
          mutedForeground: Color(0xFFADB5BD),
          accent: Color(0xFF283054),
          accentForeground: Color(0xFFE2E7FF),
          destructive: Color(0xFFEF4444),
          destructiveForeground: Color(0xFFF8F9FA),
          border: Color(0xFF343A40),
          input: Color(0xFF343A40),
          ring: Color(0xFF8E9CE6),
          selection: Color(0xFF355172),
        )
      : const ShadColorScheme(
          background: AppBrandColors.backgroundBlue,
          foreground: Color(0xFF1E293B),
          card: AppBrandColors.surface,
          cardForeground: Color(0xFF1E293B),
          popover: AppBrandColors.surface,
          popoverForeground: Color(0xFF1E293B),
          primary: AppBrandColors.primaryBlue,
          primaryForeground: Colors.white,
          secondary: Color(0xFFEAF3FF),
          secondaryForeground: Color(0xFF1F3150),
          muted: AppBrandColors.surfaceStrong,
          mutedForeground: AppBrandColors.mutedForeground,
          accent: Color(0xFFDCEBFF),
          accentForeground: Color(0xFF1F3150),
          destructive: Color(0xFFDC2626),
          destructiveForeground: Colors.white,
          border: AppBrandColors.borderSoft,
          input: AppBrandColors.borderSoft,
          ring: AppBrandColors.primaryBlue,
          selection: Color(0xFFB4D7FF),
        );

  final cardRadius = BorderRadius.circular(16);
  final cardShadows = [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.28)
          : AppBrandColors.primaryBlue.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  return ShadThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    radius: cardRadius,
    cardTheme: ShadCardTheme(
      backgroundColor: colorScheme.card,
      padding: const EdgeInsets.all(16),
      radius: cardRadius,
      border: ShadBorder.all(color: colorScheme.border, width: 1),
      shadows: cardShadows,
    ),
    primaryBadgeTheme: ShadBadgeTheme(
      backgroundColor: colorScheme.primary,
      hoverBackgroundColor: colorScheme.primary.withValues(alpha: 0.88),
      foregroundColor: colorScheme.primaryForeground,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    secondaryBadgeTheme: ShadBadgeTheme(
      backgroundColor: colorScheme.secondary,
      hoverBackgroundColor: colorScheme.secondary.withValues(alpha: 0.88),
      foregroundColor: colorScheme.secondaryForeground,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    outlineBadgeTheme: ShadBadgeTheme(
      foregroundColor: colorScheme.foreground,
      shape: StadiumBorder(side: BorderSide(color: colorScheme.border)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    destructiveBadgeTheme: ShadBadgeTheme(
      backgroundColor: colorScheme.destructive,
      hoverBackgroundColor: colorScheme.destructive.withValues(alpha: 0.88),
      foregroundColor: colorScheme.destructiveForeground,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
  );
}

class MaumShadThemeScope extends StatelessWidget {
  const MaumShadThemeScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final existing = ShadTheme.maybeOf(context);
    final brightness = Theme.of(context).brightness;
    if (existing != null && existing.brightness == brightness) {
      return child;
    }

    return ShadTheme(
      data: buildMaumShadThemeData(brightness),
      child: child,
    );
  }
}

ThemeData _buildTheme() {
  final baseColorScheme = ColorScheme.fromSeed(
    seedColor: AppBrandColors.primaryBlue,
    brightness: Brightness.light,
  );
  final colorScheme = baseColorScheme.copyWith(
    primary: AppBrandColors.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppBrandColors.iconBlue,
    onSecondary: Colors.white,
    primaryContainer: const Color(0xFFDCEBFF),
    onPrimaryContainer: const Color(0xFF1F3150),
    secondaryContainer: const Color(0xFFEAF6FF),
    onSecondaryContainer: const Color(0xFF1F3150),
    surface: AppBrandColors.surface,
    onSurface: AppBrandColors.foreground,
    surfaceContainerHighest: AppBrandColors.surfaceStrong,
    onSurfaceVariant: AppBrandColors.mutedForeground,
    outlineVariant: AppBrandColors.borderSoft,
  );
  final textTheme = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.18,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.22,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, height: 1.35),
    labelLarge: TextStyle(
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
  ).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppBrandColors.backgroundBlue,
    textTheme: textTheme,
    dividerColor: colorScheme.outlineVariant,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppBrandColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppBrandColors.borderSoft),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppBrandColors.surface,
      border: inputBorder,
      enabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final baseColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8E9CE6),
    brightness: Brightness.dark,
  );
  final colorScheme = baseColorScheme.copyWith(
    primary: const Color(0xFF8E9CE6),
    onPrimary: const Color(0xFF141824),
    primaryContainer: const Color(0xFF283054),
    onPrimaryContainer: const Color(0xFFE2E7FF),
    secondary: const Color(0xFF8E9CE6),
    onSecondary: const Color(0xFF141824),
    secondaryContainer: const Color(0xFF253042),
    onSecondaryContainer: const Color(0xFFDCEBFF),
    tertiaryContainer: const Color(0xFF3A2E1E),
    onTertiaryContainer: const Color(0xFFFDE68A),
    surface: const Color(0xFF212529),
    onSurface: const Color(0xFFF8F9FA),
    surfaceContainerHighest: const Color(0xFF2A2E33),
    onSurfaceVariant: const Color(0xFFADB5BD),
    outline: const Color(0xFF495057),
    outlineVariant: const Color(0xFF343A40),
  );
  final textTheme = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.18,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.22,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, height: 1.35),
    labelLarge: TextStyle(
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
  ).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF18191D),
    textTheme: textTheme,
    dividerColor: colorScheme.outlineVariant,
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF212529),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF343A40)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF212529),
      border: inputBorder,
      enabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
