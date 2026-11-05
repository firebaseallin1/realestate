import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// BandCard is the card style shared by the list pages (users, bookings,
/// customers, houses): a band in [color] carrying [badges] and an optional
/// [trailing] (amount, % or menu), a round [avatar] overlapping the band,
/// an optional [corner] tag under the band on the right, then [children].
class BandCard extends StatelessWidget {
  final Color color;
  final Widget avatar;
  final List<Widget> badges;
  final Widget? trailing;
  final Widget? corner;
  final List<Widget> children;
  final VoidCallback? onTap;

  const BandCard({
    super.key,
    required this.color,
    required this.avatar,
    this.badges = const [],
    this.trailing,
    this.corner,
    required this.children,
    this.onTap,
  });

  static const double bandHeight = 62;
  static const double avatarSize = 58;

  /// A round avatar in a [color] gradient holding [child] (initial or icon).
  static Widget avatarCircle(Color color, Widget child) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.white, 0.35)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      );

  /// The initial of [name] in white, for [avatarCircle].
  static Widget initial(String name) => Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: AppTypography.titleLarge.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: bandHeight + avatarSize / 2,
                child: Stack(
                  children: [
                    _buildBand(),
                    Positioned(
                      left: 14,
                      top: bandHeight - avatarSize / 2,
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandDark.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: avatar,
                      ),
                    ),
                    if (corner != null)
                      Positioned(
                        left: 14 + avatarSize + 8,
                        right: 12,
                        top: bandHeight + 6,
                        child: Align(alignment: Alignment.centerRight, child: corner),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBand() {
    return Container(
      height: bandHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative rings
          Positioned(
            right: -24,
            top: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.5),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          // Badges run along the top, above the avatar (which starts lower).
          Positioned(
            left: 12,
            right: 10,
            top: 7,
            height: 24,
            child: Row(
              children: [
                // Badges share the width left of the trailing item.
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < badges.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Flexible(child: badges[i]),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label on a [BandCard] band: frosted white, or [solid] white
/// with text in [color] to stand out (e.g. a status).
class BandBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const BandBadge({super.key, required this.icon, required this.label}) : color = null;

  const BandBadge.solid({super.key, required this.icon, required this.label, required Color this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.pureWhite;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color == null ? Colors.white.withValues(alpha: 0.2) : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The soft grey box of icon + text lines inside a [BandCard].
class BandInfoBox extends StatelessWidget {
  final List<Widget> children;

  const BandInfoBox({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One icon + text line for a [BandInfoBox].
class BandInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final bool muted;

  const BandInfoLine({super.key, required this.icon, required this.text, this.color, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final foreground = muted ? AppColors.textMutedLight : (color ?? AppColors.textSecondaryLight);

    return Row(
      children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: foreground,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Name (bold) and a muted second line, the top of a [BandCard] body.
class BandTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const BandTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
        ),
      ],
    );
  }
}
