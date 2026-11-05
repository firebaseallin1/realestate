import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/site.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/list_table_switcher.dart';
import '../widgets/location_filter_bar.dart';
import '../widgets/site_grid.dart';

/// SitesSection: search, location filter and every matching site card.
/// [wide] puts the filter and search on one row.
class SitesSection extends StatelessWidget {
  final SiteController controller;
  final TextEditingController searchController;
  final bool wide;
  final ValueChanged<Site> onEditSite;
  final ValueChanged<Site> onDeleteSite;
  final ValueChanged<Site> onOpenLayout;

  const SitesSection({
    super.key,
    required this.controller,
    required this.searchController,
    required this.wide,
    required this.onEditSite,
    required this.onDeleteSite,
    required this.onOpenLayout,
  });

  @override
  Widget build(BuildContext context) {
    final sites = controller.filteredSites;

    final search = AppTextField(
      controller: searchController,
      hintText: 'Search sites, locations or type',
      prefixIcon: const Icon(Icons.search_rounded),
      textInputAction: TextInputAction.search,
      margin: EdgeInsets.zero,
      onChanged: controller.setQuery,
    );
    final filter = LocationFilterBar(controller: controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            children: [
              Expanded(child: filter),
              const SizedBox(width: 14),
              SizedBox(width: 340, child: search),
            ],
          )
        else ...[
          search,
          const SizedBox(height: 14),
          filter,
        ],
        const SizedBox(height: 14),
        ListTableSwitcher(
          id: 'sites',
          leading: Row(
            children: [
              Flexible(
                child: Text(
                  '${controller.selectedLocation ?? 'All'} Sites',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${sites.length}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.pureWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          list: (_) => SiteGrid(
            sites: sites,
            onEdit: onEditSite,
            onDelete: onDeleteSite,
            onOpenLayout: onOpenLayout,
          ),
          table: (_) => SiteTable(
            sites: sites,
            onEdit: onEditSite,
            onDelete: onDeleteSite,
            onOpenLayout: onOpenLayout,
          ),
        ),
      ],
    );
  }
}
