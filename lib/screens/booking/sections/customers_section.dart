import 'package:flutter/material.dart';
import '../../../core/controllers/booking_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../widgets/band_card.dart';
import '../../../widgets/list_table_switcher.dart';
import '../../dashboard/widgets/report_table.dart';
import '../widgets/booking_widgets.dart';

/// CustomersSection (Sales): every customer who has booked, with contact
/// details and their plots. Tapping a plot opens that booking.
class CustomersSection extends StatelessWidget {
  final BookingController controller;
  final ValueChanged<Booking> onOpenBooking;

  const CustomersSection({
    super.key,
    required this.controller,
    required this.onOpenBooking,
  });

  @override
  Widget build(BuildContext context) {
    // One entry per mobile number, keeping the latest booking's details.
    final byMobile = <String, List<Booking>>{};
    for (final booking in controller.bookings) {
      final key = booking.customer.mobile.replaceAll(RegExp(r'\D'), '');
      byMobile.putIfAbsent(key, () => []).add(booking);
    }

    if (byMobile.isEmpty) {
      return const EmptyNote(
        icon: Icons.people_alt_outlined,
        text: 'Customers appear here once you book a plot for them.',
      );
    }

    final customers = byMobile.values.toList();

    return ListTableSwitcher(
      id: 'customers',
      list: (_) => CardWrap(
        children: [
          for (final bookings in customers)
            _CustomerCard(bookings: bookings, onOpenBooking: onOpenBooking),
        ],
      ),
      table: (_) => ReportTable(
        minWidth: 1060,
        columns: const [
          ReportColumn('Customer', flex: 1.5),
          ReportColumn('Mobile', flex: 1.1),
          ReportColumn('Email', flex: 1.6),
          ReportColumn('Address', flex: 1.6),
          ReportColumn('Plots', flex: 2.4),
          ReportColumn('Total Value', flex: 1, numeric: true),
        ],
        rows: [
          for (final bookings in customers)
            [
              ReportTable.text(bookings.first.customer.name, bold: true),
              ReportTable.text(bookings.first.customer.mobile),
              ReportTable.text(bookings.first.customer.email.isEmpty ? ReportTable.blank : bookings.first.customer.email),
              ReportTable.text(bookings.first.customer.address.isEmpty ? ReportTable.blank : bookings.first.customer.address),
              // One customer can hold several plots: each opens its booking.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final booking in bookings)
                    Material(
                      color: AppColors.mint.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: ValueKey('customer-plot-${booking.id}'),
                        onTap: () => onOpenBooking(booking),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            '${booking.siteName} · Plot ${booking.plotNumber}',
                            style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ReportTable.text(
                MoneyText.short(bookings.fold<double>(0, (sum, b) => sum + b.totalValue)),
                bold: true,
              ),
            ],
        ],
      ),
    );
  }
}

/// _CustomerCard: a sage [BandCard] with the booking count and total value
/// on the band, contact details, then each booked plot (tap to open).
class _CustomerCard extends StatelessWidget {
  final List<Booking> bookings;
  final ValueChanged<Booking> onOpenBooking;

  const _CustomerCard({required this.bookings, required this.onOpenBooking});

  @override
  Widget build(BuildContext context) {
    final customer = bookings.first.customer;
    final total = bookings.fold<double>(0, (sum, b) => sum + b.totalValue);
    final count = bookings.length;

    return BandCard(
      color: AppColors.primary,
      avatar: BandCard.avatarCircle(AppColors.primary, BandCard.initial(customer.name)),
      badges: [
        BandBadge(icon: Icons.event_available_outlined, label: '$count ${count == 1 ? 'booking' : 'bookings'}'),
      ],
      trailing: Text(
        MoneyText.short(total),
        style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
      ),
      children: [
        BandTitle(title: customer.name, subtitle: customer.mobile),
        const SizedBox(height: 12),
        BandInfoBox(
          children: [
            BandInfoLine(
              icon: Icons.mail_outline_rounded,
              text: customer.email.isEmpty ? 'No email added' : customer.email,
              muted: customer.email.isEmpty,
            ),
            BandInfoLine(
              icon: Icons.home_outlined,
              text: customer.address.isEmpty ? 'No address added' : customer.address,
              muted: customer.address.isEmpty,
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final booking in bookings)
          InkWell(
            onTap: () => onOpenBooking(booking),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Icon(booking.type.icon, size: 16, color: bookingTypeColor(booking.type)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${booking.siteName} · Plot ${booking.plotNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    MoneyText.short(booking.totalValue),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMutedLight),
                ],
              ),
            ),
          ),
      ],
    );
  }
}