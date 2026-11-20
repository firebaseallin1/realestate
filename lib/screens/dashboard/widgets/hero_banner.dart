import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'inventory_donut.dart';

/// HeroBanner is the slim sage "Portfolio Sales" strip at the top of the
/// dashboard: a sold / booked / available donut, the share sold, and the
/// unit figures. (Greeting, date and user live in the top bar.)
/// [wide] lays the figures out in one row beside the summary.
class HeroBanner extends StatelessWidget {
  final SiteController controller;
  final bool wide;

  const HeroBanner({
    super.key,
    required this.controller,
    required this.wide,
  });

  /// Below this width the figures wrap under the summary, even on web.
  static const double _oneRowMinWidth = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildBanner(wide && constraints.maxWidth >= _oneRowMinWidth),
    );
  }

  Widget _buildBanner(bool oneRow) {
    final donut = InventoryDonut(
      size: oneRow ? 68 : 60,
      strokeWidth: oneRow ? 8 : 7,
      trackColor: Colors.white.withValues(alpha: 0.08),
      segments: [
        DonutSegment(controller.soldUnits.toDouble(), AppColors.pureWhite),
        DonutSegment(controller.bookedUnits.toDouble(), AppColors.accentGoldLight),
        DonutSegment(controller.availableUnits.toDouble(), AppColors.primaryLight),
      ],
      center: Text(
        '${(controller.soldRatio * 100).round()}%',
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PORTFOLIO SALES',
          style: AppTypography.caption.copyWith(
            color: AppColors.mint,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${controller.soldUnits} of ${controller.totalUnits} units sold',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.pureWhite,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${controller.sites.length} sites across ${controller.locations.length} locations',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
      ],
    );

    final figures = Wrap(
      spacing: oneRow ? 32 : 20,
      runSpacing: 10,
      children: [
        _Figure(color: AppColors.pureWhite, label: 'Sold', value: controller.soldUnits),
        _Figure(color: AppColors.accentGoldLight, label: 'Booked', value: controller.bookedUnits),
        _Figure(color: AppColors.primaryLight, label: 'Available', value: controller.availableUnits),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandDeep, AppColors.brandDark, Color.lerp(AppColors.brandDark, AppColors.sageMid, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative ring
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1.5),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: oneRow ? 18 : 14, vertical: oneRow ? 12 : 12),
            child: oneRow
                ? Row(
                    children: [
                      donut,
                      const SizedBox(width: 14),
                      Expanded(child: summary),
                      const SizedBox(width: 14),
                      figures,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          donut,
                          const SizedBox(width: 16),
                          Expanded(child: summary),
                        ],
                      ),
                      const SizedBox(height: 14),
                      figures,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _Figure({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$value ',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: label,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
