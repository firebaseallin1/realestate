import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/location_filter_bar.dart';
import '../widgets/report_table.dart';
import '../widgets/site_card.dart';

/// InventoryReportSection: site-wise unit inventory (total, sold, booked,
/// available, sold %) for all locations or the one picked in the filter,
/// with summary tiles and a totals row.
class InventoryReportSection extends StatelessWidget {
  final SiteController controller;
  final bool wide;

  const InventoryReportSection({
    super.key,
    required this.controller,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final sites = controller.sitesIn(controller.selectedLocation);
    final total = sites.fold(0, (sum, s) => sum + s.totalUnits);
    final sold = sites.fold(0, (sum, s) => sum + s.soldUnits);
    final booked = sites.fold(0, (sum, s) => sum + s.bookedUnits);
    final available = sites.fold(0, (sum, s) => sum + s.availableUnits);
    final soldRatio = total == 0 ? 0.0 : sold / total;

    final tiles = [
      StatCard(
        icon: Icons.grid_view_rounded,
        color: AppColors.primary,
        label: 'Total Units',
        value: '$total',
        caption: '${sites.length} ${sites.length == 1 ? 'site' : 'sites'}',
      ),
      StatCard(
        icon: Icons.sell_rounded,
        color: AppColors.primaryBright,
        label: 'Sold',
        value: '$sold',
        caption: '${(soldRatio * 100).round()}% of units',
      ),
      StatCard(
        icon: Icons.bookmark_added_rounded,
        color: AppColors.accentGold,
        label: 'Booked',
        value: '$booked',
        caption: 'Awaiting sale',
      ),
      StatCard(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        label: 'Available',
        value: '$available',
        caption: 'Ready to sell',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocationFilterBar(controller: controller),
        const SizedBox(height: 12),
        _TileGrid(tiles: tiles, columns: wide ? 4 : 2),
        const SizedBox(height: 12),
        ReportTable(
          minWidth: 860,
          columns: const [
            ReportColumn('Site', flex: 2.4),
            ReportColumn('Location', flex: 1.3),
            ReportColumn('Type', flex: 1.2),
            ReportColumn('Status', flex: 1.2),
            ReportColumn('Total', numeric: true),
            ReportColumn('Sold', numeric: true),
            ReportColumn('Booked', numeric: true),
            ReportColumn('Available', numeric: true),
            ReportColumn('Sold %', flex: 1.1, numeric: true),
          ],
          rows: [
            for (final site in sites)
              [
                ReportTable.text(site.name, bold: true),
                ReportTable.text(site.location, color: AppColors.textSecondaryLight),
                ReportTable.text(site.type.label, color: AppColors.textSecondaryLight),
                ReportTable.pill(site.status.label, siteStatusColor(site.status)),
                ReportTable.text('${site.totalUnits}'),
                ReportTable.text('${site.soldUnits}'),
                ReportTable.text('${site.bookedUnits}'),
                ReportTable.text('${site.availableUnits}'),
                ReportTable.percent(site.soldRatio),
              ],
          ],
          totals: sites.isEmpty
              ? null
              : [
                  ReportTable.text('Total', bold: true),
                  ReportTable.text(controller.selectedLocation ?? 'All locations', bold: true),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  ReportTable.text('$total', bold: true),
                  ReportTable.text('$sold', bold: true),
                  ReportTable.text('$booked', bold: true),
                  ReportTable.text('$available', bold: true),
                  ReportTable.percent(soldRatio, bold: true),
                ],
        ),
      ],
    );
  }
}

/// Lays stat tiles out in rows of [columns].
class _TileGrid extends StatelessWidget {
  final List<Widget> tiles;
  final int columns;

  const _TileGrid({required this.tiles, required this.columns});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns && j < tiles.length; j++) ...[
                  if (j > i) const SizedBox(width: 14),
                  Expanded(child: tiles[j]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
