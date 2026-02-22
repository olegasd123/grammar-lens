import 'package:flutter/material.dart';

import 'package:grammarlens_ui/src/theme/app_colors.dart';
import 'package:grammarlens_ui/src/theme/app_typography.dart';

/// GrammarLens Material 3 theme configuration.
abstract final class AppTheme {
  /// Light theme.
  static ThemeData light() {
    const controlColor = AppColors.primaryLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: controlColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: controlColor,
      onPrimary: Colors.white,
      secondary: controlColor,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  /// Dark theme.
  static ThemeData dark() {
    const controlColor = AppColors.primaryLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: controlColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: controlColor,
      onPrimary: Colors.white,
      secondary: controlColor,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurface,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: colorScheme.onSurface,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppColors.darkTextTertiary,
        ),
      ),
    );
  }
}
