import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../models/site.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/dashboard_stats.dart';

/// RoleHomeSection is the dashboard for Sales Executives, Site Managers
/// and Site Incharges: a welcome strip for the role, the figures that
/// matter to it, and a tile for each of its modules.
class RoleHomeSection extends StatelessWidget {
  final AppUser user;
  final SiteController controller;
  final bool wide;
  final ValueChanged<DashboardSection> onOpenSection;

  const RoleHomeSection({
    super.key,
    required this.user,
    required this.controller,
    required this.wide,
    required this.onOpenSection,
  });

  List<StatCard> _highlights() {
    final active = controller.countWithStatus(SiteStatus.active);
    final upcoming = controller.countWithStatus(SiteStatus.upcoming);
    final completed = controller.countWithStatus(SiteStatus.completed);

    switch (user.role) {
      case UserRole.salesExecutive:
        return [
          StatCard(
            icon: Icons.grid_view_rounded,
            color: AppColors.primary,
            label: 'Units Available',
            value: '${controller.availableUnits}',
            caption: 'Ready to book',
          ),
          StatCard(
            icon: Icons.event_available_rounded,
            color: AppColors.accentGold,
            label: 'Units Booked',
            value: '${controller.bookedUnits}',
            caption: 'Awaiting sale',
          ),
          StatCard(
            icon: Icons.bolt_rounded,
            color: AppColors.success,
            label: 'Active Projects',
            value: '$active',
            caption: 'Open for sales',
          ),
          StatCard(
            icon: Icons.rocket_launch_outlined,
            color: AppColors.primaryBright,
            label: 'Upcoming Launches',
            value: '$upcoming',
            caption: 'Take early bookings',
          ),
        ];
      case UserRole.admin:
      case UserRole.siteManager:
      case UserRole.siteIncharge:
        return [
          StatCard(
            icon: Icons.construction_rounded,
            color: AppColors.primary,
            label: 'Under Construction',
            value: '$active',
            caption: 'Active sites',
          ),
          StatCard(
            icon: Icons.rocket_launch_outlined,
            color: AppColors.accentGold,
            label: 'Upcoming Sites',
            value: '$upcoming',
            caption: 'Yet to start',
          ),
          StatCard(
            icon: Icons.task_alt_rounded,
            color: AppColors.success,
            label: 'Completed',
            value: '$completed',
            caption: 'Handed over',
          ),
          StatCard(
            icon: Icons.location_city_rounded,
            color: AppColors.primaryBright,
            label: 'Locations',
            value: '${controller.locations.length}',
            caption: 'Cities with sites',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = wide ? 24.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoleBanner(user: user, wide: wide),
        SizedBox(height: gap),
        StatCardGrid(columns: wide ? 4 : 2, cards: _highlights()),
        SizedBox(height: gap),
        Text(
          'Your modules',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Everything you work on as ${user.role.label}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
        ),
        const SizedBox(height: 14),
        _ModuleGrid(
          sections: DashboardSection.forRole(user.role),
          color: user.role.color,
          onOpen: onOpenSection,
        ),
      ],
    );
  }
}

/// The sage welcome strip: role badge, greeting and what the role covers.
class _RoleBanner extends StatelessWidget {
  final AppUser user;
  final bool wide;

  const _RoleBanner({required this.user, required this.wide});

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.trim().split(' ').first;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDeep, AppColors.brandDark, Color(0xFF6F8A69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative ring
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1.5),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 14, vertical: wide ? 14 : 12),
            child: Row(
              children: [
                Container(
                  width: wide ? 50 : 44,
                  height: wide ? 50 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Icon(user.role.icon, color: AppColors.pureWhite, size: wide ? 24 : 20),
                ),
                SizedBox(width: wide ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.role.label.toUpperCase()} WORKSPACE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mint,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome, $firstName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.role.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                      ),
                    ],
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

/// One tile per module, as many per row as fit.
class _ModuleGrid extends StatelessWidget {
  final List<DashboardSection> sections;
  final Color color;
  final ValueChanged<DashboardSection> onOpen;

  const _ModuleGrid({
    required this.sections,
    required this.color,
    required this.onOpen,
  });

  static const double _minTileWidth = 240;
  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minTileWidth + _gap)).floor());
        final tileWidth = (constraints.maxWidth - _gap * (columns - 1)) / columns;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final section in sections)
              SizedBox(
                width: tileWidth,
                child: _ModuleTile(
                  section: section,
                  color: color,
                  onTap: () => onOpen(section),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final DashboardSection section;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.section,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pureWhite,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('module-${section.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(section.icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedLight),
            ],
          ),
        ),
      ),
    );
  }
}
