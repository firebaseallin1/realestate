import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/api/api_client.dart';
import 'package:real_estate/core/controllers/booking_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/core/utils/money_text.dart';
import 'package:real_estate/models/booking.dart';
import 'package:real_estate/models/site.dart';
import 'package:real_estate/screens/booking/booking_detail_screen.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';

class _Setup {
  final SiteController sites;
  final BookingController bookings;

  _Setup(this.sites, this.bookings);
}

Future<_Setup> _pump(WidgetTester tester, Size size, String username) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final sites = SiteController.test();
  final bookings = BookingController(sites);
  final users = UserController.test();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: users.findByUsername(username)),
        builder: (_) => DashboardScreen(controller: sites, userController: users, bookingController: bookings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Setup(sites, bookings);
}

/// Opens a menu page by key, through the drawer on phone.
Future<void> _openMenu(WidgetTester tester, String name) async {
  final item = find.byKey(ValueKey('menu-$name'));
  if (item.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await tester.pumpAndSettle();
  }
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(find.descendant(of: field, matching: find.byType(TextFormField)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(360, 780);
  const desktop = Size(1440, 1000);

  group('BookingController', () {
    test('Booking, rejecting and paying in full move the site\'s units', () {
      final sites = SiteController.test();
      final bookings = BookingController(sites);
      final s7 = sites.siteById('s7')!;

      final booking = Booking(
        id: 'n1',
        siteId: 's7',
        siteName: s7.name,
        plotNumber: '99',
        customer: const Customer(name: 'Test', mobile: '9999999999'),
        type: BookingType.withoutConstruction,
        plans: const [PaymentPlan(part: PaymentPart.plot, value: 1000000, mode: PaymentMode.fullPayment)],
        bookedOn: DateTime(2026, 10, 1),
        bookedBy: 'Tester',
      );
      bookings.addBooking(booking);
      expect(sites.siteById('s7')!.bookedUnits, s7.bookedUnits + 1);
      expect(bookings.isPlotTaken('s7', '99'), isTrue);

      // Approved and fully paid: sold.
      bookings.approve('n1');
      bookings.addPayment(
        'n1',
        PaymentEntry(id: 'x', part: PaymentPart.plot, amount: 1000000, date: DateTime(2026, 10, 2), method: PaymentMethod.cash),
      );
      expect(sites.siteById('s7')!.bookedUnits, s7.bookedUnits);
      expect(sites.siteById('s7')!.soldUnits, s7.soldUnits + 1);

      // Rejecting frees the unit again.
      bookings.reject('n1');
      expect(sites.siteById('s7')!.soldUnits, s7.soldUnits);
      expect(bookings.isPlotTaken('s7', '99'), isFalse);
    });

    test('A plot picked from the layout changes status on the map', () {
      final sites = SiteController.test();
      final bookings = BookingController(sites);
      final site = sites.siteById('s1')!;
      sites.updateSite(site.withPlots(const [
        Plot(id: 'p1', number: '1', widthFt: 30, lengthFt: 40, facing: PlotFacing.east, status: PlotStatus.available, rect: Rect.fromLTWH(0, 0, 0.1, 0.1)),
        Plot(id: 'p2', number: '2', widthFt: 30, lengthFt: 40, facing: PlotFacing.west, status: PlotStatus.available, rect: Rect.fromLTWH(0.2, 0, 0.1, 0.1)),
      ]));

      bookings.addBooking(Booking(
        id: 'n2',
        siteId: 's1',
        siteName: site.name,
        plotNumber: '2',
        plotId: 'p2',
        customer: const Customer(name: 'Test', mobile: '9999999999'),
        type: BookingType.withoutConstruction,
        plans: const [PaymentPlan(part: PaymentPart.plot, value: 500000, mode: PaymentMode.fullPayment)],
        bookedOn: DateTime(2026, 10, 1),
        bookedBy: 'Tester',
      ));
      expect(sites.siteById('s1')!.plots.last.status, PlotStatus.booked);
      expect(sites.siteById('s1')!.bookedUnits, 1);

      bookings.reject('n2');
      expect(sites.siteById('s1')!.plots.last.status, PlotStatus.available);
    });

    test('Money is shown the Indian way', () {
      expect(MoneyText.full(4500000), '₹45,00,000');
      expect(MoneyText.full(950), '₹950');
      expect(MoneyText.short(1250000), '₹12.5 L');
      expect(MoneyText.short(12000000), '₹1.2 Cr');
      expect(MoneyText.parse('15,00,000'), 1500000);
    });
  });

  testWidgets('Sales books a plot with construction and a loan, then records a payment', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = await _pump(tester, size, 'sales');
      final s7Booked = setup.sites.siteById('s7')!.bookedUnits;

      await _openMenu(tester, 'propertyBooking');
      expect(find.byKey(const ValueKey('booking-b2')), findsOneWidget);

      await tester.tap(size == phone ? find.byType(FloatingActionButton) : find.text('New Booking'));
      await tester.pumpAndSettle();

      // Required fields are checked.
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      expect(find.text('Please select a site.'), findsOneWidget);
      expect(find.text('Please enter the customer name.'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('booking-site')));
      await tester.tap(find.text('Kaira River Front Plots').last);
      await tester.pumpAndSettle();

      // Plot 5 is already booked at this site.
      await _type(tester, 'booking-plot-number', '5');
      await _type(tester, 'customer-name', 'Anitha Rao');
      await _type(tester, 'customer-mobile', '98765 43210');
      await _tap(tester, find.byKey(const ValueKey('type-withConstruction')));
      await _type(tester, 'plot-value', '15,00,000');
      await _tap(tester, find.byKey(const ValueKey('plot-mode-loan')));
      await _type(tester, 'plot-loan-bank', 'SBI');
      await _type(tester, 'plot-loan-amount', '1000000');
      await _type(tester, 'construction-value', '3000000');
      expect(find.text('₹45,00,000'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      expect(find.text('Plot 5 is already booked.'), findsOneWidget);

      await _type(tester, 'booking-plot-number', '9');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      // Let the confirmation snackbar go.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final booking = setup.bookings.bookings.first;
      expect(booking.customer.name, 'Anitha Rao');
      expect(booking.type, BookingType.withConstruction);
      expect(booking.plans.length, 2);
      expect(booking.plan(PaymentPart.plot)!.loan!.bankName, 'SBI');
      expect(booking.plan(PaymentPart.construction)!.mode, PaymentMode.fullPayment);
      expect(booking.status, BookingStatus.pending);
      expect(setup.sites.siteById('s7')!.bookedUnits, s7Booked + 1);

      // Payments start once the Admin approves.
      await setup.bookings.approve(booking.id);
      await tester.pumpAndSettle();

      // Open it and record a payment against the plot value.
      await _tap(tester, find.byKey(ValueKey('booking-${booking.id}')));
      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(find.text('SBI'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('record-payment')));
      await _type(tester, 'payment-amount', '20,00,000');
      await _tap(tester, find.byKey(const ValueKey('payment-method-plot')));
      await tester.tap(find.text('UPI').last);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('payment-submit')));
      expect(find.text('More than the balance of ₹15,00,000.'), findsOneWidget);

      await _type(tester, 'payment-amount', '500000');
      await _tap(tester, find.byKey(const ValueKey('payment-submit')));

      final updated = setup.bookings.bookingById(booking.id)!;
      expect(updated.paidFor(PaymentPart.plot), 500000);
      expect(updated.balance, 4000000);
      expect(find.text('Payment History'), findsOneWidget);
      expect(find.text('₹5,00,000'), findsWidgets);
    }
  });

  testWidgets('Changing the type clears payments; part of the own share is paid at booking', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = await _pump(tester, size, 'sales');
      await _openMenu(tester, 'propertyBooking');
      await tester.tap(size == phone ? find.byType(FloatingActionButton) : find.text('New Booking'));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const ValueKey('booking-site')));
      await tester.tap(find.text('Kaira River Front Plots').last);
      await tester.pumpAndSettle();
      await _type(tester, 'booking-plot-number', '31');
      await _type(tester, 'customer-name', 'Ravi Teja');
      await _type(tester, 'customer-mobile', '9876543210');

      // Filled in, then the type changes: the payment details start again.
      await _tap(tester, find.byKey(const ValueKey('type-withConstruction')));
      await _type(tester, 'plot-value', '700000');
      await _tap(tester, find.byKey(const ValueKey('plot-mode-loan')));
      await _type(tester, 'construction-value', '2000000');
      await _tap(tester, find.byKey(const ValueKey('type-withoutConstruction')));
      expect(find.byKey(const ValueKey('construction-value')), findsNothing);
      expect(find.byKey(const ValueKey('plot-loan-bank')), findsNothing);
      final plotValue = find.descendant(of: find.byKey(const ValueKey('plot-value')), matching: find.byType(TextFormField));
      expect(tester.widget<TextFormField>(plotValue).controller!.text, isEmpty);

      // Plot ₹6,50,000 on a ₹5,00,000 loan: the customer's share is ₹1,50,000.
      await _type(tester, 'plot-value', '650000');
      await _tap(tester, find.byKey(const ValueKey('plot-mode-loan')));
      await _type(tester, 'plot-loan-bank', 'HDFC');
      await _type(tester, 'plot-loan-amount', '500000');
      await _type(tester, 'plot-paid-now', '200000');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      expect(find.text("More than the customer's share (₹1,50,000)."), findsOneWidget);

      await _type(tester, 'plot-paid-now', '50000');
      expect(find.text('Still to pay ₹1,00,000', findRichText: true), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('plot-paid-method')));
      await tester.tap(find.text('UPI').last);
      await tester.pumpAndSettle();
      await _type(tester, 'plot-paid-reference', 'UTR778');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final booking = setup.bookings.bookings.firstWhere((b) => b.customer.name == 'Ravi Teja');
      expect(booking.type, BookingType.withoutConstruction);
      expect(booking.plan(PaymentPart.plot)!.loan!.amount, 500000);
      expect(booking.payments, hasLength(1));
      expect(booking.payments.single.amount, 50000);
      expect(booking.payments.single.method, PaymentMethod.upi);
      expect(booking.payments.single.reference, 'UTR778');
      expect(booking.balance, 600000);
      expect(booking.toCreateJson()['initialPayments'], hasLength(1));
    }
  });

  testWidgets('Payment tracking and customers list the bookings', (tester) async {
    for (final size in [desktop, phone]) {
      await _pump(tester, size, 'sales');

      await _openMenu(tester, 'paymentTracking');
      expect(find.text('Balance Due'), findsOneWidget);
      expect(find.text('Recent Payments'), findsOneWidget);
      expect(find.byKey(const ValueKey('due-b2')), findsOneWidget);

      await _openMenu(tester, 'customers');
      expect(find.text('Lakshmi Prasanna'), findsOneWidget);
      expect(find.text('Kiran Varma'), findsOneWidget);
    }
  });

  testWidgets('Admin approves and rejects pending bookings', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = await _pump(tester, size, 'admin');
      final s7Booked = setup.sites.siteById('s7')!.bookedUnits;

      await _openMenu(tester, 'bookingApproval');
      expect(find.byKey(const ValueKey('approval-b2')), findsOneWidget);
      expect(find.byKey(const ValueKey('approval-b1')), findsNothing);

      await _tap(tester, find.byKey(const ValueKey('reject-b2')));
      await tester.tap(find.widgetWithText(TextButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(setup.bookings.bookingById('b2')!.status, BookingStatus.rejected);
      expect(setup.sites.siteById('s7')!.bookedUnits, s7Booked - 1);
      expect(find.text('Nothing waiting for approval.'), findsOneWidget);

      // Rejected list, then approve from the detail page of a new pending one.
      await _tap(tester, find.byKey(const ValueKey('approval-filter-rejected')));
      expect(find.byKey(const ValueKey('approval-b2')), findsOneWidget);
    }
  });

  testWidgets('Admin approves from the booking page', (tester) async {
    final setup = await _pump(tester, desktop, 'admin');

    await _openMenu(tester, 'bookingApproval');
    await _tap(tester, find.byKey(const ValueKey('approval-b2')));
    expect(find.byKey(const ValueKey('plan-plot')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-construction')), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('detail-approve')));
    expect(setup.bookings.bookingById('b2')!.status, BookingStatus.approved);
    expect(find.byKey(const ValueKey('detail-approve')), findsNothing);
  });

  testWidgets('Loan disbursements move the loan status; it can be marked before then', (tester) async {
    final setup = await _pump(tester, desktop, 'sales');
    await setup.bookings.approve('b2');
    await _openMenu(tester, 'propertyBooking');
    await _tap(tester, find.byKey(const ValueKey('booking-b2')));

    // The construction loan is Applied; mark it Sanctioned.
    expect(find.byKey(const ValueKey('loan-status-construction')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('loan-status-menu-construction')));
    await tester.tap(find.text('Sanctioned').last);
    await tester.pumpAndSettle();
    expect(setup.bookings.bookingById('b2')!.plan(PaymentPart.construction)!.loan!.status, LoanStatus.sanctioned);

    Future<void> disburse(String amount) async {
      await _tap(tester, find.byKey(const ValueKey('record-payment')));
      await _type(tester, 'payment-amount', amount);
      await _tap(tester, find.byKey(const ValueKey('payment-method-plot')));
      await tester.tap(find.text('Loan Disbursement').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('loan-note')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('payment-submit')));
    }

    // The SBI plot loan is ₹10,00,000: part of it, then more than is left.
    await disburse('400000');
    LoanDetails plotLoan() => setup.bookings.bookingById('b2')!.plan(PaymentPart.plot)!.loan!;
    expect(plotLoan().status, LoanStatus.partlyDisbursed);
    expect(find.text('Partly Disbursed'), findsOneWidget);

    await disburse('700000');
    expect(find.text('More than the balance of ₹6,00,000.'), findsOneWidget);
    await _type(tester, 'payment-amount', '600000');
    await _tap(tester, find.byKey(const ValueKey('payment-submit')));
    expect(plotLoan().status, LoanStatus.disbursed);

    // Disbursed: the status follows the payments, so no menu.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loan-status-menu-plot')), findsNothing);
    expect(setup.bookings.bookingById('b2')!.loanToComeFor(PaymentPart.plot), 0);
  });

  testWidgets('Only approved bookings can be edited, never below what is paid', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = await _pump(tester, size, 'sales');
      await _openMenu(tester, 'propertyBooking');

      // Pending: no edit.
      await _tap(tester, find.byKey(const ValueKey('booking-b2')));
      expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Approved b1: ₹18,00,000 plot, ₹5,00,000 paid.
      await _tap(tester, find.byKey(const ValueKey('booking-b1')));
      await _tap(tester, find.byKey(const ValueKey('detail-edit')));
      expect(find.text('Edit Booking'), findsWidgets);
      expect(find.byKey(const ValueKey('booking-site')), findsNothing);
      expect(find.byKey(const ValueKey('plot-paid-now')), findsNothing);

      await _type(tester, 'customer-address', 'Madhapur, Hyderabad');
      await _type(tester, 'plot-value', '400000');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      expect(find.text('₹5,00,000 is already paid; it cannot be less.'), findsOneWidget);

      // A bank loan for part of it.
      await _type(tester, 'plot-value', '1900000');
      await _tap(tester, find.byKey(const ValueKey('plot-mode-loan')));
      await _type(tester, 'plot-loan-bank', 'Axis Bank');
      await _type(tester, 'plot-loan-amount', '1000000');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final b1 = setup.bookings.bookingById('b1')!;
      expect(b1.customer.address, 'Madhapur, Hyderabad');
      expect(b1.customer.name, 'Ramesh Naidu');
      expect(b1.plan(PaymentPart.plot)!.value, 1900000);
      expect(b1.plan(PaymentPart.plot)!.loan!.bankName, 'Axis Bank');
      expect(b1.payments, hasLength(1));
      expect(find.text('Axis Bank'), findsOneWidget);
    }
  });

  testWidgets('Sales sees approval status, and sends a rejected booking back for approval', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = await _pump(tester, size, 'sales');
      final s7 = setup.sites.siteById('s7')!;

      // b2 waits for approval: the customers list says so.
      await _openMenu(tester, 'customers');
      expect(find.text('1 pending approval'), findsOneWidget);

      // The Admin rejects it; Sales finds it with the status filter.
      await setup.bookings.reject('b2');
      await tester.pumpAndSettle();
      expect(setup.sites.siteById('s7')!.bookedUnits, s7.bookedUnits - 1);
      await _openMenu(tester, 'propertyBooking');
      await _tap(tester, find.byKey(const ValueKey('booking-status-rejected')));
      expect(find.byKey(const ValueKey('booking-b2')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-b1')), findsNothing);

      // Rejected: no payments or plain edit, but edit & re-submit.
      await _tap(tester, find.byKey(const ValueKey('booking-b2')));
      expect(find.byKey(const ValueKey('record-payment')), findsNothing);
      expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('detail-edit-resubmit')));
      expect(find.text('Edit & Re-submit'), findsOneWidget);
      await _type(tester, 'customer-address', 'Labbipet, Vijayawada');
      await _tap(tester, find.byKey(const ValueKey('booking-submit')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final b2 = setup.bookings.bookingById('b2')!;
      expect(b2.status, BookingStatus.pending);
      expect(b2.customer.address, 'Labbipet, Vijayawada');
      expect(setup.sites.siteById('s7')!.bookedUnits, s7.bookedUnits);
      expect(find.byKey(const ValueKey('detail-resubmit')), findsNothing);
    }
  });

  test('A rejected booking cannot come back once its plot is taken', () async {
    final sites = SiteController.test();
    final bookings = BookingController(sites);
    await bookings.reject('b2');
    final b2 = bookings.bookingById('b2')!;
    await bookings.addBooking(Booking(
      id: 'n9',
      siteId: b2.siteId,
      siteName: b2.siteName,
      plotNumber: b2.plotNumber,
      customer: const Customer(name: 'Other', mobile: '9999999999'),
      type: BookingType.withoutConstruction,
      plans: const [PaymentPlan(part: PaymentPart.plot, value: 100, mode: PaymentMode.fullPayment)],
      bookedOn: DateTime(2026, 11, 1),
      bookedBy: 'Tester',
    ));
    await expectLater(bookings.resubmit(b2), throwsA(isA<ApiException>()));
    expect(bookings.bookingById('b2')!.status, BookingStatus.rejected);
  });

  testWidgets('A booking waiting for approval is read-only for Sales', (tester) async {
    final setup = await _pump(tester, desktop, 'sales');

    // In the customers list the pending plot does not open.
    await _openMenu(tester, 'customers');
    await tester.tap(find.byKey(const ValueKey('customer-row-b2')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingDetailScreen), findsNothing);

    // Its details offer no payment, edit or loan change.
    await _openMenu(tester, 'propertyBooking');
    await _tap(tester, find.byKey(const ValueKey('booking-b2')));
    expect(find.byKey(const ValueKey('record-payment')), findsNothing);
    expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
    expect(find.byKey(const ValueKey('loan-status-menu-plot')), findsNothing);

    // Once approved, payments and edits open up.
    await setup.bookings.approve('b2');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record-payment')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
  });
}
