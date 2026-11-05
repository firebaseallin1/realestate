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

  @override
  Widget build(BuildContext context) {
    final all = widget.controller.bookings;
    final shown = _type == null ? all : all.where((b) => b.type == _type).toList();

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
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'bookings',
          empty: shown.isEmpty
              ? const EmptyNote(
                  icon: Icons.event_available_outlined,
                  text: 'No bookings yet. Create one with New Booking.',
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
