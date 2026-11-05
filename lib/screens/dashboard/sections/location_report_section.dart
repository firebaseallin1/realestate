import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../widgets/location_sales_chart.dart';
import '../widgets/report_table.dart';

/// LocationReportSection: one row per location with its sites and unit
/// totals, plus the sales-by-location chart. Tapping a city in the chart
/// opens that city's sites.
class LocationReportSection extends StatelessWidget {
  final SiteController controller;
  final ValueChanged<String> onOpenLocation;

  const LocationReportSection({
    super.key,
    required this.controller,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = controller.locationSummaries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportTable(
          minWidth: 680,
          columns: const [
            ReportColumn('Location', flex: 2),
            ReportColumn('Sites', numeric: true),
            ReportColumn('Total', numeric: true),
            ReportColumn('Sold', numeric: true),
            ReportColumn('Booked', numeric: true),
            ReportColumn('Available', numeric: true),
            ReportColumn('Sold %', flex: 1.1, numeric: true),
          ],
          rows: [
            for (final s in summaries)
              [
                ReportTable.text(s.name, bold: true),
                ReportTable.text('${s.siteCount}'),
                ReportTable.text('${s.totalUnits}'),
                ReportTable.text('${s.soldUnits}'),
                ReportTable.text('${s.bookedUnits}'),
                ReportTable.text('${s.availableUnits}'),
                ReportTable.percent(s.soldRatio),
              ],
          ],
          totals: summaries.isEmpty
              ? null
              : [
                  ReportTable.text('All locations', bold: true),
                  ReportTable.text('${controller.sites.length}', bold: true),
                  ReportTable.text('${controller.totalUnits}', bold: true),
                  ReportTable.text('${controller.soldUnits}', bold: true),
                  ReportTable.text('${controller.bookedUnits}', bold: true),
                  ReportTable.text('${controller.availableUnits}', bold: true),
                  ReportTable.percent(controller.soldRatio, bold: true),
                ],
        ),
        const SizedBox(height: 14),
        LocationSalesChart(controller: controller, onOpenLocation: onOpenLocation),
      ],
    );
  }
}
