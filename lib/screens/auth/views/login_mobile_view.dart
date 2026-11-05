import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_brand_logo.dart';
import '../widgets/login_backdrop.dart';
import '../widgets/login_form_card.dart';

/// LoginMobileView is the phone layout: a curved sage header with the
/// white logo and tagline, the shared login card overlapping its edge,
/// a faint dot pattern behind, and the footer line at the bottom.
class LoginMobileView extends StatelessWidget {
  final Widget form;

  const LoginMobileView({super.key, required this.form});

  /// Height of the sage header below the status bar.
  static const double _headerHeight = 300;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    // Light status bar icons over the sage header.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: ColoredBox(
        color: AppColors.offWhite,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              // Fill the screen so the dots and footer reach the bottom.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: DotPatternPainter())),
                  Positioned(top: 0, left: 0, right: 0, height: _headerHeight + topInset, child: const _SageHeader()),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 40, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: LoginFormCard.maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Brand: Logo & Name on the sage header
                            const Center(child: AppBrandLogo(size: 76, onDark: true)),
                            const SizedBox(height: 12),
                            Text(
                              'Luxury Residences & Smart Living',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 28),

                            form,
                            const SizedBox(height: 28),
                            LoginBackdrop.footer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sage gradient header with a curved bottom edge, rings and a glow.
class _SageHeader extends StatelessWidget {
  const _SageHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDeep, AppColors.sage],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(color: AppColors.brandDark.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: LoginBackdrop.ring(240)),
          Positioned(bottom: -120, left: -80, child: LoginBackdrop.ring(260)),
          Positioned(top: 40, left: -60, child: LoginBackdrop.glow(260, AppColors.sageMid, 0.45)),
        ],
      ),
    );
  }
}
