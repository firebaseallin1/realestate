import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/hero_banner.dart';
import '../widgets/location_sales_chart.dart';
import '../widgets/top_sites_list.dart';

/// OverviewSection: portfolio sales strip, key stats, sales by location and the
/// top-selling sites. [wide] places the two panels side by side.
class OverviewSection extends StatelessWidget {
  final SiteController controller;
  final bool wide;
  final ValueChanged<String> onOpenLocation;
  final VoidCallback onViewAllSites;

  const OverviewSection({
    super.key,
    required this.controller,
    required this.wide,
    required this.onOpenLocation,
    required this.onViewAllSites,
  });

  @override
  Widget build(BuildContext context) {
    final chart = LocationSalesChart(controller: controller, onOpenLocation: onOpenLocation);
    final topSites = TopSitesList(controller: controller, onViewAll: onViewAllSites);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroBanner(controller: controller, wide: wide),
        SizedBox(height: wide ? 16 : 12),
        DashboardStats(controller: controller, columns: wide ? 4 : 2),
        SizedBox(height: wide ? 16 : 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: chart),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: topSites),
            ],
          )
        else ...[
          chart,
          const SizedBox(height: 12),
          topSites,
        ],
      ],
    );
  }
}
