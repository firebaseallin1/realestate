import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/site.dart';
import 'inventory_donut.dart';

/// Status colors shared by the site card and anywhere a status is shown.
Color siteStatusColor(SiteStatus status) {
  switch (status) {
    case SiteStatus.upcoming:
      return AppColors.accentGold;
    case SiteStatus.active:
      return AppColors.success;
    case SiteStatus.completed:
      return AppColors.primaryBright;
  }
}

/// Cover gradient for each site type, all within the sage family.
LinearGradient siteTypeGradient(SiteType type) {
  switch (type) {
    case SiteType.plots:
      return const LinearGradient(
        colors: [AppColors.brandDeep, AppColors.sage],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case SiteType.apartments:
      return const LinearGradient(
        colors: [AppColors.sage, Color(0xFF7A9573)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case SiteType.villas:
      return const LinearGradient(
        colors: [Color(0xFF52684D), Color(0xFF6E8F7A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case SiteType.commercial:
      return const LinearGradient(
        colors: [Color(0xFF3B4A38), AppColors.brandSurface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  }
}

/// SiteCard shows one site: a colored cover with type and status, then
/// name, location, owner, a sold-percentage ring and the unit figures.
/// Tags show the land areas, an attached map / brochure and the drawn plots. Plot layout,
/// edit and delete live in the cover's menu.
class SiteCard extends StatelessWidget {
  final Site site;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenLayout;

  const SiteCard({
    super.key,
    required this.site,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenLayout,
  });

  static const Color soldColor = AppColors.primary;
  static const Color bookedColor = AppColors.accentGold;
  static const Color availableColor = AppColors.sageSoft;

  static String _area(double area) => MoneyText.grouped(area);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCover(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMutedLight),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        site.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
                if (site.ownerName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textMutedLight),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          site.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ],
                // Land areas
                if (site.totalArea > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(icon: Icons.landscape_outlined, label: 'Total ${_area(site.totalArea)} sq yd'),
                      if (site.salesArea > 0) _Tag(icon: Icons.sell_outlined, label: 'Sales ${_area(site.salesArea)}'),
                      if (site.roadArea > 0) _Tag(icon: Icons.add_road_rounded, label: 'Road ${_area(site.roadArea)}'),
                      if (site.gardenArea > 0) _Tag(icon: Icons.park_outlined, label: 'Garden ${_area(site.gardenArea)}'),
                      if (site.otherArea > 0) _Tag(icon: Icons.category_outlined, label: 'Other ${_area(site.otherArea)}'),
                    ],
                  ),
                ],
                // Attachments and layout
                if (site.siteMap != null || site.brochure != null || site.hasLayout) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (site.hasLayout)
                        _Tag(
                          icon: Icons.grid_on_rounded,
                          label: '${site.plots.length} plots mapped',
                          onTap: onOpenLayout,
                        ),
                      if (site.siteMap != null)
                        _Tag(icon: Icons.map_outlined, label: 'Site map', onTap: onOpenLayout),
                      if (site.brochure != null)
                        const _Tag(icon: Icons.menu_book_outlined, label: 'Brochure'),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.lightBorder),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InventoryDonut(
                      size: 46,
                      strokeWidth: 6,
                      trackColor: AppColors.lightSurfaceVariant,
                      segments: [
                        DonutSegment(site.soldUnits.toDouble(), soldColor),
                        DonutSegment(site.bookedUnits.toDouble(), bookedColor),
                        DonutSegment(site.availableUnits.toDouble(), availableColor),
                      ],
                      center: Text(
                        '${(site.soldRatio * 100).round()}%',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    _Figure(label: 'Sold', value: site.soldUnits, color: soldColor),
                    _Figure(label: 'Booked', value: site.bookedUnits, color: bookedColor),
                    _Figure(label: 'Available', value: site.availableUnits, color: availableColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    final statusColor = siteStatusColor(site.status);

    return Container(
      height: 76,
      decoration: BoxDecoration(gradient: siteTypeGradient(site.type)),
      child: Stack(
        children: [
          // Large faded type icon
          Positioned(
            right: 14,
            bottom: -18,
            child: Icon(site.type.icon, size: 96, color: Colors.white.withValues(alpha: 0.1)),
          ),

          // Status chip
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    site.status.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Type label
          Positioned(
            left: 14,
            bottom: 12,
            child: Row(
              children: [
                Icon(site.type.icon, size: 16, color: AppColors.pureWhite),
                const SizedBox(width: 6),
                Text(
                  '${site.type.label} • ${site.totalUnits} units',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.pureWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Actions menu
          Positioned(
            right: 4,
            top: 4,
            child: SiteActionsMenu(
              iconColor: AppColors.pureWhite,
              onOpenLayout: onOpenLayout,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

/// The site's plot layout, edit and delete actions.
class SiteActionsMenu extends StatelessWidget {
  final Color iconColor;
  final VoidCallback onOpenLayout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SiteActionsMenu({
    super.key,
    required this.iconColor,
    required this.onOpenLayout,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Site actions',
      icon: Icon(Icons.more_horiz_rounded, color: iconColor),
      color: AppColors.pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'layout':
            onOpenLayout();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'layout',
          child: Row(
            children: [
              Icon(Icons.grid_on_rounded, size: 18, color: AppColors.textPrimaryLight),
              SizedBox(width: 10),
              Text('Plot layout'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimaryLight),
              SizedBox(width: 10),
              Text('Edit site'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete site', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small mint tag on the card, e.g. "Site map" or "24 plots mapped".
class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Tag({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mint.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

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
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
