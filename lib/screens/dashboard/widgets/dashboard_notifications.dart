import 'package:flutter/material.dart';
import '../../../core/controllers/booking_controller.dart';
import '../../../core/controllers/site_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/site.dart';
import 'dashboard_section.dart';

/// DashboardNotification is one alert worked out from the current data.
/// [id] stays the same while the alert holds, so it can be marked read.
class DashboardNotification {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final DashboardSection section;
  final String? location;

  const DashboardNotification({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.section,
    this.location,
  });

  /// Alerts worth a look right now: bookings waiting for approval,
  /// upcoming launches, sites that are almost sold out, and locations
  /// with no sites yet.
  static List<DashboardNotification> fromData(SiteController controller, {BookingController? bookings}) {
    final sites = controller.sites;
    return [
      for (final booking in bookings?.withStatus(BookingStatus.pending) ?? const <Booking>[])
        DashboardNotification(
          id: 'approve-${booking.id}',
          icon: Icons.fact_check_outlined,
          color: AppColors.primary,
          title: 'Booking to approve',
          message: '${booking.customer.name} · Plot ${booking.plotNumber}, ${booking.siteName}.',
          section: DashboardSection.bookingApproval,
        ),
      for (final site in sites.where((s) => s.status == SiteStatus.upcoming))
        DashboardNotification(
          id: 'upcoming-${site.id}',
          icon: Icons.rocket_launch_outlined,
          color: AppColors.accentGold,
          title: 'Upcoming launch',
          message: '${site.name} in ${site.location} has ${site.bookedUnits} early bookings.',
          section: DashboardSection.sites,
          location: site.location,
        ),
      for (final site in sites.where((s) => s.status != SiteStatus.completed && s.soldRatio >= 0.65))
        DashboardNotification(
          id: 'selling-${site.id}',
          icon: Icons.local_fire_department_outlined,
          color: AppColors.error,
          title: 'Selling fast',
          message: '${site.name} is ${(site.soldRatio * 100).round()}% sold — '
              '${site.availableUnits} units left.',
          section: DashboardSection.sites,
          location: site.location,
        ),
      for (final location in controller.locations.where((l) => controller.siteCountAt(l) == 0))
        DashboardNotification(
          id: 'empty-$location',
          icon: Icons.add_location_alt_outlined,
          color: AppColors.primary,
          title: 'No sites yet',
          message: '$location has no sites. Add one from Masters › Sites.',
          section: DashboardSection.locations,
        ),
    ];
  }
}

/// NotificationBell is the bell button with an unread badge. It opens a
/// panel listing [notifications]; opening it calls [onOpened] (to mark
/// them read) and tapping one calls [onSelected].
class NotificationBell extends StatelessWidget {
  final List<DashboardNotification> notifications;
  final int unreadCount;
  final VoidCallback onOpened;
  final ValueChanged<DashboardNotification> onSelected;

  const NotificationBell({
    super.key,
    required this.notifications,
    required this.unreadCount,
    required this.onOpened,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DashboardNotification>(
      key: const ValueKey('notification-bell'),
      tooltip: 'Notifications',
      offset: const Offset(0, 52),
      color: AppColors.pureWhite,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onOpened: onOpened,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<DashboardNotification>(
          enabled: false,
          height: 44,
          child: Row(
            children: [
              Text(
                'Notifications',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${notifications.length}',
                style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
              ),
            ],
          ),
        ),
        if (notifications.isEmpty)
          PopupMenuItem<DashboardNotification>(
            enabled: false,
            child: Text(
              "You're all caught up.",
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
            ),
          ),
        for (final n in notifications)
          PopupMenuItem<DashboardNotification>(
            value: n,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: n.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(n.icon, size: 18, color: n.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
                      ),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, color: AppColors.textPrimaryLight),
            if (unreadCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  key: const ValueKey('notification-badge'),
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.pureWhite, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        height: 1,
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// UserGreeting is the avatar with "Good evening", the username and their
/// role, for the top bar. [compact] shows the avatar alone.
class UserGreeting extends StatelessWidget {
  final String username;
  final UserRole? role;
  final String greeting;
  final bool compact;

  const UserGreeting({
    super.key,
    required this.username,
    this.role,
    required this.greeting,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        username.isEmpty ? '?' : username[0].toUpperCase(),
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (compact) {
      final roleText = role == null ? '' : ' · ${role!.label}';
      return Tooltip(message: '$greeting, $username$roleText', child: avatar);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
              ),
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (role case final role?)
                Text(
                  role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: role.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
