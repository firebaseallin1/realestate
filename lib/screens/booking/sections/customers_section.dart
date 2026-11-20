import 'package:flutter/material.dart';

import '../../../core/controllers/booking_controller.dart';
import '../../../core/controllers/customer_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/money_text.dart';
import '../../../models/booking.dart';
import '../../../models/customer.dart';
import '../../../models/lead.dart';
import '../../../widgets/band_card.dart';
import '../../../widgets/list_table_switcher.dart';
import '../../dashboard/widgets/report_table.dart';
import '../widgets/booking_widgets.dart';

/// Which customers to show.
enum CustomerFilter {
  notBooked('Not booked yet'),
  booked('Booked');

  const CustomerFilter(this.label);

  final String label;
}

/// One customer: their own record (when converted from a lead) and the
/// plots they have booked, matched on the mobile number.
class _Entry {
  final CustomerProfile? profile;
  final List<Booking> bookings;

  _Entry(this.profile, this.bookings);

  Customer get _booked => bookings.first.customer;
  String get name => profile?.name ?? _booked.name;
  String get mobile => profile?.mobile ?? _booked.mobile;
  String get email => profile?.email ?? _booked.email;
  String get address => profile?.address ?? _booked.address;
  bool get isBooked => bookings.isNotEmpty;
  double get total => bookings.fold<double>(0, (sum, b) => sum + b.totalValue);
}

/// CustomersSection (Sales): every customer, with contact details and their
/// plots. Customers converted from a lead show here straight away, marked
/// Not booked yet with a Book a Plot button. Tapping a plot opens its
/// booking.
class CustomersSection extends StatefulWidget {
  final BookingController controller;
  final CustomerController? customers;
  final ValueChanged<Booking> onOpenBooking;
  final ValueChanged<CustomerProfile>? onBookPlot;

  const CustomersSection({
    super.key,
    required this.controller,
    required this.onOpenBooking,
    this.customers,
    this.onBookPlot,
  });

  @override
  State<CustomersSection> createState() => _CustomersSectionState();
}

class _CustomersSectionState extends State<CustomersSection> {
  CustomerFilter? _filter;

  List<_Entry> _entries() {
    // One entry per mobile number.
    final byMobile = <String, List<Booking>>{};
    for (final booking in widget.controller.bookings) {
      byMobile.putIfAbsent(Lead.mobileKey(booking.customer.mobile), () => []).add(booking);
    }
    final entries = <_Entry>[];
    // Customers with their own record first, newest first.
    for (final profile in widget.customers?.customers ?? const <CustomerProfile>[]) {
      entries.add(_Entry(profile, byMobile.remove(profile.mobileKey) ?? []));
    }
    for (final bookings in byMobile.values) {
      entries.add(_Entry(null, bookings));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final all = _entries();
    if (all.isEmpty) {
      return const EmptyNote(
        icon: Icons.people_alt_outlined,
        text: 'Customers appear here once you convert a lead or book a plot for them.',
      );
    }

    final notBooked = all.where((e) => !e.isBooked).length;
    final shown = switch (_filter) {
      null => all,
      CustomerFilter.notBooked => all.where((e) => !e.isBooked).toList(),
      CustomerFilter.booked => all.where((e) => e.isBooked).toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterChips<CustomerFilter>(
          keyPrefix: 'customer-filter',
          selected: _filter,
          onSelected: (filter) => setState(() => _filter = filter),
          options: [
            (null, 'All', all.length),
            (CustomerFilter.notBooked, CustomerFilter.notBooked.label, notBooked),
            (CustomerFilter.booked, CustomerFilter.booked.label, all.length - notBooked),
          ],
        ),
        const SizedBox(height: 12),
        ListTableSwitcher(
          id: 'customers',
          empty: shown.isEmpty
              ? const EmptyNote(icon: Icons.filter_alt_off_outlined, text: 'No customers match this filter.')
              : null,
          list: (_) => CardWrap(
            children: [
              for (final entry in shown)
                _CustomerCard(entry: entry, onOpenBooking: widget.onOpenBooking, onBookPlot: widget.onBookPlot),
            ],
          ),
          table: (_) => _buildTable(shown),
        ),
      ],
    );
  }

  Widget _buildTable(List<_Entry> entries) {
    return ReportTable(
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
        for (final entry in entries)
          [
            ReportTable.text(entry.name, bold: true),
            ReportTable.text(entry.mobile),
            ReportTable.text(entry.email.isEmpty ? ReportTable.blank : entry.email),
            ReportTable.text(entry.address.isEmpty ? ReportTable.blank : entry.address),
            // One customer can hold several plots: each opens its booking.
            if (!entry.isBooked)
              Align(
                alignment: Alignment.centerLeft,
                child: widget.onBookPlot == null || entry.profile == null
                    ? ReportTable.text('Not booked yet')
                    : TextButton.icon(
                        key: ValueKey('customer-book-row-${entry.profile!.id}'),
                        onPressed: () => widget.onBookPlot!(entry.profile!),
                        icon: const Icon(Icons.event_available_rounded, size: 16),
                        label: const Text('Not booked yet · Book a Plot'),
                      ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final booking in entry.bookings)
                    Material(
                      color: AppColors.mint.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: ValueKey('customer-plot-${booking.id}'),
                        onTap: booking.status == BookingStatus.pending ? null : () => widget.onOpenBooking(booking),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            '${booking.siteName} · Plot ${booking.plotNumber} · ${booking.status.label}',
                            style: AppTypography.caption.copyWith(
                              color: booking.status.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ReportTable.text(entry.isBooked ? MoneyText.short(entry.total) : ReportTable.blank, bold: true),
          ],
      ],
    );
  }
}

/// _CustomerCard: a [BandCard] with the booking count and total value on
/// the band (or New Customer, before a booking), contact details, then each
/// booked plot (tap to open) or a Book a Plot button.
class _CustomerCard extends StatelessWidget {
  final _Entry entry;
  final ValueChanged<Booking> onOpenBooking;
  final ValueChanged<CustomerProfile>? onBookPlot;

  const _CustomerCard({required this.entry, required this.onOpenBooking, required this.onBookPlot});

  @override
  Widget build(BuildContext context) {
    final bookings = entry.bookings;
    final profile = entry.profile;
    final count = bookings.length;
    final pending = bookings.where((b) => b.status == BookingStatus.pending).length;
    final rejected = bookings.where((b) => b.status == BookingStatus.rejected).length;
    final color = entry.isBooked ? AppColors.primary : AppColors.accentGold;

    return BandCard(
      key: ValueKey('customer-${profile?.id ?? Lead.mobileKey(entry.mobile)}'),
      color: color,
      avatar: BandCard.avatarCircle(color, BandCard.initial(entry.name)),
      badges: [
        if (entry.isBooked)
          BandBadge(icon: Icons.event_available_outlined, label: '$count ${count == 1 ? 'booking' : 'bookings'}')
        else
          const BandBadge(icon: Icons.fiber_new_outlined, label: 'New customer'),
        if (pending > 0) BandBadge(icon: BookingStatus.pending.icon, label: '$pending pending approval'),
        if (rejected > 0) BandBadge(icon: BookingStatus.rejected.icon, label: '$rejected rejected'),
        if (profile?.source != null && !entry.isBooked)
          BandBadge(icon: profile!.source!.icon, label: profile.source!.label),
      ],
      trailing: entry.isBooked
          ? Text(
              MoneyText.short(entry.total),
              style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700),
            )
          : null,
      children: [
        BandTitle(title: entry.name, subtitle: entry.mobile),
        const SizedBox(height: 12),
        BandInfoBox(
          children: [
            BandInfoLine(
              icon: Icons.mail_outline_rounded,
              text: entry.email.isEmpty ? 'No email added' : entry.email,
              muted: entry.email.isEmpty,
            ),
            BandInfoLine(
              icon: Icons.home_outlined,
              text: entry.address.isEmpty ? 'No address added' : entry.address,
              muted: entry.address.isEmpty,
            ),
            if (profile != null && profile.alternateMobile.isNotEmpty)
              BandInfoLine(icon: Icons.phone_rounded, text: 'Alternate: ${profile.alternateMobile}'),
            if (profile != null && profile.occupation.isNotEmpty)
              BandInfoLine(icon: Icons.work_outline_rounded, text: profile.occupation),
            if (profile != null && profile.leadId != null)
              BandInfoLine(
                icon: Icons.how_to_reg_rounded,
                text:
                    'Converted from a lead on ${DateText.shortDate(profile.createdAt)}'
                    '${profile.ownerName.isEmpty ? '' : ' by ${profile.ownerName}'}',
                muted: true,
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (!entry.isBooked && profile != null && onBookPlot != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('customer-book-${profile.id}'),
                onPressed: () => onBookPlot!(profile),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('Book a Plot'),
              ),
            ),
          ),
        for (final booking in bookings)
          InkWell(
            key: ValueKey('customer-row-${booking.id}'),
            // Nothing to do until the Admin decides.
            onTap: booking.status == BookingStatus.pending ? null : () => onOpenBooking(booking),
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
                  _StatusDot(status: booking.status),
                  const SizedBox(width: 8),
                  Text(
                    MoneyText.short(booking.totalValue),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    booking.status == BookingStatus.pending ? Icons.lock_clock_outlined : Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMutedLight,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The booking's approval status in its own colour, e.g. Pending Approval.
class _StatusDot extends StatelessWidget {
  final BookingStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            status == BookingStatus.pending ? 'Pending' : status.label,
            style: AppTypography.caption.copyWith(color: status.color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
