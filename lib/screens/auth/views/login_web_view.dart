import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_brand_logo.dart';
import '../widgets/login_backdrop.dart';
import '../widgets/login_form_card.dart';

/// LoginWebView is the wide-screen split layout: a sage brand panel
/// on the left and the shared login form on a soft mint panel on the right.
class LoginWebView extends StatelessWidget {
  final Widget form;

  const LoginWebView({
    super.key,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Brand Panel
        Expanded(
          flex: 5,
          child: _buildBrandPanel(),
        ),

        // Form Panel
        Expanded(
          flex: 4,
          child: _buildFormPanel(),
        ),
      ],
    );
  }

  /// Soft mint backdrop for the card: corner glows, a faint dot pattern
  /// and a footer line.
  Widget _buildFormPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.offWhite, AppColors.pureWhite],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -140, right: -140, child: LoginBackdrop.glow(420, AppColors.mint, 0.9)),
          Positioned(bottom: -160, left: -120, child: LoginBackdrop.glow(400, AppColors.sageSoft, 0.4)),
          const Positioned.fill(child: CustomPaint(painter: DotPatternPainter())),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 72),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LoginFormCard.maxWidth),
                child: form,
              ),
            ),
          ),

          // Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: LoginBackdrop.footer(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.brandGradient),
      child: Stack(
        children: [
          // Decorative Rings
          Positioned(
            top: -140,
            left: -140,
            child: _ring(420),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: _ring(480),
          ),

          // Soft Center Glow
          Center(
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Brand: Logo, Name & Tagline
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppBrandLogo(size: 120, onDark: true),
                  const SizedBox(height: 18),
                  Text(
                    'Luxury Residences & Smart Living',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Text(
              'Trusted Homes • Verified Listings',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textMutedDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5),
      ),
    );
  }
}
