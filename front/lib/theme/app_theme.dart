import 'package:flutter/material.dart';

import '../shared/ui/brand_identity.dart';

ThemeData buildAppTheme() {
  return _buildTheme(Brightness.light);
}

ThemeData buildDarkAppTheme() {
  return _buildTheme(Brightness.dark);
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final baseColorScheme = ColorScheme.fromSeed(
    seedColor: AppBrandColors.primaryBlue,
    brightness: brightness,
  );
  final colorScheme = baseColorScheme.copyWith(
    primary: AppBrandColors.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppBrandColors.iconBlue,
    onSecondary: Colors.white,
    primaryContainer:
        isDark ? const Color(0xFF244C79) : const Color(0xFFDCEBFF),
    onPrimaryContainer:
        isDark ? const Color(0xFFDCEBFF) : const Color(0xFF1F3150),
    secondaryContainer:
        isDark ? const Color(0xFF164557) : const Color(0xFFEAF6FF),
    onSecondaryContainer:
        isDark ? const Color(0xFFEAF6FF) : const Color(0xFF1F3150),
    surface: isDark ? AppBrandColors.darkSurfaceBlue : AppBrandColors.surface,
    onSurface: isDark ? const Color(0xFFE8EEF8) : AppBrandColors.foreground,
    surfaceContainerHighest: isDark
        ? AppBrandColors.darkSurfaceStrongBlue
        : AppBrandColors.surfaceStrong,
    onSurfaceVariant: isDark
        ? AppBrandColors.darkMutedForeground
        : AppBrandColors.mutedForeground,
    outlineVariant:
        isDark ? AppBrandColors.darkBorderBlue : AppBrandColors.borderSoft,
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
    borderRadius: BorderRadius.circular(8),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? AppBrandColors.darkBackgroundBlue
        : AppBrandColors.backgroundBlue,
    textTheme: textTheme,
    dividerColor: colorScheme.outlineVariant,
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppBrandColors.darkSurfaceBlue : AppBrandColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark
              ? AppBrandColors.darkBorderBlue
              : AppBrandColors.borderSoft,
        ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF12304B) : AppBrandColors.surface,
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
          borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(8),
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
