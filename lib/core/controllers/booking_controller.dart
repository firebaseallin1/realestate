import 'package:flutter/foundation.dart';
import '../../models/booking.dart';
import '../../models/site.dart';
import 'site_controller.dart';

/// BookingController holds plot bookings and their payments (in memory
/// for now). It keeps the site's units in step: a new booking marks the
/// plot booked, a rejected one frees it, and an approved booking that is
/// fully paid marks it sold.
class BookingController extends ChangeNotifier {
  /// A controller with the sample bookings, keeping [_sites] in step.
  /// The app shares [instance]; tests and previews make their own.
  BookingController(this._sites) {
    _seedBookings();
  }

  static final BookingController instance = BookingController(SiteController.instance);

  final SiteController _sites;
  final List<Booking> _bookings = [];
  int _nextId = 1;

  void _seedBookings() {
    _bookings.addAll([
      Booking(
        id: 'b1',
        siteId: 's1',
        siteName: 'Kaira Green Meadows',
        plotNumber: '12',
        plotSize: '30 × 40 ft',
        facing: PlotFacing.east,
        customer: const Customer(name: 'Ramesh Naidu', mobile: '9849012345', email: 'ramesh@example.com'),
        type: BookingType.withoutConstruction,
        plans: const [
          PaymentPlan(part: PaymentPart.plot, value: 1800000, mode: PaymentMode.fullPayment),
        ],
        payments: [
          PaymentEntry(
            id: 'p1',
            part: PaymentPart.plot,
            amount: 500000,
            date: DateTime(2026, 9, 2),
            method: PaymentMethod.cash,
            reference: 'Token advance',
          ),
        ],
        status: BookingStatus.approved,
        bookedOn: DateTime(2026, 9, 2),
        bookedBy: 'Priya Sharma',
      ),
      Booking(
        id: 'b2',
        siteId: 's7',
        siteName: 'Kaira River Front Plots',
        plotNumber: '5',
        plotSize: '40 × 60 ft',
        facing: PlotFacing.north,
        customer: const Customer(name: 'Lakshmi Prasanna', mobile: '9000011122', address: 'Benz Circle, Vijayawada'),
        type: BookingType.withConstruction,
        plans: const [
          PaymentPlan(
            part: PaymentPart.plot,
            value: 1500000,
            mode: PaymentMode.loan,
            loan: LoanDetails(bankName: 'SBI', amount: 1000000, reference: 'SBI-HL-55120', status: LoanStatus.sanctioned),
          ),
          PaymentPlan(
            part: PaymentPart.construction,
            value: 3500000,
            mode: PaymentMode.loan,
            loan: LoanDetails(bankName: 'HDFC Bank', amount: 2800000, status: LoanStatus.applied),
          ),
        ],
        payments: [
          PaymentEntry(
            id: 'p2',
            part: PaymentPart.plot,
            amount: 500000,
            date: DateTime(2026, 10, 14),
            method: PaymentMethod.bankTransfer,
            reference: 'NEFT 8812',
          ),
        ],
        bookedOn: DateTime(2026, 10, 14),
        bookedBy: 'Priya Sharma',
      ),
      Booking(
        id: 'b3',
        siteId: 's1',
        siteName: 'Kaira Green Meadows',
        plotNumber: '27',
        plotSize: '40 × 50 ft',
        facing: PlotFacing.west,
        customer: const Customer(name: 'Kiran Varma', mobile: '9876543210'),
        type: BookingType.withConstruction,
        plans: const [
          PaymentPlan(part: PaymentPart.plot, value: 2000000, mode: PaymentMode.fullPayment),
          PaymentPlan(part: PaymentPart.construction, value: 4000000, mode: PaymentMode.fullPayment),
        ],
        payments: [
          PaymentEntry(id: 'p3', part: PaymentPart.plot, amount: 2000000, date: DateTime(2026, 8, 20), method: PaymentMethod.cheque, reference: 'CHQ 004512'),
          PaymentEntry(id: 'p4', part: PaymentPart.construction, amount: 1000000, date: DateTime(2026, 9, 25), method: PaymentMethod.upi),
        ],
        status: BookingStatus.approved,
        bookedOn: DateTime(2026, 8, 20),
        bookedBy: 'Priya Sharma',
      ),
    ]);
    _nextId = _bookings.length + 1;
  }

  // Getters
  List<Booking> get bookings => List.unmodifiable(_bookings.reversed);

  Booking? bookingById(String id) {
    for (final booking in _bookings) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  List<Booking> withStatus(BookingStatus? status) =>
      status == null ? bookings : bookings.where((b) => b.status == status).toList();

  int countWithStatus(BookingStatus status) => _bookings.where((b) => b.status == status).length;

  /// Bookings that still count (not rejected), for money totals.
  Iterable<Booking> get _live => _bookings.where((b) => b.status != BookingStatus.rejected);

  double get totalValue => _live.fold(0, (sum, b) => sum + b.totalValue);
  double get totalCollected => _live.fold(0, (sum, b) => sum + b.totalPaid);
  double get totalOutstanding => _live.fold(0, (sum, b) => sum + b.balance);
  int get loanCount => _live.where((b) => b.hasLoan).length;

  /// Every payment received, newest first, with its booking.
  List<(Booking, PaymentEntry)> get recentPayments {
    final all = [
      for (final b in _live)
        for (final p in b.payments) (b, p),
    ]..sort((a, b) => b.$2.date.compareTo(a.$2.date));
    return all;
  }

  /// True when a live booking already holds plot [number] at [siteId].
  bool isPlotTaken(String siteId, String number) {
    final key = number.trim().toLowerCase();
    return _live.any((b) => b.siteId == siteId && b.plotNumber.toLowerCase() == key);
  }

  String newId() => 'b${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  void addBooking(Booking booking) {
    _bookings.add(booking);
    _moveUnit(booking, from: PlotStatus.available, to: PlotStatus.booked);
    notifyListeners();
  }

  void approve(String id) => _setStatus(id, BookingStatus.approved);

  void reject(String id) => _setStatus(id, BookingStatus.rejected);

  void _setStatus(String id, BookingStatus status) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final before = _bookings[index];
    if (before.status == status) return;
    final after = before.copyWith(status: status);
    _bookings[index] = after;

    if (status == BookingStatus.rejected) {
      _moveUnit(before, from: _unitStatus(before), to: PlotStatus.available);
    } else if (after.isFullyPaid) {
      _moveUnit(after, from: PlotStatus.booked, to: PlotStatus.sold);
    }
    notifyListeners();
  }

  /// Records [payment] against booking [id]. Rejected bookings take none.
  void addPayment(String id, PaymentEntry payment) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1 || _bookings[index].status == BookingStatus.rejected) return;
    final before = _bookings[index];
    final after = before.copyWith(payments: [...before.payments, payment]);
    _bookings[index] = after;

    if (after.status == BookingStatus.approved && after.isFullyPaid && !before.isFullyPaid) {
      _moveUnit(after, from: PlotStatus.booked, to: PlotStatus.sold);
    }
    notifyListeners();
  }

  PlotStatus _unitStatus(Booking b) =>
      b.status == BookingStatus.approved && b.isFullyPaid ? PlotStatus.sold : PlotStatus.booked;

  /// Moves the booking's unit between statuses on its site: the drawn plot
  /// when there is one, otherwise the site's booked / sold counts.
  void _moveUnit(Booking booking, {required PlotStatus from, required PlotStatus to}) {
    final site = _sites.siteById(booking.siteId);
    if (site == null || from == to) return;

    if (site.hasLayout && booking.plotId != null) {
      _sites.updateSite(site.withPlots([
        for (final plot in site.plots) plot.id == booking.plotId ? plot.copyWith(status: to) : plot,
      ]));
      return;
    }

    int delta(PlotStatus s) => (to == s ? 1 : 0) - (from == s ? 1 : 0);
    final booked = (site.bookedUnits + delta(PlotStatus.booked)).clamp(0, site.totalUnits);
    final sold = (site.soldUnits + delta(PlotStatus.sold)).clamp(0, site.totalUnits);
    _sites.updateSite(site.copyWith(bookedUnits: booked, soldUnits: sold));
  }
}
