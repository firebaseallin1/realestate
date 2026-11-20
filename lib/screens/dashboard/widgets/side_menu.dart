import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../widgets/app_brand_logo.dart';
import 'dashboard_section.dart';

/// SideMenu is the sage main menu shared by the web sidebar and the mobile
/// drawer: the logo, a Dashboard entry (both open the main page), the
/// groups for the signed-in user's [role], and the user with logout.
///
/// With [showLabels] the groups expand and collapse in place. Without it
/// (the web icon rail) each group is an icon that pops out its pages.
class SideMenu extends StatefulWidget {
  final DashboardSection section;
  final ValueChanged<DashboardSection> onSectionChanged;
  final VoidCallback onOpenDashboard;
  final String username;
  final UserRole role;
  final VoidCallback onLogout;
  final bool showLabels;

  const SideMenu({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.onOpenDashboard,
    required this.username,
    required this.role,
    required this.onLogout,
    this.showLabels = true,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  /// Groups start open so every page is one tap away. With more than three
  /// (the Admin, who sees every team's pages) only the first three and the
  /// one holding the open page start open, to keep the menu short.
  late final Set<MenuGroup> _expanded = {
    ...MenuGroup.forRole(widget.role).take(3),
    ?widget.section.group,
  };

  void _toggle(MenuGroup group) {
    setState(() {
      if (!_expanded.remove(group)) _expanded.add(group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showLabels = widget.showLabels;

    return Padding(
      padding: EdgeInsets.fromLTRB(showLabels ? 14 : 10, 18, showLabels ? 14 : 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo opens the dashboard
          Tooltip(
            message: 'Open dashboard',
            child: InkWell(
              key: const ValueKey('go-dashboard'),
              onTap: widget.onOpenDashboard,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: showLabels ? 6 : 0, vertical: 4),
                child: Align(
                  alignment: showLabels ? Alignment.centerLeft : Alignment.center,
                  child: AppBrandInline(onDark: true, showWordmark: showLabels),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDashboardItem(showLabels),
                  const SizedBox(height: 8),
                  for (final group in MenuGroup.forRole(widget.role))
                    showLabels ? _buildGroup(group) : _buildRailGroup(group),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildUserCard(showLabels),
        ],
      ),
    );
  }

  /// Top-level Dashboard entry, above the groups, so the main page is
  /// always one tap away.
  Widget _buildDashboardItem(bool showLabels) {
    const section = DashboardSection.overview;
    final selected = widget.section == section;
    final color = selected ? AppColors.pureWhite : AppColors.textSecondaryDark;

    final item = Material(
      color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('menu-overview'),
        onTap: () => widget.onSectionChanged(section),
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: SizedBox(
          height: 40,
          child: showLabels
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(section.icon, size: 20, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AppTypography.titleSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accentGoldLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                )
              : Center(child: Icon(section.icon, size: 21, color: color)),
        ),
      ),
    );

    // The icon rail names the entry on hover.
    return showLabels ? item : Tooltip(message: section.label, child: item);
  }

  /// Expandable group: header row, then its pages indented below.
  Widget _buildGroup(MenuGroup group) {
    final expanded = _expanded.contains(group);
    final containsCurrent = widget.section.group == group;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey('menu-group-${group.name}'),
              onTap: () => _toggle(group),
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.white.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(group.icon, size: 20, color: AppColors.pureWhite),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Gold dot marks the group holding the open page
                    if (containsCurrent && !expanded)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.accentGoldLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 22, top: 2),
                    child: Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final section in group.sections.where((s) => s.allows(widget.role)))
                            _MenuItem(
                              section: section,
                              selected: section == widget.section,
                              onTap: () => widget.onSectionChanged(section),
                            ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Icon rail group: one icon that pops out the group's pages.
  Widget _buildRailGroup(MenuGroup group) {
    final containsCurrent = widget.section.group == group;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PopupMenuButton<DashboardSection>(
        key: ValueKey('menu-group-${group.name}'),
        tooltip: group.label,
        offset: const Offset(64, 0),
        color: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: widget.onSectionChanged,
        itemBuilder: (context) => [
          PopupMenuItem<DashboardSection>(
            enabled: false,
            height: 36,
            child: Text(
              group.label.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textMutedLight,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final section in group.sections.where((s) => s.allows(widget.role)))
            PopupMenuItem<DashboardSection>(
              key: ValueKey('menu-${section.name}'),
              value: section,
              child: Row(
                children: [
                  Icon(
                    section.icon,
                    size: 18,
                    color: section == widget.section ? AppColors.primary : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: section == widget.section ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: containsCurrent ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            group.icon,
            size: 21,
            color: containsCurrent ? AppColors.pureWhite : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(bool showLabels) {
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.sageMid,
      child: Text(
        widget.username.isEmpty ? '?' : widget.username[0].toUpperCase(),
        style: AppTypography.titleSmall.copyWith(color: AppColors.pureWhite),
      ),
    );
    final logout = IconButton(
      tooltip: 'Logout',
      onPressed: widget.onLogout,
      icon: Icon(Icons.logout_rounded, size: 20, color: AppColors.textSecondaryDark),
    );

    if (!showLabels) {
      return Column(
        children: [
          Tooltip(message: '${widget.username} · ${widget.role.label}', child: avatar),
          const SizedBox(height: 6),
          logout,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(color: AppColors.pureWhite),
                ),
                Text(
                  widget.role.label,
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedDark),
                ),
              ],
            ),
          ),
          logout,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final DashboardSection section;
  final bool selected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.pureWhite : AppColors.textSecondaryDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('menu-${section.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(section.icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  // Long names (Construction Planning) wrap to a second line.
                  child: Text(
                    section.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentGoldLight,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
