import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'dashboard_panel.dart';
import 'site_card.dart';

/// TopSitesList ranks the best-selling sites with their sold progress.
class TopSitesList extends StatelessWidget {
  final SiteController controller;
  final VoidCallback onViewAll;

  const TopSitesList({
    super.key,
    required this.controller,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final sites = controller.topSites();

    return DashboardPanel(
      title: 'Top Performing Sites',
      subtitle: 'Ranked by share of units sold',
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text(
          'View all',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sites.length; i++) ...[
            if (i > 0) Divider(height: 14, color: AppColors.lightBorder),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: siteTypeGradient(sites[i].type),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(sites[i].type.icon, size: 20, color: AppColors.pureWhite),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sites[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
                      ),
                      Text(
                        '${sites[i].location} • ${sites[i].type.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(sites[i].soldRatio * 100).round()}%',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sites[i].soldRatio,
                          minHeight: 5,
                          backgroundColor: AppColors.lightSurfaceVariant,
                          valueColor: AlwaysStoppedAnimation(siteStatusColor(sites[i].status)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
