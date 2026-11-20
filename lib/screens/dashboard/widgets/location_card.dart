import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';
import '../../../widgets/location_map.dart';
import 'site_card.dart';

/// LocationCard summarises one city: a coloured banner with its name, how
/// its units split between sold, booked and available, the kinds of projects
/// there, and where it is on the map. Tapping it opens that city's sites.
class LocationCard extends StatelessWidget {
  final LocationSummary summary;
  final VoidCallback onOpen;

  /// Chooses or changes the map spot; null hides the option.
  final VoidCallback? onSetPoint;

  const LocationCard({super.key, required this.summary, required this.onOpen, this.onSetPoint});

  @override
  Widget build(BuildContext context) {
    final point = summary.point;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.brandDark.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Banner(summary: summary),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UnitSplit(summary: summary),
                      const SizedBox(height: 14),
                      _Types(summary: summary),
                      if (point != null) ...[
                        const SizedBox(height: 14),
                        LocationMapPreview(
                          point: point,
                          height: 110,
                          onTap: () => showLocationOnMap(context, name: summary.name, point: point),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.lightBorder),
                _Footer(summary: summary, onOpen: onOpen, onSetPoint: onSetPoint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand-coloured header: city name, site count and how much is sold.
class _Banner extends StatelessWidget {
  final LocationSummary summary;

  const _Banner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final sold = (summary.soldRatio * 100).round();
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sage, Color.lerp(AppColors.sage, AppColors.sageMid, 0.65)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Soft circles and a faded skyline give the banner some depth.
          Positioned(right: 70, top: -40, child: _Circle(size: 90, alpha: 0.08)),
          Positioned(left: -30, bottom: -50, child: _Circle(size: 110, alpha: 0.06)),
          Positioned(
            right: -14,
            bottom: -22,
            child: Icon(Icons.location_city_rounded, size: 120, color: AppColors.pureWhite.withValues(alpha: 0.09)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.pureWhite.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.location_city_rounded, color: AppColors.pureWhite),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.siteCount} ${summary.siteCount == 1 ? 'site' : 'sites'} · '
                        '${summary.totalUnits} units',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.pureWhite.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.pureWhite, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '$sold% sold',
                    style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One bar split into sold, booked and available, with a tile for each.
class _UnitSplit extends StatelessWidget {
  final LocationSummary summary;

  const _UnitSplit({required this.summary});

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Sold', summary.soldUnits, SiteCard.soldColor),
      ('Booked', summary.bookedUnits, SiteCard.bookedColor),
      ('Available', summary.availableUnits, SiteCard.availableColor),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: summary.totalUnits == 0
                ? Container(color: AppColors.lightSurfaceVariant)
                : Row(
                    children: [
                      for (final (_, count, color) in parts)
                        if (count > 0)
                          Expanded(
                            flex: count,
                            child: Container(color: color),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            children: [
              for (final (index, (label, count, color)) in parts.indexed) ...[
                if (index > 0) VerticalDivider(width: 20, thickness: 1, color: AppColors.lightBorder),
                Expanded(
                  child: _StatTile(label: label, value: count, color: color),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The kinds of projects in the city.
class _Types extends StatelessWidget {
  final LocationSummary summary;

  const _Types({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.types.isEmpty) {
      return Text(
        'No sites yet — add one from the Sites menu.',
        style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in summary.types)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon, size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  type.label,
                  style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Where the city is (or a button to set it), and a link to its sites.
class _Footer extends StatelessWidget {
  final LocationSummary summary;
  final VoidCallback onOpen;
  final VoidCallback? onSetPoint;

  const _Footer({required this.summary, required this.onOpen, required this.onSetPoint});

  @override
  Widget build(BuildContext context) {
    final point = summary.point;
    final compact = TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      textStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          if (point != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.place_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                point.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
              ),
            ),
            if (onSetPoint != null) TextButton(onPressed: onSetPoint, style: compact, child: const Text('Change')),
          ] else ...[
            if (onSetPoint != null)
              TextButton.icon(
                onPressed: onSetPoint,
                style: compact,
                icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                label: const Text('Set on map'),
              ),
            const Spacer(),
          ],
          TextButton(
            onPressed: onOpen,
            style: compact,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('View Sites'), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 16)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double alpha;

  const _Circle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.pureWhite.withValues(alpha: alpha),
    ),
  );
}
