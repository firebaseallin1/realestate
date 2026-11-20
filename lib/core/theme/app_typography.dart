import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_options.dart';

/// AppTypography provides typography styles for headers, subheadings,
/// body copy, button labels, and captions, set in the font chosen in Settings > Text.
/// Sizes are kept compact so screens fit more without crowding.
class AppTypography {
  AppTypography._();

  /// The font an Admin picked in Settings > Text; null uses the device's font.
  static String? get fontFamily => AppFont.current.family;

  // Headings
  static TextStyle get displayLarge => TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.textPrimaryDark,
    height: 1.2,
  );

  static TextStyle get displayMedium => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryDark,
    height: 1.25,
  );

  static TextStyle get displaySmall => TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimaryDark,
    height: 1.3,
  );

  // Titles
  static TextStyle get titleLarge => TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimaryDark,
    height: 1.35,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryDark,
    height: 1.4,
  );

  static TextStyle get titleSmall => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryDark,
    height: 1.4,
  );

  // Body
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryDark,
    height: 1.4,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryDark,
    height: 1.4,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMutedDark,
    height: 1.35,
  );

  // Labels & Buttons
  static TextStyle get buttonLarge => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: Colors.white,
  );

  static TextStyle get buttonMedium => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  static TextStyle get labelMedium =>
      TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryDark);

  static TextStyle get caption =>
      TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMutedDark);
}
