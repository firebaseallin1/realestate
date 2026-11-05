import 'package:flutter/material.dart';
import '../../../core/controllers/booking_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../widgets/list_table_switcher.dart';
import '../../dashboard/widgets/dashboard_panel.dart';
import '../../dashboard/widgets/dashboard_stats.dart';
import '../../dashboard/widgets/report_table.dart';
import '../booking_detail_screen.dart';
import '../widgets/booking_widgets.dart';

/// PaymentTrackingSection (Sales): collection totals, bookings that still
/// have a balance (largest first), and the latest payments received.
class PaymentTrackingSection extends StatelessWidget {
  final BookingController controller;
  final bool wide;
  final ValueChanged<Booking> onOpenBooking;

  const PaymentTrackingSection({
    super.key,
    required this.controller,
    required this.wide,
    required this.onOpenBooking,
  });

  @override
  Widget build(BuildContext context) {
    final due = controller.bookings.where((b) => b.status != BookingStatus.rejected && b.balance > 0).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final recent = controller.recentPayments.take(8).toList();

    final stats = StatCardGrid(
      columns: wide ? 4 : 2,
      cards: [
        StatCard(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          label: 'Booking Value',
          value: MoneyText.short(controller.totalValue),
          caption: '${controller.bookings.length - controller.countWithStatus(BookingStatus.rejected)} bookings',
        ),
        StatCard(
          icon: Icons.south_west_rounded,
          color: AppColors.success,
          label: 'Collected',
          value: MoneyText.short(controller.totalCollected),
          caption: '${controller.recentPayments.length} payments',
        ),
        StatCard(
          icon: Icons.pending_actions_rounded,
          color: AppColors.error,
          label: 'Outstanding',
          value: MoneyText.short(controller.totalOutstanding),
          caption: '${due.length} with a balance',
        ),
        StatCard(
          icon: Icons.account_balance_outlined,
          color: AppColors.accentGold,
          label: 'On Bank Loan',
          value: '${controller.loanCount}',
          caption: 'Bookings with a loan',
        ),
      ],
    );

    final duePanel = DashboardPanel(
      title: 'Balance Due',
      subtitle: 'Largest balance first',
      child: ListTableSwitcher(
        id: 'payments-due',
        empty: due.isEmpty ? const EmptyNote(icon: Icons.task_alt_rounded, text: 'Every booking is fully paid.') : null,
        list: (_) => CardWrap(
          minCardWidth: 300,
          children: [
            for (final booking in due)
              BookingCard(
                key: ValueKey('due-${booking.id}'),
                booking: booking,
                onTap: () => onOpenBooking(booking),
              ),
          ],
        ),
        table: (_) => BookingTable(bookings: due, onOpen: onOpenBooking),
      ),
    );

    final recentPanel = DashboardPanel(
      title: 'Recent Payments',
      subtitle: 'Latest amounts received',
      child: ListTableSwitcher(
        id: 'payments-recent',
        empty: recent.isEmpty ? const EmptyNote(icon: Icons.receipt_long_outlined, text: 'No payments yet.') : null,
        list: (_) => Column(
          children: [
            for (final (booking, payment) in recent)
              InkWell(
                onTap: () => onOpenBooking(booking),
                child: PaymentRow(
                  payment: payment,
                  title: '${booking.customer.name} · Plot ${booking.plotNumber}',
                ),
              ),
          ],
        ),
        table: (_) => ReportTable(
          minWidth: 760,
          columns: const [
            ReportColumn('Customer', flex: 1.6),
            ReportColumn('Plot', flex: 0.6),
            ReportColumn('Date', flex: 1),
            ReportColumn('Method', flex: 1.2),
            ReportColumn('Reference', flex: 1.2),
            ReportColumn('Amount', flex: 1, numeric: true),
          ],
          onRowTap: (i) => onOpenBooking(recent[i].$1),
          rows: [
            for (final (booking, payment) in recent)
              [
                ReportTable.text(booking.customer.name, bold: true),
                ReportTable.text(booking.plotNumber),
                ReportTable.text(DateText.shortDate(payment.date)),
                ReportTable.text(payment.method.label),
                ReportTable.text(payment.reference.isEmpty ? ReportTable.blank : payment.reference),
                ReportTable.text(MoneyText.full(payment.amount), bold: true, color: AppColors.success),
              ],
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stats,
        SizedBox(height: wide ? 16 : 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: duePanel),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: recentPanel),
            ],
          )
        else ...[
          duePanel,
          const SizedBox(height: 12),
          recentPanel,
        ],
      ],
    );
  }
}
