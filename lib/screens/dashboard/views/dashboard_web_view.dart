import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../core/utils/date_text.dart';
import '../../../models/app_user.dart';
import '../widgets/dashboard_notifications.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/side_menu.dart';

/// DashboardWebView is the wide-screen frame: the sage [SideMenu] as a
/// sidebar, a top bar with the page title, the section's action button,
/// date, notifications and the signed-in user, and the current section's
/// content.
///
/// The sidebar expands to full labels or collapses to an icon rail from
/// the menu button in the top bar. It starts collapsed on narrower windows.
class DashboardWebView extends StatefulWidget {
  final DashboardSection section;
  final ValueChanged<DashboardSection> onSectionChanged;
  final AppUser user;
  final DashboardAction? action;
  final VoidCallback onLogout;
  final Widget? notificationBell;
  final Widget content;

  const DashboardWebView({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.user,
    this.action,
    required this.onLogout,
    this.notificationBell,
    required this.content,
  });

  @override
  State<DashboardWebView> createState() => _DashboardWebViewState();
}

class _DashboardWebViewState extends State<DashboardWebView> {
  static const double _expandedWidth = 232;
  static const double _collapsedWidth = 72;

  /// Sidebar starts collapsed below this window width.
  static const double _autoCollapseBelow = 1100;

  /// Labels show only once the animating sidebar is at least this wide,
  /// so nothing overflows mid-animation.
  static const double _labelsMinWidth = 200;

  /// Null until the user toggles; until then it follows the window width.
  bool? _collapsed;

  bool _isCollapsed(BuildContext context) =>
      _collapsed ?? MediaQuery.sizeOf(context).width < _autoCollapseBelow;

  void _toggleSidebar() {
    setState(() => _collapsed = !_isCollapsed(context));
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _isCollapsed(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Row(
        children: [
          _buildSidebar(collapsed),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(collapsed),
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey(widget.section),
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: widget.content,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool collapsed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandDark, AppColors.brandDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SideMenu(
          section: widget.section,
          onSectionChanged: widget.onSectionChanged,
          onOpenDashboard: () => widget.onSectionChanged(DashboardSection.overview),
          username: widget.user.name,
          role: widget.user.role,
          onLogout: widget.onLogout,
          showLabels: constraints.maxWidth >= _labelsMinWidth,
        ),
      ),
    );
  }

  Widget _buildTopBar(bool collapsed) {
    final group = widget.section.group;

    return Container(
      height: 68,
      padding: const EdgeInsets.only(left: 12, right: 20),
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          // Sidebar expand / collapse
          IconButton(
            tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
            onPressed: _toggleSidebar,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.offWhite,
              side: const BorderSide(color: AppColors.lightBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
              collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group the page sits under, e.g. "MASTERS"
                if (group != null)
                  Text(
                    group.label.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                Text(
                  widget.section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                ),
                Text(
                  widget.section.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          if (widget.action case final action?) ...[
            AppButton.primary(
              text: action.label,
              width: null,
              height: 40,
              gradient: AppColors.brandGradient,
              icon: Icon(action.icon, color: Colors.white, size: 16),
              onPressed: action.onPressed,
            ),
            const SizedBox(width: 14),
          ],
          _buildUserArea(),
        ],
      ),
    );
  }

  /// Right side of the top bar: date, notifications and the signed-in
  /// user. Narrower windows drop the date, then shrink the user to an
  /// avatar, so the page title keeps its room.
  Widget _buildUserArea() {
    final width = MediaQuery.sizeOf(context).width;
    final now = DateTime.now();
    final showDate = width >= 1280;
    final compactUser = width < 1100;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  DateText.longDate(now),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        ?widget.notificationBell,
        const SizedBox(width: 16),
        Container(width: 1, height: 30, color: AppColors.lightBorder),
        const SizedBox(width: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: UserGreeting(
            username: widget.user.name,
            role: widget.user.role,
            greeting: DateText.greeting(now),
            compact: compactUser,
          ),
        ),
      ],
    );
  }
}
