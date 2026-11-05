import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_brand_logo.dart';
import '../../../core/utils/date_text.dart';
import '../../../models/app_user.dart';
import '../widgets/dashboard_notifications.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/side_menu.dart';

/// DashboardMobileView is the phone frame: a header with the menu button,
/// the logo (tap to open the dashboard), notifications and the user menu; the main menu
/// as a slide-out [SideMenu] drawer; the current section's content; and a
/// floating button for the section's action.
class DashboardMobileView extends StatelessWidget {
  final DashboardSection section;
  final ValueChanged<DashboardSection> onSectionChanged;
  final AppUser user;
  final DashboardAction? action;
  final VoidCallback onLogout;
  final Widget? notificationBell;
  final Widget content;

  const DashboardMobileView({
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      drawer: Drawer(
        width: 290,
        backgroundColor: AppColors.brandDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandDark, AppColors.brandDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            // Builder gives a context under the Scaffold, to close the drawer.
            child: Builder(
              builder: (drawerContext) {
                void go(DashboardSection target) {
                  Scaffold.of(drawerContext).closeDrawer();
                  onSectionChanged(target);
                }

                return SideMenu(
                  section: section,
                  onSectionChanged: go,
                  onOpenDashboard: () => go(DashboardSection.overview),
                  username: user.name,
                  role: user.role,
                  onLogout: onLogout,
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                key: PageStorageKey(section),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard opens with its own banner; other pages get a title.
                    if (section != DashboardSection.overview) ...[
                      if (section.group case final group?)
                        Text(
                          group.label.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      Text(
                        section.label,
                        style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight),
                      ),
                      Text(
                        section.subtitle,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                      ),
                      const SizedBox(height: 12),
                    ],
                    content,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: action == null ? null : _ActionButton(action: action!),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        children: [
          // Opens the main menu drawer
          Builder(
            builder: (context) => IconButton(
              key: const ValueKey('open-menu'),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.pureWhite,
                side: const BorderSide(color: AppColors.lightBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimaryLight),
            ),
          ),
          const SizedBox(width: 8),
          // Logo opens the dashboard
          InkWell(
            onTap: () => onSectionChanged(DashboardSection.overview),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: AppBrandInline(size: 36),
            ),
          ),
          const Spacer(),
          ?notificationBell,
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Account',
            color: AppColors.pureWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: UserGreeting(username: user.name, role: user.role, greeting: DateText.greeting(DateTime.now())),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandDark,
                child: Text(
                  user.initial,
                  style: AppTypography.titleSmall.copyWith(color: AppColors.pureWhite),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _ActionButton is the floating section action, styled like the app's
/// primary button: sage gradient, glossy top shine, soft glow and a
/// frosted badge around the icon.
class _ActionButton extends StatelessWidget {
  final DashboardAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy shine across the top half
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          FloatingActionButton.extended(
            onPressed: action.onPressed,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.pureWhite,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: shape,
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Icon(action.icon, size: 16),
            ),
            label: Text(
              action.label,
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
