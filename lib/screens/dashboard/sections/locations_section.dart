import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/list_table_switcher.dart';
import '../../../models/site.dart';
import '../../../widgets/location_map.dart';
import '../widgets/location_card.dart';
import '../widgets/report_table.dart';

/// LocationsSection: one card per city, as many per row as fit, or a table.
/// Tapping a card or row opens that city's sites.
class LocationsSection extends StatelessWidget {
  final SiteController controller;
  final ValueChanged<String> onOpenLocation;

  /// Sets a location's map point; null when the user may not change it.
  final ValueChanged<String>? onSetPoint;

  const LocationsSection({
    super.key,
    required this.controller,
    required this.onOpenLocation,
    this.onSetPoint,
  });

  static const double _minCardWidth = 300;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final summaries = controller.locationSummaries;

    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'No locations yet. Add a site to create one.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedLight),
        ),
      );
    }

    return ListTableSwitcher(
      id: 'locations',
      list: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minCardWidth + _gap)).floor());
          final cardWidth = (constraints.maxWidth - _gap * (columns - 1)) / columns;

          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final summary in summaries)
                SizedBox(
                  width: cardWidth,
                  child: LocationCard(
                    key: ValueKey(summary.name),
                    summary: summary,
                    onOpen: () => onOpenLocation(summary.name),
                    onSetPoint: onSetPoint == null ? null : () => onSetPoint!(summary.name),
                  ),
                ),
            ],
          );
        },
      ),
      table: (_) => ReportTable(
        minWidth: 820,
        columns: const [
          ReportColumn('Location', flex: 1.6),
          ReportColumn('Types', flex: 2),
          ReportColumn('Sites', flex: 0.7, numeric: true),
          ReportColumn('Units', flex: 0.8, numeric: true),
          ReportColumn('Sold', flex: 0.8, numeric: true),
          ReportColumn('Booked', flex: 0.8, numeric: true),
          ReportColumn('Available', flex: 0.9, numeric: true),
          ReportColumn('Sold %', flex: 0.9, numeric: true),
          ReportColumn('Map', flex: 1.1),
        ],
        rowKeys: [for (final s in summaries) ValueKey('location-row-${s.name}')],
        onRowTap: (i) => onOpenLocation(summaries[i].name),
        rows: [
          for (final s in summaries)
            [
              ReportTable.text(s.name, bold: true),
              ReportTable.text(s.types.isEmpty ? ReportTable.blank : s.types.map((t) => t.label).join(', ')),
              ReportTable.text('${s.siteCount}'),
              ReportTable.text('${s.totalUnits}'),
              ReportTable.text('${s.soldUnits}'),
              ReportTable.text('${s.bookedUnits}'),
              ReportTable.text('${s.availableUnits}'),
              ReportTable.percent(s.soldRatio),
              s.point == null
                  ? ReportTable.text(ReportTable.blank)
                  : _MapLink(name: s.name, point: s.point!),
            ],
        ],
      ),
    );
  }
}

/// "View" in the table's Map column, opening the location on the map.
class _MapLink extends StatelessWidget {
  final String name;
  final MapPoint point;

  const _MapLink({required this.name, required this.point});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showLocationOnMap(context, name: name, point: point),
        icon: const Icon(Icons.map_outlined, size: 16),
        label: const Text('View'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
