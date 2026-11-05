import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
