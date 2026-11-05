import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/booking_controller.dart';
import 'package:real_estate/core/controllers/construction_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/models/app_user.dart';
import 'package:real_estate/models/booking.dart';
import 'package:real_estate/screens/booking/booking_detail_screen.dart';
import 'package:real_estate/screens/booking/sections/booking_approval_section.dart';
import 'package:real_estate/screens/booking/sections/customers_section.dart';
import 'package:real_estate/screens/booking/sections/payment_tracking_section.dart';
import 'package:real_estate/screens/booking/sections/property_booking_section.dart';
import 'package:real_estate/screens/construction/construction_screen.dart';
import 'package:real_estate/screens/construction/sections/construction_projects_section.dart';
import 'package:real_estate/screens/dashboard/sections/locations_section.dart';
import 'package:real_estate/screens/dashboard/sections/sites_section.dart';
import 'package:real_estate/screens/dashboard/sections/users_section.dart';
import 'package:real_estate/screens/dashboard/widgets/dashboard_section.dart';
import 'package:real_estate/screens/dashboard/widgets/site_card.dart';
import 'package:real_estate/screens/dashboard/widgets/report_table.dart';
import 'package:real_estate/widgets/list_table_switcher.dart';

const _phone = Size(360, 780);
const _desktop = Size(1440, 1000);

Future<void> _pump(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _table(WidgetTester tester, String id) => _tap(tester, find.byKey(ValueKey('view-table-$id')));

/// Taps a row near its left edge: a wide row's center can be off-screen on
/// a phone until it is scrolled sideways.
Future<void> _tapRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey(key));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getTopLeft(row) + const Offset(40, 18));
  await tester.pumpAndSettle();
}

BookingController _bookings() => BookingController(SiteController.test());

void main() {
  setUp(ListTableSwitcher.reset);

  testWidgets('Sites: both views, actions from the table, choice remembered, no overflow', (tester) async {
    for (final size in [_desktop, _phone]) {
      ListTableSwitcher.reset();
      final controller = SiteController.test();
      var edited = '';
      var deleted = '';
      var laidOut = '';
      final search = TextEditingController();
      addTearDown(search.dispose);
      Widget section() => SitesSection(
            controller: controller,
            searchController: search,
            wide: size == _desktop,
            onEditSite: (s) => edited = s.id,
            onDeleteSite: (s) => deleted = s.id,
            onOpenLayout: (s) => laidOut = s.id,
          );

      await _pump(tester, size, section());

      // Starts as today's cards.
      expect(find.byType(SiteCard), findsWidgets);
      expect(find.byType(ReportTable), findsNothing);

      await _table(tester, 'sites');
      expect(find.byType(SiteCard), findsNothing);
      expect(find.byKey(const ValueKey('site-row-s1')), findsOneWidget);
      expect(find.text('Kaira Green Meadows'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Every card action still works from the row menu.
      final menu = find.descendant(of: find.byKey(const ValueKey('site-row-s1')), matching: find.byTooltip('Site actions'));
      for (final (label, check) in [
        ('Edit site', () => edited),
        ('Plot layout', () => laidOut),
        ('Delete site', () => deleted),
      ]) {
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        // Scrolled sideways on a phone: the menu is the row's last cell.
        await tester.dragUntilVisible(menu, find.byType(ReportTable), const Offset(-300, 0));
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(check(), 's1');
      }

      // Coming back to the screen keeps the table.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, size, section());
      expect(find.byKey(const ValueKey('site-row-s1')), findsOneWidget);

      // And back to the cards.
      await _tap(tester, find.byKey(const ValueKey('view-list-sites')));
      expect(find.byType(SiteCard), findsWidgets);
    }
  });

  testWidgets('Sites table shows what filtering leaves, and the empty note', (tester) async {
    final controller = SiteController.test()..setQuery('zzz-none');
    final search = TextEditingController();
    addTearDown(search.dispose);
    await _pump(
      tester,
      _desktop,
      SitesSection(
        controller: controller,
        searchController: search,
        wide: true,
        onEditSite: (_) {},
        onDeleteSite: (_) {},
        onOpenLayout: (_) {},
      ),
    );
    await _table(tester, 'sites');
    expect(find.text('No sites found'), findsOneWidget);
    expect(find.byType(ReportTable), findsNothing);
  });

  testWidgets('Locations table opens the city', (tester) async {
    String? opened;
    await _pump(
      tester,
      _desktop,
      LocationsSection(controller: SiteController.test(), onOpenLocation: (l) => opened = l),
    );
    await _table(tester, 'locations');
    await _tapRow(tester, 'location-row-Chennai');
    expect(opened, 'Chennai');
  });

  testWidgets('Choices are per screen', (tester) async {
    final bookings = _bookings();
    await _pump(tester, _desktop, PropertyBookingSection(controller: bookings, onOpenBooking: (_) {}));
    await _table(tester, 'bookings');
    expect(find.byType(ReportTable), findsOneWidget);

    await _pump(tester, _desktop, CustomersSection(controller: bookings, onOpenBooking: (_) {}));
    expect(find.byType(ReportTable), findsNothing);
  });

  testWidgets('Booking tables open bookings; approvals approve and reject from the row', (tester) async {
    for (final size in [_desktop, _phone]) {
      ListTableSwitcher.reset();
      final bookings = _bookings();
      Booking? opened;
      await _pump(tester, size, PropertyBookingSection(controller: bookings, onOpenBooking: (b) => opened = b));
      await _table(tester, 'bookings');
      expect(tester.takeException(), isNull);
      final first = bookings.bookings.first;
      await _tapRow(tester, 'booking-row-${first.id}');
      expect(opened?.id, first.id);

      final approved = <String>[];
      final rejected = <String>[];
      await _pump(
        tester,
        size,
        BookingApprovalSection(
          controller: bookings,
          onOpenBooking: (_) {},
          onApprove: (b) => approved.add(b.id),
          onReject: (b) => rejected.add(b.id),
        ),
      );
      await _table(tester, 'approvals');
      expect(tester.takeException(), isNull);
      final approve = find.byKey(const ValueKey('approve-b2'));
      await tester.dragUntilVisible(approve, find.byType(ReportTable), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(approve);
      await tester.tap(find.byKey(const ValueKey('reject-b2')));
      await tester.pumpAndSettle();
      expect(approved, ['b2']);
      expect(rejected, ['b2']);
    }
  });

  testWidgets('Payments have separate due and recent tables; customers open their plots', (tester) async {
    final bookings = _bookings();
    Booking? opened;
    await _pump(
      tester,
      _desktop,
      PaymentTrackingSection(controller: bookings, wide: true, onOpenBooking: (b) => opened = b),
    );
    await _table(tester, 'payments-recent');
    expect(find.byType(ReportTable), findsOneWidget);
    await _table(tester, 'payments-due');
    expect(find.byType(ReportTable), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await _pump(tester, _desktop, CustomersSection(controller: bookings, onOpenBooking: (b) => opened = b));
    await _table(tester, 'customers');
    final booking = bookings.bookings.first;
    await _tap(tester, find.byKey(ValueKey('customer-plot-${booking.id}')));
    expect(opened?.id, booking.id);
  });

  testWidgets('Every construction tab has a working table', (tester) async {
    for (final size in [_desktop, _phone]) {
      ListTableSwitcher.reset();
      final construction = ConstructionController(_bookings());
      final project = construction.projectById('b3')!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: ConstructionScreen(projectId: 'b3', controller: construction, userName: 'T')),
      );
      await tester.pumpAndSettle();

      // Stages: tapping a row edits it.
      await _table(tester, 'stages');
      await _tapRow(tester, 'stage-2');
      expect(find.byKey(const ValueKey('stage-submit')), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const ValueKey('tab-dailyWork')));
      await _table(tester, 'daily-work');
      expect(find.byKey(const ValueKey('daily-row-d1')), findsOneWidget);

      // Workers: pay from the row.
      await _tap(tester, find.byKey(const ValueKey('tab-workers')));
      await _table(tester, 'workers');
      final pay = find.byKey(const ValueKey('pay-worker-w1'));
      await tester.dragUntilVisible(pay, find.byKey(const ValueKey('worker-row-w1')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(pay);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('expense-submit')));
      expect(project.wagesDue('w1'), 0);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Materials: edit from the row.
      await _tap(tester, find.byKey(const ValueKey('tab-materials')));
      await _table(tester, 'materials');
      final edit = find.byKey(const ValueKey('edit-material-m2'));
      await tester.dragUntilVisible(edit, find.byKey(const ValueKey('material-row-m2')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Edit Material'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const ValueKey('tab-expenses')));
      await _table(tester, 'expenses');
      expect(find.text('NEFT 1102'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Users table removes others, but not yourself', (tester) async {
    for (final size in [_desktop, _phone]) {
      ListTableSwitcher.reset();
      final users = UserController.test();
      final me = users.findByUsername('manager')!;
      AppUser? removed;
      await _pump(
        tester,
        size,
        UsersSection(controller: users, currentUserId: me.id, onRemoveUser: (u) => removed = u),
      );
      await _table(tester, 'users');
      expect(find.text('${me.name} (You)'), findsOneWidget);
      expect(find.byKey(const ValueKey('user-menu-manager')), findsNothing);
      expect(tester.takeException(), isNull);

      final menu = find.byKey(const ValueKey('user-menu-incharge'));
      await tester.ensureVisible(find.byKey(const ValueKey('user-row-incharge')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(menu, find.byKey(const ValueKey('user-row-incharge')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove user'));
      await tester.pumpAndSettle();
      expect(removed?.username, 'incharge');
    }
  });

  testWidgets('Projects table opens a project; Site Assignment picks the incharge in the row', (tester) async {
    for (final size in [_desktop, _phone]) {
      ListTableSwitcher.reset();
      final users = UserController.test();
      final construction = ConstructionController(_bookings());
      String? opened;
      String? assigned;
      Widget section(DashboardSection s) => ConstructionProjectsSection(
            key: ValueKey(s),
            controller: construction,
            user: users.findByUsername('manager')!,
            section: s,
            incharges: users.usersWithRole(UserRole.siteIncharge),
            wide: size == _desktop,
            onOpenProject: (p, _) => opened = p.id,
            onAssign: (_, id) => assigned = id,
          );

      await _pump(tester, size, section(DashboardSection.progressMonitoring));
      await _table(tester, 'projects');
      expect(find.text('Suresh Reddy'), findsOneWidget);
      await _tapRow(tester, 'project-b3');
      expect(opened, 'b3');

      await _pump(tester, size, section(DashboardSection.siteAssignment));
      expect(tester.takeException(), isNull);
      final picker = find.byKey(const ValueKey('assign-b3'));
      expect(picker, findsOneWidget);
      await tester.dragUntilVisible(picker, find.byKey(const ValueKey('project-b3')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suresh Reddy').last);
      await tester.pumpAndSettle();
      expect(assigned, 'u4');
    }
  });

  testWidgets('Payment history in a booking has a table', (tester) async {
    final bookings = _bookings();
    final withPayments = bookings.bookings.firstWhere((b) => b.payments.isNotEmpty);
    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: BookingDetailScreen(bookingId: withPayments.id, controller: bookings)),
    );
    await tester.pumpAndSettle();
    await _table(tester, 'booking-payments');
    expect(find.byType(ReportTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
