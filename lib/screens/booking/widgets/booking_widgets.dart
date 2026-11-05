import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../widgets/band_card.dart';
import '../../dashboard/widgets/report_table.dart';

/// Small rounded label with an icon, tinted in [color].
class BookingChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const BookingChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  factory BookingChip.status(BookingStatus status) =>
      BookingChip(label: status.label, icon: status.icon, color: status.color);

  factory BookingChip.type(BookingType type) => BookingChip(
        label: type.label,
        icon: type.icon,
        color: type == BookingType.withConstruction ? AppColors.primaryBright : AppColors.primary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// PaidProgress: a bar of [paid] out of [total] with the figures below.
class PaidProgress extends StatelessWidget {
  final double paid;
  final double total;
  final bool compact;

  const PaidProgress({
    super.key,
    required this.paid,
    required this.total,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final done = total > 0 && paid >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: compact ? 6 : 8,
            backgroundColor: AppColors.mint.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation(done ? AppColors.success : AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Paid ${MoneyText.short(paid)} (${(ratio * 100).round()}%)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                done ? 'Fully paid' : 'Balance ${MoneyText.short(math.max(0, total - paid))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.caption.copyWith(
                  color: done ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Band color for a booking type: teal for With Construction, sage for a
/// plot only.
Color bookingTypeColor(BookingType type) =>
    type == BookingType.withConstruction ? const Color(0xFF2E8B83) : AppColors.primary;

/// BookingCard: a [BandCard] colored by booking type, with the type and
/// status on the band and the total value at its right; then customer,
/// site and plot, loan and paid progress. [actions] (e.g. Approve /
/// Reject) sit along the bottom.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  final List<Widget> actions;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final color = bookingTypeColor(booking.type);
    final loans = booking.plans.where((p) => p.loan != null).map((p) => p.loan!.bankName).toSet();

    return BandCard(
      color: color,
      onTap: onTap,
      avatar: BandCard.avatarCircle(color, BandCard.initial(booking.customer.name)),
      badges: [
        BandBadge(icon: booking.type.icon, label: booking.type.label),
        BandBadge.solid(icon: booking.status.icon, label: booking.status.label, color: booking.status.color),
      ],
      trailing: Text(
        MoneyText.short(booking.totalValue),
        style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
      ),
      children: [
        BandTitle(
          title: booking.customer.name,
          subtitle: '${booking.siteName} · Plot ${booking.plotNumber}',
        ),
        const SizedBox(height: 12),
        BandInfoBox(
          children: [
            BandInfoLine(icon: Icons.phone_outlined, text: booking.customer.mobile),
            BandInfoLine(
              icon: Icons.account_balance_outlined,
              text: loans.isEmpty ? 'Full payment' : 'Bank loan · ${loans.join(', ')}',
              color: loans.isEmpty ? null : AppColors.accentGold,
            ),
            PaidProgress(paid: booking.totalPaid, total: booking.totalValue, compact: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Booked ${DateText.shortDate(booking.bookedOn)} by ${booking.bookedBy}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// BookingTable shows bookings one row each; tap a row to open it.
/// [actionsFor] adds a last column of buttons, e.g. Approve / Reject.
class BookingTable extends StatelessWidget {
  final List<Booking> bookings;
  final ValueChanged<Booking> onOpen;
  final List<Widget> Function(Booking booking)? actionsFor;

  const BookingTable({
    super.key,
    required this.bookings,
    required this.onOpen,
    this.actionsFor,
  });

  @override
  Widget build(BuildContext context) {
    return ReportTable(
      minWidth: actionsFor == null ? 1160 : 1460,
      columns: [
        const ReportColumn('Customer', flex: 1.6),
        const ReportColumn('Mobile', flex: 1.2),
        const ReportColumn('Site', flex: 1.8),
        const ReportColumn('Plot', flex: 0.6),
        const ReportColumn('Type', flex: 1.9),
        const ReportColumn('Status', flex: 1.6),
        const ReportColumn('Value', flex: 1, numeric: true),
        const ReportColumn('Paid', flex: 1, numeric: true),
        const ReportColumn('Balance', flex: 1, numeric: true),
        const ReportColumn('Booked', flex: 1),
        if (actionsFor != null) const ReportColumn('', flex: 3, numeric: true),
      ],
      rowKeys: [for (final b in bookings) ValueKey('booking-row-${b.id}')],
      onRowTap: (i) => onOpen(bookings[i]),
      rows: [
        for (final b in bookings)
          [
            ReportTable.text(b.customer.name, bold: true),
            ReportTable.text(b.customer.mobile),
            ReportTable.text(b.siteName),
            ReportTable.text(b.plotNumber),
            ReportTable.text(b.type.label),
            ReportTable.pill(b.status.label, b.status.color),
            ReportTable.text(MoneyText.short(b.totalValue)),
            ReportTable.text(MoneyText.short(b.totalPaid), color: AppColors.success),
            ReportTable.text(MoneyText.short(b.balance), color: b.balance > 0 ? AppColors.error : null),
            ReportTable.text(DateText.shortDate(b.bookedOn)),
            if (actionsFor != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: actionsFor!(b)),
              ),
          ],
      ],
    );
  }
}

/// Lays [children] out as cards, as many per row as fit.
class CardWrap extends StatelessWidget {
  final List<Widget> children;
  final double minCardWidth;
  final double gap;

  const CardWrap({
    super.key,
    required this.children,
    this.minCardWidth = 320,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, ((constraints.maxWidth + gap) / (minCardWidth + gap)).floor());
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// A row of filter chips with counts; the selected one is filled.
class FilterChips<T> extends StatelessWidget {
  final List<(T?, String, int)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final String keyPrefix;

  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, count) in options)
          _FilterChip(
            key: ValueKey('$keyPrefix-${value is Enum ? value.name : 'all'}'),
            label: label,
            count: count,
            selected: value == selected,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.pureWhite,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? AppColors.primary : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: selected ? AppColors.pureWhite : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : AppColors.mint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.caption.copyWith(
                    color: selected ? AppColors.pureWhite : AppColors.brandDeep,
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

/// Centered note for a list with nothing in it.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyNote({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.sageMid),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
