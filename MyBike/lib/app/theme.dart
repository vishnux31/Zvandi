import 'package:flutter/material.dart';
import 'colors.dart';

/// MyBike visual theme: custom high-contrast dark telemetry theme.
class AppTheme {
  static ThemeData light() => _build();
  static ThemeData dark() => _build();

  static ThemeData _build() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryOrange,
      secondary: AppColors.safeGreen,
      tertiary: AppColors.warningAmber,
      surface: AppColors.surfacePanel,
      surfaceContainerHighest: AppColors.surfaceLight,
      onPrimary: AppColors.onPrimaryText,
      onSecondary: AppColors.darkBlack,
      onTertiary: AppColors.darkBlack,
      onSurface: Color(0xFFE5E2E1),
      onSurfaceVariant: AppColors.labelZinc,
      outline: AppColors.subtextZinc,
      outlineVariant: AppColors.outlineGray,
      error: AppColors.dangerRed,
      onError: Color(0xFF690005),
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 44,
        height: 52 / 44,
        letterSpacing: -1.0,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 32 / 24,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 26 / 20,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 16,
        height: 24 / 16,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
        height: 20 / 14,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 1.0,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 10,
        height: 14 / 10,
        letterSpacing: 1.5,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.darkBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBlack,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
