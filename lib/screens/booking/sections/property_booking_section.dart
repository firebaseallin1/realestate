import 'package:flutter/material.dart';
import '../../../core/controllers/booking_controller.dart';
import '../../../models/booking.dart';
import '../../../widgets/list_table_switcher.dart';
import '../widgets/booking_widgets.dart';

/// PropertyBookingSection (Sales): every booking as a card or table row,
/// filtered by with / without construction. Tapping one opens its details.
class PropertyBookingSection extends StatefulWidget {
  final BookingController controller;
  final ValueChanged<Booking> onOpenBooking;

  const PropertyBookingSection({
    super.key,
    required this.controller,
    required this.onOpenBooking,
  });

  @override
  State<PropertyBookingSection> createState() => _PropertyBookingSectionState();
}

class _PropertyBookingSectionState extends State<PropertyBookingSection> {
  /// Null shows both types.
  BookingType? _type;

  /// Null shows every approval status.
  BookingStatus? _status;

  @override
  Widget build(BuildContext context) {
    final all = widget.controller.bookings;
    final ofType = _type == null ? all : all.where((b) => b.type == _type).toList();
    final shown = _status == null ? ofType : ofType.where((b) => b.status == _status).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterChips<BookingType>(
          keyPrefix: 'booking-filter',
          selected: _type,
          onSelected: (type) => setState(() => _type = type),
          options: [
            (null, 'All', all.length),
            for (final type in BookingType.values) (type, type.label, all.where((b) => b.type == type).length),
          ],
        ),
        const SizedBox(height: 8),
        FilterChips<BookingStatus>(
          keyPrefix: 'booking-status',
          selected: _status,
          onSelected: (status) => setState(() => _status = status),
          options: [
            (null, 'Any status', ofType.length),
            for (final status in BookingStatus.values)
              (status, status.label, ofType.where((b) => b.status == status).length),
          ],
        ),
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'bookings',
          empty: shown.isEmpty
              ? EmptyNote(
                  icon: Icons.event_available_outlined,
                  text: all.isEmpty ? 'No bookings yet. Create one with New Booking.' : 'No bookings match these filters.',
                )
              : null,
          list: (_) => CardWrap(
            children: [
              for (final booking in shown)
                BookingCard(
                  key: ValueKey('booking-${booking.id}'),
                  booking: booking,
                  onTap: () => widget.onOpenBooking(booking),
                ),
            ],
          ),
          table: (_) => BookingTable(bookings: shown, onOpen: widget.onOpenBooking),
        ),
      ],
    );
  }
}
