import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'dashboard_panel.dart';
import 'site_card.dart';

/// LocationSalesChart compares locations with one stacked bar each
/// (sold / booked / available units). Tapping a row opens that location.
class LocationSalesChart extends StatelessWidget {
  final SiteController controller;
  final ValueChanged<String> onOpenLocation;

  const LocationSalesChart({
    super.key,
    required this.controller,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = controller.locationSummaries
      ..sort((a, b) => b.totalUnits.compareTo(a.totalUnits));

    return DashboardPanel(
      title: 'Sales by Location',
      subtitle: 'Unit inventory per city • tap a city to open it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: SiteCard.soldColor, label: 'Sold'),
              _Legend(color: SiteCard.bookedColor, label: 'Booked'),
              _Legend(color: SiteCard.availableColor, label: 'Available'),
            ],
          ),
          const SizedBox(height: 6),
          if (summaries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No locations yet.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
              ),
            ),
          for (final summary in summaries)
            InkWell(
              onTap: () => onOpenLocation(summary.name),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.name,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Text(
                          '${summary.soldUnits}/${summary.totalUnits} sold',
                          style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(summary.soldRatio * 100).round()}%',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StackedBar(
                      sold: summary.soldUnits,
                      booked: summary.bookedUnits,
                      available: summary.availableUnits,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final int sold;
  final int booked;
  final int available;

  const _StackedBar({
    required this.sold,
    required this.booked,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: sold + booked + available == 0
            ? Container(color: AppColors.lightSurfaceVariant)
            : Row(
                children: [
                  if (sold > 0) Expanded(flex: sold, child: Container(color: SiteCard.soldColor)),
                  if (booked > 0) Expanded(flex: booked, child: Container(color: SiteCard.bookedColor)),
                  if (available > 0)
                    Expanded(flex: available, child: Container(color: SiteCard.availableColor)),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight)),
      ],
    );
  }
}
