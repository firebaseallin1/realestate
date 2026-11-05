import 'package:flutter/material.dart';

/// AppColors defines the central color palette for the Real Estate application.
/// A calm sage green & white aesthetic built on four palette tones:
/// #5C7057 (sage), #89A482 (mid sage), #ACC5A6 (soft sage), #D1EDD3 (mint).
class AppColors {
  AppColors._();

  // --- Sage Palette (source tones) ---
  static const Color sage = Color(0xFF5C7057);             // Deep sage — main brand color
  static const Color sageMid = Color(0xFF89A482);          // Mid sage
  static const Color sageSoft = Color(0xFFACC5A6);         // Soft sage
  static const Color mint = Color(0xFFD1EDD3);             // Pale mint

  // --- Signature Sage & White Core ---
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F9F4);         // White with a hint of mint
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static const Color whiteBorder = Color(0xFFE0EADD);

  // --- Brand Shades (backgrounds, panels, buttons with white text) ---
  static const Color brandDark = sage;                       // Main brand fill
  static const Color brandDeep = Color(0xFF4A5C46);          // Deeper sage for gradients
  static const Color brandSurface = Color(0xFF677D62);       // Elevated sage surface
  static const Color brandCard = Color(0xFF738B6D);          // Card background in dark mode
  static const Color brandBorder = sageMid;                  // Sage border
  static const Color brandBorderLight = Color(0x33FFFFFF);   // Translucent white on sage

  // --- Theme Aliases (for seamless system compatibility) ---
  static const Color darkBackground = brandDark;
  static const Color darkSurface = brandSurface;
  static const Color darkSurfaceVariant = brandCard;
  static const Color darkCard = brandCard;
  static const Color darkBorder = brandBorderLight;
  static const Color darkBorderFocused = pureWhite;

  static const Color lightBackground = pureWhite;
  static const Color lightSurface = pureWhite;
  static const Color lightSurfaceVariant = offWhite;
  static const Color lightCard = pureWhite;
  static const Color lightBorder = whiteBorder;
  static const Color lightBorderFocused = brandDark;

  // --- Primary Brand Colors ---
  static const Color primary = sage;                       // Readable on white
  static const Color primaryBright = sageMid;              // Icons, bars, decoration
  static const Color primaryLight = sageSoft;              // Soft fills, glows, cursor
  static const Color primaryGlow = Color(0x405C7057);      // Subtle sage shadow

  // --- Accent & Feature Colors ---
  static const Color accentGold = Color(0xFFD4A24C);       // Warm earthy gold
  static const Color accentGoldLight = Color(0xFFE9C46A);

  // --- Typography: On Sage (White & Mint) ---
  static const Color textPrimaryDark = Color(0xFFFFFFFF);   // Pure crisp white
  static const Color textSecondaryDark = Color(0xFFEEF6EC); // Soft mint white
  static const Color textMutedDark = mint;                  // Pale mint
  static const Color textDisabledDark = sageSoft;

  // --- Typography: On White (Deep Green-Grey) ---
  static const Color textPrimaryLight = Color(0xFF2E3A2B);  // Deep green-grey text
  static const Color textSecondaryLight = Color(0xFF52604E); // Muted green-grey
  static const Color textMutedLight = Color(0xFF8A9786);

  // --- Status & Feedback Colors ---
  static const Color success = Color(0xFF3F8F5A);
  static const Color successBg = Color(0x1A3F8F5A);
  static const Color error = Color(0xFFD9534F);
  static const Color errorBg = Color(0x1AD9534F);
  static const Color warning = Color(0xFFD4A24C);
  static const Color warningBg = Color(0x1AD4A24C);
  static const Color info = Color(0xFF6B9AA8);

  // --- Gradients (Sage and White harmony) ---
  /// Deep sage gradient — safe under white text (buttons, banners, panels).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandDeep, sage],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sage to mid sage — decorative fills and logo tiles.
  static const LinearGradient brandSoftGradient = LinearGradient(
    colors: [sage, sageMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = brandSoftGradient;

  static const LinearGradient cardDarkGradient = LinearGradient(
    colors: [brandSurface, brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = cardDarkGradient;

  static const LinearGradient whiteCardGradient = LinearGradient(
    colors: [pureWhite, offWhite],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [brandDark, brandDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
