import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';
import 'site_card.dart';

/// LocationCard summarises one city: its sites, units, sold progress and
/// the kinds of projects there. Tapping it opens that city's sites.
class LocationCard extends StatelessWidget {
  final LocationSummary summary;
  final VoidCallback onOpen;

  const LocationCard({
    super.key,
    required this.summary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pureWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.location_city_rounded, color: AppColors.pureWhite),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${summary.siteCount} ${summary.siteCount == 1 ? 'site' : 'sites'}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.textMutedLight),
                ],
              ),
              const SizedBox(height: 12),

              // Figures
              Row(
                children: [
                  _Metric(label: 'Units', value: summary.totalUnits),
                  _Metric(label: 'Sold', value: summary.soldUnits),
                  _Metric(label: 'Booked', value: summary.bookedUnits),
                  _Metric(label: 'Available', value: summary.availableUnits),
                ],
              ),
              const SizedBox(height: 12),

              // Sold progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: summary.soldRatio,
                        minHeight: 8,
                        backgroundColor: AppColors.lightSurfaceVariant,
                        valueColor: const AlwaysStoppedAnimation(SiteCard.soldColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(summary.soldRatio * 100).round()}% sold',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Project types
              if (summary.types.isEmpty)
                Text(
                  'No sites yet — add one from the Sites menu.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in summary.types)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 13, color: AppColors.primary),
                            const SizedBox(width: 5),
                            Text(
                              type.label,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
          ),
        ],
      ),
    );
  }
}
