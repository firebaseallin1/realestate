import 'package:flutter/material.dart';
import '../../../core/controllers/booking_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/list_table_switcher.dart';
import '../widgets/booking_widgets.dart';

/// BookingApprovalSection (Admin): bookings raised by sales, pending ones
/// first, each pending card or table row with Approve and Reject.
class BookingApprovalSection extends StatefulWidget {
  final BookingController controller;
  final ValueChanged<Booking> onOpenBooking;
  final ValueChanged<Booking> onApprove;
  final ValueChanged<Booking> onReject;

  const BookingApprovalSection({
    super.key,
    required this.controller,
    required this.onOpenBooking,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<BookingApprovalSection> createState() => _BookingApprovalSectionState();
}

class _BookingApprovalSectionState extends State<BookingApprovalSection> {
  /// Null shows every status; starts on what needs action.
  BookingStatus? _status = BookingStatus.pending;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final shown = controller.withStatus(_status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterChips<BookingStatus>(
          keyPrefix: 'approval-filter',
          selected: _status,
          onSelected: (status) => setState(() => _status = status),
          options: [
            for (final status in BookingStatus.values) (status, status.label, controller.countWithStatus(status)),
            (null, 'All', controller.bookings.length),
          ],
        ),
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'approvals',
          empty: shown.isEmpty
              ? EmptyNote(
                  icon: Icons.fact_check_outlined,
                  text: _status == BookingStatus.pending
                      ? 'Nothing waiting for approval.'
                      : 'No ${_status?.label.toLowerCase() ?? ''} bookings.',
                )
              : null,
          list: (_) => CardWrap(
            children: [
              for (final booking in shown)
                BookingCard(
                  key: ValueKey('approval-${booking.id}'),
                  booking: booking,
                  onTap: () => widget.onOpenBooking(booking),
                  actions: booking.status == BookingStatus.pending
                      ? [
                          AppButton.outline(
                            key: ValueKey('reject-${booking.id}'),
                            text: 'Reject',
                            height: 44,
                            onPressed: () => widget.onReject(booking),
                          ),
                          AppButton.primary(
                            key: ValueKey('approve-${booking.id}'),
                            text: 'Approve',
                            height: 44,
                            gradient: AppColors.brandGradient,
                            onPressed: () => widget.onApprove(booking),
                          ),
                        ]
                      : const [],
                ),
            ],
          ),
          table: (_) => BookingTable(
            bookings: shown,
            onOpen: widget.onOpenBooking,
            actionsFor: (booking) => booking.status == BookingStatus.pending
                ? [
                    TextButton(
                      key: ValueKey('reject-${booking.id}'),
                      onPressed: () => widget.onReject(booking),
                      child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: ValueKey('approve-${booking.id}'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => widget.onApprove(booking),
                      child: const Text('Approve'),
                    ),
                  ]
                : const [],
          ),
        ),
      ],
    );
  }
}
