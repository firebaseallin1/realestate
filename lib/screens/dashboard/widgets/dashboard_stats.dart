import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';

/// DashboardStats shows the portfolio totals as stat cards, laid out in
/// rows of [columns] (2 on mobile, 4 on web).
class DashboardStats extends StatelessWidget {
  final SiteController controller;
  final int columns;

  const DashboardStats({
    super.key,
    required this.controller,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = controller.countWithStatus(SiteStatus.upcoming);

    final cards = [
      StatCard(
        icon: Icons.domain_rounded,
        color: AppColors.primary,
        label: 'Total Sites',
        value: '${controller.sites.length}',
        caption: '${controller.countWithStatus(SiteStatus.completed)} completed',
      ),
      StatCard(
        icon: Icons.location_city_rounded,
        color: AppColors.primaryBright,
        label: 'Locations',
        value: '${controller.locations.length}',
        caption: 'Cities managed',
      ),
      StatCard(
        icon: Icons.bolt_rounded,
        color: AppColors.success,
        label: 'Active Projects',
        value: '${controller.countWithStatus(SiteStatus.active)}',
        caption: '$upcoming upcoming ${upcoming == 1 ? 'launch' : 'launches'}',
      ),
      StatCard(
        icon: Icons.grid_view_rounded,
        color: AppColors.accentGold,
        label: 'Total Units',
        value: '${controller.totalUnits}',
        caption: '${controller.availableUnits} still available',
      ),
    ];

    return StatCardGrid(columns: columns, cards: cards);
  }
}

/// StatCardGrid lays [cards] out in equal-height rows of [columns].
class StatCardGrid extends StatelessWidget {
  final int columns;
  final List<Widget> cards;

  const StatCardGrid({
    super.key,
    required this.columns,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += columns) {
      final rowCards = cards.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < rowCards.length; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(child: rowCards[j]),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}

/// StatCard is a single white metric tile with a tinted icon and a
/// colored accent along its left edge.
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;

  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft corner glow in the card's color
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, size: 17, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppTypography.displayMedium.copyWith(color: AppColors.textPrimaryLight),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
