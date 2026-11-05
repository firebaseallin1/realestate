import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/controllers/user_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_user.dart';
import '../../../widgets/band_card.dart';
import '../../../widgets/list_table_switcher.dart';
import '../widgets/report_table.dart';

/// UsersSection (Admin): the team as cards or a table, filtered by role,
/// with each member's role, username, phone and current work; others can
/// be removed, the signed-in user cannot.
class UsersSection extends StatefulWidget {
  final UserController controller;
  final String currentUserId;
  final ValueChanged<AppUser> onRemoveUser;

  /// A short line about each person's work, e.g. "3 bookings raised".
  final String Function(AppUser user)? activityFor;

  const UsersSection({
    super.key,
    required this.controller,
    required this.currentUserId,
    required this.onRemoveUser,
    this.activityFor,
  });

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  /// Null shows every role.
  UserRole? _role;

  static const double _minCardWidth = 260;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final users = controller.usersWithRole(_role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role filter
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RoleChip(
              key: const ValueKey('role-filter-all'),
              label: 'All',
              count: controller.users.length,
              color: AppColors.primary,
              selected: _role == null,
              onTap: () => setState(() => _role = null),
            ),
            for (final role in UserRole.values)
              _RoleChip(
                key: ValueKey('role-filter-${role.name}'),
                label: role.label,
                icon: role.icon,
                count: controller.countWithRole(role),
                color: role.color,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'users',
          empty: users.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No ${_role?.label ?? ''} users yet. Add one with Add User.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textMutedLight),
                  ),
                )
              : null,
          list: (_) => LayoutBuilder(
            builder: (context, constraints) {
              final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minCardWidth + _gap)).floor());
              final cardWidth = (constraints.maxWidth - _gap * (columns - 1)) / columns;

              return Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final user in users)
                    SizedBox(
                      width: cardWidth,
                      child: _UserCard(
                        key: ValueKey('user-${user.username}'),
                        user: user,
                        isYou: user.id == widget.currentUserId,
                        activity: widget.activityFor?.call(user),
                        onRemove: () => widget.onRemoveUser(user),
                      ),
                    ),
                ],
              );
            },
          ),
          table: (_) => ReportTable(
            minWidth: 860,
            columns: const [
              ReportColumn('Name', flex: 1.7),
              ReportColumn('Username', flex: 1.2),
              ReportColumn('Role', flex: 1.3),
              ReportColumn('Phone', flex: 1.2),
              ReportColumn('Work', flex: 2),
              ReportColumn('', flex: 0.5, numeric: true),
            ],
            rowKeys: [for (final user in users) ValueKey('user-row-${user.username}')],
            rows: [
              for (final user in users)
                [
                  ReportTable.text(user.id == widget.currentUserId ? '${user.name} (You)' : user.name, bold: true),
                  ReportTable.text('@${user.username}'),
                  ReportTable.pill(user.role.label, user.role.color),
                  ReportTable.text(user.phone.isEmpty ? ReportTable.blank : user.phone),
                  ReportTable.text(widget.activityFor?.call(user) ?? ReportTable.blank),
                  if (user.id == widget.currentUserId)
                    const SizedBox.shrink()
                  else
                    _UserMenu(
                      username: user.username,
                      iconColor: AppColors.textSecondaryLight,
                      onRemove: () => widget.onRemoveUser(user),
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The "Remove user" menu, on a card's band or at the end of a table row.
class _UserMenu extends StatelessWidget {
  final String username;
  final Color iconColor;
  final VoidCallback onRemove;

  const _UserMenu({required this.username, required this.iconColor, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        key: ValueKey('user-menu-$username'),
        tooltip: 'More',
        padding: EdgeInsets.zero,
        color: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: Icon(Icons.more_horiz_rounded, color: iconColor),
        onSelected: (_) => onRemove(),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                SizedBox(width: 10),
                Text('Remove user', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    super.key,
    required this.label,
    this.icon,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.pureWhite : AppColors.textPrimaryLight;

    return Material(
      color: selected ? color : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? color : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? AppColors.pureWhite : color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.caption.copyWith(
                    color: selected ? AppColors.pureWhite : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// _UserCard: a [BandCard] in the role's color with the role badge and
/// menu, then name, username, phone and a line about the person's work
/// ([activity]).
class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isYou;
  final String? activity;
  final VoidCallback onRemove;

  const _UserCard({
    super.key,
    required this.user,
    required this.isYou,
    this.activity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final role = user.role;

    return BandCard(
      color: role.color,
      avatar: BandCard.avatarCircle(role.color, BandCard.initial(user.name)),
      badges: [BandBadge(icon: role.icon, label: role.label)],
      trailing: isYou
          ? null
          : _UserMenu(username: user.username, iconColor: AppColors.pureWhite, onRemove: onRemove),
      corner: isYou
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'You',
                style: AppTypography.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      children: [
        BandTitle(title: user.name, subtitle: '@${user.username}'),
        const SizedBox(height: 12),
        BandInfoBox(
          children: [
            BandInfoLine(
              icon: Icons.phone_outlined,
              text: user.phone.isEmpty ? 'No phone added' : user.phone,
              muted: user.phone.isEmpty,
            ),
            if (activity != null) BandInfoLine(icon: Icons.work_outline_rounded, text: activity!, color: role.color),
          ],
        ),
      ],
    );
  }
}