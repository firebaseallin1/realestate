import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Decorative pieces shared by the mobile and web login layouts.
class LoginBackdrop {
  LoginBackdrop._();

  /// A soft round glow of [color], fading out to the edge.
  static Widget glow(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  /// A thin translucent ring, for sage panels.
  static Widget ring(double size, {double alpha = 0.07}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: alpha), width: 1.5),
      ),
    );
  }

  /// "© 2026 Kaira Properties. All rights reserved."
  static Widget footer() {
    return Text(
      '© ${DateTime.now().year} Kaira Properties. All rights reserved.',
      textAlign: TextAlign.center,
      style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
    );
  }
}

/// Faint sage dot grid behind the login card.
class DotPatternPainter extends CustomPainter {
  const DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.sageSoft.withValues(alpha: 0.35);
    const step = 24.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
