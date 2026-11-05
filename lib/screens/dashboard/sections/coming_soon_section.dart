import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/dashboard_section.dart';

/// ComingSoonSection holds the place of a menu page that is not built
/// yet, so every role's menu is complete today.
class ComingSoonSection extends StatelessWidget {
  final DashboardSection section;

  const ComingSoonSection({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(section.icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            '${section.label} is coming soon',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              '${section.subtitle} will be managed here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }
}
