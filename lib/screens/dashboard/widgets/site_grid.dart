import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/site.dart';
import 'report_table.dart';
import 'site_card.dart';

/// SiteGrid lays out site cards in as many columns as fit the width
/// (one column on phones), or an empty state when nothing matches.
class SiteGrid extends StatelessWidget {
  final List<Site> sites;
  final ValueChanged<Site> onEdit;
  final ValueChanged<Site> onDelete;
  final ValueChanged<Site> onOpenLayout;

  const SiteGrid({
    super.key,
    required this.sites,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenLayout,
  });

  static const double _minCardWidth = 320;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const _EmptySites();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minCardWidth + _gap)).floor());
        final cardWidth = (constraints.maxWidth - _gap * (columns - 1)) / columns;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final site in sites)
              SizedBox(
                width: cardWidth,
                child: SiteCard(
                  key: ValueKey(site.id),
                  site: site,
                  onEdit: () => onEdit(site),
                  onDelete: () => onDelete(site),
                  onOpenLayout: () => onOpenLayout(site),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// SiteTable shows the same sites as [SiteGrid], one row each, with the
/// site's actions at the end of the row.
class SiteTable extends StatelessWidget {
  final List<Site> sites;
  final ValueChanged<Site> onEdit;
  final ValueChanged<Site> onDelete;
  final ValueChanged<Site> onOpenLayout;

  const SiteTable({
    super.key,
    required this.sites,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenLayout,
  });

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const _EmptySites();

    return ReportTable(
      minWidth: 1180,
      columns: const [
        ReportColumn('Site', flex: 2.2),
        ReportColumn('Location', flex: 1.2),
        ReportColumn('Owner', flex: 1.4),
        ReportColumn('Type', flex: 1.1),
        ReportColumn('Status', flex: 1.1),
        ReportColumn('Area (sq yd)', flex: 1.1, numeric: true),
        ReportColumn('Units', flex: 0.7, numeric: true),
        ReportColumn('Sold', flex: 0.7, numeric: true),
        ReportColumn('Booked', flex: 0.8, numeric: true),
        ReportColumn('Available', flex: 0.9, numeric: true),
        ReportColumn('Sold %', flex: 0.9, numeric: true),
        ReportColumn('', flex: 0.6, numeric: true),
      ],
      rowKeys: [for (final site in sites) ValueKey('site-row-${site.id}')],
      rows: [
        for (final site in sites)
          [
            ReportTable.text(site.name, bold: true),
            ReportTable.text(site.location),
            ReportTable.text(site.ownerName.isEmpty ? ReportTable.blank : site.ownerName),
            ReportTable.text(site.type.label),
            ReportTable.pill(site.status.label, siteStatusColor(site.status)),
            ReportTable.text(site.totalArea > 0 ? MoneyText.grouped(site.totalArea) : ReportTable.blank),
            ReportTable.text('${site.totalUnits}'),
            ReportTable.text('${site.soldUnits}'),
            ReportTable.text('${site.bookedUnits}'),
            ReportTable.text('${site.availableUnits}'),
            ReportTable.percent(site.soldRatio),
            SiteActionsMenu(
              iconColor: AppColors.textSecondaryLight,
              onOpenLayout: () => onOpenLayout(site),
              onEdit: () => onEdit(site),
              onDelete: () => onDelete(site),
            ),
          ],
      ],
    );
  }
}

class _EmptySites extends StatelessWidget {
  const _EmptySites();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMutedLight),
          const SizedBox(height: 12),
          Text(
            'No sites found',
            style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 4),
          Text(
            'Try another location or search, or add a new site.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
          ),
        ],
      ),
    );
  }
}
