import 'package:flutter/material.dart';

import 'app_palette.dart';

/// AppColors defines the central color palette for the Real Estate application.
///
/// Brand colours come from the theme an Admin picks ([AppPalette]). They are
/// getters, so widgets pick up a new theme the next time they build. White,
/// gold and the status colours are the same in every theme.
class AppColors {
  AppColors._();

  static AppPalette get _p => AppPalette.current;

  // --- Brand palette (named after the original sage theme) ---
  static Color get sage => _p.primary; // Main brand color
  static Color get sageMid => _p.mid;
  static Color get sageSoft => _p.soft;
  static Color get mint => _p.pale; // Palest brand tint

  // --- White Core ---
  static const Color pureWhite = Color(0xFFFFFFFF);
  static Color get offWhite => _p.offWhite; // White with a hint of the brand
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static Color get whiteBorder => _p.border;

  // --- Brand Shades (backgrounds, panels, buttons with white text) ---
  static Color get brandDark => _p.primary;
  static Color get brandDeep => _p.deep;
  static Color get brandSurface => _p.surface;
  static Color get brandCard => _p.card;
  static Color get brandBorder => _p.mid;
  static const Color brandBorderLight = Color(0x33FFFFFF); // Translucent white on brand

  // --- Theme Aliases (for seamless system compatibility) ---
  static Color get darkBackground => brandDark;
  static Color get darkSurface => brandSurface;
  static Color get darkSurfaceVariant => brandCard;
  static Color get darkCard => brandCard;
  static const Color darkBorder = brandBorderLight;
  static const Color darkBorderFocused = pureWhite;

  static const Color lightBackground = pureWhite;
  static const Color lightSurface = pureWhite;
  static Color get lightSurfaceVariant => offWhite;
  static const Color lightCard = pureWhite;
  static Color get lightBorder => whiteBorder;
  static Color get lightBorderFocused => brandDark;

  // --- Primary Brand Colors ---
  static Color get primary => _p.primary; // Readable on white
  static Color get primaryBright => _p.mid; // Icons, bars, decoration
  static Color get primaryLight => _p.soft; // Soft fills, glows, cursor
  static Color get primaryGlow => _p.primary.withValues(alpha: 0.25); // Subtle shadow

  // --- Accent & Feature Colors ---
  static const Color accentGold = Color(0xFFD4A24C); // Warm earthy gold
  static const Color accentGoldLight = Color(0xFFE9C46A);

  // --- Typography: On Brand (White & Pale) ---
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static Color get textSecondaryDark => Color.lerp(pureWhite, _p.pale, 0.4)!;
  static Color get textMutedDark => _p.pale;
  static Color get textDisabledDark => _p.soft;

  // --- Typography: On White ---
  static Color get textPrimaryLight => _p.text;
  static Color get textSecondaryLight => _p.textSecondary;
  static Color get textMutedLight => _p.textMuted;

  // --- Status & Feedback Colors ---
  static const Color success = Color(0xFF3F8F5A);
  static const Color successBg = Color(0x1A3F8F5A);
  static const Color error = Color(0xFFD9534F);
  static const Color errorBg = Color(0x1AD9534F);
  static const Color warning = Color(0xFFD4A24C);
  static const Color warningBg = Color(0x1AD4A24C);
  static const Color info = Color(0xFF6B9AA8);

  // --- Gradients ---
  /// Deep brand gradient — safe under white text (buttons, banners, panels).
  static LinearGradient get brandGradient =>
      LinearGradient(colors: [brandDeep, sage], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Brand to mid brand — decorative fills and logo tiles.
  static LinearGradient get brandSoftGradient =>
      LinearGradient(colors: [sage, sageMid], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static LinearGradient get primaryGradient => brandSoftGradient;

  static LinearGradient get cardDarkGradient =>
      LinearGradient(colors: [brandSurface, brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static LinearGradient get darkCardGradient => cardDarkGradient;

  static LinearGradient get whiteCardGradient =>
      LinearGradient(colors: [pureWhite, offWhite], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static LinearGradient get splashGradient =>
      LinearGradient(colors: [brandDark, brandDeep], begin: Alignment.topCenter, end: Alignment.bottomCenter);
}
