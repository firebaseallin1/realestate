import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// AppBrandLogo renders the Kaira Properties emblem with the stacked
/// wordmark: a bold sage "KAIRA" over a wide-tracked "PROPERTIES".
/// Set [onDark] when placing it on a dark sage background.
class AppBrandLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const AppBrandLogo({super.key, this.size = 96, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final scale = size / 96;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Emblem
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: onDark ? AppColors.brandSoftGradient : AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: onDark ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2) : null,
            boxShadow: [
              BoxShadow(
                color: onDark ? Colors.black.withValues(alpha: 0.3) : AppColors.brandDark.withValues(alpha: 0.28),
                blurRadius: 32 * scale,
                offset: Offset(0, 12 * scale),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.roofing_rounded, size: size * 0.42, color: Colors.white),
              Positioned(
                bottom: size * 0.2,
                child: Icon(Icons.vpn_key_rounded, size: size * 0.2, color: AppColors.accentGoldLight),
              ),
            ],
          ),
        ),
        SizedBox(height: 22 * scale),

        // Wordmark
        Text(
          'KAIRA',
          style: AppTypography.displayLarge.copyWith(
            fontSize: 34 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 6 * scale,
            color: onDark ? AppColors.pureWhite : AppColors.brandDark,
          ),
        ),
        SizedBox(height: 4 * scale),
        ShaderMask(
          shaderCallback: (bounds) =>
              (onDark ? const LinearGradient(colors: [AppColors.pureWhite, AppColors.mint]) : AppColors.brandGradient)
                  .createShader(bounds),
          child: Text(
            'PROPERTIES',
            style: AppTypography.labelMedium.copyWith(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 6 * scale,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// AppBrandInline is the compact one-line brand for headers and top bars:
/// a small emblem tile followed by the "KAIRA PROPERTIES" wordmark.
/// Set [onDark] when placing it on a dark sage background, and
/// [showWordmark] to false for the emblem alone.
class AppBrandInline extends StatelessWidget {
  final double size;
  final bool onDark;
  final bool showWordmark;

  const AppBrandInline({super.key, this.size = 40, this.onDark = false, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: onDark ? AppColors.brandSoftGradient : AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: onDark ? Border.all(color: Colors.white.withValues(alpha: 0.18)) : null,
          ),
          child: Icon(Icons.roofing_rounded, size: size * 0.55, color: Colors.white),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          // Shrinks rather than overflows in tight spots (e.g. the sidebar
          // while it animates open).
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KAIRA',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      height: 1.1,
                      color: onDark ? AppColors.pureWhite : AppColors.brandDark,
                    ),
                  ),
                  Text(
                    'PROPERTIES',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: onDark ? AppColors.mint : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
