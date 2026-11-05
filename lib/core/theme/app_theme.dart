import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// AppTheme builds ThemeData for both Sage (Primary) and White modes.
class AppTheme {
  AppTheme._();

  /// Sage Theme - Deep sage canvas with crisp white typography and cards
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.brandDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBright,
        onPrimary: AppColors.pureWhite,
        primaryContainer: AppColors.brandSurface,
        onPrimaryContainer: AppColors.pureWhite,
        secondary: AppColors.primaryBright,
        onSecondary: AppColors.brandDark,
        tertiary: AppColors.accentGold,
        surface: AppColors.brandSurface,
        onSurface: AppColors.pureWhite,
        error: AppColors.error,
        onError: AppColors.pureWhite,
        outline: AppColors.brandBorderLight,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.titleLarge,
        iconTheme: IconThemeData(color: AppColors.pureWhite),
      ),
      cardTheme: CardThemeData(
        color: AppColors.brandCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.brandBorderLight, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.brandSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedDark),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.pureWhite),
        floatingLabelStyle: AppTypography.titleSmall.copyWith(color: AppColors.pureWhite),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandBorderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandBorderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.pureWhite, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pureWhite,
          foregroundColor: AppColors.brandDark,
          minimumSize: const Size.fromHeight(52),
          elevation: 2,
          shadowColor: AppColors.primaryGlow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.buttonLarge.copyWith(color: AppColors.brandDark),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pureWhite,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.pureWhite, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.pureWhite,
          textStyle: AppTypography.buttonMedium,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.brandBorderLight,
        thickness: 1,
        space: 24,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBright;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.pureWhite, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }

  /// White Theme - Clean pure white canvas with sage green accents
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.pureWhite,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandDark,
        onPrimary: AppColors.pureWhite,
        primaryContainer: AppColors.offWhite,
        onPrimaryContainer: AppColors.brandDark,
        secondary: AppColors.primaryBright,
        onSecondary: AppColors.pureWhite,
        tertiary: AppColors.accentGold,
        surface: AppColors.pureWhite,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
        onError: AppColors.pureWhite,
        outline: AppColors.whiteBorder,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
        iconTheme: IconThemeData(color: AppColors.brandDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.pureWhite,
        elevation: 2,
        shadowColor: AppColors.brandDark.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.whiteBorder, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.offWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedLight),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
        floatingLabelStyle: AppTypography.titleSmall.copyWith(color: AppColors.brandDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.whiteBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.whiteBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandDark, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandDark,
          foregroundColor: AppColors.pureWhite,
          minimumSize: const Size.fromHeight(52),
          elevation: 2,
          shadowColor: AppColors.primaryGlow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.buttonLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandDark,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.brandDark, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTypography.buttonLarge.copyWith(color: AppColors.brandDark),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandDark,
          textStyle: AppTypography.buttonMedium,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.whiteBorder,
        thickness: 1,
        space: 24,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandDark;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.brandDark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }
}
