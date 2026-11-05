import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// LocationFilterBar is a horizontally scrolling row of location pills
/// ("All" plus each city with its site count) that filters the site list.
class LocationFilterBar extends StatelessWidget {
  final SiteController controller;

  const LocationFilterBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LocationPill(
            label: 'All Locations',
            count: controller.sites.length,
            selected: controller.selectedLocation == null,
            onTap: () => controller.selectLocation(null),
          ),
          for (final location in controller.locations) ...[
            const SizedBox(width: 8),
            _LocationPill(
              label: location,
              count: controller.siteCountAt(location),
              selected: controller.selectedLocation == location,
              onTap: () => controller.selectLocation(location),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _LocationPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.pureWhite : AppColors.textPrimaryLight;

    return Material(
      color: selected ? AppColors.brandDark : AppColors.pureWhite,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.brandDark : AppColors.lightBorder),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
